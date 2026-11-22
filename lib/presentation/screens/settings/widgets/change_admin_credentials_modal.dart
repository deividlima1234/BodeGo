import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/core/services/cloud_security_manager.dart';
import 'package:bodego/core/services/google_sheets_sync_service.dart';

/// Modal Bottom Sheet para actualizar los datos y credenciales del Administrador
/// (Nombre, Correo Electrónico y Contraseña con privilegios totales).
/// Exige la contraseña actual para autorizar cualquier modificación.
class ChangeAdminCredentialsModal extends StatefulWidget {
  final VoidCallback? onSaved;

  const ChangeAdminCredentialsModal({super.key, this.onSaved});

  static Future<void> show(BuildContext context, {VoidCallback? onSaved}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeAdminCredentialsModal(onSaved: onSaved),
    );
  }

  @override
  State<ChangeAdminCredentialsModal> createState() => _ChangeAdminCredentialsModalState();
}

class _ChangeAdminCredentialsModalState extends State<ChangeAdminCredentialsModal> {
  final UserRepository _userRepo = UserRepository();
  final GoogleSheetsSyncService _syncService = GoogleSheetsSyncService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  User? _admin;
  bool _isCloudSyncConfigured = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    final admin = await _userRepo.getFirstAdmin();
    final cloudConfig = await _syncService.getConfig();

    if (mounted) {
      setState(() {
        _admin = admin;
        _nameController.text = admin?.name ?? 'Administrador Principal';
        _emailController.text = admin?.email ?? '';
        _isCloudSyncConfigured = cloudConfig.isTenantAuthenticated;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;
    final currentPass = _currentPasswordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Ingresa el nombre del Administrador.');
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Ingresa un correo electrónico válido.');
      return;
    }

    if (newPass.isNotEmpty) {
      if (newPass.length < 4) {
        setState(() => _errorMessage = 'La nueva contraseña debe tener al menos 4 caracteres.');
        return;
      }
      if (newPass != confirmPass) {
        setState(() => _errorMessage = 'La confirmación de la nueva contraseña no coincide.');
        return;
      }
    }

    if (currentPass.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu contraseña actual para autorizar los cambios.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    HapticFeedback.selectionClick();

    // 1. Validar contraseña actual del Administrador
    final isAuthorized = await _userRepo.validateAdminPassword(currentPass);
    if (!isAuthorized) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'La contraseña actual es incorrecta.';
        });
        HapticFeedback.heavyImpact();
      }
      return;
    }

    // 2. Actualizar en la base de datos local Isar
    final effectiveNewPass = newPass.isNotEmpty ? newPass : null;
    await _userRepo.updateAdmin(
      userId: _admin?.id,
      name: name,
      email: email,
      password: effectiveNewPass,
    );

    // 3. Sincronizar actualización con la Nube (Google Sheets) si está configurado
    String? cloudNotice;
    if (_isCloudSyncConfigured) {
      final cloudRes = await CloudSecurityManager().updateBusinessProfile(
        ownerName: name,
        ownerEmail: email,
        newPassword: effectiveNewPass,
      );
      if (!cloudRes.success) {
        cloudNotice = 'Guardado localmente. La nube se actualizará al tener mejor conexión.';
      }
    }

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                cloudNotice ?? '¡Credenciales de Administrador actualizadas exitosamente!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: cloudNotice != null ? const Color(0xFFD97706) : Colors.green[800],
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
                            color: const Color(0xFFF59E0B).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Color(0xFFD97706),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Perfil de Administrador',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Nombre, correo y clave de acceso total',
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
                  // Indicador de sincronización en la nube si está activo
                  if (_isCloudSyncConfigured) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4353FF).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF4353FF).withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_done_rounded, color: Color(0xFF4353FF), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Conectado a Google Sheets • Los cambios se respaldarán en la nube.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF4353FF), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

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

                  // Campo 1: Nombre del Administrador
                  const Text(
                    'Nombre del Administrador',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      hintText: 'Ej. Administrador Principal',
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
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
                  const SizedBox(height: 14),

                  // Campo 2: Correo Electrónico
                  const Text(
                    'Correo Electrónico (Para recuperación y nube)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      hintText: 'admin@bodego.pe',
                      prefixIcon: const Icon(Icons.email_outlined, size: 20),
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
                  const SizedBox(height: 18),

                  // Sección: Cambio de Contraseña (Opcional)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.key_rounded, size: 18, color: Color(0xFF4353FF)),
                            SizedBox(width: 8),
                            Text(
                              'Nueva Contraseña (Opcional)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Déjala en blanco si solo deseas actualizar tu nombre o correo.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Nueva Contraseña
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF262626) : Colors.white,
                            hintText: 'Nueva contraseña (mínimo 4 caracteres)',
                            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureNewPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                size: 18,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
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
                              borderSide: const BorderSide(color: Color(0xFF4353FF), width: 1.8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Confirmar Nueva Contraseña
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF262626) : Colors.white,
                            hintText: 'Confirmar nueva contraseña',
                            prefixIcon: const Icon(Icons.check_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                size: 18,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
                              borderSide: const BorderSide(color: Color(0xFF4353FF), width: 1.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Caja de Confirmación de Identidad con Contraseña Actual
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
                            Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Confirmar Identidad',
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
                          'Ingresa tu contraseña actual de Administrador para aplicar los cambios.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: _obscureCurrentPassword,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                            hintText: 'Contraseña Actual del Administrador',
                            prefixIcon: const Icon(Icons.password_rounded, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureCurrentPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                size: 18,
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                              onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
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
                                      'Guardar Cambios',
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
