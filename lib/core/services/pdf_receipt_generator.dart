import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';

/// Generador de comprobantes en PDF vectorial de alta definición optimizados para
/// impresión directa en red IPP / Wi-Fi (Canon MegaTank G3110, Epson EcoTank, HP Smart Tank).
class PdfReceiptGenerator {
  static String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  static String _formatRuc(String ruc) {
    final trimmed = ruc.trim();
    if (trimmed.isEmpty) return '';
    String clean = trimmed;
    final rucRegex = RegExp(r'^RUC\s*[:\.\-]?\s*', caseSensitive: false);
    while (rucRegex.hasMatch(clean)) {
      clean = clean.replaceFirst(rucRegex, '').trim();
    }
    return 'RUC: $clean';
  }

  static String _formatPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    String clean = trimmed;
    final phoneRegex = RegExp(r'^(Tel\s*/?\s*Cel|Tel|Cel)\s*[:\.\-]?\s*', caseSensitive: false);
    while (phoneRegex.hasMatch(clean)) {
      clean = clean.replaceFirst(phoneRegex, '').trim();
    }
    return 'Tel / Cel: $clean';
  }

  static String _getPresetSvg(String presetKey) {
    if (presetKey == 'shopping_cart') {
      return '<svg width="44" height="44" viewBox="0 0 44 44"><circle cx="22" cy="22" r="19" stroke="#000000" stroke-width="2" fill="none"/><path d="M13 14h3.2l2.4 10h10.8l1.8-7.2H17.2" stroke="#000000" stroke-width="2" fill="none"/><circle cx="20.5" cy="29.5" r="1.8" fill="#000000"/><circle cx="28.5" cy="29.5" r="1.8" fill="#000000"/></svg>';
    }
    return '<svg width="44" height="44" viewBox="0 0 44 44"><circle cx="22" cy="22" r="19" stroke="#000000" stroke-width="2" fill="none"/><path d="M14 17l1.5-4h13l1.5 4M13 17h18v12H13zM18 29v-6h8v6" stroke="#000000" stroke-width="2" fill="none"/></svg>';
  }

  /// Genera los bytes de documento PDF en memoria
  static Future<Uint8List> generateTicketPdf({
    required SaleTicket ticket,
    required BusinessConfig businessConfig,
    required PrinterConfig printerConfig,
  }) async {
    final pdf = pw.Document();

    final isHalfA4 = printerConfig.inkjetPaperFormat == 'half_a4_vertical';
    final isStrip80 = printerConfig.inkjetPaperFormat == 'strip_80mm';

    // Dimensiones de página
    final pageFormat = isHalfA4
        ? const PdfPageFormat(105 * PdfPageFormat.mm, 297 * PdfPageFormat.mm, marginAll: 4 * PdfPageFormat.mm)
        : isStrip80
            ? const PdfPageFormat(80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm)
            : const PdfPageFormat(210 * PdfPageFormat.mm, 297 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm);

    // Cargar imagen de logo si existe
    pw.MemoryImage? logoImage;
    if (businessConfig.logoType == 'file' && businessConfig.logoValue.trim().isNotEmpty) {
      try {
        final file = File(businessConfig.logoValue.trim());
        if (file.existsSync()) {
          logoImage = pw.MemoryImage(file.readAsBytesSync());
        }
      } catch (_) {}
    }

    final formattedRuc = _formatRuc(businessConfig.ruc);
    final formattedPhone = _formatPhone(businessConfig.phone);
    final formattedDate = _formatDateTime(ticket.date);
    final barcodeData = ticket.ticketNumber.replaceAll('-', '');
    final barcodeLabel = ticket.id.replaceAll('TKT_', '');

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Container(
            width: isHalfA4 ? 96 * PdfPageFormat.mm : (isStrip80 ? 74 * PdfPageFormat.mm : 96 * PdfPageFormat.mm),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // 1. Logo
                pw.Center(
                  child: logoImage != null
                      ? pw.Container(
                          width: 44,
                          height: 44,
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        )
                      : pw.Container(
                          width: 44,
                          height: 44,
                          child: pw.SvgImage(
                            svg: _getPresetSvg(businessConfig.logoValue),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                ),
                pw.SizedBox(height: 5),

                // 2. Nombre del Negocio y Datos Fiscales
                pw.Center(
                  child: pw.Text(
                    businessConfig.businessName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (businessConfig.showRucOnTicket && formattedRuc.isNotEmpty) ...[
                  pw.SizedBox(height: 1.5),
                  pw.Center(child: pw.Text(formattedRuc, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800))),
                ],
                if (businessConfig.showAddressOnTicket && businessConfig.address.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 1.5),
                  pw.Center(child: pw.Text(businessConfig.address.trim(), style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800))),
                ],
                if (businessConfig.showPhoneOnTicket && formattedPhone.isNotEmpty) ...[
                  pw.SizedBox(height: 1.5),
                  pw.Center(child: pw.Text(formattedPhone, style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800))),
                ],

                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'COMPROBANTE DE CAJA',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8, color: PdfColors.grey700),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    ticket.ticketNumber,
                    style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold),
                  ),
                ),

                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8, color: PdfColors.grey700),
                ),

                // 3. Metadatos
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('FECHA:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                    pw.Text(formattedDate, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.SizedBox(height: 1.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('CAJERO:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                    pw.Text(ticket.cashierName, style: const pw.TextStyle(fontSize: 9.5)),
                  ],
                ),
                pw.SizedBox(height: 1.5),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TIPO:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: pw.BoxDecoration(
                        color: ticket.isCredit ? PdfColors.orange100 : PdfColors.green100,
                        borderRadius: pw.BorderRadius.circular(3),
                        border: pw.Border.all(
                          color: ticket.isCredit ? PdfColors.orange400 : PdfColors.green400,
                          width: 0.5,
                        ),
                      ),
                      child: pw.Text(
                        ticket.isCredit ? 'VENTA AL FIADO' : 'AL CONTADO',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: ticket.isCredit ? PdfColors.orange900 : PdfColors.green900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (ticket.customerName != null && ticket.customerName!.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 1.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CLIENTE:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                      pw.Text(ticket.customerName!.trim(), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],

                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8, color: PdfColors.grey700),
                ),

                // 4. Tabla de Productos (PRODUCTO | CANT | TOTAL)
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 5,
                      child: pw.Text('PRODUCTO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('CANT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700), textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5, color: PdfColors.grey500),
                pw.SizedBox(height: 3),

                // Listado de ítems
                ...ticket.items.map((item) {
                  final qtyStr = item.unit == 'und'
                      ? 'x${item.quantity.toInt()}'
                      : '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(item.unit == 'kg' ? 3 : 2)} ${item.unit}';

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 5,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.name, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                              pw.Text('P.U. S/ ${item.unitPrice.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text(qtyStr, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text('S/ ${item.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),
                  );
                }),

                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8, color: PdfColors.grey700),
                ),

                // 5. Totales y Descuentos
                if (ticket.discount > 0) ...[
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SUBTOTAL:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                      pw.Text('S/ ${ticket.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('DESCUENTO:', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.green800)),
                      pw.Text('- S/ ${ticket.discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.5, color: PdfColors.grey500),
                  pw.SizedBox(height: 3),
                ],

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      ticket.isCredit ? 'TOTAL A FIAR:' : 'TOTAL A PAGAR:',
                      style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'S/ ${ticket.total.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 14.5, fontWeight: pw.FontWeight.bold, color: ticket.isCredit ? PdfColors.orange900 : PdfColors.black),
                    ),
                  ],
                ),

                // Desglose de Fiado
                if (ticket.isCredit && ticket.newDebt != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.orange50,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColors.orange200, width: 0.6),
                    ),
                    child: pw.Column(
                      children: [
                        if (ticket.previousDebt != null) ...[
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Saldo Anterior:', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.Text('S/ ${ticket.previousDebt!.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                            ],
                          ),
                          pw.SizedBox(height: 1),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Fiado de Hoy:', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.orange900)),
                              pw.Text('+ S/ ${ticket.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                            ],
                          ),
                          pw.SizedBox(height: 2),
                          pw.Divider(thickness: 0.4, color: PdfColors.orange300),
                        ],
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('NUEVA DEUDA:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                            pw.Text('S/ ${ticket.newDebt!.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Divider(borderStyle: pw.BorderStyle.dashed, thickness: 0.8, color: PdfColors.grey700),
                ),

                // 6. Mensaje de Despedida
                pw.Center(
                  child: pw.Text(
                    businessConfig.ticketFooterMessage.isNotEmpty ? businessConfig.ticketFooterMessage : '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.4),
                    textAlign: pw.TextAlign.center,
                  ),
                ),

                // 7. Código de Barras
                if (businessConfig.showBarcodeOnTicket) ...[
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code39(),
                      data: barcodeData,
                      width: 130,
                      height: 24,
                      drawText: false,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Center(
                    child: pw.Text(
                      '* $barcodeLabel *',
                      style: const pw.TextStyle(fontSize: 8.5, letterSpacing: 1.5, color: PdfColors.grey700),
                    ),
                  ),
                ],

                // 8. Branding EddamCore
                if (businessConfig.showEddamCoreBranding) ...[
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blueGrey50,
                        borderRadius: pw.BorderRadius.circular(3),
                        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.6),
                      ),
                      child: pw.Text(
                        '* Tecnologia impulsada por EddamCore *',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                    ),
                  ),
                ],

                // 9. Línea de corte
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text(
                    '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'CORTAR AQUI (FIN DEL COMPROBANTE)',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return await pdf.save();
  }
}
