import 'package:flutter/material.dart';
import 'package:bodego/core/theme/app_theme.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/presentation/screens/auth/onboarding_screen.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';

/// Pantalla de Splash que actúa como enrutador inicial de BodeGo.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();

  @override
  void initState() {
    super.initState();
    _handleRouting();
  }

  Future<void> _handleRouting() async {
    // Retraso de 2 segundos para que se aprecie la pantalla de presentación
    await Future.delayed(const Duration(seconds: 2));

    try {
      final settings = await _settingsRepository.getSettings();

      if (settings.selectedTheme == 'eddamcoreDark') {
        AppTheme.setTheme(BodeGoTheme.eddamcoreDark);
      } else {
        AppTheme.setTheme(BodeGoTheme.moderno);
      }

      if (!mounted) return;

      if (settings.isFirstRun) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PinLoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error en enrutamiento inicial: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'BodeGo by EddamCore',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tecnología impulsada por eddamcore.com',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
