import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodego/core/services/pwg_raster_encoder.dart';
import 'package:bodego/core/services/ticket_canvas_renderer.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PwgRasterEncoder Test Suite', () {
    test('buildPageHeader produces exactly 1796 bytes with correct offsets for sgray8 and srgb8', () {
      final headerGray = PwgRasterEncoder.buildPageHeader(
        width: 1240,
        height: 1754,
        dpi: 300,
        pageSizeName: 'iso_a4_210x297mm',
        colorSpace: PwgColorSpace.sgray8,
      );

      expect(headerGray.length, equals(1796));
      final byteDataGray = ByteData.sublistView(headerGray);

      // PwgRaster identifier @ 0
      expect(String.fromCharCodes(headerGray.sublist(0, 9)), equals('PwgRaster'));

      // HWResolution @ 276
      expect(byteDataGray.getUint32(276, Endian.big), equals(300));
      expect(byteDataGray.getUint32(280, Endian.big), equals(300));

      // cupsWidth @ 372 y cupsHeight @ 376
      expect(byteDataGray.getUint32(372, Endian.big), equals(1240));
      expect(byteDataGray.getUint32(376, Endian.big), equals(1754));

      // cupsBitsPerPixel @ 388 (8 bits para escala de grises)
      expect(byteDataGray.getUint32(388, Endian.big), equals(8));
      // cupsColorSpace @ 400 (18 = PWG_CS_SGRAY)
      expect(byteDataGray.getUint32(400, Endian.big), equals(18));

      // PWG cupsInteger fields
      expect(byteDataGray.getUint32(452, Endian.big), equals(1)); // TotalPageCount
      expect(byteDataGray.getInt32(456, Endian.big), equals(1)); // CrossFeedTransform
      expect(byteDataGray.getInt32(460, Endian.big), equals(1)); // FeedTransform
      expect(byteDataGray.getUint32(464, Endian.big), equals(0)); // ImageBox Left
      expect(byteDataGray.getUint32(468, Endian.big), equals(0)); // ImageBox Top
      expect(byteDataGray.getUint32(472, Endian.big), equals(1240)); // ImageBox Right
      expect(byteDataGray.getUint32(476, Endian.big), equals(1754)); // ImageBox Bottom
      expect(byteDataGray.getUint32(484, Endian.big), equals(4)); // PrintQuality

      // Color sRGB
      final headerRgb = PwgRasterEncoder.buildPageHeader(
        width: 1240,
        height: 1754,
        dpi: 300,
        pageSizeName: 'iso_a4_210x297mm',
        colorSpace: PwgColorSpace.srgb8,
      );
      expect(headerRgb.length, equals(1796));
      final byteDataRgb = ByteData.sublistView(headerRgb);
      expect(byteDataRgb.getUint32(388, Endian.big), equals(24));
      expect(byteDataRgb.getUint32(400, Endian.big), equals(19));
    });

    test('packPwgScanline compresses repeated pixel colors correctly per PWG spec', () {
      // 10 píxeles blancos en sRGB (30 bytes en 0xFF)
      final input = Uint8List.fromList(List.filled(30, 0xFF));
      final packed = PwgRasterEncoder.packPwgScanline(input);

      // En CUPS/PWG: 1..128 píxeles repetidos = byte (count - 1), seguido de los 3 bytes del color
      // 10 - 1 = 9, seguido de 0xFF, 0xFF, 0xFF -> exactamente 4 bytes!
      expect(packed.length, equals(4));
      expect(packed[0], equals(9));
      expect(packed[1], equals(0xFF));
      expect(packed[2], equals(0xFF));
      expect(packed[3], equals(0xFF));
    });

    test('packPwgScanline compresses non-repeating pixel sequences correctly per PWG spec', () {
      // 3 píxeles de colores distintos: Rojo, Verde, Azul (9 bytes)
      final input = Uint8List.fromList([
        255, 0, 0, // Rojo
        0, 255, 0, // Verde
        0, 0, 255, // Azul
      ]);
      final packed = PwgRasterEncoder.packPwgScanline(input);

      // En CUPS/PWG: 2..128 píxeles no repetidos = byte (257 - count), seguido de los (count * 3) bytes
      // 257 - 3 = 254 (0xFE), seguido de los 9 bytes -> exactamente 10 bytes!
      expect(packed.length, equals(10));
      expect(packed[0], equals(254));
      expect(packed[1], equals(255));
      expect(packed[2], equals(0));
      expect(packed[3], equals(0));
    });

    test('encodeRgba produces complete PWG Raster with RaS2 header and compressed scanlines', () {
      const width = 10;
      const height = 4;
      // 10x4 píxeles blancos en RGBA (40 píxeles * 4 bytes = 160 bytes)
      final rgba = Uint8List(width * height * 4);
      for (int i = 0; i < rgba.length; i += 4) {
        rgba[i] = 255;
        rgba[i + 1] = 255;
        rgba[i + 2] = 255;
        rgba[i + 3] = 255;
      }

      final pwg = PwgRasterEncoder.encodeRgba(
        rgbaBytes: rgba,
        width: width,
        height: height,
        dpi: 300,
      );

      expect(pwg.length, greaterThan(1792 + 4));
      // Verificar "RaS2"
      expect(pwg[0], equals(0x52));
      expect(pwg[1], equals(0x61));
      expect(pwg[2], equals(0x53));
      expect(pwg[3], equals(0x32));
    });

    test('TicketCanvasRenderer renders real ticket to valid PWG-Raster stream', () async {
      final ticket = SaleTicket(
        id: 'TKT_TEST_PWG',
        ticketNumber: 'TKT-0002',
        date: DateTime.now(),
        total: 10.00,
        subtotal: 10.00,
        discount: 0.0,
        isCredit: false,
        cashierName: 'Deivid',
        businessName: 'MINIMARKET DORUCK',
        items: [
          SaleTicketItem(
            productId: 1,
            name: 'Agua Oxigenada 60 mL',
            quantity: 1,
            unitPrice: 2.00,
            subtotal: 2.00,
          ),
          SaleTicketItem(
            productId: 2,
            name: 'Detergente Patito',
            quantity: 1,
            unitPrice: 1.00,
            subtotal: 1.00,
          ),
          SaleTicketItem(
            productId: 3,
            name: 'Azúcar Rubia',
            quantity: 2,
            unitPrice: 3.50,
            subtotal: 7.00,
            unit: 'kg',
          ),
        ],
      );

      final businessConfig = const BusinessConfig(
        businessName: 'MINIMARKET DORUCK',
        ruc: 'RUC: 10458921341',
        address: 'AV - Principal',
        phone: 'Tel / Cel: 987 654 321',
        logoType: 'preset',
        logoValue: 'shopping_cart',
        showBarcodeOnTicket: true,
        showEddamCoreBranding: true,
      );

      final printerConfig = const PrinterConfig(
        printerType: 'inkjet_system',
        inkjetPaperFormat: 'half_a4_vertical',
      );

      final pwgBytes = await TicketCanvasRenderer.renderTicketToPwg(
        ticket: ticket,
        businessConfig: businessConfig,
        printerConfig: printerConfig,
      );

      expect(pwgBytes.isNotEmpty, isTrue);
      // Validar Sync Word "RaS2"
      expect(pwgBytes[0], equals(0x52));
      expect(pwgBytes[1], equals(0x61));
      expect(pwgBytes[2], equals(0x53));
      expect(pwgBytes[3], equals(0x32));
      // Tamaño razonable comprimido (< 1.5 MB para A4 completa con compresión PackBits)
      expect(pwgBytes.length, greaterThan(2000));
      expect(pwgBytes.length, lessThan(1500000));

      File('/tmp/real_ticket.pwg').writeAsBytesSync(pwgBytes);
    });
  });
}
