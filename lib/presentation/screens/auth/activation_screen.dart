import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/data/models/license_info.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';
import 'package:bodego/presentation/screens/auth/widgets/developer_panel_modal.dart';
import 'package:bodego/presentation/widgets/bodego_logo.dart';

/// Pantalla elegante y persuasiva de activación de licencia.
/// Se presenta automáticamente cuando expira el periodo de prueba de 7 días.
class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final LicenseService _licenseService = LicenseService();
  final TextEditingController _codeController = TextEditingController();

  int _logoTapCount = 0;
  DateTime? _lastLogoTap;
  bool _isActivating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (_lastLogoTap == null || now.difference(_lastLogoTap!) > const Duration(seconds: 2)) {
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }
    _lastLogoTap = now;

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      HapticFeedback.heavyImpact();
      DeveloperPanelModal.show(context);
    }
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _attemptActivation() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa tu clave de activación.';
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _errorMessage = null;
    });

    final success = await _licenseService.validateAndActivate(code);

    if (!mounted) return;

    setState(() {
      _isActivating = false;
    });

    if (success) {
      HapticFeedback.heavyImpact();
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                '¡BodeGo Activado con Éxito!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Tu licencia ha sido verificada y vinculada a este equipo. Disfruta de todas las funciones sin restricciones.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4353FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
                    );
                  },
                  child: const Text('INGRESAR AL SISTEMA'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = 'Clave de activación inválida para este equipo. Verifica e intenta nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<LicenseInfo?>(
          valueListenable: _licenseService.licenseNotifier,
          builder: (context, info, _) {
            final machineId = info?.machineId ?? 'BDG-0000-0000';

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logotipo con shortcut secreto de desarrollador (5 toques)
                      GestureDetector(
                        onTap: _handleLogoTap,
                        child: const BodeGoLogoWidget(
                          size: 70,
                          withBackground: true,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Título
                      const Text(
                        'Periodo de Prueba Finalizado',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tus 7 días de prueba gratis han concluido. Para continuar usando BodeGo y respaldar tu negocio, activa tu licencia.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tarjeta con ID del Equipo
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF4353FF).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4353FF).withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.fingerprint_rounded,
                                  size: 18,
                                  color: Color(0xFF4353FF),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'ID ÚNICO DE TU EQUIPO',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    color: Color(0xFF4353FF),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SelectableText(
                              machineId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('Copiar ID de Equipo'),
                              onPressed: () => _copyToClipboard(
                                machineId,
                                'ID de Equipo copiado',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón Solicitar Activación por WhatsApp
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded),
                          label: const Text(
                            'SOLICITAR ACTIVACIÓN (WHATSAPP)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            final msg =
                                'Hola, deseo activar mi licencia para BodeGo. Mi ID de equipo es: *$machineId*';
                            _copyToClipboard(msg, 'Mensaje listo para enviar a WhatsApp');
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text(
                              '¿YA TIENES TU CLAVE?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[500],
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.withOpacity(0.3))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Input Código de Activación
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Clave de Activación',
                          hintText: 'ACT-XXXX-XXXX-XXXX',
                          errorText: _errorMessage,
                          prefixIcon: const Icon(Icons.vpn_key_rounded),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.paste_rounded),
                            tooltip: 'Pegar clave',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null) {
                                setState(() {
                                  _codeController.text = data!.text!.trim();
                                });
                              }
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón Activar BodeGo
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4353FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _isActivating ? null : _attemptActivation,
                          child: _isActivating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'ACTIVAR MI BODEGO',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Nota de pie
                      Text(
                        'Tecnología segura respaldada por EddamCore.\nToca 5 veces el logo si eres el desarrollador.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
