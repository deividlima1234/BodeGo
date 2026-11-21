import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/core/services/sync_queue_service.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/data/models/google_sheets_config.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/ticket_repository.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/core/services/cloud_security_manager.dart';
import 'package:isar/isar.dart';

/// Servicio maestro para la Sincronización en la Nube con Google Sheets
/// mediante Google Apps Script (Web App).
/// Soporta arquitectura Multi-Tenant (negocios aislados), Registro de Tiendas,
/// Login/Recuperación de cuentas por pérdida de teléfono y manejo Offline-First.
class GoogleSheetsSyncService {
  static const String _configFile = 'google_sheets_config.json';

  static final GoogleSheetsSyncService _instance = GoogleSheetsSyncService._internal();
  factory GoogleSheetsSyncService() => _instance;
  GoogleSheetsSyncService._internal();

  final ValueNotifier<GoogleSheetsConfig> configNotifier =
      ValueNotifier<GoogleSheetsConfig>(const GoogleSheetsConfig());

  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);

  Future<File> _getConfigFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_configFile');
  }

  /// Obtiene la configuración actual de Google Sheets
  Future<GoogleSheetsConfig> getConfig() async {
    try {
      final file = await _getConfigFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          final config = GoogleSheetsConfig.fromJson(json);
          configNotifier.value = config;
          return config;
        }
      }
      const initial = GoogleSheetsConfig();
      configNotifier.value = initial;
      return initial;
    } catch (e) {
      debugPrint('Error leyendo configuración de Google Sheets: $e');
      return const GoogleSheetsConfig();
    }
  }

  /// Guarda de forma persistente la configuración de Google Sheets
  Future<void> saveConfig(GoogleSheetsConfig config) async {
    try {
      final file = await _getConfigFile();
      final jsonStr = jsonEncode(config.toJson());
      await file.writeAsString(jsonStr);
      configNotifier.value = config;
    } catch (e) {
      debugPrint('Error guardando configuración de Google Sheets: $e');
    }
  }

  /// Realiza una solicitud HTTP GET siguiendo redirecciones (HTTP 301, 302, 307)
  Future<Map<String, dynamic>?> _httpGet(String url, {Map<String, String>? queryParams}) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);

    try {
      Uri uri = Uri.parse(url);
      if (queryParams != null && queryParams.isNotEmpty) {
        final updatedParams = Map<String, String>.from(uri.queryParameters)..addAll(queryParams);
        uri = uri.replace(queryParameters: updatedParams);
      }

      var request = await client.getUrl(uri);
      request.followRedirects = false;
      var response = await request.close().timeout(const Duration(seconds: 18));

      int redirects = 0;
      while ((response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307) && redirects < 5) {
        redirects++;
        final redirectLocation = response.headers.value(HttpHeaders.locationHeader);
        if (redirectLocation == null) break;

        final redirectUri = Uri.parse(redirectLocation);
        request = await client.getUrl(redirectUri);
        request.followRedirects = false;
        response = await request.close().timeout(const Duration(seconds: 18));
      }

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      } else {
        debugPrint('HTTP GET fallo con status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error en HTTP GET a Google Sheets: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Realiza una solicitud HTTP POST con cuerpo JSON siguiendo redirecciones
  Future<Map<String, dynamic>?> _httpPost(String url, Map<String, dynamic> body) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 18);

    try {
      final uri = Uri.parse(url);
      final jsonBody = jsonEncode(body);

      var request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.followRedirects = false;
      request.write(jsonBody);

      var response = await request.close().timeout(const Duration(seconds: 35));

      int redirects = 0;
      while ((response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307) && redirects < 5) {
        redirects++;
        final redirectLocation = response.headers.value(HttpHeaders.locationHeader);
        if (redirectLocation == null) break;

        final redirectUri = Uri.parse(redirectLocation);
        final getReq = await client.getUrl(redirectUri);
        getReq.followRedirects = false;
        response = await getReq.close().timeout(const Duration(seconds: 25));
      }

      if (response.statusCode == 200) {
        final respBody = await response.transform(utf8.decoder).join();
        return jsonDecode(respBody) as Map<String, dynamic>;
      } else {
        debugPrint('HTTP POST fallo con status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error en HTTP POST a Google Sheets: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Prueba la conexión contra el servicio en la nube protegido
  Future<({bool success, String message, String? serverName})> testConnection([String? testUrl]) async {
    final config = await getConfig();
    final url = (testUrl != null && testUrl.trim().isNotEmpty)
        ? testUrl.trim()
        : config.effectiveScriptUrl;

    if (url.isEmpty || !url.startsWith('https://')) {
      return (
        success: false,
        message: 'Servicio en la nube no configurado correctamente.',
        serverName: null,
      );
    }

    final resp = await _httpGet(url, queryParams: {'action': 'ping'});
    if (resp != null && resp['success'] == true) {
      final sName = resp['serverName'] as String? ?? 'BodeGo Cloud Hub';
      return (
        success: true,
        message: '¡Servicio en la Nube Conectado y Operativo!\nHub: "$sName"',
        serverName: sName,
      );
    }

    return (
      success: false,
      message: 'No se pudo conectar con el servidor en la nube. Verifica tu conexión a Internet.',
      serverName: null,
    );
  }

  // =====================================================================
  // AUTO-REGISTRO RESILIENTE (OFFLINE-FIRST)
  // =====================================================================

  /// Asegura que el negocio esté debidamente registrado y autenticado en Google Apps Script.
  /// Si el negocio se creó sin internet, este método detecta la falta de businessId
  /// y realiza el registro automáticamente con los datos locales en cuanto hay red.
  Future<bool> ensureTenantRegistered() async {
    final config = await getConfig();
    if (config.isTenantAuthenticated) {
      return true;
    }

    try {
      final bRepo = BusinessConfigRepository();
      final bConfig = await bRepo.getConfig();
      if (bConfig.businessName.trim().isEmpty) return false;

      final isar = DatabaseService.db;
      final users = await isar.users.where().findAll();
      final admin = users.firstWhere(
        (u) => u.role == 'admin',
        orElse: () => User()
          ..name = 'Administrador'
          ..email = 'admin@bodego.pe'
          ..password = '1234',
      );

      final email = (admin.email != null && admin.email!.contains('@'))
          ? admin.email!.trim()
          : 'admin@bodego.pe';
      final pass = (admin.password != null && admin.password!.isNotEmpty)
          ? admin.password!.trim()
          : '1234';

      debugPrint('Auto-registrando negocio en Google Cloud: ${bConfig.businessName} ($email)');

      final reg = await registerBusiness(
        businessName: bConfig.businessName,
        ownerName: admin.name,
        ownerEmail: email,
        password: pass,
        ruc: bConfig.ruc,
      );

      if (reg.success) {
        debugPrint('Auto-registro en la nube completado con éxito: ${reg.businessId}');
        // Crear el respaldo inicial con el catálogo local
        await createFullBackup();
        final c = await getConfig();
        unawaited(_httpPost(c.effectiveScriptUrl, {
          'action': 'protectTenantSheets',
          'businessId': c.businessId,
          'authToken': c.authToken,
        }));
        return true;
      } else {
        debugPrint('Fallo al auto-registrar negocio: ${reg.message}');
        // Si el correo ya existe en la nube, recuperar sesión con las credenciales locales
        if (reg.message.contains('ya está registrado') || reg.message.contains('inicia sesión')) {
          debugPrint('El correo ya existe en la nube. Re-autenticando...');
          final loginResult = await loginBusiness(
            email: email,
            password: pass,
          );
          if (loginResult.success) {
            await createFullBackup();
            final c = await getConfig();
            unawaited(_httpPost(c.effectiveScriptUrl, {
              'action': 'protectTenantSheets',
              'businessId': c.businessId,
              'authToken': c.authToken,
            }));
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error en ensureTenantRegistered: $e');
    }
    return false;
  }

  /// Registra una nueva bodega en el hub multi-tenant de Google Apps Script.
  Future<({bool success, String message, String? businessId})> registerBusiness({
    required String businessName,
    required String ownerName,
    required String ownerEmail,
    required String password,
    String? ruc,
    String? scriptUrl,
  }) async {
    final config = await getConfig();
    final targetUrl = (scriptUrl != null && scriptUrl.isNotEmpty) ? scriptUrl : config.effectiveScriptUrl;
    final license = await LicenseService().init();

    final payload = {
      'action': 'registerBusiness',
      'businessName': businessName.trim(),
      'ownerName': ownerName.trim(),
      'ownerEmail': ownerEmail.trim(),
      'password': password.trim(),
      'ruc': ruc?.trim() ?? '',
      'machineId': license.machineId,
      'createdAt': DateTime.now().toIso8601String(),
    };

    try {
      final resp = await _httpPost(targetUrl, payload);
      if (resp != null && resp['success'] == true) {
        final bId = resp['businessId'] as String;
        final token = resp['authToken'] as String;
        final sheetId = resp['spreadsheetId'] as String?;

        final updated = config.copyWith(
          scriptUrl: targetUrl,
          isEnabled: true,
          businessId: bId,
          authToken: token,
          ownerEmail: ownerEmail.trim(),
          spreadsheetId: sheetId,
          sheetName: 'BodeGo - ${businessName.trim()}',
          lastSyncAt: DateTime.now(),
        );
        await saveConfig(updated);

        return (
          success: true,
          message: resp['message'] as String? ?? '¡Negocio registrado exitosamente en la nube!',
          businessId: bId,
        );
      }

      return (
        success: false,
        message: resp?['error']?.toString() ?? 'Error al registrar el negocio en la nube',
        businessId: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'No se pudo conectar al servidor de registro: $e',
        businessId: null,
      );
    }
  }

  // =====================================================================
  // LOGIN Y RECUPERACIÓN DE NEGOCIO (CAMBIO O PÉRDIDA DE TELÉFONO)
  // =====================================================================

  /// Inicia sesión con Email y Contraseña del Administrador y restaura todo el catálogo en Isar
  Future<({bool success, String message, String? businessName, int productsRestored})> loginBusiness({
    required String email,
    required String password,
    String? scriptUrl,
  }) async {
    final config = await getConfig();
    final targetUrl = (scriptUrl != null && scriptUrl.isNotEmpty) ? scriptUrl : config.effectiveScriptUrl;

    final payload = {
      'action': 'loginBusiness',
      'email': email.trim(),
      'password': password.trim(),
    };

    try {
      final resp = await _httpPost(targetUrl, payload);
      if (resp == null || resp['success'] != true) {
        return (
          success: false,
          message: resp?['error']?.toString() ?? 'Credenciales incorrectas o servidor no disponible',
          businessName: null,
          productsRestored: 0,
        );
      }

      final bId = resp['businessId'] as String;
      final token = resp['authToken'] as String;
      final bName = resp['businessName'] as String? ?? 'Mi Bodega';
      final bRuc = resp['ruc'] as String? ?? '';
      final oName = resp['ownerName'] as String? ?? 'Administrador';
      final oEmail = resp['ownerEmail'] as String? ?? email.trim();
      final sheetId = resp['spreadsheetId'] as String?;
      final catalog = resp['catalog'] as Map<String, dynamic>? ?? {};

      // 1. Guardar Configuración de Google Sheets
      final updatedConfig = config.copyWith(
        scriptUrl: targetUrl,
        isEnabled: true,
        businessId: bId,
        authToken: token,
        ownerEmail: oEmail,
        spreadsheetId: sheetId,
        sheetName: 'BodeGo - $bName',
        lastSyncAt: DateTime.now(),
      );
      await saveConfig(updatedConfig);

      // 2. Guardar Identidad Comercial en BusinessConfig
      final bRepo = BusinessConfigRepository();
      final currentBConfig = await bRepo.getConfig();
      final updatedBConfig = currentBConfig.copyWith(
        businessName: bName,
        ruc: bRuc,
      );
      await bRepo.saveConfig(updatedBConfig);

      // 3. Hidratar Base de Datos Local Isar con el Catálogo y Usuarios de la nube
      final isar = DatabaseService.db;
      final categoriesData = (catalog['categories'] as List<dynamic>? ?? []);
      final productsData = (catalog['products'] as List<dynamic>? ?? []);
      final customersData = (catalog['customers'] as List<dynamic>? ?? []);
      final usersData = (catalog['users'] as List<dynamic>? ?? []);
      final secretKey = '${bId}_${GoogleSheetsConfig.cloudSecretKey}';

      int importedCount = 0;

      await isar.writeTxn(() async {
        // A. Sincronizar Usuarios (Cajeros con PINs desencriptados y Administradores)
        for (final item in usersData) {
          final name = (item['name'] as String? ?? '').trim();
          final role = (item['role'] as String? ?? 'cajero').trim();
          final encPin = (item['pin'] as String? ?? '').trim();
          final plainPin = encPin.isNotEmpty
              ? CloudSecurityManager.decryptPin(encPin, secretKey: secretKey)
              : '';
          final email = (item['email'] as String?)?.trim();

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

          if (plainPin.isNotEmpty) u.pin = plainPin;
          if (email != null && email.isNotEmpty) u.email = email;
          await isar.users.put(u);
        }

        // B. Garantizar Admin y Cajero en Isar si no vinieron en el respaldo
        final existingUsers = await isar.users.where().findAll();
        if (!existingUsers.any((u) => u.role == 'admin')) {
          final admin = User()
            ..name = oName
            ..role = 'admin'
            ..email = oEmail
            ..password = password;
          await isar.users.put(admin);
        }
        if (!existingUsers.any((u) => u.role == 'cajero')) {
          final cashier = User()
            ..name = 'Cajero Principal'
            ..role = 'cajero'
            ..pin = '1234';
          await isar.users.put(cashier);
        }
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
          importedCount++;
        }

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

      // 5. Marcar Onboarding como completado y guardar nombre del negocio
      final appSettingsRepo = AppSettingsRepository();
      await appSettingsRepo.updateBusinessName(bName);

      return (
        success: true,
        message: '¡Bienvenido de vuelta a $bName!\nSe restauraron $importedCount productos y clientes.',
        businessName: bName,
        productsRestored: importedCount,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error al iniciar sesión y restaurar: $e',
        businessName: null,
        productsRestored: 0,
      );
    }
  }

  // =====================================================================
  // OPERACIONES TRANSACCIONALES (PUSH, PULL Y BACKUPS POR NEGOCIO)
  // =====================================================================

  /// Despacha todos los movimientos pendientes de la cola local a Google Sheets
  Future<({bool success, int count, String? error})> processPendingQueue() async {
    var config = await getConfig();
    if (!config.isConfigured || !config.isEnabled) {
      return (success: false, count: 0, error: 'Sincronización inactiva');
    }

    // Auto-registro en la nube si no está autenticado aún
    if (!config.isTenantAuthenticated) {
      final ok = await ensureTenantRegistered();
      if (!ok) {
        return (success: false, count: 0, error: 'Esperando conexión para auto-registrar negocio en la nube');
      }
      config = await getConfig();
    }

    final queueService = SyncQueueService();
    final pending = await queueService.getPendingMovements();

    if (pending.isEmpty) {
      return (success: true, count: 0, error: null);
    }

    final license = await LicenseService().init();
    final businessConfig = await BusinessConfigRepository().getConfig();

    final payload = {
      'action': 'pushBatch',
      'businessId': config.businessId,
      'authToken': config.authToken,
      'deviceInfo': {
        'machineId': license.machineId,
        'name': businessConfig.businessName,
        'role': 'pos_terminal',
      },
      'movements': pending.map((m) => m.toJson()).toList(),
    };

    final resp = await _httpPost(config.effectiveScriptUrl, payload);
    if (resp != null && resp['success'] == true) {
      final syncedIds = pending.map((m) => m.id).toList();
      await queueService.markAsSynced(syncedIds);

      final ticketRepo = TicketRepository();
      final saleTicketIds = pending
          .where((m) => m.type == 'VENTA')
          .map((m) => m.data['ticket']?['id'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();
      if (saleTicketIds.isNotEmpty) {
        await ticketRepo.markTicketsAsSynced(saleTicketIds);
      }

      final updatedConfig = config.copyWith(lastSyncAt: DateTime.now());
      await saveConfig(updatedConfig);
      await queueService.updatePendingCount();

      return (success: true, count: pending.length, error: null);
    }

    return (success: false, count: 0, error: resp?['error']?.toString() ?? 'Error al despachar lote');
  }

  Future<Map<String, dynamic>> _buildFullSnapshot() async {
    final isar = DatabaseService.db;
    final license = await LicenseService().init();
    final businessConfig = await BusinessConfigRepository().getConfig();

    final categories = await isar.categorys.where().sortByName().findAll();
    final products = await isar.products.where().sortByName().findAll();
    final customers = await isar.customers.where().sortByName().findAll();
    final users = await isar.users.where().findAll();
    final config = await getConfig();
    final secretKey = '${config.businessId ?? "BODEGO"}_${GoogleSheetsConfig.cloudSecretKey}';

    for (final p in products) {
      await p.category.load();
    }

    final usersList = users.map((u) {
      final pin = u.pin?.trim() ?? '';
      final encPin = pin.isNotEmpty
          ? CloudSecurityManager.encryptPin(pin, secretKey: secretKey)
          : '';
      return {
        'id': u.id,
        'name': u.name,
        'role': u.role,
        'pin': encPin,
        'email': u.email,
      };
    }).toList();

    return {
      'machineId': license.machineId,
      'businessConfig': {
        'businessName': businessConfig.businessName,
        'address': businessConfig.address,
        'ruc': businessConfig.ruc,
        'phone': businessConfig.phone,
      },
      'categories': categories.map((c) => {
        'id': c.id,
        'name': c.name,
        'hexColor': c.hexColor,
      }).toList(),
      'products': products.map((p) => {
        'id': p.id,
        'barcode': p.barcode,
        'name': p.name,
        'categoryName': p.category.value?.name,
        'costPrice': p.costPrice,
        'salePrice': p.salePrice,
        'stock': p.stock,
        'minStock': p.minStock,
        'unit': p.unit,
      }).toList(),
      'customers': customers.map((c) => {
        'id': c.id,
        'name': c.name,
        'phone': c.phone,
        'address': c.address,
        'creditLimit': c.creditLimit,
        'currentDebt': c.currentDebt,
      }).toList(),
      'users': usersList,
    };
  }

  /// Dispara un respaldo en segundo plano si la sincronización automática está habilitada.
  /// Se ejecuta al agregar o editar productos, categorías y clientes para mantener Google Sheets al día.
  void triggerAutoBackupIfEnabled() {
    Future.microtask(() async {
      try {
        final config = await getConfig();
        if (config.isEnabled && config.autoSyncOnSale && config.isTenantAuthenticated) {
          debugPrint('Sincronizando automáticamente catálogo en Google Sheets...');
          await createFullBackup();
        }
      } catch (e) {
        debugPrint('Auto-backup silencioso omitido: $e');
      }
    });
  }

  /// Realiza un Respaldo Completo (Full Backup) manual hacia la hoja exclusiva del negocio
  Future<({bool success, String message})> createFullBackup() async {
    var config = await getConfig();
    if (!config.isConfigured) {
      return (success: false, message: 'Google Sheets no está configurado');
    }

    if (!config.isTenantAuthenticated) {
      final ok = await ensureTenantRegistered();
      if (!ok) {
        return (success: false, message: 'Esperando conexión a Internet para registrar la tienda en la nube');
      }
      config = await getConfig();
    }

    isSyncingNotifier.value = true;
    try {
      final snapshot = await _buildFullSnapshot();
      final payload = {
        'action': 'fullBackup',
        'businessId': config.businessId,
        'authToken': config.authToken,
        'data': snapshot,
      };

      final resp = await _httpPost(config.effectiveScriptUrl, payload);
      if (resp != null && resp['success'] == true) {
        final updatedConfig = config.copyWith(lastSyncAt: DateTime.now());
        await saveConfig(updatedConfig);
        return (success: true, message: '¡Respaldo completo guardado exitosamente en tu hoja de Google Sheets!');
      }

      return (success: false, message: resp?['error']?.toString() ?? 'Error al enviar respaldo a Google Sheets');
    } catch (e) {
      return (success: false, message: 'Fallo al realizar respaldo: $e');
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Restaura o descarga todo el catálogo desde Google Sheets hacia Isar local
  Future<({bool success, int productsImported, String message})> restoreCatalogFromSheets() async {
    var config = await getConfig();
    if (!config.isConfigured) {
      return (success: false, productsImported: 0, message: 'Google Sheets no está configurado');
    }

    if (!config.isTenantAuthenticated) {
      final ok = await ensureTenantRegistered();
      if (!ok) {
        return (success: false, productsImported: 0, message: 'No hay conexión para sincronizar con la nube');
      }
      config = await getConfig();
    }

    isSyncingNotifier.value = true;
    try {
      final queryParams = <String, String>{'action': 'getCatalog'};
      if (config.businessId != null) queryParams['businessId'] = config.businessId!;
      if (config.authToken != null) queryParams['authToken'] = config.authToken!;

      final resp = await _httpGet(config.effectiveScriptUrl, queryParams: queryParams);
      if (resp == null || resp['success'] != true || resp['data'] == null) {
        return (success: false, productsImported: 0, message: resp?['error']?.toString() ?? 'No se pudo obtener el catálogo desde Google Sheets');
      }

      final data = resp['data'] as Map<String, dynamic>;
      final isar = DatabaseService.db;

      final categoriesData = (data['categories'] as List<dynamic>? ?? []);
      final productsData = (data['products'] as List<dynamic>? ?? []);
      final customersData = (data['customers'] as List<dynamic>? ?? []);

      int importedCount = 0;

      await isar.writeTxn(() async {
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
          importedCount++;
        }

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

        // Sincronizar Usuarios / Cajeros con PIN desencriptado
        final usersData = (data['users'] as List<dynamic>? ?? []);
        final secretKey = '${config.businessId ?? "BODEGO"}_${GoogleSheetsConfig.cloudSecretKey}';

        for (final item in usersData) {
          final name = (item['name'] as String? ?? '').trim();
          final role = (item['role'] as String? ?? 'cajero').trim();
          final encPin = (item['pin'] as String? ?? '').trim();
          final plainPin = encPin.isNotEmpty
              ? CloudSecurityManager.decryptPin(encPin, secretKey: secretKey)
              : '';
          final email = (item['email'] as String?)?.trim();

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

          if (plainPin.isNotEmpty) u.pin = plainPin;
          if (email != null && email.isNotEmpty) u.email = email;
          await isar.users.put(u);
        }
      });

      final updatedConfig = config.copyWith(lastSyncAt: DateTime.now());
      await saveConfig(updatedConfig);

      return (
        success: true,
        productsImported: importedCount,
        message: '¡Catálogo descargado y sincronizado con éxito! ($importedCount productos)',
      );
    } catch (e) {
      return (success: false, productsImported: 0, message: 'Fallo al restaurar catálogo: $e');
    } finally {
      isSyncingNotifier.value = false;
    }
  }

  /// Trae los movimientos más recientes desde Google Sheets para reflejarlos en este equipo (Pull Updates)
  Future<({bool success, int deltasApplied, String message})> pullUpdates() async {
    var config = await getConfig();
    if (!config.isConfigured) {
      return (success: false, deltasApplied: 0, message: 'Google Sheets no configurado');
    }

    if (!config.isTenantAuthenticated) {
      return (success: true, deltasApplied: 0, message: 'Pendiente de vinculación');
    }

    final license = await LicenseService().init();
    final myMachineId = license.machineId;

    final sinceDate = config.lastSyncAt ?? DateTime.now().subtract(const Duration(days: 7));
    final queryParams = <String, String>{
      'action': 'pullUpdates',
      'since': sinceDate.toIso8601String(),
    };
    if (config.businessId != null) queryParams['businessId'] = config.businessId!;
    if (config.authToken != null) queryParams['authToken'] = config.authToken!;

    final resp = await _httpGet(config.effectiveScriptUrl, queryParams: queryParams);

    if (resp == null || resp['success'] != true) {
      return (success: false, deltasApplied: 0, message: 'No se pudieron descargar novedades');
    }

    final updates = (resp['updates'] as List<dynamic>? ?? []);
    if (updates.isEmpty) {
      return (success: true, deltasApplied: 0, message: 'Sin movimientos nuevos por aplicar');
    }

    int applied = 0;
    final isar = DatabaseService.db;

    await isar.writeTxn(() async {
      for (final up in updates) {
        final originDevice = up['deviceId'] as String?;
        if (originDevice == myMachineId) continue;

        final type = up['type'] as String?;
        final data = (up['data'] as Map<String, dynamic>? ?? {});

        if (type == 'VENTA') {
          final ticket = data['ticket'] as Map<String, dynamic>?;
          final items = (ticket?['items'] as List<dynamic>? ?? []);
          for (final itm in items) {
            final pName = itm['name'] as String?;
            final qty = (itm['quantity'] as num?)?.toDouble() ?? 0.0;
            if (pName != null && qty > 0) {
              final prod = await isar.products.filter().nameEqualTo(pName, caseSensitive: false).findFirst();
              if (prod != null) {
                prod.stock = (prod.stock - qty).clamp(0.0, double.infinity);
                await isar.products.put(prod);
              }
            }
          }

          final isCredit = ticket?['isCredit'] as bool? ?? false;
          final total = (ticket?['total'] as num?)?.toDouble() ?? 0.0;
          final cName = ticket?['customerName'] as String?;
          if (isCredit && cName != null && cName.isNotEmpty && total > 0) {
            final cust = await isar.customers.filter().nameEqualTo(cName, caseSensitive: false).findFirst();
            if (cust != null) {
              cust.currentDebt += total;
              await isar.customers.put(cust);
            }
          }
          applied++;
        } else if (type == 'ABONO_DEUDA') {
          final cName = data['customerName'] as String?;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          if (cName != null && amount > 0) {
            final cust = await isar.customers.filter().nameEqualTo(cName, caseSensitive: false).findFirst();
            if (cust != null) {
              cust.currentDebt = (cust.currentDebt - amount).clamp(0.0, double.infinity);
              await isar.customers.put(cust);
            }
          }
          applied++;
        } else if (type == 'REPOSICION_STOCK') {
          final pName = data['productName'] as String?;
          final qty = (data['quantity'] as num?)?.toDouble() ?? 0.0;
          final newCost = (data['newCostPrice'] as num?)?.toDouble();
          if (pName != null && qty > 0) {
            final prod = await isar.products.filter().nameEqualTo(pName, caseSensitive: false).findFirst();
            if (prod != null) {
              prod.stock += qty;
              if (newCost != null && newCost > 0) prod.costPrice = newCost;
              await isar.products.put(prod);
            }
          }
          applied++;
        }
      }
    });

    final updatedConfig = config.copyWith(lastSyncAt: DateTime.now());
    await saveConfig(updatedConfig);

    return (
      success: true,
      deltasApplied: applied,
      message: 'Se aplicaron $applied movimientos con éxito',
    );
  }

  /// Sincronización Completa Bidireccional
  Future<({bool success, int pushed, int pulled, String message})> syncNow() async {
    isSyncingNotifier.value = true;
    try {
      // 0. Auto-registro si no está registrado aún
      final config = await getConfig();
      if (!config.isTenantAuthenticated) {
        final ok = await ensureTenantRegistered();
        if (!ok) {
          return (
            success: false,
            pushed: 0,
            pulled: 0,
            message: 'No se pudo conectar a la nube. Verifica tu conexión a Internet.',
          );
        }
      }

      // 1. Despachar movimientos pendientes (Push)
      final pushResult = await processPendingQueue();

      // 2. Traer novedades foráneas (Pull)
      final pullResult = await pullUpdates();

      final success = pushResult.success || pullResult.success;
      final msg = pushResult.success
          ? 'Sincronización completada. ${pushResult.count} enviados, ${pullResult.deltasApplied} recibidos.'
          : 'Atención: ${pushResult.error ?? "No se pudieron enviar pendientes"}';

      return (
        success: success,
        pushed: pushResult.count,
        pulled: pullResult.deltasApplied,
        message: msg,
      );
    } catch (e) {
      return (
        success: false,
        pushed: 0,
        pulled: 0,
        message: 'Error durante la sincronización: $e',
      );
    } finally {
      isSyncingNotifier.value = false;
    }
  }
}
