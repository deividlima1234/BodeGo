import 'package:flutter_test/flutter_test.dart';
import 'package:bodego/core/services/cloud_security_manager.dart';

void main() {
  group('PIN Encryption & Decryption Tests', () {
    const secretKey = 'BIZ_1795145376098_5928_SECRET_KEY';
    const testPin = '1234';

    test('El PIN encriptado tiene el prefijo ENC: y formato esperado', () {
      final enc = CloudSecurityManager.encryptPin(testPin, secretKey: secretKey);
      expect(enc.startsWith('ENC:'), isTrue);
      final parts = enc.split(':');
      expect(parts.length, equals(3));
      expect(parts[1].length, equals(16)); // 8 bytes salt = 16 hex chars
      expect(enc, isNot(contains(testPin))); // El PIN nunca está en texto plano
    });

    test('Dos cifrados del mismo PIN generan ciphertexts distintos por el salt aleatorio', () {
      final enc1 = CloudSecurityManager.encryptPin(testPin, secretKey: secretKey);
      final enc2 = CloudSecurityManager.encryptPin(testPin, secretKey: secretKey);
      expect(enc1, isNot(equals(enc2)));
    });

    test('Desencriptar con la clave correcta recupera el PIN exacto', () {
      final enc = CloudSecurityManager.encryptPin(testPin, secretKey: secretKey);
      final decrypted = CloudSecurityManager.decryptPin(enc, secretKey: secretKey);
      expect(decrypted, equals(testPin));
    });

    test('Desencriptar con clave errónea no produce el PIN original', () {
      final enc = CloudSecurityManager.encryptPin(testPin, secretKey: secretKey);
      final decrypted = CloudSecurityManager.decryptPin(enc, secretKey: 'WRONG_KEY');
      expect(decrypted, isNot(equals(testPin)));
    });

    test('Mantiene compatibilidad con PINs legados en texto plano', () {
      const legacyPin = '9876';
      final decrypted = CloudSecurityManager.decryptPin(legacyPin, secretKey: secretKey);
      expect(decrypted, equals(legacyPin));
    });
  });
}

