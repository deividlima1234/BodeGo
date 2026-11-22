import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/repositories/app_settings_repository.dart';

/// Repositorio local para la persistencia y gestión de la identidad y configuración del negocio.
class BusinessConfigRepository {
  static const String _fileName = 'business_config.json';
  static final BusinessConfigRepository _instance = BusinessConfigRepository._internal();

  factory BusinessConfigRepository() => _instance;
  BusinessConfigRepository._internal();

  final AppSettingsRepository _appSettingsRepo = AppSettingsRepository();

  /// Notificador reactivo para que cualquier pantalla o componente se actualice en tiempo real
  final ValueNotifier<BusinessConfig?> configNotifier = ValueNotifier<BusinessConfig?>(null);

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Obtiene la configuración actual del negocio o inicializa una con los valores de la bodega
  Future<BusinessConfig> getConfig() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          final config = BusinessConfig.fromJson(json);
          configNotifier.value = config;
          return config;
        }
      }

      // Si aún no existe el archivo JSON, tomamos el nombre actual de Isar si existe
      final appSettings = await _appSettingsRepo.getSettings();
      final currentName = (appSettings.businessName?.trim().isNotEmpty ?? false)
          ? appSettings.businessName!.trim()
          : '';

      final defaultConfig = BusinessConfig(
        businessName: currentName,
      );

      // Solo persistir si la app ya no está en su primer inicio (onboarding completado)
      if (!appSettings.isFirstRun && currentName.isNotEmpty) {
        await saveConfig(defaultConfig);
      }
      configNotifier.value = defaultConfig;
      return defaultConfig;
    } catch (e) {
      const fallback = BusinessConfig();
      configNotifier.value = fallback;
      return fallback;
    }
  }

  /// Guarda y persiste los cambios de configuración del negocio
  Future<void> saveConfig(BusinessConfig config) async {
    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(config.toJson());
      await file.writeAsString(jsonStr);

      // Sincronizar el nombre con Isar para retrocompatibilidad completa
      await _appSettingsRepo.updateBusinessName(config.businessName);

      // Notificar reactivamente a toda la app
      configNotifier.value = config;
    } catch (e) {
      debugPrint('Error al guardar business_config: $e');
    }
  }
}

