import 'package:flutter/material.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/data/repositories/user_repository.dart';
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/presentation/screens/auth/widgets/legal_terms_modal.dart';
import 'package:bodego/core/services/app_version_service.dart';
import 'package:bodego/presentation/screens/settings/widgets/change_cashier_pin_modal.dart';
import 'package:bodego/presentation/screens/settings/widgets/change_admin_credentials_modal.dart';

/// Modal Bottom Sheet elegante y moderno que despliega los datos del negocio,
/// la información del Administrador/Encargado, el Cajero en turno y accesos rápidos.
/// 
/// Mapeado 100% a la paleta reactiva de [Theme.of(context).colorScheme] para soportar
/// cualquier cambio de tema futuro sin romper la interfaz.
class UserBusinessModal extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onLockOrSwitchCashier;

  const UserBusinessModal({
    super.key,
    this.onNavigateToSettings,
    this.onLockOrSwitchCashier,
  });

  /// Método estático para presentar el modal de manera rápida y limpia
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onNavigateToSettings,
    VoidCallback? onLockOrSwitchCashier,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserBusinessModal(
        onNavigateToSettings: onNavigateToSettings,
        onLockOrSwitchCashier: onLockOrSwitchCashier,
      ),
    );
  }

  @override
  State<UserBusinessModal> createState() => _UserBusinessModalState();
}

class _UserBusinessModalState extends State<UserBusinessModal> {
  final UserRepository _userRepo = UserRepository();
  final BusinessConfigRepository _configRepo = BusinessConfigRepository();

  bool _isLoading = true;
  BusinessConfig? _config;
  User? _adminUser;
  User? _cashierUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final config = await _configRepo.getConfig();
      final admin = await _userRepo.getFirstAdmin();
      final cashier = await _userRepo.getFirstCashier();

      if (mounted) {
        setState(() {
          _config = config;
          _adminUser = admin;
          _cashierUser = cashier;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark ? colorScheme.surface : colorScheme.background;
    final borderColor = colorScheme.onSurface.withOpacity(0.08);
    final cardBg = isDark
        ? colorScheme.background
        : colorScheme.surface.withOpacity(0.45);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ==========================================
                    // 1. MANIJA SUPERIOR (Drag Handle)
                    // ==========================================
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ==========================================
                    // 2. CABECERA PRINCIPAL: IDENTIDAD COMERCIAL
                    // ==========================================
                    _buildBusinessHeader(theme, cardBg, borderColor),
                    const SizedBox(height: 16),

                    // ==========================================
                    // 3. TARJETA: ENCARGADO / ADMINISTRADOR
                    // ==========================================
                    _buildAdminCard(theme, cardBg, borderColor),
                    const SizedBox(height: 12),

                    // ==========================================
                    // 4. TARJETA: CAJERO Y TURNO ACTIVO
                    // ==========================================
                    _buildCashierCard(theme, cardBg, borderColor),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 5. ACCIONES RÁPIDAS
                    // ==========================================
                    Text(
                      'ACCIONES RÁPIDAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: colorScheme.onSurface.withOpacity(0.45),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Botón: Cambiar de Cajero / Bloquear Caja
                    _buildActionButton(
                      theme: theme,
                      icon: Icons.lock_person_rounded,
                      title: 'Cambiar de Cajero / Bloquear Caja',
                      subtitle: 'Finaliza o traspasa la sesión de caja por PIN',
                      color: colorScheme.primary,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onLockOrSwitchCashier?.call();
                      },
                    ),
                    const SizedBox(height: 8),

                    // Botón: Configuración del Negocio
                    _buildActionButton(
                      theme: theme,
                      icon: Icons.storefront_rounded,
                      title: 'Configuración de la Tienda y Tickets',
                      subtitle: 'Personaliza RUC, dirección, logo y comprobantes',
                      color: colorScheme.secondary,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateToSettings?.call();
                      },
                    ),
                    const SizedBox(height: 8),

                    // Botón: Ver Términos y Privacidad EddamCore
                    _buildActionButton(
                      theme: theme,
                      icon: Icons.verified_user_rounded,
                      title: 'Acerca de BodeGo v${AppVersionService.versionName} & EddamCore',
                      subtitle: 'Términos de servicio, privacidad offline y soporte',
                      color: colorScheme.onSurface.withOpacity(0.7),
                      onTap: () {
                        Navigator.pop(context);
                        LegalTermsModal.show(context);
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Cabecera con datos comerciales de la Bodega
  Widget _buildBusinessHeader(ThemeData theme, Color cardBg, Color borderColor) {
    final colorScheme = theme.colorScheme;
    final config = _config ?? const BusinessConfig();

    final presetKey = config.logoValue;
    final preset = BusinessConfig.presets[presetKey] ??
        (icon: Icons.storefront_rounded, label: 'Bodega');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono / Isotipo de rubro
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  preset.icon,
                  color: colorScheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),

              // Nombre y Rubro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.businessName.isNotEmpty
                          ? config.businessName
                          : 'Mi Bodega',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            preset.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge Offline
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 3,
                                backgroundColor: colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '100% Offline',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // RUC y Dirección
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 15,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                config.ruc.isNotEmpty ? config.ruc : 'RUC: No registrado',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.receipt_long_outlined,
                size: 15,
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Text(
                '${config.paperWidthMm}mm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.65),
                ),
              ),
            ],
          ),
          if (config.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    config.address,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface.withOpacity(0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Tarjeta del Administrador / Encargado
  Widget _buildAdminCard(ThemeData theme, Color cardBg, Color borderColor) {
    final colorScheme = theme.colorScheme;
    final adminName = _adminUser?.name.isNotEmpty == true
        ? _adminUser!.name
        : 'Administrador Principal';
    final adminEmail = _adminUser?.email?.isNotEmpty == true
        ? _adminUser!.email!
        : 'admin@bodego.local';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Avatar Admin con corona
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primary.withOpacity(0.15),
                child: Text(
                  adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 9,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Nombres y rol
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        adminName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  adminEmail,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface.withOpacity(0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: colorScheme.onSurface.withOpacity(0.55),
            ),
            tooltip: 'Editar credenciales de Administrador',
            onPressed: () {
              Navigator.pop(context);
              ChangeAdminCredentialsModal.show(context);
            },
          ),
        ],
      ),
    );
  }

  /// Tarjeta del Cajero y Turno
  Widget _buildCashierCard(ThemeData theme, Color cardBg, Color borderColor) {
    final colorScheme = theme.colorScheme;
    final cashierName = _cashierUser?.name.isNotEmpty == true
        ? _cashierUser!.name
        : 'Cajero de Turno';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.secondary.withOpacity(0.18),
            child: Icon(
              Icons.point_of_sale_rounded,
              size: 20,
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cashierName,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'CAJERO',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.pin_outlined,
                      size: 13,
                      color: colorScheme.onSurface.withOpacity(0.45),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PIN 4 dígitos activo · Turno Abierto',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: colorScheme.onSurface.withOpacity(0.55),
            ),
            tooltip: 'Editar PIN de Cajero',
            onPressed: () {
              Navigator.pop(context);
              ChangeCashierPinModal.show(context);
            },
          ),
        ],
      ),
    );
  }

  /// Botón de acción interactivo
  Widget _buildActionButton({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withOpacity(0.5)
                : colorScheme.surface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.onSurface.withOpacity(0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
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
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.onSurface.withOpacity(0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
