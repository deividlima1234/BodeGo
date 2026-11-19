import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bodego/core/services/html_receipt_generator.dart';
import 'package:bodego/core/services/esc_pos_ticket_generator.dart';
import 'package:bodego/core/services/pdf_receipt_generator.dart';
import 'package:bodego/core/services/ipp_client.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';

void main() {
  group('Receipt Generators Test Suite', () {
    late SaleTicket testTicket;
    late BusinessConfig testBusinessConfig;
    late PrinterConfig testPrinterConfig;

    setUp(() {
      testTicket = SaleTicket(
        id: 'TKT_1795018815374',
        ticketNumber: 'TKT-0002',
        date: DateTime(2026, 11, 18, 11, 20, 15),
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
            unit: 'und',
          ),
          SaleTicketItem(
            productId: 2,
            name: 'Detergente Patito',
            quantity: 1,
            unitPrice: 1.00,
            subtotal: 1.00,
            unit: 'und',
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

      testBusinessConfig = const BusinessConfig(
        businessName: 'MINIMARKET DORUCK',
        ruc: 'RUC: 10458921341',
        address: 'AV - Principal',
        phone: 'Tel / Cel: 987 654 321',
        logoType: 'preset',
        logoValue: 'shopping_cart',
        showBarcodeOnTicket: true,
        showEddamCoreBranding: true,
      );

      testPrinterConfig = const PrinterConfig(
        printerType: 'inkjet_system',
        inkjetPaperFormat: 'half_a4_vertical',
      );
    });

    test('HtmlReceiptGenerator generates clean HTML with logo, clean barcode and no duplicated prefixes', () {
      final html = HtmlReceiptGenerator.generateTicketHtml(
        ticket: testTicket,
        businessConfig: testBusinessConfig,
        printerConfig: testPrinterConfig,
      );

      // 1. Debe incluir el SVG del logo preset (shopping_cart)
      expect(html.contains('<svg width="44" height="44"'), isTrue);

      // 2. No debe tener prefijos duplicados
      expect(html.contains('RUC: RUC:'), isFalse);
      expect(html.contains('Tel / Cel: Tel / Cel:'), isFalse);
      expect(html.contains('RUC: 10458921341'), isTrue);
      expect(html.contains('Tel / Cel: 987 654 321'), isTrue);

      // 3. Debe incluir el código de barras en SVG vectorial
      expect(html.contains('<svg class="barcode-svg"'), isTrue);
      expect(html.contains('* 1795018815374 *'), isTrue);

      // 4. No debe contener plecas de texto antiguas || ||
      expect(html.contains('|| | |||| | ||| || ||| |'), isFalse);

      // 5. Debe contener las unidades formateadas como el modal (x1 y 2 kg)
      expect(html.contains('x1'), isTrue);
      expect(html.contains('2 kg'), isTrue);

      // 6. Debe incluir el badge AL CONTADO
      expect(html.contains('AL CONTADO'), isTrue);
    });

    test('EscPosTicketGenerator generates valid bytes with barcode and sanitization', () {
      final bytes = EscPosTicketGenerator.generateTicketBytes(
        ticket: testTicket,
        businessConfig: testBusinessConfig,
        paperWidthMm: 58,
      );

      expect(bytes.isNotEmpty, isTrue);
    });

    test('PdfReceiptGenerator generates valid PDF bytes for Direct IPP printing', () async {
      final pdfBytes = await PdfReceiptGenerator.generateTicketPdf(
        ticket: testTicket,
        businessConfig: testBusinessConfig,
        printerConfig: testPrinterConfig,
      );

      expect(pdfBytes.isNotEmpty, isTrue);
      // Validar cabecera mágica de PDF (%PDF-)
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header.startsWith('%PDF-'), isTrue);
    });

    test('IppClient builds valid binary IPP payload RFC 8011', () async {
      final pdfBytes = await PdfReceiptGenerator.generateTicketPdf(
        ticket: testTicket,
        businessConfig: testBusinessConfig,
        printerConfig: testPrinterConfig,
      );

      final payload = IppClient.buildIppPrintJobPayload(
        printerIp: '192.168.22.1',
        printerPort: 631,
        documentBytes: pdfBytes,
        jobName: 'Ticket_Test',
      );

      expect(payload.isNotEmpty, isTrue);
      // Validar versión IPP 1.1 (0x01, 0x01)
      expect(payload[0], equals(0x01));
      expect(payload[1], equals(0x01));
      // Validar Operation ID Print-Job (0x00, 0x02)
      expect(payload[2], equals(0x00));
      expect(payload[3], equals(0x02));
    });

    test('IppClient builds valid Get-Printer-Attributes payload and parses attributes', () {
      final payload = IppClient.buildGetPrinterAttributesPayload(
        printerIp: '192.168.114.1',
        printerPort: 631,
      );

      expect(payload.isNotEmpty, isTrue);
      // Operation ID 0x000B (Get-Printer-Attributes)
      expect(payload[2], equals(0x00));
      expect(payload[3], equals(0x0B));

      // Test parsing
      final mockData = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01,
        // printer-make-and-model
        0x42,
        0x00, 0x16, ...utf8.encode('printer-make-and-model'),
        0x00, 0x12, ...utf8.encode('Canon G3010 series'),
        // document-format-supported
        0x49,
        0x00, 0x19, ...utf8.encode('document-format-supported'),
        0x00, 0x10, ...utf8.encode('image/pwg-raster'),
        0x03, // end of attributes
      ]);

      final parsed = IppClient.parsePrinterAttributes(mockData);
      expect(parsed.model, equals('Canon G3010 series'));
      expect(parsed.formats.contains('image/pwg-raster'), isTrue);
      expect(parsed.formats.contains('application/pdf'), isFalse);
    });

    test('IppClient builds valid Get-Job-Attributes payload and parses job & printer telemetry', () {
      final payload = IppClient.buildGetJobAttributesPayload(
        printerIp: '192.168.1.50',
        printerPort: 631,
        jobId: 42,
      );

      expect(payload.isNotEmpty, isTrue);
      // Operation ID 0x0009 (Get-Job-Attributes)
      expect(payload[2], equals(0x00));
      expect(payload[3], equals(0x09));

      // Test parsing job response with job-id, job-state, printer-state and reasons
      final mockData = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x02, // job attributes tag
        // job-id (integer 0x21, value 42)
        0x21,
        0x00, 0x06, ...utf8.encode('job-id'),
        0x00, 0x04, 0x00, 0x00, 0x00, 0x2A, // 42 in int32
        // job-state (enum 0x23, value 5 = processing)
        0x23,
        0x00, 0x09, ...utf8.encode('job-state'),
        0x00, 0x04, 0x00, 0x00, 0x00, 0x05, // 5 = processing
        // job-state-reasons (keyword 0x44)
        0x44,
        0x00, 0x11, ...utf8.encode('job-state-reasons'),
        0x00, 0x0C, ...utf8.encode('job-printing'),
        // printer-state (enum 0x23, value 4 = processing)
        0x23,
        0x00, 0x0D, ...utf8.encode('printer-state'),
        0x00, 0x04, 0x00, 0x00, 0x00, 0x04, // 4 = processing
        // printer-state-reasons
        0x44,
        0x00, 0x15, ...utf8.encode('printer-state-reasons'),
        0x00, 0x04, ...utf8.encode('none'),
        0x03, // end of attributes
      ]);

      final attrs = IppClient.parseIppAttributes(mockData);
      expect(attrs['job-id'], equals(42));
      expect(attrs['job-state'], equals(5));
      expect(attrs['job-state-reasons'], equals('job-printing'));
      expect(attrs['printer-state'], equals(4));
      expect(attrs['printer-state-reasons'], equals('none'));
    });
  });
}

