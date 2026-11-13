import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/data/local/isar/collections/app_settings.dart';
import 'package:bodego/data/local/isar/collections/category.dart';
import 'package:bodego/data/local/isar/collections/product.dart';
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/data/local/isar/collections/customer.dart';

/// Servicio de base de datos local usando Isar.
/// Implementado como un Singleton para gestionar el ciclo de vida de la BD offline-first.
class DatabaseService {
  // Patrón Singleton
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Acceso a la instancia única del Singleton
  static DatabaseService get instance => _instance;

  /// Instancia de Isar guardada a nivel de clase
  static Isar? _isar;

  /// Getter para acceder a la instancia activa de Isar.
  /// Lanza [StateError] si la base de datos no ha sido inicializada previamente.
  static Isar get db {
    final isarInstance = _isar;
    if (isarInstance == null) {
      throw StateError(
        'DatabaseService no ha sido inicializado. Llama a init() antes de acceder a la base de datos.',
      );
    }
    return isarInstance;
  }

  /// Getter de instancia para conveniencia de inyección de dependencias
  Isar get isar => db;

  /// Inicializa la base de datos Isar de manera asíncrona.
  /// Obtiene el directorio de documentos de la aplicación mediante [path_provider]
  /// y abre la base de datos con los esquemas de entidades registrados.
  static Future<void> init() async {
    if (_isar != null && _isar!.isOpen) {
      return;
    }

    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open(
      [
        ProductSchema,
        CategorySchema,
        AppSettingsSchema,
        UserSchema,
        CustomerSchema,
      ],
      directory: dir.path,
      name: 'bodego_db',
      inspector: true,
    );
  }

  /// Cierra la instancia activa de Isar si está abierta.
  static Future<void> close() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.close();
      _isar = null;
    }
  }

  /// Vacía todas las colecciones de la base de datos (útil para reiniciar la app desde cero).
  static Future<void> cleanDb() async {
    if (_isar != null && _isar!.isOpen) {
      await _isar!.writeTxn(() async {
        await _isar!.clear();
      });
    }
  }
}
