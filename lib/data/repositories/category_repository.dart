import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/category.dart';

/// Repositorio para gestionar categorías de productos en Isar Database.
class CategoryRepository {
  final Isar _isar;

  CategoryRepository({Isar? isar}) : _isar = isar ?? DatabaseService.db;

  /// Obtiene todas las categorías ordenadas por nombre.
  Future<List<Category>> getAllCategories() async {
    return await _isar.categorys.where().sortByName().findAll();
  }

  /// Crea una nueva categoría.
  Future<Category> createCategory(String name, {String? hexColor}) async {
    final category = Category()
      ..name = name.trim()
      ..hexColor = hexColor ?? '#4353FF';

    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });

    return category;
  }

  /// Actualiza una categoría existente.
  Future<void> updateCategory(Category category) async {
    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
  }

  /// Elimina una categoría por su ID.
  Future<bool> deleteCategory(int id) async {
    return await _isar.writeTxn(() async {
      return await _isar.categorys.delete(id);
    });
  }

  /// Puebla categorías iniciales de muestra típicas para bodegas si no existen.
  Future<void> seedInitialCategories() async {
    final count = await _isar.categorys.count();
    if (count > 0) return;

    final defaultCategories = [
      Category()..name = 'Abarrotes'..hexColor = '#4353FF',
      Category()..name = 'Bebidas'..hexColor = '#4FD1C5',
      Category()..name = 'Lácteos'..hexColor = '#FFB800',
      Category()..name = 'Snacks & Golosinas'..hexColor = '#FF6B6B',
      Category()..name = 'Limpieza del Hogar'..hexColor = '#845EC2',
      Category()..name = 'Cuidado Personal'..hexColor = '#00C9A7',
    ];

    await _isar.writeTxn(() async {
      await _isar.categorys.putAll(defaultCategories);
    });
  }
}

