import 'package:flutter/material.dart';
import 'package:bodego/core/theme/app_theme.dart';
import 'package:bodego/core/services/app_version_service.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/presentation/screens/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.init();
  await AppVersionService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BodeGoTheme>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentTheme, _) {
        return MaterialApp(
          title: 'BodeGo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(currentTheme),
          home: const SplashScreen(),
        );
      },
    );
  }
}
