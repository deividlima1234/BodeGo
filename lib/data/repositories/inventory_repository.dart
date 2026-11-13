import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';

/// Repositorio de Inventario encargado de gestionar Productos y Categorías en Isar.
class InventoryRepository {
  final Isar _isar;

  InventoryRepository({Isar? isar}) : _isar = isar ?? DatabaseService.db;

  // ==========================================
  // OPERACIONES DE CATEGORÍAS
  // ==========================================

  /// 1. Obtiene todas las categorías registradas.
  Future<List<Category>> getCategories() async {
    return await _isar.categorys.where().sortByName().findAll();
  }

  /// 2. Agrega una nueva categoría a la base de datos.
  Future<void> addCategory(String name, String? hexColor) async {
    final category = Category()
      ..name = name.trim()
      ..hexColor = hexColor ?? '#4353FF';

    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
  }

  /// 3. Elimina una categoría por su ID.
  Future<void> deleteCategory(int id) async {
    await _isar.writeTxn(() async {
      await _isar.categorys.delete(id);
    });
  }

  // ==========================================
  // OPERACIONES DE PRODUCTOS
  // ==========================================

  /// 4. Obtiene todos los productos cargando su categoría vinculada.
  Future<List<Product>> getProducts() async {
    final products = await _isar.products.where().sortByName().findAll();
    for (final product in products) {
      await product.category.load();
    }
    return products;
  }

  /// 5. Agrega un nuevo producto y enlaza su categoría en Isar.
  Future<void> addProduct(
    String name,
    String? barcode,
    double cost,
    double sale,
    int stock,
    int minStock,
    int categoryId,
  ) async {
    final category = await _isar.categorys.get(categoryId);

    final product = Product()
      ..name = name.trim()
      ..barcode = (barcode != null && barcode.trim().isNotEmpty) ? barcode.trim() : null
      ..costPrice = cost
      ..salePrice = sale
      ..stock = stock
      ..minStock = minStock;

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
      if (category != null) {
        product.category.value = category;
        await product.category.save();
      }
    });
  }

  /// 6. Elimina un producto por su ID.
  Future<void> deleteProduct(int id) async {
    await _isar.writeTxn(() async {
      await _isar.products.delete(id);
    });
  }

  /// 7. Descuenta existencias de un producto tras la venta.
  Future<void> updateStock(int productId, int quantitySold) async {
    final product = await _isar.products.get(productId);
    if (product != null) {
      product.stock -= quantitySold;
      await _isar.writeTxn(() async {
        await _isar.products.put(product);
      });
    }
  }
}

