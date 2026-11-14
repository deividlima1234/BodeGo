import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/core/services/app_version_service.dart';
import 'package:bodego/data/models/ota_update_info.dart';

/// Servicio encargado de la gestión completa de actualizaciones OTA (Over-The-Air)
/// desde GitHub Releases para BodeGo.
class OtaUpdateService {
  OtaUpdateService._();

  static const String defaultVersionJsonUrl =
      'https://raw.githubusercontent.com/deividlima1234/BodeGo/main/version.json';

  static const MethodChannel _channel =
      MethodChannel('com.eddamcore.bodego/ota_updater');

  /// Archivo local donde se persiste el conteo de avisos por versión
  static Future<File> _getStateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/ota_state.json');
  }

  /// Consulta si existe una versión más reciente en GitHub
  static Future<OtaCheckResult?> checkForUpdate({
    String url = defaultVersionJsonUrl,
  }) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6);

      final uri = Uri.parse(url);
      final request = await client.getUrl(uri);
      request.followRedirects = true;

      final response = await request.close().timeout(const Duration(seconds: 7));

      if (response.statusCode != HttpStatus.ok) {
        client.close();
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final Map<String, dynamic> data = jsonDecode(responseBody) as Map<String, dynamic>;
      final updateInfo = OtaUpdateInfo.fromJson(data);

      // Comprobamos si la versión remota es más nueva que la instalada
      final isNewer = updateInfo.isNewerThan(
        AppVersionService.versionName,
        AppVersionService.versionCode,
      );

      if (!isNewer) return null;

      // Leemos el estado local de avisos
      final stateFile = await _getStateFile();
      int dismissCount = 0;
      if (await stateFile.exists()) {
        try {
          final content = await stateFile.readAsString();
          final state = jsonDecode(content) as Map<String, dynamic>;
          if (state['last_version'] == updateInfo.latestVersion) {
            dismissCount = (state['dismiss_count'] as num?)?.toInt() ?? 0;
          }
        } catch (_) {}
      }

      // La actualización es obligatoria si el JSON lo marca o si ya se avisó 3 o más veces
      final isMandatory = updateInfo.isMandatory || dismissCount >= 2;

      return OtaCheckResult(
        updateInfo: updateInfo,
        dismissCount: dismissCount + 1, // Número de aviso actual (1, 2 o 3)
        isMandatory: isMandatory,
      );
    } catch (e) {
      debugPrint('[OtaUpdateService] No se pudo verificar actualización (Modo Offline o sin red): $e');
      return null;
    }
  }

  /// Registra que el usuario postergó el aviso de actualización
  static Future<void> recordDismiss(String version) async {
    try {
      final stateFile = await _getStateFile();
      int count = 0;
      if (await stateFile.exists()) {
        final content = await stateFile.readAsString();
        final state = jsonDecode(content) as Map<String, dynamic>;
        if (state['last_version'] == version) {
          count = (state['dismiss_count'] as num?)?.toInt() ?? 0;
        }
      }

      count += 1;

      final newState = {
        'last_version': version,
        'dismiss_count': count,
        'last_dismissed_at': DateTime.now().toIso8601String(),
      };

      await stateFile.writeAsString(jsonEncode(newState));
    } catch (e) {
      debugPrint('[OtaUpdateService] Error al guardar descarte: $e');
    }
  }

  /// Descarga el paquete APK con reporte progresivo en tiempo real
  static Future<File> downloadApk(
    String downloadUrl, {
    required void Function(double progress, int downloadedBytes, int totalBytes)
        onProgress,
  }) async {
    final client = HttpClient()
      ..autoUncompress = true
      ..connectionTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse(downloadUrl);
      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 6;

      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('Error HTTP al descargar APK: ${response.statusCode}');
      }

      final totalBytes = response.contentLength;
      int downloadedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/bodego_update.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();

      await for (final chunk in response) {
        downloadedBytes += chunk.length;
        sink.add(chunk);

        final progress = totalBytes > 0
            ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
            : 0.0;

        onProgress(progress, downloadedBytes, totalBytes);
      }

      await sink.flush();
      await sink.close();
      client.close();

      return apkFile;
    } catch (e) {
      client.close();
      rethrow;
    }
  }

  /// Lanza el instalador nativo de Android a través de FileProvider
  static Future<bool> installApk(String filePath) async {
    try {
      final success = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[OtaUpdateService] Error al invocar instalador de Android: $e');
      rethrow;
    }
  }
}

