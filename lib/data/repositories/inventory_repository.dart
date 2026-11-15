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

  /// 4. Obtiene todos los productos cargando su categoría vinculada y autoreparando registros legados.
  Future<List<Product>> getProducts() async {
    final products = await _isar.products.where().sortByName().findAll();
    bool needsRepair = false;
    for (final product in products) {
      if (product.stock.isNaN || product.minStock.isNaN || product.unit.isEmpty) {
        if (product.stock.isNaN) product.stock = 0.0;
        if (product.minStock.isNaN) product.minStock = 5.0;
        if (product.unit.isEmpty) product.unit = 'und';
        needsRepair = true;
      }
      await product.category.load();
    }
    if (needsRepair) {
      await _isar.writeTxn(() async {
        await _isar.products.putAll(products);
      });
    }
    return products;
  }

  /// 5. Busca un producto por su código de barras exacto.
  Future<Product?> getProductByBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    final product = await _isar.products
        .filter()
        .barcodeEqualTo(cleanBarcode)
        .findFirst();

    if (product != null) {
      await product.category.load();
    }
    return product;
  }

  /// 6. Agrega un nuevo producto con unidad de medida y enlaza su categoría en Isar.
  Future<void> addProduct(
    String name,
    String? barcode,
    double cost,
    double sale,
    double stock,
    double minStock,
    int categoryId, {
    String unit = 'und',
  }) async {
    final category = await _isar.categorys.get(categoryId);

    final product = Product()
      ..name = name.trim()
      ..barcode = (barcode != null && barcode.trim().isNotEmpty) ? barcode.trim() : null
      ..costPrice = cost
      ..salePrice = sale
      ..stock = stock
      ..minStock = minStock
      ..unit = unit;

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
      if (category != null) {
        product.category.value = category;
        await product.category.save();
      }
    });
  }

  /// 6. Actualiza integralmente un producto existente y actualiza su categoría.
  Future<void> updateProduct(
    int id, {
    required String name,
    String? barcode,
    required double costPrice,
    required double salePrice,
    required double stock,
    required double minStock,
    required int categoryId,
    required String unit,
  }) async {
    final product = await _isar.products.get(id);
    if (product == null) return;

    final category = await _isar.categorys.get(categoryId);

    product.name = name.trim();
    product.barcode = (barcode != null && barcode.trim().isNotEmpty) ? barcode.trim() : null;
    product.costPrice = costPrice;
    product.salePrice = salePrice;
    product.stock = stock;
    product.minStock = minStock;
    product.unit = unit;

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
      if (category != null) {
        product.category.value = category;
        await product.category.save();
      }
    });
  }

  /// 7. Recepción de lote / reposición rápida de stock con actualización opcional de costos y precios.
  Future<void> replenishStock(
    int productId,
    double quantityToAdd, {
    double? newCostPrice,
    double? newSalePrice,
  }) async {
    final product = await _isar.products.get(productId);
    if (product == null) return;

    final currentStock = (product.stock.isNaN || product.stock < 0) ? 0.0 : product.stock;
    product.stock = currentStock + quantityToAdd;

    if (newCostPrice != null && newCostPrice >= 0) {
      product.costPrice = newCostPrice;
    }
    if (newSalePrice != null && newSalePrice > 0) {
      product.salePrice = newSalePrice;
    }

    await _isar.writeTxn(() async {
      await _isar.products.put(product);
    });
  }

  /// 8. Elimina un producto por su ID.
  Future<void> deleteProduct(int id) async {
    await _isar.writeTxn(() async {
      await _isar.products.delete(id);
    });
  }

  /// 9. Descuenta existencias de un producto tras la venta (soporta unidades fraccionarias).
  Future<void> updateStock(int productId, double quantitySold) async {
    final product = await _isar.products.get(productId);
    if (product != null) {
      product.stock -= quantitySold;
      if (product.stock < 0) product.stock = 0;
      await _isar.writeTxn(() async {
        await _isar.products.put(product);
      });
    }
  }

  // ==========================================
  // STREAMS EN TIEMPO REAL (REACTIVIDAD ISAR)
  // ==========================================

  /// Emite un evento cada vez que la colección de productos cambia en Isar (creación, edición, eliminación o stock).
  Stream<void> watchProducts() {
    return _isar.products.watchLazy();
  }

  /// Emite un evento cada vez que la colección de categorías cambia en Isar.
  Stream<void> watchCategories() {
    return _isar.categorys.watchLazy();
  }
}

