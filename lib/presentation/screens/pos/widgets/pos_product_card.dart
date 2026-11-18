import 'package:flutter/material.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/presentation/screens/pos/widgets/category_visual_helper.dart';

/// Tarjeta moderna e intuitiva para exhibición y venta rápida de productos en Caja.
class PosProductCard extends StatelessWidget {
  final Product product;
  final double quantityInCart;
  final VoidCallback onTap;

  const PosProductCard({
    super.key,
    required this.product,
    required this.quantityInCart,
    required this.onTap,
  });

  static String formatStock(double stock, String unit) {
    final clean = (stock.isNaN || stock.isInfinite) ? 0.0 : stock;
    final u = unit.trim().isEmpty ? 'und' : unit.trim();
    if (clean % 1 == 0) {
      return '${clean.toInt()} $u';
    }
    return '${clean.toStringAsFixed(u == 'kg' ? 3 : 2)} $u';
  }

  static String formatBadgeQuantity(double qty, String unit) {
    final clean = (qty.isNaN || qty.isInfinite) ? 0.0 : qty;
    final u = unit.trim().isEmpty ? 'und' : unit.trim();
    if (clean % 1 == 0) {
      return '${clean.toInt()} $u';
    }
    return '${clean.toStringAsFixed(u == 'kg' ? 2 : 1)} $u';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bool isOutOfStock = product.stock <= 0;
    final bool isLowStock = !isOutOfStock && product.stock <= product.minStock;
    final bool isInCart = quantityInCart > 0;

    // Resuelve estilo, paleta e icono temático por categoría y producto
    final visual = CategoryVisualHelper.resolve(
      category: product.category.value,
      productName: product.name,
      allowsDecimals: product.allowsDecimals,
      isDark: isDark,
    );

    // Color de acento de la tarjeta (usa el color de la categoría o primario)
    final accentColor = visual.primaryColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2235) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isInCart
              ? accentColor
              : isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
          width: isInCart ? 2.0 : 1.0,
        ),
        boxShadow: [
          if (isInCart)
            BoxShadow(
              color: accentColor.withOpacity(0.22),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isOutOfStock ? null : onTap,
          splashColor: accentColor.withOpacity(0.12),
          highlightColor: accentColor.withOpacity(0.06),
          child: Opacity(
            opacity: isOutOfStock ? 0.55 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HEADER: Micro-pill de categoría y badge de existencias
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Chip de categoría con punto de color
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: accentColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                visual.categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.grey[300] : const Color(0xFF4A5568),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Pill de existencias
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.grey.withOpacity(0.2)
                              : isLowStock
                                  ? Colors.redAccent.withOpacity(0.14)
                                  : Colors.green.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOutOfStock
                              ? 'Agotado'
                              : '${formatStock(product.stock, product.unit)} disp.',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: isOutOfStock
                                ? Colors.grey[700]
                                : isLowStock
                                    ? Colors.redAccent
                                    : Colors.green[800],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // 2. ZONA VISUAL CENTRAL: Iconografía temática con glassmorphism y glow
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            visual.containerBackground,
                            visual.containerBackground.withOpacity(visual.containerBackground.opacity * 1.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accentColor.withOpacity(0.16),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Anillo difuso de fondo
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? Colors.black.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.7),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.15),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),

                          // Icono Temático Central
                          Icon(
                            visual.icon,
                            size: 32,
                            color: accentColor,
                          ),

                          // Distintivo de balanza / pesable (si permite decimales)
                          if (product.allowsDecimals)
                            Positioned(
                              bottom: 5,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.black : Colors.white).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.scale_rounded,
                                      size: 11,
                                      color: Colors.amber[800],
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Balanza',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Badge flotante si está en el carrito
                          if (isInCart)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      formatBadgeQuantity(quantityInCart, product.unit),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. NOMBRE DEL PRODUCTO (2 líneas máx)
                  SizedBox(
                    height: 36,
                    child: Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF141A3C),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 4. FOOTER: Precio y botón de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Bloque de Precio
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PRECIO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 1),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF141A3C),
                              ),
                              children: [
                                const TextSpan(
                                  text: 'S/ ',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: product.salePrice.toStringAsFixed(2),
                                ),
                                if (product.unit != 'und')
                                  TextSpan(
                                    text: '/${product.unit}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Botón interactivo de añadir / pesaje
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isOutOfStock
                              ? Colors.grey.withOpacity(0.2)
                              : isInCart
                                  ? accentColor
                                  : accentColor.withOpacity(0.14),
                          shape: BoxShape.circle,
                          boxShadow: isInCart
                              ? [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.35),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          isOutOfStock
                              ? Icons.block_rounded
                              : isInCart
                                  ? Icons.add_rounded
                                  : product.allowsDecimals
                                      ? Icons.scale_rounded
                                      : Icons.add_shopping_cart_rounded,
                          size: 17,
                          color: isOutOfStock
                              ? Colors.grey
                              : isInCart
                                  ? Colors.white
                                  : accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

