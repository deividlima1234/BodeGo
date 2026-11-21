import 'dart:convert';

/// Modelo de configuración de sincronización con Google Sheets.
/// La URL maestra del servicio en la nube se encuentra ofuscada y protegida
/// en el código para evitar su exposición y proteger la seguridad del sistema.
class GoogleSheetsConfig {
  // URL maestra ofuscada en Base64 para que no sea vulnerable en texto plano
  static const String _cloudSecretKey =
      'aHR0cHM6Ly9zY3JpcHQuZ29vZ2xlLmNvbS9tYWNyb3Mvcy9BS2Z5Y2J3R29IYlNtbEdFWjlNNmZqT1AyN2MzZFh2UVI1OGI0WUV6Zlhwb1pad2JweWg3cEVHbHJ3WjFqc0w2SjVaNHVsckMvZXhlYw==';

  static const String cloudSecretKey = _cloudSecretKey;

  static String get defaultMasterScriptUrl =>
      utf8.decode(base64.decode(_cloudSecretKey));

  final String scriptUrl;
  final bool isEnabled;
  final DateTime? lastSyncAt;
  final bool autoSyncOnSale;
  final String? sheetName;
  final String? businessId;
  final String? authToken;
  final String? ownerEmail;
  final String? spreadsheetId;

  const GoogleSheetsConfig({
    String? scriptUrl,
    this.isEnabled = true,
    this.lastSyncAt,
    this.autoSyncOnSale = true,
    this.sheetName,
    this.businessId,
    this.authToken,
    this.ownerEmail,
    this.spreadsheetId,
  }) : scriptUrl = scriptUrl ?? _cloudSecretKey;

  /// Retorna la URL descifrada lista para realizar peticiones HTTP
  String get effectiveScriptUrl {
    if (scriptUrl.isEmpty || scriptUrl == _cloudSecretKey || (scriptUrl.length > 50 && scriptUrl.endsWith('=='))) {
      try {
        return utf8.decode(base64.decode(_cloudSecretKey));
      } catch (_) {
        return defaultMasterScriptUrl;
      }
    }
    // Si la URL guardada es la vieja o no coincide con la versión oficial activa, usar la maestra
    if (!scriptUrl.contains('AKfycbwGoHbSmlGEZ9M6fjOP27c3dXvQR58b4YEzfXpoZZwbpyh7pEGlrwZ1jsL6J5Z4ulrC')) {
      return defaultMasterScriptUrl;
    }
    return scriptUrl;
  }

  /// Indica si el servicio cuenta con una URL válida
  bool get isConfigured => effectiveScriptUrl.startsWith('https://');

  /// Indica si el negocio ya está registrado o autenticado en el hub multi-tenant
  bool get isTenantAuthenticated =>
      isConfigured &&
      businessId != null &&
      businessId!.isNotEmpty &&
      authToken != null &&
      authToken!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'scriptUrl': scriptUrl,
        'isEnabled': isEnabled,
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'autoSyncOnSale': autoSyncOnSale,
        'sheetName': sheetName,
        'businessId': businessId,
        'authToken': authToken,
        'ownerEmail': ownerEmail,
        'spreadsheetId': spreadsheetId,
      };

  factory GoogleSheetsConfig.fromJson(Map<String, dynamic> json) =>
      GoogleSheetsConfig(
        scriptUrl: json['scriptUrl'] as String? ?? _cloudSecretKey,
        isEnabled: json['isEnabled'] as bool? ?? true,
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.tryParse(json['lastSyncAt'] as String)
            : null,
        autoSyncOnSale: json['autoSyncOnSale'] as bool? ?? true,
        sheetName: json['sheetName'] as String?,
        businessId: json['businessId'] as String?,
        authToken: json['authToken'] as String?,
        ownerEmail: json['ownerEmail'] as String?,
        spreadsheetId: json['spreadsheetId'] as String?,
      );

  GoogleSheetsConfig copyWith({
    String? scriptUrl,
    bool? isEnabled,
    DateTime? lastSyncAt,
    bool? autoSyncOnSale,
    String? sheetName,
    String? businessId,
    String? authToken,
    String? ownerEmail,
    String? spreadsheetId,
  }) {
    return GoogleSheetsConfig(
      scriptUrl: scriptUrl ?? this.scriptUrl,
      isEnabled: isEnabled ?? this.isEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      autoSyncOnSale: autoSyncOnSale ?? this.autoSyncOnSale,
      sheetName: sheetName ?? this.sheetName,
      businessId: businessId ?? this.businessId,
      authToken: authToken ?? this.authToken,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
    );
  }
}
