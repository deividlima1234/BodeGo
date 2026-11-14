import 'package:flutter/material.dart';
import 'package:bodego/core/theme/app_theme.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/presentation/screens/auth/onboarding_screen.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';
import 'package:bodego/presentation/widgets/bodego_logo.dart';

/// Pantalla de Splash cinemática animada con el logotipo oficial de BodeGo
/// y enrutamiento inteligente según el estado del Onboarding.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();

  late final AnimationController _animController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textFade;
  late final Animation<double> _badgeFade;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoScale = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.70, curve: Curves.easeIn),
      ),
    );

    _badgeFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.60, 0.95, curve: Curves.easeIn),
      ),
    );

    _animController.forward();
    _handleRouting();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleRouting() async {
    // 2.4 segundos para que se aprecie la animación completa
    await Future.delayed(const Duration(milliseconds: 2400));

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
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OnboardingScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const PinLoginScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error en enrutamiento inicial: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F121C) : const Color(0xFFF9FAFF),
      body: SafeArea(
        child: Stack(
          children: [
            // Resplandor sutil ambiental en el fondo
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4353FF).withOpacity(isDark ? 0.15 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Contenido Central Animado
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Isotipo / Logo Animado
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: const BodeGoLogoWidget(
                        size: 110,
                        borderRadius: 28,
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // 2. Marca "BodeGo" con tipografía estilizada
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Bode',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                              color: isDark ? Colors.white : const Color(0xFF1E222D),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4353FF), Color(0xFF00D084)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00D084).withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Text(
                              'GO',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Insignia "by EddamCore"
                  FadeTransition(
                    opacity: _badgeFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : const Color(0xFF4353FF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.12)
                              : const Color(0xFF4353FF).withOpacity(0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: Color(0xFF4353FF),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'by EddamCore',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white70 : const Color(0xFF4353FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Pie de página con barra de carga y crédito
            Positioned(
              left: 30,
              right: 30,
              bottom: 28,
              child: FadeTransition(
                opacity: _badgeFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Barra de progreso delgada animada
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _animController.value,
                            minHeight: 3.5,
                            backgroundColor: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.grey.withOpacity(0.15),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4353FF)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tecnología impulsada por eddamcore.com',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
