/// Modelo que encapsula los metadatos de actualización OTA alojados en GitHub.
class OtaUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final String downloadUrl;
  final List<String> releaseNotes;
  final bool isMandatory;
  final String minSupportedVersion;
  final String publishedAt;

  const OtaUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isMandatory = false,
    this.minSupportedVersion = '1.0.0',
    this.publishedAt = '',
  });

  factory OtaUpdateInfo.fromJson(Map<String, dynamic> json) {
    List<String> notes = [];
    if (json['release_notes'] is List) {
      notes = (json['release_notes'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (json['release_notes'] is String) {
      notes = (json['release_notes'] as String)
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return OtaUpdateInfo(
      latestVersion: json['latest_version']?.toString().trim() ?? '1.0.0',
      buildNumber: (json['build_number'] as num?)?.toInt() ?? 1,
      downloadUrl: json['download_url']?.toString().trim() ?? '',
      releaseNotes: notes,
      isMandatory: json['is_mandatory'] as bool? ?? false,
      minSupportedVersion:
          json['min_supported_version']?.toString().trim() ?? '1.0.0',
      publishedAt: json['published_at']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'build_number': buildNumber,
      'download_url': downloadUrl,
      'release_notes': releaseNotes,
      'is_mandatory': isMandatory,
      'min_supported_version': minSupportedVersion,
      'published_at': publishedAt,
    };
  }

  /// Compara si esta versión remota es más reciente que la instalada en el dispositivo
  bool isNewerThan(String currentVersionName, int currentVersionCode) {
    // 1. Comparar primero por buildNumber si el JSON lo especifica
    if (buildNumber > currentVersionCode) return true;

    // 2. Comparar por version semántica x.y.z
    final remoteParts = _parseVersionParts(latestVersion);
    final localParts = _parseVersionParts(currentVersionName);

    for (int i = 0; i < 3; i++) {
      if (remoteParts[i] > localParts[i]) return true;
      if (remoteParts[i] < localParts[i]) return false;
    }

    return buildNumber > currentVersionCode;
  }

  static List<int> _parseVersionParts(String version) {
    final cleaned = version.replaceAll(RegExp(r'[^0-9.]'), '');
    final parts = cleaned.split('.');
    final result = <int>[0, 0, 0];
    for (int i = 0; i < parts.length && i < 3; i++) {
      result[i] = int.tryParse(parts[i]) ?? 0;
    }
    return result;
  }
}

/// Resultado de la verificación OTA con estado de advertencias
class OtaCheckResult {
  final OtaUpdateInfo updateInfo;
  final int dismissCount;
  final bool isMandatory;

  const OtaCheckResult({
    required this.updateInfo,
    required this.dismissCount,
    required this.isMandatory,
  });
}

