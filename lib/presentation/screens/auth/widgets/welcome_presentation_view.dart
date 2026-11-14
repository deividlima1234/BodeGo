import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:bodego/presentation/widgets/bodego_logo.dart';
import 'package:bodego/presentation/screens/auth/widgets/legal_terms_modal.dart';

/// Pantalla de bienvenida institucional y presentación de BodeGo
/// Muestra qué es, qué hace, el respaldo de EddamCore y los accesos legales.
class WelcomePresentationView extends StatelessWidget {
  final VoidCallback onStartTour;
  final VoidCallback onSkipToForm;

  const WelcomePresentationView({
    super.key,
    required this.onStartTour,
    required this.onSkipToForm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),

              // 1. Badge Superior de Versión Oficial
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF4353FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF4353FF).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 14,
                      color: Color(0xFF4353FF),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Punto de Venta Oficial • Perú',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4353FF),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Isotipo Oficial BodeGo con Sombra y Profundidad
              const Center(
                child: BodeGoLogoWidget(
                  size: 88,
                  withBackground: true,
                  borderRadius: 22,
                ),
              ),

              const SizedBox(height: 14),

              // 3. Título Tipográfico BodeGo (Cápsula GO en Gradiente)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Bode',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4353FF), Color(0xFF00D084)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4353FF).withOpacity(0.4),
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
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Subtítulo de Posicionamiento
              Text(
                'El Sistema Punto de Venta ágil y moderno para bodegas y minimarkets.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // 4. ¿Qué es y qué hace BodeGo? (4 Pilares en Tarjetas Compactas)
              _buildFeatureCard(
                icon: Icons.flash_on_rounded,
                iconColor: const Color(0xFF4353FF),
                title: 'Ventas al Instante',
                description:
                    'Escanea códigos de barras o busca por nombre. Cobra con efectivo, Yape o Plin en segundos.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureCard(
                icon: Icons.book_outlined,
                iconColor: const Color(0xFFFFA114),
                title: 'Control Total de Fiados',
                description:
                    'Dile adiós a los cuadernos arrugados. Registra a tus clientes caseros, pon límites y anota abonos con exactitud.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureCard(
                icon: Icons.print_rounded,
                iconColor: const Color(0xFF00D084),
                title: 'Boletas e Impresión Bluetooth',
                description:
                    'Conéctate al instante a impresoras térmicas de 58mm y 80mm para entregar tickets claros con tu logo.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _buildFeatureCard(
                icon: Icons.wifi_off_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: '100% Offline-First',
                description:
                    'Funciona siempre sin necesidad de internet. Tus ventas y base de datos nunca salen de tu dispositivo.',
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // 5. Banner de Respaldo Tecnológico EddamCore
              InkWell(
                onTap: () => LegalTermsModal.show(context, initialTab: 2),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4353FF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4353FF).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          size: 18,
                          color: Color(0xFF4353FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tecnología e Innovación',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                            const Text(
                              'Impulsado por EddamCore',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4353FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'eddamcore.com',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded,
                                size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 6. Botón Principal: Conocer Funcionalidades (Tour Animado)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onStartTour,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4353FF),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFF4353FF).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Descubrir Funcionalidades',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 7. Botón Secundario: Configurar mi Bodega directamente
              TextButton(
                onPressed: onSkipToForm,
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
                ),
                child: const Text(
                  'Configurar mi Bodega directamente',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 8. Footer Legal y Condiciones con Enlaces Clicables
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                    children: [
                      const TextSpan(text: 'Al continuar, aceptas nuestros '),
                      TextSpan(
                        text: 'Términos y Condiciones',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4353FF),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              LegalTermsModal.show(context, initialTab: 0),
                      ),
                      const TextSpan(text: ' y nuestras '),
                      TextSpan(
                        text: 'Políticas de Privacidad',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00D084),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              LegalTermsModal.show(context, initialTab: 1),
                      ),
                      const TextSpan(
                        text: ' de EddamCore.',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

