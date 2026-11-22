import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodego/presentation/screens/auth/splash_screen.dart';
import 'package:bodego/presentation/screens/auth/onboarding_screen.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';
import 'package:bodego/presentation/screens/auth/widgets/welcome_presentation_view.dart';
import 'package:bodego/presentation/screens/auth/widgets/cloud_login_modal.dart';
import 'package:bodego/presentation/screens/auth/widgets/secondary_device_onboarding_modal.dart';
import 'package:bodego/presentation/screens/auth/widgets/legal_terms_modal.dart';
import 'package:bodego/presentation/screens/pos/main_pos_screen.dart';
import 'golden_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await GoldenTestHelper.loadRealFonts();
    await GoldenTestHelper.initTestEnvironment();
  });

  tearDownAll(() async {
    await GoldenTestHelper.tearDownEnvironment();
  });

  group('Fase 01: Onboarding, Autenticación y Acceso a Caja', () {
    // -------------------------------------------------------------------------
    // CAPTURA 01: Splash Screen Animado
    // -------------------------------------------------------------------------
    testWidgets('01_01_splash_arranque', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);
      await GoldenTestHelper.resetToFreshInstall();

      await tester.pumpWidget(GoldenTestHelper.buildApp(const SplashScreen()));
      // 1200ms para capturar el logo escalado y visible antes de la navegación automática
      await tester.pump(const Duration(milliseconds: 1200));

      await GoldenTestHelper.captureScreen(tester, '01_01_splash_arranque.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURA 02: Bienvenida Oficial BodeGo
    // -------------------------------------------------------------------------
    testWidgets('01_02_bienvenida_oficial', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);

      await tester.pumpWidget(
        GoldenTestHelper.buildApp(
          WelcomePresentationView(
            onStartTour: () {},
            onSkipToForm: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await GoldenTestHelper.captureScreen(tester, '01_02_bienvenida_oficial.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURA 03: Modal de Inicio de Sesión en la Nube
    // -------------------------------------------------------------------------
    testWidgets('01_03_modal_login_nube', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);

      await tester.pumpWidget(
        GoldenTestHelper.buildApp(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => CloudLoginModal.show(context),
                    child: const Text('Abrir Modal'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      // Ingresar credenciales de Administrador en el modal
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'admin@minimakt.com');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pumpAndSettle();

      await GoldenTestHelper.captureScreen(tester, '01_03_modal_login_nube.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURA 04: Modal Vincular Dispositivo Secundario
    // -------------------------------------------------------------------------
    testWidgets('01_04_modal_vincular_secundario', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);

      await tester.pumpWidget(
        GoldenTestHelper.buildApp(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => SecondaryDeviceOnboardingModal.show(context),
                    child: const Text('Abrir Vinculacion'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Vinculacion'));
      // Uso de pump con duración fija para no colgarse en la animación continua
      await tester.pump(const Duration(milliseconds: 400));

      await GoldenTestHelper.captureScreen(tester, '01_04_modal_vincular_secundario.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURA 05: Modal Términos y Condiciones Legales
    // -------------------------------------------------------------------------
    testWidgets('01_05_modal_terminos_legales', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);

      await tester.pumpWidget(
        GoldenTestHelper.buildApp(
          Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => LegalTermsModal.show(context),
                    child: const Text('Abrir Legales'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Abrir Legales'));
      await tester.pumpAndSettle();

      await GoldenTestHelper.captureScreen(tester, '01_05_modal_terminos_legales.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURAS 06 a 09: Tour Interactivo (Slides 1 al 4)
    // -------------------------------------------------------------------------
    testWidgets('01_06_a_09_tour_interactivo', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);
      await GoldenTestHelper.resetToFreshInstall();

      await tester.pumpWidget(GoldenTestHelper.buildApp(const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Abrir el tour
      await tester.tap(find.text('Descubrir Funcionalidades'));
      await tester.pump(const Duration(milliseconds: 400));

      // Slide 1: Ventas y Catálogo al Instante
      await GoldenTestHelper.captureScreen(tester, '01_06_tour_slide1_ventas.png');

      // Slide 2: Control de Fiados
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 400));
      await GoldenTestHelper.captureScreen(tester, '01_07_tour_slide2_fiados.png');

      // Slide 3: Tickets Térmicos
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 400));
      await GoldenTestHelper.captureScreen(tester, '01_08_tour_slide3_impresoras.png');

      // Slide 4: Cierre Z
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 400));
      await GoldenTestHelper.captureScreen(tester, '01_09_tour_slide4_cierre_z.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURAS 10 a 12: Wizard de 3 Pasos
    // -------------------------------------------------------------------------
    testWidgets('01_10_a_12_wizard_formulario', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);
      await GoldenTestHelper.resetToFreshInstall();

      await tester.pumpWidget(GoldenTestHelper.buildApp(const OnboardingScreen()));
      await tester.pumpAndSettle();

      // Saltar directamente al formulario
      await tester.tap(find.text('Configurar mi Bodega directamente'));
      await tester.pumpAndSettle();

      // --- PASO 1: Datos del Negocio ---
      final textFieldsP1 = find.byType(TextField);
      await tester.enterText(textFieldsP1.at(0), 'Minimarket Doruck');
      await tester.enterText(textFieldsP1.at(1), 'Av. Principal 123');
      await tester.enterText(textFieldsP1.at(2), '20601234567');
      await tester.pumpAndSettle();

      await GoldenTestHelper.captureScreen(tester, '01_10_wizard_paso1_negocio.png');

      // Avanzar al Paso 2
      await tester.tap(find.text('Siguiente: Administrador'));
      await tester.pumpAndSettle();

      // --- PASO 2: Administrador ---
      final textFieldsP2 = find.byType(TextField);
      await tester.enterText(textFieldsP2.at(0), 'Devid');
      await tester.enterText(textFieldsP2.at(1), 'admin@minimakt.com');
      await tester.enterText(textFieldsP2.at(2), 'password123');
      await tester.pumpAndSettle();

      await GoldenTestHelper.captureScreen(tester, '01_11_wizard_paso2_administrador.png');

      // Avanzar al Paso 3
      await tester.tap(find.text('Siguiente: Configurar Cajero'));
      await tester.pumpAndSettle();

      // --- PASO 3: Cajero y PIN ---
      final textFieldsP3 = find.byType(TextField);
      await tester.enterText(textFieldsP3.at(0), 'Eloy');
      await tester.pumpAndSettle();

      // Digitar PIN 1234 con el teclado táctil NumericPad
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('4'));
      await tester.pump(const Duration(milliseconds: 200));

      await GoldenTestHelper.captureScreen(tester, '01_12_wizard_paso3_cajero_pin.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURAS 13 y 14: Acceso Diario por PIN
    // -------------------------------------------------------------------------
    testWidgets('01_13_y_14_login_pin', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);
      await GoldenTestHelper.seedDoruckBusinessData();

      await tester.pumpWidget(GoldenTestHelper.buildApp(const PinLoginScreen()));
      await tester.pumpAndSettle();

      // Captura 13: Pantalla de bloqueo limpia esperando PIN
      await GoldenTestHelper.captureScreen(tester, '01_13_login_pin_pantalla_bloqueo.png');

      // Captura 14: Digitando PIN (3 números marcados)
      await tester.tap(find.text('1'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('2'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 100));

      await GoldenTestHelper.captureScreen(tester, '01_14_login_pin_ingresando.png');
    });

    // -------------------------------------------------------------------------
    // CAPTURA 15: Entrada a la Ventana Principal "Caja & Venta"
    // -------------------------------------------------------------------------
    testWidgets('01_15_caja_principal_llegada', (WidgetTester tester) async {
      GoldenTestHelper.configureViewport(tester);
      await GoldenTestHelper.seedDoruckBusinessData();

      await tester.pumpWidget(GoldenTestHelper.buildApp(const MainPosScreen()));
      // Permitir que se cargue la lista reactiva de productos y categorías de Isar
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await GoldenTestHelper.captureScreen(tester, '01_15_caja_principal_llegada.png');
    });
  });
}

