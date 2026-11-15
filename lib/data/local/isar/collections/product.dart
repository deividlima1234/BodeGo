import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/collections/category.dart';

part 'product.g.dart';

@collection
class Product {
  Id id = Isar.autoIncrement;

  String? barcode;

  late String name;

  double costPrice = 0.0;

  double salePrice = 0.0;

  double stock = 0.0;

  double minStock = 0.0;

  String unit = 'und';

  final category = IsarLink<Category>();

  /// Indica si el producto permite venta fraccionada / pesaje (kg, g, m, L)
  @ignore
  bool get allowsDecimals =>
      unit == 'kg' || unit == 'g' || unit == 'm' || unit == 'L' || unit == 'litro';
}

