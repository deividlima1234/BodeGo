import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:bodego/core/services/license_service.dart';
import 'package:bodego/core/services/app_version_service.dart';
import 'package:bodego/core/services/google_sheets_sync_service.dart';

/// Gestor Centralizado de Seguridad y Gateway de Comunicación Cloud.
/// Todas las operaciones hacia Google Sheets (lectura, escritura, actualización)
/// pasan obligatoriamente por este gestor, el cual firma cada petición con el
/// Token Privado (`authToken` + `businessId`) y parámetros criptográficos.
class CloudSecurityManager {
  static final CloudSecurityManager _instance = CloudSecurityManager._internal();
  factory CloudSecurityManager() => _instance;
  CloudSecurityManager._internal();

  final GoogleSheetsSyncService _syncService = GoogleSheetsSyncService();

  // =====================================================================
  // CRIPTOGRAFÍA DE PIN DE CAJEROS (Cifrado Simétrico por Negocio)
  // =====================================================================

  /// Encripta un PIN de 4 dígitos con HMAC-SHA256 y salt aleatorio,
  /// haciéndolo completamente ilegible e irreversible para quien abra la hoja
  /// en Google Sheets directamente. Formato de salida: `ENC:<saltHex>:<cipherHex>`.
  static String encryptPin(String pin, {required String secretKey}) {
    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) return '';

    try {
      final random = Random.secure();
      final saltBytes = List<int>.generate(8, (_) => random.nextInt(256));
      final saltHex = saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final hmac = Hmac(sha256, utf8.encode(secretKey));
      final keyStream = hmac.convert(utf8.encode(saltHex)).bytes;

      final pinBytes = utf8.encode(cleanPin);
      final cipherBytes = <int>[];
      for (int i = 0; i < pinBytes.length; i++) {
        cipherBytes.add(pinBytes[i] ^ keyStream[i % keyStream.length]);
      }
      final cipherHex = cipherBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      return 'ENC:$saltHex:$cipherHex';
    } catch (e) {
      debugPrint('Error encriptando PIN: $e');
      return cleanPin;
    }
  }

  /// Desencripta un PIN cifrado recuperado desde Google Sheets.
  /// Si el valor no viene cifrado (retrocompatibilidad), se retorna tal cual.
  static String decryptPin(String cipherText, {required String secretKey}) {
    final clean = cipherText.trim();
    if (clean.isEmpty) return '';
    if (!clean.startsWith('ENC:')) return clean;

    final parts = clean.split(':');
    if (parts.length != 3) return clean;

    try {
      final saltHex = parts[1];
      final cipherHex = parts[2];

      final cipherBytes = <int>[];
      for (int i = 0; i < cipherHex.length; i += 2) {
        cipherBytes.add(int.parse(cipherHex.substring(i, i + 2), radix: 16));
      }

      final hmac = Hmac(sha256, utf8.encode(secretKey));
      final keyStream = hmac.convert(utf8.encode(saltHex)).bytes;

      final plainBytes = <int>[];
      for (int i = 0; i < cipherBytes.length; i++) {
        plainBytes.add(cipherBytes[i] ^ keyStream[i % keyStream.length]);
      }

      return utf8.decode(plainBytes);
    } catch (e) {
      debugPrint('Error desencriptando PIN: $e');
      return clean;
    }
  }

  /// Firma y despacha cualquier acción autenticada hacia Google Apps Script
  Future<Map<String, dynamic>?> signAndDispatch({
    required String action,
    Map<String, dynamic>? data,
  }) async {
    final config = await _syncService.getConfig();
    if (!config.isConfigured || !config.isTenantAuthenticated) {
      debugPrint('CloudSecurityManager: Negocio no autenticado. Imposible firmar $action');
      return null;
    }

    final license = await LicenseService().init();

    final payload = {
      'action': action,
      'businessId': config.businessId,
      'authToken': config.authToken,
      'timestamp': DateTime.now().toIso8601String(),
      'clientVersion': AppVersionService.versionName,
      'machineId': license.machineId,
      'data': data ?? {},
    };

    return await _httpPost(config.effectiveScriptUrl, payload);
  }

  /// Actualiza el perfil comercial de la bodega en la nube con firma de Token
  Future<({bool success, String message})> updateBusinessProfile({
    String? businessName,
    String? ruc,
    String? ownerName,
    String? newPassword,
    String? phone,
    String? address,
  }) async {
    try {
      final res = await signAndDispatch(
        action: 'updateBusinessProfile',
        data: {
          if (businessName != null) 'businessName': businessName,
          if (ruc != null) 'ruc': ruc,
          if (ownerName != null) 'ownerName': ownerName,
          if (newPassword != null) 'newPassword': newPassword,
          if (phone != null) 'phone': phone,
          if (address != null) 'address': address,
        },
      );

      if (res != null && res['success'] == true) {
        return (
          success: true,
          message: res['message'] as String? ?? 'Perfil actualizado en la nube',
        );
      }
      return (
        success: false,
        message: res?['error']?.toString() ?? 'Error al actualizar perfil en la nube',
      );
    } catch (e) {
      return (success: false, message: 'Fallo de red: $e');
    }
  }

  /// Solicita al backend asegurar la protección de solo lectura en la hoja de cálculo
  Future<void> ensureSheetsProtected() async {
    try {
      await signAndDispatch(action: 'protectTenantSheets');
    } catch (_) {}
  }

  /// Realiza una solicitud HTTP POST con cuerpo JSON siguiendo redirecciones
  Future<Map<String, dynamic>?> _httpPost(String url, Map<String, dynamic> body) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 18);

    try {
      final uri = Uri.parse(url);
      final jsonBody = jsonEncode(body);

      var request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.followRedirects = false;
      request.write(jsonBody);

      var response = await request.close().timeout(const Duration(seconds: 35));

      int redirects = 0;
      while ((response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 307) && redirects < 5) {
        redirects++;
        final redirectLocation = response.headers.value(HttpHeaders.locationHeader);
        if (redirectLocation == null) break;

        final redirectUri = Uri.parse(redirectLocation);
        final getReq = await client.getUrl(redirectUri);
        getReq.followRedirects = false;
        response = await getReq.close().timeout(const Duration(seconds: 25));
      }

      if (response.statusCode == 200) {
        final respBody = await response.transform(utf8.decoder).join();
        return jsonDecode(respBody) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('CloudSecurityManager HTTP POST error: $e');
      return null;
    } finally {
      client.close();
    }
  }
}

