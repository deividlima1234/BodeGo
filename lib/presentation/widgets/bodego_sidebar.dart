import 'package:flutter/material.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';
import 'package:bodego/presentation/widgets/bodego_logo.dart';
import 'package:bodego/presentation/widgets/user_business_modal.dart';
import 'package:bodego/presentation/screens/auth/widgets/legal_terms_modal.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';
import 'package:bodego/core/services/app_version_service.dart';

/// Barra lateral (Sidebar) moderna, elegante y adaptable para BodeGo.
/// 
/// Funciona tanto como [Drawer] deslizable en dispositivos móviles como panel
/// fijo/expandible en tablets y pantallas de escritorio.
/// 
/// Mapeada 100% a la paleta reactiva de [Theme.of(context).colorScheme] para soportar
/// cualquier cambio de tema presente o futuro de forma transparente.
class BodeGoSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isExpanded;
  final VoidCallback onToggleSidebar;
  final String businessName;
  final String userName;
  final bool isDrawer;
  final VoidCallback? onLogoutOrCloseShift;
  final VoidCallback? onOpenBusinessProfile;

  const BodeGoSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isExpanded,
    required this.onToggleSidebar,
    required this.businessName,
    required this.userName,
    this.isDrawer = false,
    this.onLogoutOrCloseShift,
    this.onOpenBusinessProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final List<_SidebarItemData> navItems = const [
      _SidebarItemData(
        title: 'Caja & Venta',
        icon: Icons.point_of_sale_rounded,
        emoji: '🛒',
      ),
      _SidebarItemData(
        title: 'Inventario & Stock',
        icon: Icons.inventory_2_rounded,
        emoji: '📦',
      ),
      _SidebarItemData(
        title: 'Clientes & Fiados',
        icon: Icons.people_alt_rounded,
        emoji: '👥',
      ),
      _SidebarItemData(
        title: 'Reportes & Cierre Z',
        icon: Icons.bar_chart_rounded,
        emoji: '📊',
      ),
      _SidebarItemData(
        title: 'Configuración',
        icon: Icons.settings_rounded,
        emoji: '⚙️',
      ),
    ];

    final double targetWidth = isDrawer
        ? 290.0
        : (isExpanded ? 250.0 : 72.0);

    final showContent = isExpanded || isDrawer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: targetWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        border: Border(
          right: BorderSide(
            color: colorScheme.onSurface.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ==========================================
          // 1. CABECERA CORPORATIVA DE ALTO IMPACTO
          // ==========================================
          _buildCorporateHeader(context, showContent),

          // ==========================================
          // 2. LISTA DE NAVEGACIÓN PRINCIPAL
          // ==========================================
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: showContent ? 10 : 6,
                vertical: 8,
              ),
              children: [
                ...List.generate(navItems.length, (index) {
                  final isSelected = selectedIndex == index;
                  final item = navItems[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildSidebarButton(
                      context: context,
                      item: item,
                      isSelected: isSelected,
                      showText: showContent,
                      onTap: () => onItemSelected(index),
                    ),
                  );
                }),

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.onSurface.withOpacity(0.07),
                  indent: showContent ? 8 : 4,
                  endIndent: showContent ? 8 : 4,
                ),
                const SizedBox(height: 12),

                // ==========================================
                // 3. UTILIDADES DEL SISTEMA
                // ==========================================
                // Acerca de BodeGo & EddamCore
                _buildSystemTile(
                  context: context,
                  icon: Icons.info_outline_rounded,
                  title: 'Acerca de v${AppVersionService.versionName}',
                  showText: showContent,
                  color: colorScheme.onSurface.withOpacity(0.75),
                  onTap: () {
                    if (isDrawer) Navigator.pop(context);
                    LegalTermsModal.show(context);
                  },
                ),
                const SizedBox(height: 4),

                // Cerrar Turno / Salir
                _buildSystemTile(
                  context: context,
                  icon: Icons.logout_rounded,
                  title: 'Cerrar Turno',
                  showText: showContent,
                  color: colorScheme.error,
                  onTap: () => _showCloseShiftDialog(context),
                ),
              ],
            ),
          ),

          // ==========================================
          // 4. TARJETA FIJA INFERIOR DE USUARIO
          // ==========================================
          _buildBottomUserCard(context, showContent),
        ],
      ),
    );
  }

  /// Cabecera moderna con gradiente azul real corporativo
  Widget _buildCorporateHeader(BuildContext context, bool showContent) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Gradiente dinámico derivado de colorScheme.primary
    final headerGradient = LinearGradient(
      colors: [
        colorScheme.primary,
        Color.lerp(colorScheme.primary, Colors.black, 0.22) ??
            colorScheme.primary,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: headerGradient,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showContent ? 14.0 : 8.0,
            vertical: 14.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fila superior: Logo + Título + Botón Menú
              Row(
                mainAxisAlignment: showContent
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.center,
                children: [
                  if (showContent) ...[
                    Row(
                      children: [
                        const BodeGoLogoWidget(
                          size: 32,
                          withBackground: false,
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Text(
                              'Bode',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(left: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.onPrimary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'GO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ] else ...[
                    const BodeGoLogoWidget(
                      size: 28,
                      withBackground: false,
                    ),
                  ],

                  // Botón para cerrar drawer o colapsar sidebar
                  IconButton(
                    icon: Icon(
                      isDrawer
                          ? Icons.close_rounded
                          : (isExpanded
                              ? Icons.menu_open_rounded
                              : Icons.menu_rounded),
                    ),
                    color: colorScheme.onPrimary,
                    tooltip: isExpanded ? 'Colapsar menú' : 'Expandir menú',
                    onPressed: onToggleSidebar,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                  ),
                ],
              ),

              // Fila de Identidad del Negocio (si está expandido)
              if (showContent) ...[
                const SizedBox(height: 12),
                ValueListenableBuilder<BusinessConfig?>(
                  valueListenable:
                      BusinessConfigRepository().configNotifier,
                  builder: (context, config, _) {
                    final presetKey = config?.logoValue ?? 'storefront';
                    final preset = BusinessConfig.presets[presetKey] ??
                        (icon: Icons.storefront_rounded, label: 'Bodega');
                    final displayName = (config?.businessName.isNotEmpty == true)
                        ? config!.businessName
                        : businessName;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.onPrimary.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            preset.icon,
                            color: colorScheme.onPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondary.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OFFLINE',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Botón interactivo de navegación
  Widget _buildSidebarButton({
    required BuildContext context,
    required _SidebarItemData item,
    required bool isSelected,
    required bool showText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final activeBg = colorScheme.primary;
    final inactiveText = isDark
        ? colorScheme.onSurface.withOpacity(0.85)
        : colorScheme.onSurface.withOpacity(0.8);

    return Tooltip(
      message: showText ? '' : item.title,
      child: Material(
        color: isSelected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        elevation: isSelected ? 2 : 0,
        shadowColor: colorScheme.primary.withOpacity(0.3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: showText ? 12 : 0,
              vertical: 11,
            ),
            child: Row(
              mainAxisAlignment: showText
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? colorScheme.onPrimary : inactiveText,
                  size: 21,
                ),
                if (showText) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color:
                            isSelected ? colorScheme.onPrimary : inactiveText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botón de utilidades (Acerca de, Cerrar Sesión)
  Widget _buildSystemTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool showText,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: showText ? '' : title,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: showText ? 12 : 0,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment: showText
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                if (showText) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta de Usuario Pinned en la parte inferior
  Widget _buildBottomUserCard(BuildContext context, bool showContent) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? colorScheme.surface.withOpacity(0.6)
        : colorScheme.surface.withOpacity(0.3);
    final borderColor = colorScheme.onSurface.withOpacity(0.08);

    final initial = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : 'U';

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: showContent ? 10 : 8,
          vertical: 10,
        ),
        child: Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              if (onOpenBusinessProfile != null) {
                onOpenBusinessProfile!();
              } else {
                UserBusinessModal.show(
                  context,
                  onNavigateToSettings: () => onItemSelected(4),
                  onLockOrSwitchCashier: () {
                    if (onLogoutOrCloseShift != null) {
                      onLogoutOrCloseShift!();
                    } else {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PinLoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: showContent ? 12 : 8,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: showContent
                  ? Row(
                      children: [
                        // Avatar circular con inicial
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colorScheme.primary,
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Nombre y Rol
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                userName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'TURNO ACTIVO',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Indicador Chevron
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ],
                    )
                  : Center(
                      child: Tooltip(
                        message: '$userName\n(Click para ver negocio y perfil)',
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: colorScheme.primary,
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Diálogo moderno de confirmación para cerrar turno o salir
  void _showCloseShiftDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        backgroundColor: isDark ? colorScheme.surface : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.logout_rounded,
                color: colorScheme.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Cerrar Turno de Caja?',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Puedes bloquear la terminal para cambiar de cajero o cerrar la aplicación. Todas las operaciones y ventas quedan respaldadas de forma segura.',
          style: TextStyle(
            fontSize: 13.5,
            color: colorScheme.onSurface.withOpacity(0.75),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancelar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('Bloquear / Cambiar'),
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (onLogoutOrCloseShift != null) {
                onLogoutOrCloseShift!();
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PinLoginScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  final String title;
  final IconData icon;
  final String emoji;

  const _SidebarItemData({
    required this.title,
    required this.icon,
    required this.emoji,
  });
}
