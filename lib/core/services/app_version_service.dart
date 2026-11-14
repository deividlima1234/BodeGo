import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio central encargado de obtener y exponer la versión REAL de la aplicación
/// consultando directamente el sistema operativo Android a través de MethodChannel.
class AppVersionService {
  AppVersionService._();

  static const MethodChannel _channel =
      MethodChannel('com.eddamcore.bodego/ota_updater');

  static String _versionName = '1.0.0';
  static int _versionCode = 1;
  static bool _isInitialized = false;

  /// Inicializa y consulta la versión real del sistema
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getAppVersion');
      if (result != null) {
        _versionName = result['versionName']?.toString() ?? '1.0.0';
        _versionCode = (result['versionCode'] as num?)?.toInt() ?? 1;
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('[AppVersionService] Error al obtener versión real: $e');
      _versionName = '1.0.0';
      _versionCode = 1;
      _isInitialized = true;
    }
  }

  /// Retorna el nombre de la versión (ej. "1.0.0")
  static String get versionName => _versionName;

  /// Retorna el código de compilación / build number (ej. 1)
  static int get versionCode => _versionCode;

  /// Retorna la cadena completa formateada (ej. "v1.0.0+1")
  static String get fullVersion => 'v$_versionName+$_versionCode';

  /// Retorna una etiqueta amigable (ej. "BodeGo POS v1.0.0")
  static String get displayLabel => 'BodeGo POS v$_versionName';
}

