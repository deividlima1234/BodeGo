import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/models/sync_movement.dart';
import 'package:bodego/core/services/google_sheets_sync_service.dart';

/// Servicio de Cola Offline Persistente para Movimientos Transaccionales.
/// Garantiza que la app NUNCA se cuelgue ni bloquee la experiencia del usuario
/// si no hay acceso a internet. Guarda los movimientos en disco y los despacha
/// a Google Sheets cuando haya conexión.
class SyncQueueService {
  static const String _fileName = 'sync_movement_queue.json';

  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  bool _isProcessing = false;
  Timer? _periodicTimer;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Inicializa el contador de pendientes al iniciar la app y arranca el monitor de red
  Future<void> init() async {
    await updatePendingCount();
    _startBackgroundSyncer();
  }

  void _startBackgroundSyncer() {
    _periodicTimer?.cancel();
    // Reintentar periódicamente cada 45 segundos para sincronizar al volver el internet
    _periodicTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      triggerBackgroundSync();
    });
    // Intento rápido a los 4 segundos tras iniciar la app
    Future.delayed(const Duration(seconds: 4), () {
      triggerBackgroundSync();
    });
  }

  /// Carga todos los movimientos almacenados en la cola
  Future<List<SyncMovement>> getAllMovements() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> list = jsonDecode(content) as List<dynamic>;
      return list
          .map((j) => SyncMovement.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error leyendo cola de sincronización: $e');
      return [];
    }
  }

  /// Obtiene los movimientos pendientes de sincronizar
  Future<List<SyncMovement>> getPendingMovements() async {
    final all = await getAllMovements();
    return all.where((m) => !m.isSynced).toList();
  }

  /// Actualiza el ValueNotifier con el conteo actual de pendientes
  Future<int> updatePendingCount() async {
    final pending = await getPendingMovements();
    pendingCountNotifier.value = pending.length;
    return pending.length;
  }

  Future<void> _saveMovements(List<SyncMovement> movements) async {
    final file = await _getFile();
    // Conservar los últimos 1500 movimientos para evitar crecimiento desmedido
    final truncated = movements.length > 1500
        ? movements.sublist(movements.length - 1500)
        : movements;
    final jsonString = jsonEncode(truncated.map((m) => m.toJson()).toList());
    await file.writeAsString(jsonString);
    pendingCountNotifier.value = truncated.where((m) => !m.isSynced).length;
  }

  /// Encola un movimiento transaccional genérico
  Future<void> enqueueMovement(SyncMovement movement) async {
    final all = await getAllMovements();
    all.add(movement);
    await _saveMovements(all);

    // Intentar despachar en segundo plano sin bloquear la UI
    _triggerAutoSyncSilently();
  }

  /// Encola una Venta realizada (contado o fiado)
  Future<void> enqueueSaleTicket(SaleTicket ticket) async {
    final license = await LicenseService().init();
    final movement = SyncMovement(
      id: 'MOV_SALE_${ticket.id}',
      timestamp: ticket.date,
      deviceId: license.machineId,
      type: 'VENTA',
      detail: '${ticket.isCredit ? "Venta Fiada" : "Venta"} ${ticket.ticketNumber} - Total: S/ ${ticket.total.toStringAsFixed(2)}',
      data: {
        'ticket': ticket.toJson(),
      },
      isSynced: false,
    );
    await enqueueMovement(movement);
  }

  /// Encola un Pago de Deuda (Abono de fiado de un cliente)
  Future<void> enqueueDebtPayment({
    required int customerId,
    required String customerName,
    required double amount,
  }) async {
    final license = await LicenseService().init();
    final movement = SyncMovement(
      id: 'MOV_PAY_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      deviceId: license.machineId,
      type: 'ABONO_DEUDA',
      detail: 'Abono de S/ ${amount.toStringAsFixed(2)} por $customerName',
      data: {
        'customerId': customerId,
        'customerName': customerName,
        'amount': amount,
      },
      isSynced: false,
    );
    await enqueueMovement(movement);
  }

  /// Encola un Ingreso de Mercadería o Reposición de Stock
  Future<void> enqueueStockReplenish({
    required int productId,
    required String productName,
    required double quantity,
    double? newCostPrice,
    double? newSalePrice,
  }) async {
    final license = await LicenseService().init();
    final movement = SyncMovement(
      id: 'MOV_STOCK_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      deviceId: license.machineId,
      type: 'REPOSICION_STOCK',
      detail: 'Ingreso de $quantity unds a $productName',
      data: {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'newCostPrice': newCostPrice,
        'newSalePrice': newSalePrice,
      },
      isSynced: false,
    );
    await enqueueMovement(movement);
  }

  /// Marca una lista de movimientos como sincronizados
  Future<void> markAsSynced(List<String> movementIds) async {
    final all = await getAllMovements();
    final updated = all.map((m) {
      if (movementIds.contains(m.id)) {
        return m.copyWith(isSynced: true);
      }
      return m;
    }).toList();
    await _saveMovements(updated);
  }

  /// Dispara la sincronización en segundo plano sin colgar ni esperar
  void _triggerAutoSyncSilently() {
    triggerBackgroundSync();
  }

  /// Sincronizador resiliente: auto-registra cuentas creadas offline y despacha la cola
  Future<void> triggerBackgroundSync() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final syncService = GoogleSheetsSyncService();
      final config = await syncService.getConfig();
      if (!config.isEnabled || !config.isConfigured) return;

      // 1. Si la cuenta fue creada sin internet, auto-registrarla en cuanto haya conexión
      if (!config.isTenantAuthenticated) {
        final registered = await syncService.ensureTenantRegistered();
        if (!registered) return;
      }

      // 2. Si hay movimientos en cola, despacharlos
      final pending = await getPendingMovements();
      if (pending.isNotEmpty) {
        await syncService.processPendingQueue();
      }
    } catch (e) {
      debugPrint('Sincronización periódica en segundo plano omitida: $e');
    } finally {
      _isProcessing = false;
      await updatePendingCount();
    }
  }

  /// Vacía la cola local (útil para reiniciar o limpiar datos)
  Future<void> clearQueue() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
    pendingCountNotifier.value = 0;
  }
}

