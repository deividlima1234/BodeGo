import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/user.dart';
import 'package:bodego/core/services/google_sheets_sync_service.dart';

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
    GoogleSheetsSyncService().triggerAutoBackupIfEnabled();
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
    GoogleSheetsSyncService().triggerAutoBackupIfEnabled();
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

  /// Obtiene el usuario con rol de Administrador principal registrado.
  Future<User?> getFirstAdmin() async {
    return await _isar.users.filter().roleEqualTo('admin').findFirst();
  }

  /// Actualiza o crea el PIN del primer cajero registrado.
  Future<void> updateOrCreateCashierPin(String pin, {String name = 'Cajero Principal'}) async {
    final existing = await getFirstCashier();
    await _isar.writeTxn(() async {
      if (existing != null) {
        existing.pin = pin.trim();
        await _isar.users.put(existing);
      } else {
        final cashier = User()
          ..name = name.trim()
          ..role = 'cajero'
          ..pin = pin.trim();
        await _isar.users.put(cashier);
      }
    });
    GoogleSheetsSyncService().triggerAutoBackupIfEnabled();
  }

  /// Actualiza el nombre y/o PIN de un cajero específico
  Future<void> updateCashier(int userId, {String? name, String? pin}) async {
    final user = await _isar.users.get(userId);
    if (user != null && user.role == 'cajero') {
      await _isar.writeTxn(() async {
        if (name != null && name.trim().isNotEmpty) user.name = name.trim();
        if (pin != null && pin.trim().isNotEmpty) user.pin = pin.trim();
        await _isar.users.put(user);
      });
      GoogleSheetsSyncService().triggerAutoBackupIfEnabled();
    }
  }
}

