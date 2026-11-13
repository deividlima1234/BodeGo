import 'package:flutter/material.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
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
  String _pin = '';
  String _businessName = 'BodeGo';
  String? _errorMessage;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadBusinessName();
  }

  Future<void> _loadBusinessName() async {
    final settings = await _settingsRepository.getSettings();
    if (mounted && (settings.businessName?.isNotEmpty ?? false)) {
      setState(() {
        _businessName = settings.businessName!;
      });
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

    final cashier = await _userRepository.validateCashierPin(_pin);

    if (!mounted) return;

    if (cashier != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPosScreen()),
      );
    } else {
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
              const SizedBox(height: 20),
              Container(
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 24),

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

              const SizedBox(height: 16),

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
