import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/data/models/license_info.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/presentation/screens/auth/activation_screen.dart';
import 'package:bodego/presentation/screens/auth/widgets/developer_panel_modal.dart';
import 'package:bodego/presentation/screens/pos/main_pos_screen.dart';
import 'package:bodego/presentation/widgets/numeric_pad.dart';

/// Pantalla de Login rápido con PIN para desbloquear la terminal de ventas.
class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();
  final UserRepository _userRepository = UserRepository();
  final LicenseService _licenseService = LicenseService();

  String _pin = '';
  String _businessName = 'BodeGo';
  String? _errorMessage;
  bool _isChecking = false;

  // Contador de toques secretos para el Desarrollador
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;

  @override
  void initState() {
    super.initState();
    _loadBusinessName();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    final license = await _licenseService.init();
    if (!mounted) return;
    if (!license.canAccessApp) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ActivationScreen()),
      );
    }
  }

  Future<void> _loadBusinessName() async {
    final settings = await _settingsRepository.getSettings();
    if (mounted && (settings.businessName?.isNotEmpty ?? false)) {
      setState(() {
        _businessName = settings.businessName!;
      });
    }
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

  void _onNumberSelected(String number) {
    if (_pin.length < 4 && !_isChecking) {
      setState(() {
        _errorMessage = null;
        _pin += number;
      });

      if (_pin.length == 4) {
        _validatePin();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty && !_isChecking) {
      setState(() {
        _errorMessage = null;
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _validatePin() async {
    setState(() {
      _isChecking = true;
    });

    // Validar estado de licencia antes de ingresar
    final license = await _licenseService.init();
    if (!license.canAccessApp) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ActivationScreen()),
      );
      return;
    }

    final cashier = await _userRepository.validateCashierPin(_pin);

    if (!mounted) return;

    if (cashier != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPosScreen()),
      );
    } else {
      // Verificar si hay algún cajero registrado en este equipo
      final allUsers = await _userRepository.getAllUsers();
      final hasCashiers = allUsers.any((u) => u.role == 'cajero');

      if (!hasCashiers) {
        // En este dispositivo aún no hay cajero registrado (ej. equipo vinculado antes de sincronizar usuarios)
        // Se crea automáticamente el cajero con este PIN de 4 dígitos para permitir el acceso inmediato
        await _userRepository.createCashier('Cajero Principal', _pin);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN configurado con éxito para este equipo.'),
            backgroundColor: Color(0xFF4353FF),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPosScreen()),
        );
        return;
      }

      setState(() {
        _isChecking = false;
        _errorMessage = 'PIN incorrecto. Intenta nuevamente.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // Indicador de Licencia / Periodo de prueba
              ValueListenableBuilder<LicenseInfo?>(
                valueListenable: _licenseService.licenseNotifier,
                builder: (context, info, _) {
                  if (info == null || info.isActivated) {
                    return const SizedBox(height: 16);
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          'Prueba Gratuita: ${info.trialDaysRemaining} días restantes',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Logo con toque secreto de 5 toques
              GestureDetector(
                onTap: _handleLogoTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _businessName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                'Ingresa tu PIN de 4 dígitos para ingresar',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Indicadores de los 4 círculos del PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final bool isFilled = index < _pin.length;
                  final bool hasError = _errorMessage != null;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasError
                          ? Colors.redAccent
                          : isFilled
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                      border: Border.all(
                        color: hasError
                            ? Colors.redAccent
                            : isFilled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 14),

              // Mensaje de error o estado de validación
              SizedBox(
                height: 24,
                child: _isChecking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _errorMessage != null
                        ? Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
              ),

              const Spacer(),

              // Teclado numérico táctil
              NumericPad(
                onNumberSelected: _onNumberSelected,
                onDelete: _onDelete,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

