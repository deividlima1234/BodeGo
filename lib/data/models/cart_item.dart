import 'package:bodego/data/local/isar/collections/product.dart';

/// Modelo de ítem individual en el carrito de compras del Punto de Venta.
class CartItem {
  Product product;
  double quantity;

  CartItem({
    required this.product,
    this.quantity = 1.0,
  });

  /// Calcula el subtotal multiplicando el precio de venta por la cantidad seleccionada.
  double get subtotal => product.salePrice * quantity;

  /// Formato legible de la cantidad según la unidad del producto
  String get formattedQuantity {
    if (product.allowsDecimals) {
      if (quantity % 1 == 0) {
        return '${quantity.toInt()} ${product.unit}';
      }
      return '${quantity.toStringAsFixed(product.unit == 'kg' ? 3 : 2)} ${product.unit}';
    }
    return '${quantity.toInt()} ${product.unit}';
  }
}

