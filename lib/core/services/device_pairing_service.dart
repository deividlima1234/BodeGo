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
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/data/models/linked_device.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/data/repositories/ticket_repository.dart';

/// Resultado de una sesión de emparejamiento generada por el Master
class PairingSession {
  final String passkey; // PIN de 6 dígitos
  final String qrPayload; // Cadena de texto para el Código QR
  final String localIp; // IP local del servidor Wi-Fi
  final List<String> candidateIps; // Todas las IPs candidatas locales
  final int port; // Puerto (ej: 8089)
  final DateTime expiresAt;

  const PairingSession({
    required this.passkey,
    required this.qrPayload,
    required this.localIp,
    this.candidateIps = const [],
    required this.port,
    required this.expiresAt,
  });
}

/// Servicio integral para Vinculación de Equipos, Passkey, Servidor Local y Sincronización de Datos.
class DevicePairingService {
  static const String _fileName = 'linked_devices.json';
  static const String _roleFileName = 'device_role.json';
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

  Future<File> _getRoleFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_roleFileName');
  }

  /// Indica si este dispositivo opera como terminal secundaria
  Future<bool> isSecondaryDevice() async {
    try {
      final file = await _getRoleFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          return json['role'] == 'secondary';
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Retorna la información de la Caja Master a la que este dispositivo está vinculado
  Future<MasterDeviceInfo?> getMasterInfo() async {
    try {
      final file = await _getRoleFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          if (json['role'] == 'secondary') {
            return MasterDeviceInfo.fromJson(json);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Configura de forma persistente este dispositivo como Terminal Secundaria
  Future<void> setSecondaryRole({
    required String masterMachineId,
    required String masterIp,
    required String businessName,
  }) async {
    try {
      final file = await _getRoleFile();
      final info = MasterDeviceInfo(
        masterMachineId: masterMachineId,
        masterIp: masterIp,
        businessName: businessName,
        linkedAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
      );
      final data = {
        'role': 'secondary',
        ...info.toJson(),
      };
      await file.writeAsString(jsonEncode(data));

      // Limpiar linked_devices.json en el secundario para que no se liste a sí mismo
      final devFile = await _getFile();
      if (await devFile.exists()) {
        await devFile.writeAsString('[]');
        devicesNotifier.value = [];
      }
    } catch (e) {
      debugPrint('Error guardando rol secundario: $e');
    }
  }

  /// Actualiza la fecha de última sincronización con la Caja Master
  Future<void> updateMasterLastSync() async {
    try {
      final info = await getMasterInfo();
      if (info != null) {
        final file = await _getRoleFile();
        final updated = info.copyWith(lastSyncAt: DateTime.now());
        final data = {
          'role': 'secondary',
          ...updated.toJson(),
        };
        await file.writeAsString(jsonEncode(data));
      }
    } catch (_) {}
  }

  /// Carga la lista de dispositivos vinculados guardados
  Future<List<LinkedDevice>> getLinkedDevices() async {
    try {
      final myLicense = await LicenseService().init();
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> list = jsonDecode(content) as List<dynamic>;
          // Filtrar cualquier dispositivo que coincida con la propia máquina para que no se autoliste
          final devices = list
              .map((j) => LinkedDevice.fromJson(j as Map<String, dynamic>))
              .where((d) => d.machineId != myLicense.machineId)
              .toList();

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

  /// Registra o actualiza un dispositivo vinculado (solo dispositivos foráneos/secundarios)
  Future<void> saveDevice(LinkedDevice device) async {
    final myLicense = await LicenseService().init();
    // No permitir que un dispositivo se guarde a sí mismo como vinculado
    if (device.machineId == myLicense.machineId) return;

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

  /// Obtiene la dirección IP local del dispositivo en la red Wi-Fi o Hotspot,
  /// descartando interfaces de datos móviles celulares (4G/LTE/5G)
  /// que no son accesibles desde otros dispositivos de la red local.
  Future<String> getLocalIp() async {
    final candidateIps = await getCandidateIps();
    if (candidateIps.isNotEmpty) {
      return candidateIps.first;
    }
    return '192.168.4.1'; // IP fallback típica de Hotspot móvil
  }

  /// Retorna todas las IPs locales válidas ordenadas por relevancia:
  /// 1. Interfaces Wi-Fi reales (wlan, wifi, en, wl)
  /// 2. Interfaces Hotspot / Punto de acceso (ap, softap, rndis)
  /// 3. Subredes locales estándar (192.168.X.X, 172.16-31.X.X, 10.X.X.X no celulares)
  /// Excluyendo explícitamente datos móviles celulares (rmnet, ccmni, pdp, wwan, dummy)
  Future<List<String>> getCandidateIps() async {
    final List<({String ip, String ifaceName, int score})> scoredList = [];

    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();

        for (final addr in iface.addresses) {
          if (addr.isLoopback || addr.isLinkLocal) continue;
          final ip = addr.address;

          int score = 0;

          // Descartar interfaces de datos móviles celulares (ej. 4G de Claro, Movistar, Entel, etc.)
          final isCellular = name.startsWith('rmnet') ||
              name.startsWith('ccmni') ||
              name.startsWith('pdp') ||
              name.startsWith('wwan') ||
              name.startsWith('v4-') ||
              name.startsWith('dummy');

          if (isCellular) {
            score -= 100;
          }

          // Descartar VPNs
          if (name.startsWith('tun') || name.startsWith('tap') || name.startsWith('ppp')) {
            score -= 100;
          }

          // Priorizar interfaces Wi-Fi conocidas
          if (name.startsWith('wlan') || name.startsWith('wifi') || name.startsWith('wl') || name.startsWith('en')) {
            score += 80;
          }

          // Priorizar Hotspot / Zona Wi-Fi portátil
          if (name.startsWith('ap') || name.startsWith('softap') || name.startsWith('rndis')) {
            score += 70;
          }

          // Priorizar subredes privadas estándar de routers y hotspots
          if (ip.startsWith('192.168.')) {
            score += 60;
          } else if (ip.startsWith('172.')) {
            final secondOctet = int.tryParse(ip.split('.')[1]) ?? 0;
            if (secondOctet >= 16 && secondOctet <= 31) {
              score += 40;
            }
          } else if (ip.startsWith('10.') && !isCellular) {
            score += 30;
          }

          scoredList.add((ip: ip, ifaceName: name, score: score));
        }
      }

      // Ordenar de mayor a menor puntuación
      scoredList.sort((a, b) => b.score.compareTo(a.score));

      // Filtrar sólo aquellas con score > 0 (sin celulares ni VPN)
      final validIps = scoredList
          .where((item) => item.score > 0)
          .map((item) => item.ip)
          .toSet()
          .toList();

      if (validIps.isNotEmpty) {
        return validIps;
      }

      return scoredList.map((item) => item.ip).toSet().toList();
    } catch (e) {
      debugPrint('Error listando interfaces de red: $e');
      return [];
    }
  }

  /// Genera una sesión de emparejamiento con PIN de 6 dígitos y código QR dinámico
  Future<PairingSession> generatePairingSession() async {
    final license = await LicenseService().init();
    final config = await BusinessConfigRepository().getConfig();
    final candidateIps = await getCandidateIps();
    final ip = candidateIps.isNotEmpty ? candidateIps.first : '192.168.4.1';

    // Generar PIN aleatorio de 6 dígitos
    final random = Random.secure();
    final pin = (100000 + random.nextInt(900000)).toString();

    final payloadData = {
      'protocol': 'bodego_sync_v1',
      'masterId': license.machineId,
      'business': config.businessName,
      'passkey': pin,
      'ip': ip,
      'candidateIps': candidateIps,
      'port': defaultPort,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final qrPayload = 'BODEGO_PAIR:${base64UrlEncode(utf8.encode(jsonEncode(payloadData)))}';

    final session = PairingSession(
      passkey: pin,
      qrPayload: qrPayload,
      localIp: ip,
      candidateIps: candidateIps,
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
    final users = await isar.users.where().findAll();

    for (final p in products) {
      await p.category.load();
    }

    final data = {
      'type': 'bodego_catalog_snapshot',
      'exportedAt': DateTime.now().toIso8601String(),
      'machineId': license.machineId,
      'businessName': config.businessName,
      'businessConfig': {
        'businessName': config.businessName,
        'address': config.address,
        'ruc': config.ruc,
        'phone': config.phone,
        'logoValue': config.logoValue,
      },
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
      'users': users.map((u) => {
        'name': u.name,
        'role': u.role,
        'email': u.email,
        'password': u.password,
        'pin': u.pin,
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
      final usersData = (json['users'] as List<dynamic>? ?? []);

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

        // 4. Sincronizar Usuarios (Cajeros y Administradores con sus PINs)
        for (final item in usersData) {
          final name = (item['name'] as String? ?? '').trim();
          final role = (item['role'] as String? ?? 'cajero').trim();
          final pin = (item['pin'] as String?)?.trim();
          final email = (item['email'] as String?)?.trim();
          final password = (item['password'] as String?)?.trim();

          if (name.isEmpty) continue;

          var u = await isar.users
              .filter()
              .nameEqualTo(name, caseSensitive: false)
              .and()
              .roleEqualTo(role)
              .findFirst();

          u ??= User()
            ..name = name
            ..role = role;

          if (pin != null && pin.isNotEmpty) u.pin = pin;
          if (email != null && email.isNotEmpty) u.email = email;
          if (password != null && password.isNotEmpty) u.password = password;

          await isar.users.put(u);
        }
      });

      // 5. Sincronizar Configuración e Identidad del Negocio
      if (json.containsKey('businessConfig')) {
        try {
          final bConf = json['businessConfig'] as Map<String, dynamic>;
          final curConfig = await BusinessConfigRepository().getConfig();
          final updatedConfig = curConfig.copyWith(
            businessName: bConf['businessName'] as String?,
            address: bConf['address'] as String?,
            ruc: bConf['ruc'] as String?,
            phone: bConf['phone'] as String?,
            logoValue: bConf['logoValue'] as String?,
          );
          await BusinessConfigRepository().saveConfig(updatedConfig);
        } catch (e) {
          debugPrint('Error sincronizando businessConfig: $e');
        }
      }

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
      _server = await shelf_io.serve(router, InternetAddress.anyIPv4, defaultPort, shared: true);
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

  Future<Response> _handleHttpRequests(Request request) async {
    final path = request.url.path;

    if (path == 'status') {
      return Response.ok(
        jsonEncode({
          'status': 'online',
          'server': 'BodeGo Sync Server',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {
          'content-type': 'application/json',
          'access-control-allow-origin': '*',
        },
      );
    }

    if (path == 'sync') {
      // Registrar o actualizar datos del equipo secundario solicitante
      final clientMachineId = request.url.queryParameters['machineId'] ?? request.headers['x-secondary-id'];
      final clientName = request.url.queryParameters['name'] ?? request.headers['x-device-name'];
      final clientIp = request.url.queryParameters['clientIp'];

      if (clientMachineId != null && clientMachineId.trim().isNotEmpty) {
        final secDev = LinkedDevice(
          id: 'DEV-${DateTime.now().millisecondsSinceEpoch}',
          name: clientName?.trim().isNotEmpty == true ? clientName!.trim() : 'Móvil Dueño / Secundario',
          machineId: clientMachineId.trim(),
          role: 'secondary',
          pairedAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
          ipAddress: clientIp,
          isActive: true,
        );
        await saveDevice(secDev);
        debugPrint('Caja Master: Equipo secundario sincronizado y registrado -> ${secDev.name} (${secDev.machineId})');
      }

      // Endpoint que entrega el snapshot completo al móvil secundario
      final snapshot = await exportDatabaseSnapshot();
      return Response.ok(
        snapshot,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'access-control-allow-origin': '*',
        },
      );
    }

    if (path == 'pair' && request.method == 'POST') {
      try {
        final bodyStr = await request.readAsString();
        final bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;

        final secMachineId = (bodyJson['secondaryMachineId'] as String? ?? '').trim();
        final secName = (bodyJson['name'] as String? ?? 'Móvil Dueño / Secundario').trim();
        final secIp = bodyJson['secondaryIp'] as String?;
        final clientPasskey = bodyJson['passkey'] as String?;

        if (secMachineId.isNotEmpty) {
          final secDev = LinkedDevice(
            id: 'DEV-${DateTime.now().millisecondsSinceEpoch}',
            name: secName,
            machineId: secMachineId,
            role: 'secondary',
            pairedAt: DateTime.now(),
            lastSyncAt: DateTime.now(),
            ipAddress: secIp,
            isActive: true,
            passkey: clientPasskey,
          );
          await saveDevice(secDev);
          debugPrint('Caja Master: Nuevo equipo secundario emparejado y registrado -> ${secDev.name} (${secDev.machineId})');
        }

        final myLicense = await LicenseService().init();
        final myConfig = await BusinessConfigRepository().getConfig();

        return Response.ok(
          jsonEncode({
            'paired': true,
            'message': 'Dispositivo emparejado con éxito en Caja Master',
            'masterMachineId': myLicense.machineId,
            'businessName': myConfig.businessName,
          }),
          headers: {
            'content-type': 'application/json',
            'access-control-allow-origin': '*',
          },
        );
      } catch (e) {
        debugPrint('Error en endpoint /pair de Caja Master: $e');
        return Response.internalServerError(body: 'Error en emparejamiento: $e');
      }
    }

    if (path == 'sync-sales' && request.method == 'POST') {
      try {
        final bodyStr = await request.readAsString();
        final bodyJson = jsonDecode(bodyStr) as Map<String, dynamic>;

        final ticketsList = (bodyJson['tickets'] as List<dynamic>? ?? [])
            .map((t) => SaleTicket.fromJson(t as Map<String, dynamic>))
            .toList();

        final ticketRepo = TicketRepository();
        final importedCount = await ticketRepo.mergeIncomingTickets(ticketsList);

        // Descontar existencias de inventario en Isar de la Caja Master
        final isar = DatabaseService.db;
        await isar.writeTxn(() async {
          for (final tkt in ticketsList) {
            for (final itm in tkt.items) {
              Product? prod;
              if (itm.productId > 0) {
                prod = await isar.products.get(itm.productId);
              }
              prod ??= await isar.products.filter().nameEqualTo(itm.name, caseSensitive: false).findFirst();

              if (prod != null) {
                prod.stock -= itm.quantity;
                if (prod.stock < 0) prod.stock = 0;
                await isar.products.put(prod);
              }
            }

            // Si es venta al fiado, actualizar la deuda del cliente
            if (tkt.isCredit) {
              Customer? cust;
              if (tkt.customerId != null) {
                cust = await isar.customers.get(tkt.customerId!);
              }
              if (cust == null && tkt.customerName != null && tkt.customerName!.isNotEmpty) {
                cust = await isar.customers.filter().nameEqualTo(tkt.customerName!, caseSensitive: false).findFirst();
              }
              if (cust != null) {
                cust.currentDebt += tkt.total;
                await isar.customers.put(cust);
              }
            }
          }
        });

        // Actualizar última fecha de sincronización del remitente
        final senderId = bodyJson['senderMachineId'] as String?;
        if (senderId != null && senderId.isNotEmpty) {
          final list = await getLinkedDevices();
          final index = list.indexWhere((d) => d.machineId == senderId);
          if (index >= 0) {
            list[index] = list[index].copyWith(lastSyncAt: DateTime.now());
            await _saveDevices(list);
          }
        }

        return Response.ok(
          jsonEncode({
            'success': true,
            'ticketsImported': importedCount,
            'message': 'Ventas fusionadas e inventario consolidado exitosamente en Caja Master',
          }),
          headers: {
            'content-type': 'application/json',
            'access-control-allow-origin': '*',
          },
        );
      } catch (e) {
        debugPrint('Error en /sync-sales de Caja Master: $e');
        return Response.internalServerError(body: 'Error al fusionar ventas: $e');
      }
    }

    return Response.notFound('Ruta de sincronización no encontrada');
  }

  /// Comprueba rápidamente si una terminal responde en la red local
  Future<bool> pingServer(String ip, {int port = defaultPort}) async {
    try {
      var rawTarget = ip.trim();
      if (rawTarget.startsWith('http://')) rawTarget = rawTarget.substring(7);
      if (rawTarget.startsWith('https://')) rawTarget = rawTarget.substring(8);

      int effectivePort = port;
      String host = rawTarget;
      if (rawTarget.contains(':')) {
        final split = rawTarget.split(':');
        host = split[0].trim();
        effectivePort = int.tryParse(split[1].trim()) ?? port;
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(Uri.parse('http://$host:$effectivePort/status'));
      final response = await request.close().timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Envía los tickets de venta pendientes de esta terminal secundaria hacia la Caja Master
  Future<({bool success, int ticketsSent, String? message})> sendPendingSalesToMaster({
    required String masterIp,
    List<String>? candidateIps,
    int port = defaultPort,
  }) async {
    final ticketRepo = TicketRepository();
    final pendingTickets = await ticketRepo.getPendingSyncTickets();

    if (pendingTickets.isEmpty) {
      return (success: true, ticketsSent: 0, message: 'No hay ventas pendientes por transferir.');
    }

    final myLicense = await LicenseService().init();
    final payload = jsonEncode({
      'senderMachineId': myLicense.machineId,
      'tickets': pendingTickets.map((t) => t.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    final targets = <String>{masterIp};
    if (candidateIps != null) targets.addAll(candidateIps);

    for (final targetIp in targets) {
      var rawTarget = targetIp.trim();
      if (rawTarget.isEmpty) continue;
      if (rawTarget.startsWith('http://')) rawTarget = rawTarget.substring(7);
      if (rawTarget.startsWith('https://')) rawTarget = rawTarget.substring(8);

      int effectivePort = port;
      String host = rawTarget;
      if (rawTarget.contains(':')) {
        final split = rawTarget.split(':');
        host = split[0].trim();
        effectivePort = int.tryParse(split[1].trim()) ?? port;
      }
      if (host.isEmpty) continue;

      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final request = await client.postUrl(Uri.parse('http://$host:$effectivePort/sync-sales'));
        request.headers.contentType = ContentType.json;
        request.write(payload);
        final response = await request.close().timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final sentIds = pendingTickets.map((t) => t.id).toList();
          await ticketRepo.markTicketsAsSynced(sentIds);
          await updateMasterLastSync();
          debugPrint('Ventas transferidas exitosamente a Caja Master (${pendingTickets.length} tickets)');
          return (success: true, ticketsSent: pendingTickets.length, message: null);
        }
      } catch (e) {
        debugPrint('Fallo al enviar ventas a $host:$effectivePort: $e');
      }
    }

    return (success: false, ticketsSent: 0, message: 'No se pudo conectar a la Caja Master.');
  }

  /// Registra este equipo secundario en el servidor de la Caja Master
  Future<bool> registerSecondaryWithMaster({
    required String masterIp,
    List<String>? candidateIps,
    int port = defaultPort,
    required String secondaryMachineId,
    required String secondaryDeviceName,
    String? secondaryIp,
    String? passkey,
  }) async {
    final targets = <String>{masterIp};
    if (candidateIps != null) targets.addAll(candidateIps);

    final payload = jsonEncode({
      'secondaryMachineId': secondaryMachineId,
      'name': secondaryDeviceName,
      'secondaryIp': secondaryIp,
      'passkey': passkey,
      'timestamp': DateTime.now().toIso8601String(),
    });

    for (final targetIp in targets) {
      var rawTarget = targetIp.trim();
      if (rawTarget.isEmpty) continue;
      if (rawTarget.startsWith('http://')) rawTarget = rawTarget.substring(7);
      if (rawTarget.startsWith('https://')) rawTarget = rawTarget.substring(8);

      int effectivePort = port;
      String host = rawTarget;
      if (rawTarget.contains(':')) {
        final split = rawTarget.split(':');
        host = split[0].trim();
        effectivePort = int.tryParse(split[1].trim()) ?? port;
      }
      if (host.isEmpty) continue;

      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);
        final request = await client.postUrl(Uri.parse('http://$host:$effectivePort/pair'));
        request.headers.contentType = ContentType.json;
        request.write(payload);
        final response = await request.close().timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) {
          debugPrint('Handshake /pair exitoso con Caja Master en $host:$effectivePort');
          return true;
        }
      } catch (e) {
        debugPrint('Intento fallido de handshake /pair a $host:$effectivePort: $e');
      }
    }
    return false;
  }

  /// Conecta como cliente HTTP a la IP de la Caja Master en la red Wi-Fi y descarga la base de datos.
  /// Puede recibir una IP principal o una lista de IPs candidatas para probarlas automáticamente.
  Future<String?> fetchSnapshotFromMaster({
    required String ip,
    List<String>? candidateIps,
    int port = defaultPort,
    String? secondaryMachineId,
    String? secondaryDeviceName,
    String? secondaryIp,
  }) async {
    final targets = <String>{ip};
    if (candidateIps != null) {
      targets.addAll(candidateIps);
    }

    for (final targetIp in targets) {
      var rawTarget = targetIp.trim();
      if (rawTarget.isEmpty) continue;

      // Limpiar prefijo 'http://' o 'https://' si el usuario lo incluyó
      if (rawTarget.startsWith('http://')) {
        rawTarget = rawTarget.substring(7);
      } else if (rawTarget.startsWith('https://')) {
        rawTarget = rawTarget.substring(8);
      }

      int effectivePort = port;
      String host = rawTarget;
      if (rawTarget.contains(':')) {
        final split = rawTarget.split(':');
        host = split[0].trim();
        effectivePort = int.tryParse(split[1].trim()) ?? port;
      }

      if (host.isEmpty) continue;

      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);

        final queryParams = <String, String>{};
        if (secondaryMachineId != null) queryParams['machineId'] = secondaryMachineId;
        if (secondaryDeviceName != null) queryParams['name'] = secondaryDeviceName;
        if (secondaryIp != null) queryParams['clientIp'] = secondaryIp;

        final uri = Uri.http('$host:$effectivePort', '/sync', queryParams.isNotEmpty ? queryParams : null);
        debugPrint('Intentando conectar con Caja Master en: $uri');
        final request = await client.getUrl(uri);
        if (secondaryMachineId != null) {
          request.headers.set('x-secondary-id', secondaryMachineId);
        }
        final response = await request.close().timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          return body;
        } else {
          debugPrint('Respuesta no exitosa de la Caja Master: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Intento de conexión fallido a $host:$effectivePort: $e');
      }
    }
    return null;
  }

  /// Finaliza la configuración automática del equipo secundario importando datos y marcando onboarding como listo
  Future<bool> completeSecondaryDeviceSetup({
    required String businessName,
    required String masterMachineId,
    required String rawSnapshotJson,
    String? masterIp,
  }) async {
    final imported = await importDatabaseSnapshot(rawSnapshotJson);
    if (!imported) return false;

    // Actualizar nombre de negocio y marcar onboarding como completado
    final appSettingsRepo = AppSettingsRepository();
    await appSettingsRepo.updateBusinessName(businessName);

    // Asegurar que exista al menos un cajero en el dispositivo secundario
    final userRepo = UserRepository();
    final allUsers = await userRepo.getAllUsers();
    final hasCashier = allUsers.any((u) => u.role == 'cajero');
    if (!hasCashier) {
      await userRepo.createCashier('Cajero Principal', '1234');
    }

    // Configurar de forma persistente este equipo como Terminal Secundaria vinculada a la Caja Master
    await setSecondaryRole(
      masterMachineId: masterMachineId,
      masterIp: masterIp ?? '192.168.1.1',
      businessName: businessName,
    );

    return true;
  }
}
