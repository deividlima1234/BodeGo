import 'package:bodego/data/local/isar/collections/product.dart';

/// Modelo de ítem individual en el carrito de compras del Punto de Venta.
class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  /// Calcula el subtotal multiplicando el precio de venta por la cantidad seleccionada.
  double get subtotal => product.salePrice * quantity;
}

