import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/user.dart';

/// Repositorio encargado de gestionar los usuarios (Administradores y Cajeros) en Isar.
class UserRepository {
  final Isar _isar;

  UserRepository({Isar? isar}) : _isar = isar ?? DatabaseService.db;

  /// Crea y almacena un usuario con rol de Administrador (correo y contraseña).
  Future<void> createAdmin(String name, String email, String password) async {
    final admin = User()
      ..name = name.trim()
      ..role = 'admin'
      ..email = email.trim()
      ..password = password;

    await _isar.writeTxn(() async {
      await _isar.users.put(admin);
    });
  }

  /// Crea y almacena un usuario con rol de Cajero (nombre y PIN de 4 dígitos).
  Future<void> createCashier(String name, String pin) async {
    final cashier = User()
      ..name = name.trim()
      ..role = 'cajero'
      ..pin = pin.trim();

    await _isar.writeTxn(() async {
      await _isar.users.put(cashier);
    });
  }

  /// Valida si existe un cajero con el PIN ingresado y lo retorna.
  Future<User?> validateCashierPin(String pin) async {
    return await _isar.users
        .filter()
        .roleEqualTo('cajero')
        .and()
        .pinEqualTo(pin.trim())
        .findFirst();
  }

  /// Obtiene todos los usuarios registrados en el sistema.
  Future<List<User>> getAllUsers() async {
    return await _isar.users.where().findAll();
  }

  /// Obtiene el primer usuario con rol de cajero registrado.
  Future<User?> getFirstCashier() async {
    return await _isar.users.filter().roleEqualTo('cajero').findFirst();
  }
}

