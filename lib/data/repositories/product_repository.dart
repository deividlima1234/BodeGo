import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/repositories/category_repository.dart';

/// Repositorio para la gestión de productos, inventario y catálogo en Isar.
class ProductRepository {
  final Isar _isar;
  final CategoryRepository _categoryRepository;

  ProductRepository({
    Isar? isar,
    CategoryRepository? categoryRepository,
  })  : _isar = isar ?? DatabaseService.db,
        _categoryRepository = categoryRepository ?? CategoryRepository();

  /// Obtiene todos los productos del catálogo con sus categorías cargadas.
  Future<List<Product>> getAllProducts() async {
    final products = await _isar.products.where().sortByName().findAll();
    for (final product in products) {
      await product.category.load();
    }
    return products;
  }

  /// Busca productos por coincidencia de nombre o código de barras.
  Future<List<Product>> searchProducts(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return await getAllProducts();
    }

    final products = await _isar.products
        .filter()
        .nameContains(cleanQuery, caseSensitive: false)
        .or()
        .barcodeContains(cleanQuery, caseSensitive: false)
        .findAll();

    for (final product in products) {
      await product.category.load();
    }
    return products;
  }

  /// Filtra productos pertenecientes a una categoría específica.
  Future<List<Product>> getProductsByCategory(int categoryId) async {
    final products = await _isar.products
        .filter()
        .category((q) => q.idEqualTo(categoryId))
        .findAll();

    for (final product in products) {
      await product.category.load();
    }
    return products;
  }

  /// Busca un producto por su código de barras exacto (lector de barras / escáner).
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

  /// Guarda o actualiza un producto y opcionalmente vincula su categoría.
  Future<Product> saveProduct(Product product, {Category? category}) async {
    await _isar.writeTxn(() async {
      await _isar.products.put(product);
      if (category != null) {
        product.category.value = category;
        await product.category.save();
      }
    });

    await product.category.load();
    return product;
  }

  /// Elimina un producto por su ID.
  Future<bool> deleteProduct(int id) async {
    return await _isar.writeTxn(() async {
      return await _isar.products.delete(id);
    });
  }

  /// Ajusta el stock de un producto (suma o resta según la venta/ingreso).
  Future<void> updateStock(int productId, int quantitySold) async {
    final product = await _isar.products.get(productId);
    if (product != null) {
      product.stock -= quantitySold;
      await _isar.writeTxn(() async {
        await _isar.products.put(product);
      });
    }
  }

  /// Carga datos iniciales de prueba (seed data) con productos típicos de bodega si no hay ninguno.
  Future<void> seedInitialProducts() async {
    final count = await _isar.products.count();
    if (count > 0) return;

    // Asegura que las categorías existan primero
    await _categoryRepository.seedInitialCategories();
    final categories = await _categoryRepository.getAllCategories();

    Category? getCat(String name) {
      try {
        return categories.firstWhere(
          (c) => c.name.toLowerCase().contains(name.toLowerCase()),
        );
      } catch (_) {
        return categories.isNotEmpty ? categories.first : null;
      }
    }

    final catAbarrotes = getCat('Abarrotes');
    final catBebidas = getCat('Bebidas');
    final catLacteos = getCat('Lácteos');
    final catSnacks = getCat('Snacks');
    final catLimpieza = getCat('Limpieza');

    final productsToSeed = [
      (
        Product()
          ..name = 'Arroz Costeño Extra 1kg'
          ..barcode = '7750182001018'
          ..costPrice = 3.80
          ..salePrice = 4.50
          ..stock = 30
          ..minStock = 5,
        catAbarrotes
      ),
      (
        Product()
          ..name = 'Aceite Primor Premium 900ml'
          ..barcode = '7750182002022'
          ..costPrice = 7.20
          ..salePrice = 8.50
          ..stock = 20
          ..minStock = 4,
        catAbarrotes
      ),
      (
        Product()
          ..name = 'Azúcar Rubia Cartavio 1kg'
          ..barcode = '7750182003036'
          ..costPrice = 3.20
          ..salePrice = 3.90
          ..stock = 25
          ..minStock = 5,
        catAbarrotes
      ),
      (
        Product()
          ..name = 'Leche Gloria Azul Entera 400g'
          ..barcode = '7750151000103'
          ..costPrice = 3.40
          ..salePrice = 4.00
          ..stock = 48
          ..minStock = 8,
        catLacteos
      ),
      (
        Product()
          ..name = 'Yogurt Gloria Fresa 1L'
          ..barcode = '7750151002053'
          ..costPrice = 5.20
          ..salePrice = 6.20
          ..stock = 12
          ..minStock = 3,
        catLacteos
      ),
      (
        Product()
          ..name = 'Inca Kola 500ml No Retornable'
          ..barcode = '7750243000509'
          ..costPrice = 2.00
          ..salePrice = 2.50
          ..stock = 36
          ..minStock = 6,
        catBebidas
      ),
      (
        Product()
          ..name = 'Coca Cola 500ml No Retornable'
          ..barcode = '7750243000516'
          ..costPrice = 2.00
          ..salePrice = 2.50
          ..stock = 36
          ..minStock = 6,
        catBebidas
      ),
      (
        Product()
          ..name = 'Galletas Soda San Jorge Paquete'
          ..barcode = '7750284000117'
          ..costPrice = 0.70
          ..salePrice = 1.00
          ..stock = 50
          ..minStock = 10,
        catSnacks
      ),
      (
        Product()
          ..name = 'Detergente Bolívar Floral 1kg'
          ..barcode = '7750182004040'
          ..costPrice = 7.50
          ..salePrice = 9.00
          ..stock = 15
          ..minStock = 3,
        catLimpieza
      ),
    ];

    for (final item in productsToSeed) {
      await saveProduct(item.$1, category: item.$2);
    }
  }
}

