import 'package:isar/isar.dart';
import 'package:bodego/data/local/isar/database_service.dart';
import 'package:bodego/data/local/isar/collections/app_settings.dart';

/// Repositorio encargado de gestionar la configuración de la app y del negocio en Isar.
class AppSettingsRepository {
  final Isar _isar;

  AppSettingsRepository({Isar? isar}) : _isar = isar ?? DatabaseService.db;

  /// Busca el primer registro en la colección AppSettings.
  /// Si no existe (primera vez que se abre la app), crea y guarda uno nuevo con isFirstRun = true.
  Future<AppSettings> getSettings() async {
    final existingSettings = await _isar.appSettings.where().findFirst();
    if (existingSettings != null) {
      return existingSettings;
    }

    final newSettings = AppSettings()
      ..isFirstRun = true
      ..selectedTheme = 'moderno';

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(newSettings);
    });

    return newSettings;
  }

  /// Actualiza el nombre del negocio al terminar el onboarding inicial
  /// y marca isFirstRun como false.
  Future<void> updateBusinessName(String businessName) async {
    final settings = await getSettings();

    settings.businessName = businessName.trim();
    settings.isFirstRun = false;

    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
  }

  /// Método de compatibilidad: actualiza el nombre del negocio y finaliza el primer inicio.
  Future<void> updatePinAndBusiness(String pin, String businessName) async {
    await updateBusinessName(businessName);
  }

  /// Actualiza y persiste el tema visual seleccionado en Isar.
  Future<void> updateTheme(String themeName) async {
    final settings = await getSettings();
    settings.selectedTheme = themeName;
    await _isar.writeTxn(() async {
      await _isar.appSettings.put(settings);
    });
  }
}
