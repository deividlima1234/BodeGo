import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:bodego/core/theme/app_theme.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';
import 'package:bodego/data/local/isar/collections/app_settings.dart';
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/license_info.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/core/services/license_service.dart';

/// Implementación Fake de PathProviderPlatform para aislar tests del sistema de archivos real
class FakePathProviderPlatform extends PathProviderPlatform {
  final String tempPath;
  FakePathProviderPlatform(this.tempPath);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;

  @override
  Future<String?> getLibraryPath() async => tempPath;
}

class GoldenTestHelper {
  static late Directory tempDir;
  static Isar? isar;

  /// Carga las tipografías reales del SDK de Flutter para erradicar la fuente Ahem (cuadros negros)
  static Future<void> loadRealFonts() async {
    const fontsPath = '/home/eddam/development/flutter/bin/cache/artifacts/material_fonts';
    final fontsDir = Directory(fontsPath);

    if (fontsDir.existsSync()) {
      // 1. MaterialIcons
      final iconFile = File('$fontsPath/MaterialIcons-Regular.otf');
      if (iconFile.existsSync()) {
        final fontLoader = FontLoader('MaterialIcons');
        fontLoader.addFont(Future.value(ByteData.sublistView(iconFile.readAsBytesSync())));
        await fontLoader.load();
      }

      // 2. sans-serif y Roboto (Regular, Medium, Bold)
      final sansLoader = FontLoader('sans-serif');
      final robotoLoader = FontLoader('Roboto');

      for (final fontName in [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
      ]) {
        final file = File('$fontsPath/$fontName');
        if (file.existsSync()) {
          final data = ByteData.sublistView(file.readAsBytesSync());
          sansLoader.addFont(Future.value(data));
          robotoLoader.addFont(Future.value(data));
        }
      }

      await sansLoader.load();
      await robotoLoader.load();
    }
  }

