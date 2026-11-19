import 'dart:typed_data';

/// Espacio de color admitido por el codificador PWG-Raster
enum PwgColorSpace {
  /// Color sRGB estándar de 24 bits (3 canales, PWG_CS_SRGB = 19).
  /// Estándar universal requerido por los firmwares de Canon MegaTank (G3110, G2110, G3000),
  /// Epson EcoTank, HP Smart Tank y Brother.
  srgb8,

  /// Escala de grises de 8 bits (1 canal, PWG_CS_SGRAY = 18).
  sgray8,
}

/// Codificador de mapas de bits a formato PWG-Raster (PWG 5102.4 / CUPS Raster v2).
/// Estándar universal de Apple AirPrint y Mopria Alliance soportado nativamente por
/// Canon MegaTank (G3110, G2110), Epson EcoTank, HP Smart Tank y Brother.
class PwgRasterEncoder {
  /// Palabra de sincronización estándar PWG Raster versión 2 ("RaS2")
  static const List<int> syncWord = [0x52, 0x61, 0x53, 0x32];

  /// Codifica un buffer de píxeles RGBA en memoria (32 bits por pixel)
  /// a un flujo binario PWG-Raster sRGB de 24 bits (srgb_8) 100% compatible con impresoras de inyección.
  static Uint8List encodeRgba({
    required Uint8List rgbaBytes,
    required int width,
    required int height,
    int dpi = 300,
    String pageSizeName = 'iso_a4_210x297mm',
    PwgColorSpace colorSpace = PwgColorSpace.srgb8,
  }) {
    final buffer = BytesBuilder();

    // 1. Palabra de sincronización "RaS2" (4 bytes)
    buffer.add(syncWord);

    // 2. Encabezado de página estándar PWG de 1796 bytes
    final isGrayscale = colorSpace == PwgColorSpace.sgray8;
    final header = buildPageHeader(
      width: width,
      height: height,
      dpi: dpi,
      pageSizeName: pageSizeName,
      colorSpace: colorSpace,
    );
    buffer.add(header);

    // 3. Extracción de scanlines RGB (24 bits) desde el buffer RGBA
    if (!isGrayscale) {
      final bytesPerLine = width * 3;
      final scanlines = <Uint8List>[];

      for (int y = 0; y < height; y++) {
        final lineRgb = Uint8List(bytesPerLine);
        int srcIdx = y * width * 4;
        int dstIdx = 0;

        for (int x = 0; x < width; x++) {
          if (srcIdx + 3 < rgbaBytes.length) {
            final r = rgbaBytes[srcIdx];
            final g = rgbaBytes[srcIdx + 1];
            final b = rgbaBytes[srcIdx + 2];
            final a = rgbaBytes[srcIdx + 3];

            if (a == 255) {
              lineRgb[dstIdx] = r;
              lineRgb[dstIdx + 1] = g;
              lineRgb[dstIdx + 2] = b;
            } else if (a == 0) {
              lineRgb[dstIdx] = 255;
              lineRgb[dstIdx + 1] = 255;
              lineRgb[dstIdx + 2] = 255;
            } else {
              final alpha = a / 255.0;
              lineRgb[dstIdx] = ((r * alpha) + (255 * (1 - alpha))).round().clamp(0, 255);
              lineRgb[dstIdx + 1] = ((g * alpha) + (255 * (1 - alpha))).round().clamp(0, 255);
              lineRgb[dstIdx + 2] = ((b * alpha) + (255 * (1 - alpha))).round().clamp(0, 255);
            }
          } else {
            lineRgb[dstIdx] = 255;
            lineRgb[dstIdx + 1] = 255;
            lineRgb[dstIdx + 2] = 255;
          }

          srcIdx += 4;
          dstIdx += 3;
        }
        scanlines.add(lineRgb);
      }

      // 4. Compresión PackBits a nivel de píxel sin repetición multi-línea (repeatCount = 0)
      // Cada scanline se emite de forma 100% independiente con byte de repetición 0x00.
      // Esto evita desincronizaciones en procesadores de impresoras Canon MegaTank (G3110 / G2110)
      // causadas por bloques largos de repetición de líneas blancas.
      for (int y = 0; y < height; y++) {
        buffer.addByte(0); // repeatCount = 0 (1 línea exacta)
        final packedLine = packPwgScanlineRgb(scanlines[y]);
        buffer.add(packedLine);
      }
    } else {
      // Modo escala de grises para impresoras que admiten sgray_8
      final scanlines = <Uint8List>[];
      for (int y = 0; y < height; y++) {
        final lineGray = Uint8List(width);
        int srcIdx = y * width * 4;

        for (int x = 0; x < width; x++) {
          if (srcIdx + 3 < rgbaBytes.length) {
            final r = rgbaBytes[srcIdx];
            final g = rgbaBytes[srcIdx + 1];
            final b = rgbaBytes[srcIdx + 2];
            final a = rgbaBytes[srcIdx + 3];

            if (a == 0) {
              lineGray[x] = 255;
            } else if (a == 255) {
              lineGray[x] = ((r * 77 + g * 150 + b * 29) >> 8);
            } else {
              final rawGray = (r * 77 + g * 150 + b * 29) >> 8;
              final alpha = a / 255.0;
              lineGray[x] = ((rawGray * alpha) + (255 * (1 - alpha))).round().clamp(0, 255);
            }
          } else {
            lineGray[x] = 255;
          }

          srcIdx += 4;
        }
        scanlines.add(lineGray);
      }

      for (int y = 0; y < height; y++) {
        buffer.addByte(0);
        final packedLine = packPwgScanlineGray(scanlines[y]);
        buffer.add(packedLine);
      }
    }

    return buffer.toBytes();
  }

