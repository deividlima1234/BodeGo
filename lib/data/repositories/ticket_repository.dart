import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/data/models/sale_ticket.dart';

/// Repositorio local para la persistencia y consulta del Historial de Tickets de Venta.
class TicketRepository {
  static const String _fileName = 'sales_tickets.json';

  /// Notificador reactivo que se incrementa cada vez que hay cambios en los tickets
  /// (nuevas ventas, tickets descargados en segundo plano o sincronizados).
  static final ValueNotifier<int> ticketsVersionNotifier = ValueNotifier<int>(0);

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Obtiene todos los tickets reales ordenados cronológicamente de forma descendente.
  Future<List<SaleTicket>> getTickets() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      return await _readFromFile(file);
    } catch (e) {
      return [];
    }
  }

  Future<List<SaleTicket>> _readFromFile(File file) async {
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> list = jsonDecode(content) as List<dynamic>;

      // Filtrar y eliminar de raíz cualquier ticket de prueba previo (TKT_SEED)
      final tickets = list
          .map((json) => SaleTicket.fromJson(json as Map<String, dynamic>))
          .where((t) => !t.id.contains('SEED') && !t.ticketNumber.contains('SEED'))
          .toList();

      // Si había tickets falsos en el archivo, rescribirlo inmediatamente 100% limpio
      if (tickets.length != list.length) {
        final jsonString = jsonEncode(tickets.map((t) => t.toJson()).toList());
        await file.writeAsString(jsonString);
      }

      // Ordenar de más reciente a más antiguo
      tickets.sort((a, b) => b.date.compareTo(a.date));
      return tickets;
    } catch (_) {
      return [];
    }
  }

  /// Calcula el siguiente número correlativo inspeccionando el valor numérico máximo
  /// entre todos los tickets locales y sincronizados, evitando colisiones.
  int getNextTicketSequence(List<SaleTicket> tickets) {
    int maxNumber = 0;
    final regex = RegExp(r'(\d+)');
    for (final t in tickets) {
      final matches = regex.allMatches(t.ticketNumber);
      if (matches.isNotEmpty) {
        final val = int.tryParse(matches.last.group(0)!) ?? 0;
        if (val > maxNumber) maxNumber = val;
      }
    }
    return maxNumber + 1;
  }

  /// Crea y persiste un nuevo ticket de venta con correlativo autoincremental seguro.
  Future<SaleTicket> createTicket({
    required double total,
    double? subtotal,
    double discount = 0.0,
    required bool isCredit,
    int? customerId,
    String? customerName,
    double? previousDebt,
    double? newDebt,
    required String cashierName,
    required String businessName,
    required List<SaleTicketItem> items,
    bool? isSynced,
  }) async {
    final existingTickets = await getTickets();

    // Generar correlativo incremental basado en el máximo existente
    final int nextNumber = getNextTicketSequence(existingTickets);
    final String formattedNumber = 'TKT-${nextNumber.toString().padLeft(4, '0')}';
    final String id = 'TKT_${DateTime.now().millisecondsSinceEpoch}';

    final ticket = SaleTicket(
      id: id,
      ticketNumber: formattedNumber,
      date: DateTime.now(),
      subtotal: subtotal ?? (total + discount),
      discount: discount,
      total: total,
      isCredit: isCredit,
      customerId: customerId,
      customerName: customerName,
      previousDebt: previousDebt,
      newDebt: newDebt,
      cashierName: cashierName,
      businessName: businessName,
      items: items,
      isSynced: isSynced ?? false,
    );

    existingTickets.insert(0, ticket);

    final file = await _getFile();
    final jsonString = jsonEncode(existingTickets.map((t) => t.toJson()).toList());
    await file.writeAsString(jsonString);
    ticketsVersionNotifier.value++;

    return ticket;
  }

  /// Obtiene los tickets pendientes de sincronizar hacia la Caja Master
  Future<List<SaleTicket>> getPendingSyncTickets() async {
    final tickets = await getTickets();
    return tickets.where((t) => !t.isSynced).toList();
  }

  /// Marca una lista de tickets como sincronizados
  Future<void> markTicketsAsSynced(List<String> ticketIds) async {
    final tickets = await getTickets();
    final updated = tickets.map((t) {
      if (ticketIds.contains(t.id)) {
        return t.copyWith(isSynced: true);
      }
      return t;
    }).toList();

    final file = await _getFile();
    final jsonString = jsonEncode(updated.map((t) => t.toJson()).toList());
    await file.writeAsString(jsonString);
    ticketsVersionNotifier.value++;
  }

  /// Fusiona tickets foráneos recibidos de la nube o de una terminal evitando duplicados
  /// y sincronizando renumeraciones o correcciones de correlativo desde la nube.
  Future<int> mergeIncomingTickets(List<SaleTicket> incoming) async {
    final currentTickets = await getTickets();
    final Map<String, SaleTicket> ticketMap = {for (final t in currentTickets) t.id: t};

    int changesCount = 0;
    for (final inc in incoming) {
      if (!ticketMap.containsKey(inc.id)) {
        ticketMap[inc.id] = inc.copyWith(isSynced: true);
        changesCount++;
      } else {
        final existing = ticketMap[inc.id]!;
        // Si el número de ticket fue renumerado o corregido en la nube, actualizarlo localmente
        if (existing.ticketNumber != inc.ticketNumber) {
          ticketMap[inc.id] = existing.copyWith(
            ticketNumber: inc.ticketNumber,
            isSynced: true,
          );
          changesCount++;
        }
      }
    }

    if (changesCount > 0) {
      final updatedList = ticketMap.values.toList();
      updatedList.sort((a, b) => b.date.compareTo(a.date));
      final file = await _getFile();
      final jsonString = jsonEncode(updatedList.map((t) => t.toJson()).toList());
      await file.writeAsString(jsonString);
      ticketsVersionNotifier.value++;
    }

    return changesCount;
  }

  /// Obtiene un ticket por su identificador.
  Future<SaleTicket?> getTicketById(String id) async {
    final tickets = await getTickets();
    try {
      return tickets.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Retorna un resumen métrico de las ventas del día actual con datos estrictamente reales.
  Future<Map<String, dynamic>> getTodaySummary() async {
    final tickets = await getTickets();
    final now = DateTime.now();

    final todayTickets = tickets.where((t) =>
        t.date.year == now.year &&
        t.date.month == now.month &&
        t.date.day == now.day).toList();

    double totalCash = 0.0;
    double totalCredit = 0.0;

    for (final t in todayTickets) {
      if (t.isCredit) {
        totalCredit += t.total;
      } else {
        totalCash += t.total;
      }
    }

    return {
      'count': todayTickets.length,
      'total': totalCash + totalCredit,
      'cashTotal': totalCash,
      'creditTotal': totalCredit,
    };
  }

  /// Limpia todos los tickets almacenados en el archivo local.
  Future<void> clearAllTickets() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.writeAsString('[]');
      }
      ticketsVersionNotifier.value++;
    } catch (_) {}
  }
}
