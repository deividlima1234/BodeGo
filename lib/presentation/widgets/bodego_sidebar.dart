import 'package:flutter/material.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';

/// Barra lateral (Sidebar) colapsable y adaptable a móviles (Drawer) y tablets (Panel fijo).
class BodeGoSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isExpanded;
  final VoidCallback onToggleSidebar;
  final String businessName;
  final String userName;
  final bool isDrawer;

  const BodeGoSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isExpanded,
    required this.onToggleSidebar,
    required this.businessName,
    required this.userName,
    this.isDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<_SidebarItemData> items = [
      _SidebarItemData(
        title: 'Caja',
        icon: Icons.shopping_cart_rounded,
        emoji: '🛒',
      ),
      _SidebarItemData(
        title: 'Inventario',
        icon: Icons.inventory_2_rounded,
        emoji: '📦',
      ),
      _SidebarItemData(
        title: 'Clientes',
        icon: Icons.people_alt_rounded,
        emoji: '👥',
      ),
      _SidebarItemData(
        title: 'Reportes',
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
        ? 280.0
        : (isExpanded ? 240.0 : 70.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: targetWidth,
      height: double.infinity,
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // CABECERA Y BOTÓN HAMBURGUESA
            // ==========================================
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isExpanded || isDrawer ? 14.0 : 6.0,
                vertical: 14.0,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: (isExpanded || isDrawer)
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: [
                      if (isExpanded || isDrawer) ...[
                        ValueListenableBuilder<BusinessConfig?>(
                          valueListenable: BusinessConfigRepository().configNotifier,
                          builder: (context, config, _) {
                            final presetKey = config?.logoValue ?? 'storefront';
                            final icon = BusinessConfig.presets[presetKey]?.icon ??
                                Icons.storefront_rounded;
                            return Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: 18,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            businessName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      IconButton(
                        icon: Icon((isDrawer) ? Icons.close_rounded : Icons.menu_rounded),
                        color: theme.colorScheme.onSurface,
                        tooltip: isExpanded ? 'Colapsar Menú' : 'Expandir Menú',
                        onPressed: onToggleSidebar,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tarjeta del Cajero
                  Row(
                    mainAxisAlignment: (isExpanded || isDrawer)
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                        child: Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (isExpanded || isDrawer) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withOpacity(0.85),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, indent: 8, endIndent: 8),
            const SizedBox(height: 10),

            // ==========================================
            // ÍTEMS DEL MENÚ
            // ==========================================
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: (isExpanded || isDrawer) ? 10 : 6),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final isSelected = selectedIndex == index;
                  final item = items[index];

                  return _buildSidebarButton(
                    context: context,
                    item: item,
                    isSelected: isSelected,
                    showText: isExpanded || isDrawer,
                    onTap: () => onItemSelected(index),
                  );
                },
              ),
            ),

            // Pie de página
            if (isExpanded || isDrawer)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF4353FF)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Tecnología impulsada por EddamCore',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withOpacity(0.55),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarButton({
    required BuildContext context,
    required _SidebarItemData item,
    required bool isSelected,
    required bool showText,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;

    return Tooltip(
      message: showText ? '' : item.title,
      child: Material(
        color: isSelected ? activeColor : Colors.transparent,
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
              mainAxisAlignment:
                  showText ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.7),
                  size: 20,
                ),
                if (showText) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 12),
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
