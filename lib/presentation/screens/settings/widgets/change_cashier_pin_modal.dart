import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/data/repositories/user_repository.dart';

/// Modal Bottom Sheet para actualizar el nombre y el PIN de 4 dígitos del Cajero de Turno.
/// Requiere la contraseña del Administrador para autorizar el cambio de clave.
class ChangeCashierPinModal extends StatefulWidget {
  final VoidCallback? onSaved;

  const ChangeCashierPinModal({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeCashierPinModal(onSaved: onSaved),
    );
  }

  @override
  State<ChangeCashierPinModal> createState() => _ChangeCashierPinModalState();
}

class _ChangeCashierPinModalState extends State<ChangeCashierPinModal> {
  final UserRepository _userRepo = UserRepository();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final TextEditingController _adminPasswordController = TextEditingController();

  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _obscureAdminPassword = true;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  User? _cashier;

  @override
  void initState() {
    super.initState();
    _loadCashierData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCashierData() async {
    final cashier = await _userRepo.getFirstCashier();
    if (mounted) {
      setState(() {
        _cashier = cashier;
        _nameController.text = cashier?.name ?? 'Cajero Principal';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();
    final adminPass = _adminPasswordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Ingresa el nombre del cajero.');
      return;
    }

    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _errorMessage = 'El PIN debe ser exactamente de 4 dígitos numéricos.');
      return;
    }

    if (pin != confirmPin) {
      setState(() => _errorMessage = 'La confirmación del PIN no coincide.');
      return;
    }

    if (adminPass.isEmpty) {
      setState(() => _errorMessage = 'Ingresa la contraseña del Administrador para autorizar.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    HapticFeedback.selectionClick();

    // 1. Validar autorización con la contraseña de Administrador
    final isAuthorized = await _userRepo.validateAdminPassword(adminPass);
    if (!isAuthorized) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'La contraseña de Administrador es incorrecta.';
        });
        HapticFeedback.heavyImpact();
      }
      return;
    }

    // 2. Actualizar cajero en Isar
    if (_cashier != null) {
      await _userRepo.updateCashier(_cashier!.id, name: name, pin: pin);
    } else {
      await _userRepo.updateOrCreateCashierPin(pin, name: name);
    }

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡PIN del Cajero actualizado exitosamente!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );

    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final media = MediaQuery.of(context);

    final fieldBg = isDark ? const Color(0xFF242424) : const Color(0xFFF3F4F6);
    final borderColor = colorScheme.onSurface.withOpacity(0.12);

    return Container(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tirador superior (Drag Handle)
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cabecera del Modal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4353FF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: Color(0xFF4353FF),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PIN de Cajero de Turno',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Control de acceso de 4 dígitos',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 16),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF4353FF)),
                    ),
                  )
                else ...[
                  // Banner de error si existe
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Campo 1: Nombre del Cajero
                  const Text(
                    'Nombre del Cajero',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      hintText: 'Ej. Deivid, Cajero Turno Mañana',
                      prefixIcon: const Icon(Icons.person_rounded, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF4353FF), width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campos de PIN: Nuevo PIN y Confirmar
                  Row(
                    children: [
                      // Nuevo PIN
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nuevo PIN (4 dígitos)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _pinController,
                              obscureText: _obscurePin,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: fieldBg,
                                hintText: '••••',
                                hintStyle: const TextStyle(letterSpacing: 4),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePin ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    size: 18,
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF4353FF), width: 1.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Confirmar PIN
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Confirmar PIN',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _confirmPinController,
                              obscureText: _obscureConfirmPin,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: fieldBg,
                                hintText: '••••',
                                hintStyle: const TextStyle(letterSpacing: 4),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPin ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                    size: 18,
                                    color: colorScheme.onSurface.withOpacity(0.5),
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF4353FF), width: 1.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Caja de Autorización del Administrador
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security_rounded, color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Autorización requerida',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ingresa la contraseña del Administrador para autorizar el cambio de PIN del cajero.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _adminPasswordController,
                          obscureText: _obscureAdminPassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                            hintText: 'Contraseña de Administrador',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureAdminPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                size: 18,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              onPressed: () => setState(() => _obscureAdminPassword = !_obscureAdminPassword),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4353FF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Guardar PIN',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