  /// Inicializa el entorno aislado de base de datos Isar y archivos locales
  static Future<void> initTestEnvironment() async {
    tempDir = Directory.systemTemp.createTempSync('bodego_golden_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);

    // Inicializar core nativo de Isar con el binario local pre-descargado
    final isarBinary = File('test/libisar_linux_x64.so').absolute.path;
    await Isar.initializeIsarCore(
      libraries: {
        Abi.linuxX64: isarBinary,
      },
    );

    isar = await Isar.open(
      [
        ProductSchema,
        CategorySchema,
        AppSettingsSchema,
        UserSchema,
        CustomerSchema,
      ],
      directory: tempDir.path,
      name: 'bodego_golden_db',
      inspector: false,
    );

    DatabaseService.setTestInstance(isar);

    // Configurar Licencia perpetua activa
    final license = LicenseInfo(
      machineId: 'DORUCK_DEVICE_001',
      trialStartDate: DateTime.now(),
      lastActiveDate: DateTime.now(),
      isActivated: true,
      licenseType: 'lifetime',
    );
    LicenseService().licenseNotifier.value = license;

    // Escribir archivo de licencia simulado
    final licenseFile = File('${tempDir.path}/app_license.json');
    licenseFile.writeAsStringSync(jsonEncode(license.toJson()));
  }

  /// Restablece la base de datos para simular una instalación nueva (Onboarding)
  static Future<void> resetToFreshInstall() async {
    if (isar != null && isar!.isOpen) {
      await isar!.writeTxn(() async {
        await isar!.clear();
      });
    }

    // Configuración inicial de negocio en blanco o por defecto
    const initialConfig = BusinessConfig(
      businessName: '',
    );
    await BusinessConfigRepository().saveConfig(initialConfig);

    // AppSettings con isFirstRun = true
    final settings = AppSettings()..isFirstRun = true;
    await isar!.writeTxn(() async {
      await isar!.appSettings.put(settings);
    });
  }

  /// Puebla la base de datos con los datos de negocio requeridos:
  /// Minimarket Doruck, Dueño Devid, Cajero Eloy (PIN 1234) y catálogo en soles
  static Future<void> seedDoruckBusinessData() async {
    if (isar == null || !isar!.isOpen) return;

    await isar!.writeTxn(() async {
      await isar!.clear();

      // 1. AppSettings configurado
      final settings = AppSettings()
        ..isFirstRun = false
        ..businessName = 'Minimarket Doruck'
        ..selectedTheme = 'moderno';
      await isar!.appSettings.put(settings);

      // 2. Usuarios: Administrador Devid y Cajero Eloy (PIN 1234)
      final admin = User()
        ..name = 'Devid'
        ..role = 'admin'
        ..email = 'admin@minimakt.com'
        ..password = '123456';
      await isar!.users.put(admin);

      final cashier = User()
        ..name = 'Eloy'
        ..role = 'cajero'
        ..pin = '1234';
      await isar!.users.put(cashier);

      // 3. Categorías
      final catAbarrotes = Category()
        ..name = 'Abarrotes'
        ..hexColor = '#4353FF';
      await isar!.categorys.put(catAbarrotes);

      final catLacteos = Category()
        ..name = 'Lácteos y Huevos'
        ..hexColor = '#10B981';
      await isar!.categorys.put(catLacteos);

      final catBebidas = Category()
        ..name = 'Bebidas y Licores'
        ..hexColor = '#F59E0B';
      await isar!.categorys.put(catBebidas);

      final catSnacks = Category()
        ..name = 'Snacks y Golosinas'
        ..hexColor = '#EF4444';
      await isar!.categorys.put(catSnacks);

      final catLimpieza = Category()
        ..name = 'Limpieza del Hogar'
        ..hexColor = '#8B5CF6';
      await isar!.categorys.put(catLimpieza);

      // 4. Productos de Minimarket Doruck
      final p1 = Product()
        ..name = 'Arroz Costeño Extra 1 kg'
        ..salePrice = 4.80
        ..costPrice = 3.90
        ..stock = 45.0
        ..minStock = 5.0
        ..unit = 'und'
        ..barcode = '7750123456789';
      p1.category.value = catAbarrotes;
      await isar!.products.put(p1);
      await p1.category.save();

      final p2 = Product()
        ..name = 'Aceite Primor Premium 900 ml'
        ..salePrice = 9.50
        ..costPrice = 7.80
        ..stock = 24.0
        ..minStock = 4.0
        ..unit = 'und'
        ..barcode = '7750123456790';
      p2.category.value = catAbarrotes;
      await isar!.products.put(p2);
      await p2.category.save();

      final p3 = Product()
        ..name = 'Leche Gloria Azul 400 g'
        ..salePrice = 4.20
        ..costPrice = 3.50
        ..stock = 36.0
        ..minStock = 6.0
        ..unit = 'und'
        ..barcode = '7750123456791';
      p3.category.value = catLacteos;
      await isar!.products.put(p3);
      await p3.category.save();

      final p4 = Product()
        ..name = 'Huevos Pardos Frescos (kg)'
        ..salePrice = 7.50
        ..costPrice = 6.00
        ..stock = 18.5
        ..minStock = 5.0
        ..unit = 'kg'
        ..barcode = '7750123456792';
      p4.category.value = catLacteos;
      await isar!.products.put(p4);
      await p4.category.save();

      final p5 = Product()
        ..name = 'Inca Kola 1.5 L Retornable'
        ..salePrice = 6.50
        ..costPrice = 5.00
        ..stock = 16.0
        ..minStock = 4.0
        ..unit = 'und'
        ..barcode = '7750123456793';
      p5.category.value = catBebidas;
      await isar!.products.put(p5);
      await p5.category.save();

      final p6 = Product()
        ..name = 'Galletas Casino Menta x 6'
        ..salePrice = 3.50
        ..costPrice = 2.60
        ..stock = 25.0
        ..minStock = 5.0
        ..unit = 'und'
        ..barcode = '7750123456794';
      p6.category.value = catSnacks;
      await isar!.products.put(p6);
      await p6.category.save();

      final p7 = Product()
        ..name = 'Detergente Bolívar Floral 800 g'
        ..salePrice = 5.50
        ..costPrice = 4.20
        ..stock = 14.0
        ..minStock = 3.0
        ..unit = 'und'
        ..barcode = '7750123456795';
      p7.category.value = catLimpieza;
      await isar!.products.put(p7);
      await p7.category.save();

      // 5. Clientes frecuentes
      final c1 = Customer()
        ..name = 'Doña Carmen Rodríguez'
        ..phone = '987 123 456'
        ..creditLimit = 250.0
        ..currentDebt = 84.50;
      await isar!.customers.put(c1);
    });

    // Guardar configuración oficial en business_config.json
    const config = BusinessConfig(
      businessName: 'Minimarket Doruck',
      ruc: '20601234567',
      address: 'Av. Principal 123',
      phone: 'Tel / Cel: 987 654 321',
      logoType: 'preset',
      logoValue: 'storefront',
      showBarcodeOnTicket: true,
      showEddamCoreBranding: true,
    );
    await BusinessConfigRepository().saveConfig(config);
  }

  /// Limpia los recursos del entorno de pruebas
  static Future<void> tearDownEnvironment() async {
    if (isar != null && isar!.isOpen) {
      await isar!.close();
      isar = null;
    }
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Configura el viewport móvil estándar (390 x 844 px @ 3.0 DPR)
  static void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3.0, 844 * 3.0);
    tester.view.devicePixelRatio = 3.0;
  }

  /// Construye la app envuelta en el tema oficial de BodeGo
  static Widget buildApp(Widget child, {GlobalKey? repaintKey}) {
    return MaterialApp(
      title: 'BodeGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(BodeGoTheme.moderno),
      home: repaintKey != null
          ? RepaintBoundary(key: repaintKey, child: child)
          : child,
    );
  }

  /// Captura la pantalla y la guarda como Golden file en la ruta designada
  static Future<void> captureScreen(WidgetTester tester, String filename) async {
    final screenshotsDir = Directory('docs/manual/screenshots/01_onboarding_y_acceso');
    if (!screenshotsDir.existsSync()) {
      screenshotsDir.createSync(recursive: true);
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/manual/screenshots/01_onboarding_y_acceso/$filename'),
    );
  }
}
