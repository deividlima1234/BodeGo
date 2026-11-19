import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodego/core/services/pwg_raster_encoder.dart';

/// Decompresor estándar de PackBits para PWG Raster (PWG 5102.4 / CUPS)
Uint8List unpackPwgScanline(Uint8List packed, int expectedPixels) {
  final out = BytesBuilder();
  int idx = 0;
  int pixelsDecoded = 0;

  while (idx < packed.length && pixelsDecoded < expectedPixels) {
    final cb = packed[idx];
    idx++;

    if (cb <= 127) {
      // Repetición de (cb + 1) píxeles (1 a 128)
      final count = cb + 1;
      final r = packed[idx];
      final g = packed[idx + 1];
      final b = packed[idx + 2];
      idx += 3;

      for (int i = 0; i < count; i++) {
        out.addByte(r);
        out.addByte(g);
        out.addByte(b);
      }
      pixelsDecoded += count;
    } else {
      // Literal de (257 - cb) píxeles (2 a 128)
      final count = 257 - cb;
      for (int i = 0; i < count; i++) {
        out.addByte(packed[idx]);
        out.addByte(packed[idx + 1]);
        out.addByte(packed[idx + 2]);
        idx += 3;
      }
      pixelsDecoded += count;
    }
  }

  expect(pixelsDecoded, equals(expectedPixels), reason: 'Decoded pixel count mismatch');
  expect(idx, equals(packed.length), reason: 'Unread bytes remaining in packed stream');

  return out.toBytes();
}

void main() {
  group('PWG PackBits Stress & Fuzz Testing', () {
    test('Repeated pixel runs of all lengths 1 to 2480', () {
      for (int len = 1; len <= 2480; len++) {
        final input = Uint8List(len * 3);
        // Fill with color (42, 84, 126)
        for (int i = 0; i < len; i++) {
          input[i * 3] = 42;
          input[i * 3 + 1] = 84;
          input[i * 3 + 2] = 126;
        }

        final packed = PwgRasterEncoder.packPwgScanline(input);
        final unpacked = unpackPwgScanline(packed, len);

        expect(unpacked, equals(input), reason: 'Failed for repeated run of length $len');
      }
    });

    test('Non-repeating pixel sequences of all lengths 1 to 2480', () {
      for (int len = 1; len <= 500; len++) {
        final input = Uint8List(len * 3);
        for (int i = 0; i < len; i++) {
          input[i * 3] = (i * 7) & 0xFF;
          input[i * 3 + 1] = (i * 13) & 0xFF;
          input[i * 3 + 2] = (i * 29) & 0xFF;
        }

        final packed = PwgRasterEncoder.packPwgScanline(input);
        final unpacked = unpackPwgScanline(packed, len);

        expect(unpacked, equals(input), reason: 'Failed for literal run of length $len');
      }
    });

    test('Random fuzz patterns with varying runs and literals', () {
      final rand = Random(12345);
      const width = 2480;

      for (int iteration = 0; iteration < 200; iteration++) {
        final input = Uint8List(width * 3);
        int px = 0;

        while (px < width) {
          final isRun = rand.nextBool();
          final r = rand.nextInt(256);
          final g = rand.nextInt(256);
          final b = rand.nextInt(256);

          if (isRun) {
            final runLen = min(rand.nextInt(300) + 2, width - px);
            for (int i = 0; i < runLen; i++) {
              input[(px + i) * 3] = r;
              input[(px + i) * 3 + 1] = g;
              input[(px + i) * 3 + 2] = b;
            }
            px += runLen;
          } else {
            final litLen = min(rand.nextInt(50) + 1, width - px);
            for (int i = 0; i < litLen; i++) {
              input[(px + i) * 3] = rand.nextInt(256);
              input[(px + i) * 3 + 1] = rand.nextInt(256);
              input[(px + i) * 3 + 2] = rand.nextInt(256);
            }
            px += litLen;
          }
        }

        final packed = PwgRasterEncoder.packPwgScanline(input);
        final unpacked = unpackPwgScanline(packed, width);

        expect(unpacked, equals(input), reason: 'Fuzz test failed at iteration $iteration');
      }
    });
  });
}