  /// Construye la cabecera estándar PWG Raster v2 de 1796 bytes (PWG 5102.4)
  static Uint8List buildPageHeader({
    required int width,
    required int height,
    required int dpi,
    required String pageSizeName,
    PwgColorSpace colorSpace = PwgColorSpace.srgb8,
  }) {
    final header = Uint8List(1796); // 1796 bytes exactos (NO 1792)
    final byteData = ByteData.sublistView(header);
    final isGrayscale = colorSpace == PwgColorSpace.sgray8;

    // Identificador obligatorio "PwgRaster" @ offset 0
    _writeAscii(header, 0, 'PwgRaster');

    // HWResolution (X, Y) @ offset 276
    byteData.setUint32(276, dpi, Endian.big);
    byteData.setUint32(280, dpi, Endian.big);

    // NumCopies @ offset 340 (1 copia)
    byteData.setUint32(340, 1, Endian.big);

    // PageSize en puntos PostScript (1 pt = 1/72 pulgada) @ offset 352
    final ptWidth = (width * 72 / dpi).round();
    final ptHeight = (height * 72 / dpi).round();
    byteData.setUint32(352, ptWidth, Endian.big);
    byteData.setUint32(356, ptHeight, Endian.big);

    // cupsWidth @ 372 y cupsHeight @ 376
    byteData.setUint32(372, width, Endian.big);
    byteData.setUint32(376, height, Endian.big);

    // cupsBitsPerColor (8) @ 384
    byteData.setUint32(384, 8, Endian.big);
    // cupsBitsPerPixel (24 para srgb_8, 8 para sgray_8) @ 388
    byteData.setUint32(388, isGrayscale ? 8 : 24, Endian.big);
    // cupsBytesPerLine @ 392
    byteData.setUint32(392, isGrayscale ? width : (width * 3), Endian.big);
    // cupsColorOrder (0 = Chunky) @ 396
    byteData.setUint32(396, 0, Endian.big);
    // cupsColorSpace (19 = PWG_CS_SRGB, 18 = PWG_CS_SGRAY) @ 400
    byteData.setUint32(400, isGrayscale ? 18 : 19, Endian.big);
    // cupsCompression (0 = PackBits estándar PWG) @ 404
    byteData.setUint32(404, 0, Endian.big);
    // cupsNumColors (3 para srgb_8, 1 para sgray_8) @ 420
    byteData.setUint32(420, isGrayscale ? 1 : 3, Endian.big);

    // --- Campos PWG en cupsInteger[0..15] (inician en 452) ---
    // TotalPageCount @ 452 (1 página)
    byteData.setUint32(452, 1, Endian.big);
    // CrossFeedTransform (1) @ 456 y FeedTransform (1) @ 460
    byteData.setInt32(456, 1, Endian.big);
    byteData.setInt32(460, 1, Endian.big);

    // ImageBox (Left, Top, Right, Bottom) @ 464..476
    byteData.setUint32(464, 0, Endian.big);
    byteData.setUint32(468, 0, Endian.big);
    byteData.setUint32(472, width, Endian.big);
    byteData.setUint32(476, height, Endian.big);

    // AlternatePrimary (0x00FFFFFF) @ 480
    byteData.setUint32(480, 0x00FFFFFF, Endian.big);
    // PrintQuality (4 = Normal) @ 484
    byteData.setUint32(484, 4, Endian.big);

    // RenderingIntent @ 1668
    _writeAscii(header, 1668, 'relative-colorimetric');

    // PageSizeName @ 1732
    _writeAscii(header, 1732, pageSizeName);

    return header;
  }

