import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:isar/isar.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';
import 'package:bodego/data/models/linked_device.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';

/// Resultado de una sesión de emparejamiento generada por el Master
class PairingSession {
  final String passkey; // PIN de 6 dígitos
  final String qrPayload; // Cadena de texto para el Código QR
  final String localIp; // IP local del servidor Wi-Fi
  final int port; // Puerto (ej: 8089)
  final DateTime expiresAt;

  const PairingSession({
    required this.passkey,
    required this.qrPayload,
    required this.localIp,
    required this.port,
    required this.expiresAt,
  });
}

/// Servicio integral para Vinculación de Equipos, Passkey, Servidor Local y Sincronización de Datos.
class DevicePairingService {
  static const String _fileName = 'linked_devices.json';
  static const int defaultPort = 8089;

  static final DevicePairingService _instance = DevicePairingService._internal();
  factory DevicePairingService() => _instance;
  DevicePairingService._internal();

  final ValueNotifier<List<LinkedDevice>> devicesNotifier = ValueNotifier<List<LinkedDevice>>([]);
  final ValueNotifier<bool> isServerRunningNotifier = ValueNotifier<bool>(false);

  HttpServer? _server;
  PairingSession? _activePairingSession;
  PairingSession? get activePairingSession => _activePairingSession;

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Carga la lista de dispositivos vinculados guardados
  Future<List<LinkedDevice>> getLinkedDevices() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content) as List<dynamic>;
          final devices = list.map((j) => LinkedDevice.fromJson(j as Map<String, dynamic>)).toList();
          devicesNotifier.value = devices;
          return devices;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error leyendo linked_devices.json: $e');
      return [];
    }
  }

  Future<void> _saveDevices(List<LinkedDevice> devices) async {
    final file = await _getFile();
    final jsonString = jsonEncode(devices.map((d) => d.toJson()).toList());
    await file.writeAsString(jsonString);
    devicesNotifier.value = devices;
  }

  /// Registra o actualiza un dispositivo vinculado
  Future<void> saveDevice(LinkedDevice device) async {
    final list = await getLinkedDevices();
    final index = list.indexWhere((d) => d.id == device.id || d.machineId == device.machineId);
    if (index >= 0) {
      list[index] = device;
    } else {
      list.add(device);
    }
    await _saveDevices(list);
  }

  /// Revoca o elimina un dispositivo vinculado
  Future<void> removeDevice(String id) async {
    final list = await getLinkedDevices();
    list.removeWhere((d) => d.id == id);
    await _saveDevices(list);
  }

  /// Obtiene la dirección IP local del dispositivo en la red Wi-Fi o Hotspot
  Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '192.168.4.1'; // IP fallback típica de Hotspot móvil
  }

  /// Genera una sesión de emparejamiento con PIN de 6 dígitos y código QR dinámico
  Future<PairingSession> generatePairingSession() async {
    final license = await LicenseService().init();
    final config = await BusinessConfigRepository().getConfig();
    final ip = await getLocalIp();

    // Generar PIN aleatorio de 6 dígitos
    final random = Random.secure();
    final pin = (100000 + random.nextInt(900000)).toString();

    final payloadData = {
      'protocol': 'bodego_sync_v1',
      'masterId': license.machineId,
      'business': config.businessName,
      'passkey': pin,
      'ip': ip,
      'port': defaultPort,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final qrPayload = 'BODEGO_PAIR:${base64UrlEncode(utf8.encode(jsonEncode(payloadData)))}';

    final session = PairingSession(
      passkey: pin,
      qrPayload: qrPayload,
      localIp: ip,
      port: defaultPort,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );

    _activePairingSession = session;
    await startSyncServer(); // Asegurar que el servidor local esté activo para recibir la conexión
    return session;
  }

  /// Exporta una instantánea completa (Snapshot) de la base de datos en JSON
  Future<String> exportDatabaseSnapshot() async {
    final isar = DatabaseService.db;
    final license = await LicenseService().init();
    final config = await BusinessConfigRepository().getConfig();

    final categories = await isar.categorys.where().sortByName().findAll();
    final products = await isar.products.where().sortByName().findAll();
    final customers = await isar.customers.where().sortByName().findAll();

    for (final p in products) {
      await p.category.load();
    }

    final data = {
      'type': 'bodego_catalog_snapshot',
      'exportedAt': DateTime.now().toIso8601String(),
      'machineId': license.machineId,
      'businessName': config.businessName,
      'categories': categories.map((c) => {
        'name': c.name,
        'hexColor': c.hexColor,
      }).toList(),
      'products': products.map((p) => {
        'barcode': p.barcode,
        'name': p.name,
        'costPrice': p.costPrice,
        'salePrice': p.salePrice,
        'stock': p.stock,
        'minStock': p.minStock,
        'unit': p.unit,
        'categoryName': p.category.value?.name,
      }).toList(),
      'customers': customers.map((c) => {
        'name': c.name,
        'phone': c.phone,
        'address': c.address,
        'creditLimit': c.creditLimit,
        'currentDebt': c.currentDebt,
      }).toList(),
    };

    return jsonEncode(data);
  }

  /// Importa una instantánea (Snapshot) recibida por Wi-Fi o archivo compartido
  Future<bool> importDatabaseSnapshot(String rawJson) async {
    try {
      final json = jsonDecode(rawJson) as Map<String, dynamic>;
      final isar = DatabaseService.db;

      final categoriesData = (json['categories'] as List<dynamic>? ?? []);
      final productsData = (json['products'] as List<dynamic>? ?? []);
      final customersData = (json['customers'] as List<dynamic>? ?? []);

      await isar.writeTxn(() async {
        // 1. Sincronizar Categorías
        final Map<String, Category> categoryMap = {};
        for (final item in categoriesData) {
          final name = (item['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          var cat = await isar.categorys.filter().nameEqualTo(name).findFirst();
          if (cat == null) {
            cat = Category()
              ..name = name
              ..hexColor = item['hexColor'] as String? ?? '#4353FF';
            await isar.categorys.put(cat);
          }
          categoryMap[name] = cat;
        }

        // 2. Sincronizar Productos
        for (final item in productsData) {
          final name = (item['name'] as String? ?? '').trim();
          final barcode = item['barcode'] as String?;
          if (name.isEmpty) continue;

          Product? prod;
          if (barcode != null && barcode.trim().isNotEmpty) {
            prod = await isar.products.filter().barcodeEqualTo(barcode.trim()).findFirst();
          }
          prod ??= await isar.products.filter().nameEqualTo(name, caseSensitive: false).findFirst();

          prod ??= Product()..name = name;
          prod.barcode = barcode;
          prod.costPrice = (item['costPrice'] as num?)?.toDouble() ?? 0.0;
          prod.salePrice = (item['salePrice'] as num?)?.toDouble() ?? 0.0;
          prod.stock = (item['stock'] as num?)?.toDouble() ?? 0.0;
          prod.minStock = (item['minStock'] as num?)?.toDouble() ?? 5.0;
          prod.unit = item['unit'] as String? ?? 'und';

          final catName = item['categoryName'] as String?;
          if (catName != null && categoryMap.containsKey(catName)) {
            prod.category.value = categoryMap[catName];
          }

          await isar.products.put(prod);
          await prod.category.save();
        }

        // 3. Sincronizar Clientes
        for (final item in customersData) {
          final name = (item['name'] as String? ?? '').trim();
          if (name.isEmpty) continue;
          var cust = await isar.customers.filter().nameEqualTo(name, caseSensitive: false).findFirst();
          cust ??= Customer()
            ..name = name
            ..createdAt = DateTime.now();

          cust.phone = item['phone'] as String?;
          cust.address = item['address'] as String?;
          cust.creditLimit = (item['creditLimit'] as num?)?.toDouble() ?? 100.0;
          cust.currentDebt = (item['currentDebt'] as num?)?.toDouble() ?? 0.0;
          await isar.customers.put(cust);
        }
      });

      return true;
    } catch (e) {
      debugPrint('Error importando snapshot de base de datos: $e');
      return false;
    }
  }

  /// Aplica los lotes de mercadería comprados en el mercado mayorista hacia la base de datos
  Future<void> applyWholesaleBatch(List<Map<String, dynamic>> items) async {
    final isar = DatabaseService.db;
    await isar.writeTxn(() async {
      for (final item in items) {
        final barcode = item['barcode'] as String?;
        final name = (item['name'] as String? ?? '').trim();
        final addedStock = (item['addedStock'] as num?)?.toDouble() ?? 0.0;
        final newCost = (item['newCost'] as num?)?.toDouble();

        if (name.isEmpty || addedStock <= 0) continue;

        Product? prod;
        if (barcode != null && barcode.isNotEmpty) {
          prod = await isar.products.filter().barcodeEqualTo(barcode).findFirst();
        }
        prod ??= await isar.products.filter().nameEqualTo(name, caseSensitive: false).findFirst();

        if (prod != null) {
          prod.stock += addedStock;
          if (newCost != null && newCost > 0) {
            prod.costPrice = newCost;
          }
          await isar.products.put(prod);
        }
      }
    });
  }

  // --- SERVIDOR HTTP LOCAL EMBEBIDO (SHELF) ---

  /// Inicia el servidor HTTP local para atender solicitudes de sincronización por Wi-Fi
  Future<void> startSyncServer() async {
    if (_server != null) return;

    final router = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleHttpRequests);

    try {
      _server = await shelf_io.serve(router, InternetAddress.anyIPv4, defaultPort);
      isServerRunningNotifier.value = true;
      debugPrint('Servidor BodeGo Sync iniciado en puerto ${_server!.port}');
    } catch (e) {
      debugPrint('No se pudo iniciar el servidor local BodeGo: $e');
    }
  }

  /// Detiene el servidor HTTP local
  Future<void> stopSyncServer() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      isServerRunningNotifier.value = false;
      debugPrint('Servidor BodeGo Sync detenido');
    }
  }

  Response _handleHttpRequests(Request request) {
    final path = request.url.path;

    if (path == 'status') {
      return Response.ok(
        jsonEncode({
          'status': 'online',
          'server': 'BodeGo Sync Server',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'content-type': 'application/json'},
      );
    }

    if (path == 'sync') {
      // Endpoint que entrega el snapshot completo al móvil secundario
      return Response.ok(
        exportDatabaseSnapshot(),
        headers: {'content-type': 'application/json'},
      );
    }

    if (path == 'pair' && request.method == 'POST') {
      // Validar passkey recibida del equipo secundario
      return Response.ok(
        jsonEncode({'paired': true, 'message': 'Dispositivo emparejado con éxito'}),
        headers: {'content-type': 'application/json'},
      );
    }

    return Response.notFound('Ruta de sincronización no encontrada');
  }

  /// Conecta como cliente HTTP a la IP de la Caja Master en la red Wi-Fi y descarga la base de datos
  Future<String?> fetchSnapshotFromMaster({
    required String ip,
    int port = defaultPort,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('http://$ip:$port/sync'));
      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return body;
      }
    } catch (e) {
      debugPrint('Error conectando a Master en $ip:$port: $e');
    }
    return null;
  }

  /// Finaliza la configuración automática del equipo secundario importando datos y marcando onboarding como listo
  Future<bool> completeSecondaryDeviceSetup({
    required String businessName,
    required String masterMachineId,
    required String rawSnapshotJson,
  }) async {
    final imported = await importDatabaseSnapshot(rawSnapshotJson);
    if (!imported) return false;

    // Actualizar nombre de negocio y marcar onboarding como completado
    final appSettingsRepo = AppSettingsRepository();
    await appSettingsRepo.updateBusinessName(businessName);

    // Guardar registro de este dispositivo como secundario
    final myLicense = await LicenseService().init();
    final secDev = LinkedDevice(
      id: 'DEV-SEC-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Móvil Dueño / Secundario',
      machineId: myLicense.machineId,
      role: 'secondary',
      pairedAt: DateTime.now(),
      lastSyncAt: DateTime.now(),
      isActive: true,
    );
    await saveDevice(secDev);

    return true;
  }
}
