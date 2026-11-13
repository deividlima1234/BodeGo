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

  int stock = 0;

  int minStock = 0;

  final category = IsarLink<Category>();
}