  /// Compresión PackBits a nivel de píxel RGB de 3 bytes para color (srgb_8).
  /// En PWG-Raster:
  /// - 1 a 128 píxeles repetidos: byte de control (count - 1) [0..127] seguido de los 3 bytes del color.
  /// - 2 a 128 píxeles no repetidos: byte de control (257 - count) [129..255] seguido de los (count * 3) bytes.
  static Uint8List packPwgScanlineRgb(Uint8List rgbBytes) {
    final numPixels = rgbBytes.length ~/ 3;
    if (numPixels == 0) return Uint8List(0);

    final out = BytesBuilder();
    int i = 0;

    bool samePixel(int idx1, int idx2) {
      final o1 = idx1 * 3;
      final o2 = idx2 * 3;
      return rgbBytes[o1] == rgbBytes[o2] &&
          rgbBytes[o1 + 1] == rgbBytes[o2 + 1] &&
          rgbBytes[o1 + 2] == rgbBytes[o2 + 2];
    }

    while (i < numPixels) {
      int runStart = i;
      while (i + 1 < numPixels && samePixel(i, i + 1) && (i - runStart + 1) < 128) {
        i++;
      }
      final runLen = i - runStart + 1;

      if (runLen >= 2) {
        out.addByte(runLen - 1);
        final offset = runStart * 3;
        out.addByte(rgbBytes[offset]);
        out.addByte(rgbBytes[offset + 1]);
        out.addByte(rgbBytes[offset + 2]);
        i++;
      } else {
        i = runStart;
        int litStart = i;
        while (i < numPixels && (i - litStart) < 128) {
          if (i + 1 < numPixels && samePixel(i, i + 1)) {
            break;
          }
          i++;
        }

        final litLen = i - litStart;
        if (litLen == 1) {
          out.addByte(0);
          final offset = litStart * 3;
          out.addByte(rgbBytes[offset]);
          out.addByte(rgbBytes[offset + 1]);
          out.addByte(rgbBytes[offset + 2]);
        } else if (litLen > 1) {
          out.addByte(257 - litLen);
          for (int j = 0; j < litLen; j++) {
            final offset = (litStart + j) * 3;
            out.addByte(rgbBytes[offset]);
            out.addByte(rgbBytes[offset + 1]);
            out.addByte(rgbBytes[offset + 2]);
          }
        }
      }
    }

    return out.toBytes();
  }

  /// Compresión PackBits a nivel de 1 byte para escala de grises (sgray_8).
  static Uint8List packPwgScanlineGray(Uint8List grayBytes) {
    final numPixels = grayBytes.length;
    if (numPixels == 0) return Uint8List(0);

    final out = BytesBuilder();
    int i = 0;

    while (i < numPixels) {
      int runStart = i;
      while (i + 1 < numPixels && grayBytes[i] == grayBytes[i + 1] && (i - runStart + 1) < 128) {
        i++;
      }
      final runLen = i - runStart + 1;

      if (runLen >= 2) {
        out.addByte(runLen - 1);
        out.addByte(grayBytes[runStart]);
        i++;
      } else {
        i = runStart;
        int litStart = i;
        while (i < numPixels && (i - litStart) < 128) {
          if (i + 1 < numPixels && grayBytes[i] == grayBytes[i + 1]) {
            break;
          }
          i++;
        }

        final litLen = i - litStart;
        if (litLen == 1) {
          out.addByte(0);
          out.addByte(grayBytes[litStart]);
        } else if (litLen > 1) {
          out.addByte(257 - litLen);
          for (int j = 0; j < litLen; j++) {
            out.addByte(grayBytes[litStart + j]);
          }
        }
      }
    }

    return out.toBytes();
  }

  /// Método compatible con versiones anteriores
  static Uint8List packPwgScanline(Uint8List rgbBytes) => packPwgScanlineRgb(rgbBytes);

  static void _writeAscii(Uint8List target, int offset, String text) {
    for (int i = 0; i < text.length && (offset + i) < target.length; i++) {
      target[offset + i] = text.codeUnitAt(i) & 0xFF;
    }
  }
}
