import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';

/// Generador de comprobantes en HTML de alta definición optimizados para impresión
/// en impresoras de inyección de tinta (Epson L7590, HP, Canon) y hojas A4 o media hoja vertical.
class HtmlReceiptGenerator {
  static String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  /// Genera el código HTML completo del comprobante listo para el PrintManager de Android
  static String generateTicketHtml({
    required SaleTicket ticket,
    required BusinessConfig businessConfig,
    required PrinterConfig printerConfig,
  }) {
    final isHalfA4 = printerConfig.inkjetPaperFormat == 'half_a4_vertical';
    final isFullA4 = printerConfig.inkjetPaperFormat == 'full_a4';
    final isStrip80 = printerConfig.inkjetPaperFormat == 'strip_80mm';

    final pageSizeCss = isHalfA4
        ? 'size: 105mm 297mm; margin: 3mm;'
        : isFullA4
            ? 'size: 210mm 297mm; margin: 4mm;'
            : 'size: 80mm auto; margin: 2mm;';

    final containerWidthMm = isHalfA4 ? 98 : (isStrip80 ? 74 : 98);
    final formattedDate = _formatDateTime(ticket.date);

    final hasDiscount = ticket.discount > 0;
    final subtotal = ticket.subtotal;
    final discount = ticket.discount;

    final itemsRows = ticket.items.map((item) {
      final unitPrice = item.unitPrice.toStringAsFixed(2);
      final itemTotal = item.subtotal.toStringAsFixed(2);
      return '''
        <tr>
          <td class="col-cant">${item.quantity}</td>
          <td class="col-desc">
            <div class="prod-name">${_escapeHtml(item.name)}</div>
            <div class="prod-pu">P.U: S/ $unitPrice</div>
          </td>
          <td class="col-total">S/ $itemTotal</td>
        </tr>
      ''';
    }).join('\n');

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Ticket ${ticket.ticketNumber}</title>
  <style>
    @page {
      $pageSizeCss
    }
    * {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      margin: 0;
      padding: 0;
      background-color: #ffffff;
      color: #111111;
      font-family: 'Courier New', Courier, 'Liberation Mono', monospace;
      font-size: 12px;
      line-height: 1.25;
    }
    .ticket-container {
      width: ${containerWidthMm}mm;
      max-width: ${containerWidthMm}mm;
      margin: 0;
      padding: 6px 8px;
      background: #ffffff;
      ${isFullA4 ? 'border-right: 1.5px dashed #555555; padding-right: 12px;' : ''}
    }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .text-left { text-align: left; }
    .bold { font-weight: bold; }
    
    .business-name {
      font-size: 16px;
      font-weight: 900;
      letter-spacing: 0.5px;
      margin-bottom: 3px;
    }
    .business-meta {
      font-size: 11px;
      color: #333333;
      margin-bottom: 2px;
    }
    .ticket-title {
      font-size: 12px;
      font-weight: bold;
      letter-spacing: 1px;
      margin-top: 5px;
    }
    .ticket-number {
      font-size: 14px;
      font-weight: 900;
      margin-bottom: 4px;
    }
    .divider {
      border-top: 1px dashed #444444;
      margin: 6px 0;
      height: 0;
    }
    .meta-row {
      display: flex;
      justify-content: space-between;
      font-size: 11px;
      margin-bottom: 2px;
    }
    .badge {
      display: inline-block;
      padding: 1px 5px;
      border: 1px solid #222222;
      border-radius: 3px;
      font-weight: bold;
      font-size: 10px;
    }
    table.items-table {
      width: 100%;
      border-collapse: collapse;
      margin: 6px 0;
      font-size: 11px;
    }
    table.items-table th {
      border-bottom: 1px dashed #444444;
      padding: 3px 0;
      font-weight: bold;
      font-size: 10.5px;
    }
    table.items-table td {
      padding: 4px 0;
      vertical-align: top;
    }
    .col-cant { width: 14%; text-align: center; }
    .col-desc { width: 56%; text-align: left; padding-left: 4px; }
    .col-total { width: 30%; text-align: right; }
    .prod-name { font-weight: bold; }
    .prod-pu { font-size: 10px; color: #444444; }

    .totals-area {
      margin-top: 4px;
    }
    .total-row {
      display: flex;
      justify-content: space-between;
      font-size: 11.5px;
      margin-bottom: 2px;
    }
    .grand-total {
      font-size: 16px;
      font-weight: 900;
      border-top: 1px dashed #222222;
      padding-top: 4px;
      margin-top: 4px;
    }

    .barcode-box {
      margin-top: 8px;
      text-align: center;
    }
    .barcode-bars {
      display: inline-block;
      height: 32px;
      letter-spacing: 2px;
      font-size: 26px;
      font-family: 'Libre Barcode 39', 'Courier New', monospace;
      transform: scaleY(1.3);
    }
    .barcode-number {
      font-size: 10px;
      letter-spacing: 2px;
    }
    .footer-msg {
      font-size: 11px;
      font-weight: bold;
      margin-top: 6px;
      white-space: pre-line;
    }
    .branding {
      font-size: 9.5px;
      color: #555555;
      margin-top: 6px;
      padding-top: 4px;
      border-top: 0.5px dotted #999999;
    }

    /* Línea de corte punteada solicitada por el usuario */
    .cut-guide-bottom {
      margin-top: 16px;
      padding-top: 6px;
      text-align: center;
      border-top: 1.5px dashed #000000;
    }
    .cut-scissors-text {
      font-size: 11px;
      font-weight: bold;
      letter-spacing: 1px;
    }
    .cut-guide-vertical-hint {
      position: absolute;
      top: 10mm;
      left: 102mm;
      font-size: 10px;
      color: #666;
      writing-mode: vertical-rl;
    }
  </style>
</head>
<body>
  <div class="ticket-container">
    <!-- Encabezado de Negocio -->
    <div class="text-center">
      <div class="business-name">${_escapeHtml(businessConfig.businessName)}</div>
      ${businessConfig.showRucOnTicket && businessConfig.ruc.trim().isNotEmpty ? '<div class="business-meta">RUC: ${_escapeHtml(businessConfig.ruc.trim())}</div>' : ''}
      ${businessConfig.showAddressOnTicket && businessConfig.address.trim().isNotEmpty ? '<div class="business-meta">${_escapeHtml(businessConfig.address.trim())}</div>' : ''}
      ${businessConfig.showPhoneOnTicket && businessConfig.phone.trim().isNotEmpty ? '<div class="business-meta">Tel / Cel: ${_escapeHtml(businessConfig.phone.trim())}</div>' : ''}
      <div class="ticket-title">COMPROBANTE DE CAJA</div>
      <div class="ticket-number">${_escapeHtml(ticket.ticketNumber)}</div>
    </div>

    <div class="divider"></div>

    <!-- Metadatos de la Venta -->
    <div class="meta-row">
      <span>FECHA:</span>
      <span class="bold">$formattedDate</span>
    </div>
    <div class="meta-row">
      <span>CAJERO:</span>
      <span>${_escapeHtml(ticket.cashierName)}</span>
    </div>
    <div class="meta-row">
      <span>TIPO:</span>
      <span class="badge">${ticket.isCredit ? 'VENTA AL FIADO' : 'AL CONTADO'}</span>
    </div>
    ${ticket.customerName != null && ticket.customerName!.trim().isNotEmpty ? '''
    <div class="meta-row">
      <span>CLIENTE:</span>
      <span class="bold">${_escapeHtml(ticket.customerName!.trim())}</span>
    </div>
    ''' : ''}

    <div class="divider"></div>

    <!-- Tabla de Productos -->
    <table class="items-table">
      <thead>
        <tr>
          <th class="col-cant">CANT</th>
          <th class="col-desc">PRODUCTO</th>
          <th class="col-total">TOTAL</th>
        </tr>
      </thead>
      <tbody>
        $itemsRows
      </tbody>
    </table>

    <div class="divider"></div>

    <!-- Totales y Descuentos -->
    <div class="totals-area">
      ${hasDiscount ? '''
      <div class="total-row">
        <span>SUBTOTAL:</span>
        <span>S/ ${subtotal.toStringAsFixed(2)}</span>
      </div>
      <div class="total-row bold" style="color: #000;">
        <span>DESCUENTO:</span>
        <span>- S/ ${discount.toStringAsFixed(2)}</span>
      </div>
      ''' : ''}
      <div class="total-row grand-total">
        <span>TOTAL A PAGAR:</span>
        <span>S/ ${ticket.total.toStringAsFixed(2)}</span>
      </div>
    </div>

    <div class="divider"></div>

    <!-- Despedida y Código de Barras -->
    <div class="text-center">
      <div class="footer-msg">${_escapeHtml(businessConfig.ticketFooterMessage.isNotEmpty ? businessConfig.ticketFooterMessage : '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO')}</div>

      ${businessConfig.showBarcodeOnTicket ? '''
      <div class="barcode-box">
        <div style="font-family: monospace; font-size: 18px; letter-spacing: 2px;">|| | |||| | ||| || ||| |</div>
        <div class="barcode-number">* ${ticket.ticketNumber.replaceAll('-', '')} *</div>
      </div>
      ''' : ''}

      ${businessConfig.showEddamCoreBranding ? '''
      <div class="branding">⚡ Tecnología impulsada por EddamCore</div>
      ''' : ''}
    </div>

    <!-- Guía de corte inferior solicitada por el usuario -->
    <div class="cut-guide-bottom">
      <div class="cut-scissors-text">✂ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ✂</div>
      <div style="font-size: 9.5px; color: #444; margin-top: 2px;">CORTAR AQUÍ (FIN DEL COMPROBANTE)</div>
    </div>
  </div>
</body>
</html>
''';
  }

  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
