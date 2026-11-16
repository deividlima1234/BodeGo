import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/data/models/license_info.dart';

/// Servicio central de gestión de licencias, periodo de prueba y activación de hardware para BodeGo.
class LicenseService {
  static const String _fileName = 'app_license.json';
  static const String _activationMasterSecret = 'B0d3G0@ActivationMasterKey#2026';
  static const String devMasterPassword = 'eddamcore2026';

  static final LicenseService _instance = LicenseService._internal();
  factory LicenseService() => _instance;
  LicenseService._internal();

  /// Notificador reactivo global para que toda la app reaccione a cambios de licencia
  final ValueNotifier<LicenseInfo?> licenseNotifier = ValueNotifier<LicenseInfo?>(null);

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Inicializa o carga la licencia al arrancar la aplicación
  Future<LicenseInfo> init() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          var info = LicenseInfo.fromJson(json);

          // Verificar si el reloj fue retrasado de forma fraudulenta
          final now = DateTime.now();
          if (now.isBefore(info.lastActiveDate.subtract(const Duration(hours: 1)))) {
            info = info.copyWith(isClockTampered: true);
          } else {
            // Actualizar última fecha de uso válida
            info = info.copyWith(lastActiveDate: now);
          }

          await _save(info);
          licenseNotifier.value = info;
          return info;
        }
      }

      // Primera instalación: Generar Machine ID e iniciar Periodo de Prueba de 7 días
      final machineId = _generateMachineId();
      final now = DateTime.now();
      final newLicense = LicenseInfo(
        machineId: machineId,
        trialStartDate: now,
        lastActiveDate: now,
        isActivated: false,
        licenseType: 'trial',
      );

      await _save(newLicense);
      licenseNotifier.value = newLicense;
      return newLicense;
    } catch (e) {
      debugPrint('Error inicializando LicenseService: $e');
      final fallback = LicenseInfo(
        machineId: 'BDG-ERR0-0000',
        trialStartDate: DateTime.now(),
        lastActiveDate: DateTime.now(),
      );
      licenseNotifier.value = fallback;
      return fallback;
    }
  }

  /// Guarda el estado de la licencia cifrado con firma digital
  Future<void> _save(LicenseInfo info) async {
    final file = await _getFile();
    final jsonString = jsonEncode(info.toJson());
    await file.writeAsString(jsonString);
    licenseNotifier.value = info;
  }

  /// Genera un Identificador de Máquina único y amigable (ej: BDG-7F9A-4B2C)
  String _generateMachineId() {
    final platformInfo = '${Platform.operatingSystem}|${Platform.numberOfProcessors}|${Platform.localHostname}';
    final random = Random.secure();
    final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));
    final seed = '$platformInfo|${DateTime.now().microsecondsSinceEpoch}|${base64Encode(randomBytes)}';

    final hash = sha256.convert(utf8.encode(seed)).toString().toUpperCase();
    final part1 = hash.substring(0, 4);
    final part2 = hash.substring(4, 8);
    return 'BDG-$part1-$part2';
  }

  /// Genera un código de activación criptográfico offline para un Machine ID dado.
  /// Utilizado por el Desarrollador / Propietario para emitir licencias a clientes.
  static String generateActivationCode({
    required String machineId,
    required String planType, // 'lifetime', '1year', '6months', '1month'
  }) {
    final canonicalId = machineId.trim().toUpperCase().replaceAll(' ', '');
    final payload = '$canonicalId:${planType.toLowerCase()}:$_activationMasterSecret';
    
    final hmac = Hmac(sha256, utf8.encode(_activationMasterSecret));
    final digest = hmac.convert(utf8.encode(payload)).toString().toUpperCase();
    
    // Formato amigable de 12 caracteres: ACT-XXXX-XXXX-XXXX
    final p1 = digest.substring(0, 4);
    final p2 = digest.substring(4, 8);
    final p3 = digest.substring(8, 12);
    return 'ACT-$p1-$p2-$p3';
  }

  /// Valida e ingresa un código de activación en el dispositivo actual
  Future<bool> validateAndActivate(String rawCode) async {
    final currentInfo = licenseNotifier.value ?? await init();
    final cleanCode = rawCode.trim().toUpperCase().replaceAll(' ', '');

    final plans = ['lifetime', '1year', '6months', '1month'];

    for (final plan in plans) {
      final expectedCode = generateActivationCode(
        machineId: currentInfo.machineId,
        planType: plan,
      );

      if (cleanCode == expectedCode) {
        DateTime? expirationDate;
        final now = DateTime.now();

        if (plan == '1month') {
          expirationDate = now.add(const Duration(days: 30));
        } else if (plan == '6months') {
          expirationDate = now.add(const Duration(days: 180));
        } else if (plan == '1year') {
          expirationDate = now.add(const Duration(days: 365));
        }

        final updatedInfo = currentInfo.copyWith(
          isActivated: true,
          licenseType: plan,
          expirationDate: expirationDate,
          activationCode: expectedCode,
          isClockTampered: false,
          lastActiveDate: now,
        );

        await _save(updatedInfo);
        return true;
      }
    }

    return false;
  }

  // --- HERRAMIENTAS EXCLUSIVAS DEL DESARROLLADOR ---

  /// Valida la contraseña maestra del desarrollador
  static bool validateDevPassword(String password) {
    return password.trim() == devMasterPassword;
  }

  /// Activa inmediatamente la terminal con licencia de por vida
  Future<void> devDirectActivate() async {
    final current = licenseNotifier.value ?? await init();
    final code = generateActivationCode(machineId: current.machineId, planType: 'lifetime');
    final updated = current.copyWith(
      isActivated: true,
      licenseType: 'lifetime',
      expirationDate: null,
      activationCode: code,
      isClockTampered: false,
      lastActiveDate: DateTime.now(),
    );
    await _save(updated);
  }

  /// Restablece el periodo de prueba a 7 días completos
  Future<void> devResetTrial() async {
    final current = licenseNotifier.value ?? await init();
    final now = DateTime.now();
    final updated = current.copyWith(
      trialStartDate: now,
      lastActiveDate: now,
      isActivated: false,
      licenseType: 'trial',
      expirationDate: null,
      activationCode: null,
      isClockTampered: false,
    );
    await _save(updated);
  }

  /// Simula la expiración de los 7 días de prueba para probar la UI de bloqueo
  Future<void> devSimulateExpiredTrial() async {
    final current = licenseNotifier.value ?? await init();
    final now = DateTime.now();
    final updated = current.copyWith(
      trialStartDate: now.subtract(const Duration(days: 8)),
      lastActiveDate: now,
      isActivated: false,
      licenseType: 'trial',
      expirationDate: null,
      activationCode: null,
      isClockTampered: false,
    );
    await _save(updated);
  }
}

