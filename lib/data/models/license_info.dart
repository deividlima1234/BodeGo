import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Modelo de datos inmutable que almacena el estado de la licencia y periodo de prueba.
class LicenseInfo {
  final String machineId;
  final DateTime trialStartDate;
  final DateTime lastActiveDate;
  final bool isActivated;
  final String licenseType; // 'trial', '1month', '6months', '1year', 'lifetime'
  final DateTime? expirationDate;
  final String? activationCode;
  final bool isClockTampered;

  static const int trialDurationDays = 7;
  static const String secretSignatureKey = 'B0d3G0@EddamC0r3#2026!SignatureKey';

  const LicenseInfo({
    required this.machineId,
    required this.trialStartDate,
    required this.lastActiveDate,
    this.isActivated = false,
    this.licenseType = 'trial',
    this.expirationDate,
    this.activationCode,
    this.isClockTampered = false,
  });

  /// Días de prueba restantes (0 a 7)
  int get trialDaysRemaining {
    if (isActivated) return 0;
    final now = DateTime.now();
    final difference = now.difference(trialStartDate);
    final daysPassed = difference.inDays;
    final remaining = trialDurationDays - daysPassed;
    return remaining.clamp(0, trialDurationDays);
  }

  /// Indica si el periodo de prueba ha expirado
  bool get isTrialExpired {
    if (isActivated) return false;
    final now = DateTime.now();
    final elapsedDays = now.difference(trialStartDate).inDays;
    return elapsedDays >= trialDurationDays || isClockTampered;
  }

  /// Indica si la app está habilitada para operar normalmente
  bool get canAccessApp {
    if (isActivated) {
      if (licenseType == 'lifetime') return true;
      if (expirationDate != null && DateTime.now().isBefore(expirationDate!)) {
        return true;
      }
      return false; // Licencia temporal expiró
    }
    return !isTrialExpired;
  }

  /// Genera una firma digital para verificar la integridad del archivo guardado
  String generateSignature() {
    final payload = '$machineId|${trialStartDate.toIso8601String()}|'
        '${lastActiveDate.toIso8601String()}|$isActivated|$licenseType|'
        '${expirationDate?.toIso8601String() ?? ""}|$activationCode';
    final key = utf8.encode(secretSignatureKey);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  Map<String, dynamic> toJson() => {
        'machineId': machineId,
        'trialStartDate': trialStartDate.toIso8601String(),
        'lastActiveDate': lastActiveDate.toIso8601String(),
        'isActivated': isActivated,
        'licenseType': licenseType,
        'expirationDate': expirationDate?.toIso8601String(),
        'activationCode': activationCode,
        'isClockTampered': isClockTampered,
        'signature': generateSignature(),
      };

  factory LicenseInfo.fromJson(Map<String, dynamic> json) {
    final info = LicenseInfo(
      machineId: json['machineId'] as String? ?? 'BDG-UNKNOWN',
      trialStartDate: json['trialStartDate'] != null
          ? DateTime.parse(json['trialStartDate'] as String)
          : DateTime.now(),
      lastActiveDate: json['lastActiveDate'] != null
          ? DateTime.parse(json['lastActiveDate'] as String)
          : DateTime.now(),
      isActivated: json['isActivated'] as bool? ?? false,
      licenseType: json['licenseType'] as String? ?? 'trial',
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'] as String)
          : null,
      activationCode: json['activationCode'] as String?,
      isClockTampered: json['isClockTampered'] as bool? ?? false,
    );

    // Verificar firma anti-manipulación manual de archivo
    final savedSignature = json['signature'] as String?;
    if (savedSignature != null && savedSignature != info.generateSignature()) {
      // Si el archivo fue editado a mano para poner isActivated = true, se invalida
      return LicenseInfo(
        machineId: info.machineId,
        trialStartDate: info.trialStartDate,
        lastActiveDate: DateTime.now(),
        isActivated: false,
        licenseType: 'trial',
        isClockTampered: true,
      );
    }

    return info;
  }

  LicenseInfo copyWith({
    String? machineId,
    DateTime? trialStartDate,
    DateTime? lastActiveDate,
    bool? isActivated,
    String? licenseType,
    DateTime? expirationDate,
    String? activationCode,
    bool? isClockTampered,
  }) {
    return LicenseInfo(
      machineId: machineId ?? this.machineId,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      isActivated: isActivated ?? this.isActivated,
      licenseType: licenseType ?? this.licenseType,
      expirationDate: expirationDate ?? this.expirationDate,
      activationCode: activationCode ?? this.activationCode,
      isClockTampered: isClockTampered ?? this.isClockTampered,
    );
  }
}

