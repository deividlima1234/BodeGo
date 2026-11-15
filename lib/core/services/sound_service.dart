import 'package:flutter/services.dart';

/// Servicio de efectos de sonido del sistema y escáner de códigos de barras (POS).
class SoundService {
  SoundService._();

  static const MethodChannel _channel = MethodChannel('com.eddamcore.bodego/sound');

  /// Reproduce el pitido clásico y nítido de escáner de códigos de barras (POS).
  static Future<void> playScannerBeep() async {
    try {
      await _channel.invokeMethod('playScannerBeep');
    } catch (_) {
      // Fallback nativo en caso de entornos sin canal
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// Reproduce un tono de advertencia cuando un código no existe en el catálogo.
  static Future<void> playErrorBeep() async {
    try {
      await _channel.invokeMethod('playErrorBeep');
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }
}

