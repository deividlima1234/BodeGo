import 'package:flutter_test/flutter_test.dart';
import 'package:bodego/main.dart';

void main() {
  testWidgets('BodeGo smoke test - SplashScreen displays title', (WidgetTester tester) async {
    // Construye la aplicación y dispara un frame
    await tester.pumpWidget(const MyApp());

    // Verifica que el texto del Splash Screen esté en pantalla
    expect(find.text('BodeGo by EddamCore'), findsOneWidget);
  });
}
