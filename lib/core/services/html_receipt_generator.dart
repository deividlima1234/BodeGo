import 'dart:convert';
import 'dart:io';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';

/// Generador de comprobantes en HTML de alta fidelidad estética y resolución vectorial,
/// optimizado para impresión en impresoras de inyección de tinta (Epson EcoTank L7590, HP, Canon)
/// tanto en formato Media Hoja A4 vertical (105x297mm), A4 completa como tira continua de 80mm.
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

  /// Limpia y sanitiza el RUC para evitar prefijos duplicados como "RUC: RUC:"
  static String _formatRuc(String ruc) {
    final trimmed = ruc.trim();
    if (trimmed.isEmpty) return '';
    // Elimina cualquier repetición de "RUC:" o "RUC"
    String clean = trimmed;
    final rucRegex = RegExp(r'^RUC\s*[:\.\-]?\s*', caseSensitive: false);
    while (rucRegex.hasMatch(clean)) {
      clean = clean.replaceFirst(rucRegex, '').trim();
    }
    return 'RUC: $clean';
  }

  /// Limpia y sanitiza el teléfono para evitar prefijos duplicados como "Tel / Cel: Tel / Cel:"
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

  /// Genera el SVG vectorial para los iconos de presets predeterminados de BodeGo
  static String _getPresetSvg(String presetKey) {
    switch (presetKey) {
      case 'shopping_cart':
        // Minimarket / Carrito de compras idéntico al widget de la app
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M13 14.5h3.2l2.4 10a1.5 1.5 0 0 0 1.5 1.2h10.8a1.5 1.5 0 0 0 1.5-1.2l1.8-7.2H17.2" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="20.5" cy="29.5" r="1.8" fill="#1A1A1A"/>
  <circle cx="28.5" cy="29.5" r="1.8" fill="#1A1A1A"/>
</svg>''';

      case 'local_grocery':
        // Abarrotes / Canasta
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M14 20.5h16l-2 9H16l-2-9zM17 20.5l5-6 5 6M15 25h14" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

      case 'shopping_bag':
        // Bolsa de compras
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M14.5 17h15l1.5 12H13l1.5-12zM18 17v-2a4 4 0 0 1 8 0v2" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

      case 'fastfood':
        // Snacks y Bebidas
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M15 21a7 7 0 0 1 14 0H15zM14 24h16M15 27h14a2 2 0 0 1-2 2H17a2 2 0 0 1-2-2z" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

      case 'eco':
        // Frutas y Verduras / Hoja
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M15 28c5 0 13-3 13-13-6 0-13 3-13 13zM15 28c2-4 5-7 9-9" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

      case 'liquor':
        // Licores y Bebidas
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M19 14h6v3l2.5 3v9h-11v-9l2.5-3v-3zM16 25h12" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';

      case 'cake':
        // Panadería y Dulces
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M14 22h16v7H14v-7zM14 22a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0 2.7 2.7 0 0 0 5.3 0M22 15v3" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="22" cy="14" r="1" fill="#1A1A1A"/>
</svg>''';

      case 'storefront':
      default:
        // Bodega Clásica / Fachada
        return '''
<svg width="44" height="44" viewBox="0 0 44 44" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="22" cy="22" r="19.5" stroke="#1A1A1A" stroke-width="1.8" fill="#FFFFFF"/>
  <path d="M14 17l1.5-4h13l1.5 4M13 17h18v2a2.5 2.5 0 0 1-5 0 2.5 2.5 0 0 1-5 0 2.5 2.5 0 0 1-5 0 2.5 2.5 0 0 1-3 0v-2zM15 19v10h14V19M19 29v-6h6v6" stroke="#1A1A1A" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''';
    }
  }

  /// Genera el HTML del logo del negocio (imagen de archivo en Base64 o SVG de preset)
  static String _generateLogoHtml(BusinessConfig config) {
    if (config.logoType == 'file' && config.logoValue.trim().isNotEmpty) {
      try {
        final file = File(config.logoValue.trim());
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          final ext = file.path.split('.').last.toLowerCase();
          final mime = (ext == 'jpg' || ext == 'jpeg') ? 'image/jpeg' : 'image/png';
          final base64Data = base64Encode(bytes);
          return '''
            <div class="logo-wrapper">
              <img src="data:$mime;base64,$base64Data" class="logo-img" alt="Logo de Negocio" />
            </div>
          ''';
        }
      } catch (e) {
        // En caso de error leyendo el archivo, se utiliza el fallback de preset
      }
    }

    final presetSvg = _getPresetSvg(config.logoValue);
    return '''
      <div class="logo-wrapper">
        $presetSvg
      </div>
    ''';
  }

  /// Genera un código de barras 100% vectorial en SVG idéntico al widget de Flutter
  /// eliminando la necesidad de fuentes web externas que fallan en el WebView de Android.
  static String _generateBarcodeSvg() {
    const barPattern = [
      2, 1, 3, 1, 1, 2, 4, 1, 2, 3, 1, 2, 1, 4, 2, 1, 3, 1, 2, 1, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2
    ];
    final buffer = StringBuffer();
    const totalWidth = 51;
    const height = 24;

    buffer.write('<svg class="barcode-svg" viewBox="0 0 $totalWidth $height" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">');
    int x = 0;
    for (int i = 0; i < barPattern.length; i++) {
      final w = barPattern[i];
      if (i % 2 == 0) {
        buffer.write('<rect x="$x" y="0" width="$w" height="$height" fill="#111111" />');
      }
      x += w;
    }
    buffer.write('</svg>');
    return buffer.toString();
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
        ? 'size: 105mm 297mm; margin: 2.5mm;'
        : isFullA4
            ? 'size: 210mm 297mm; margin: 3.5mm;'
            : 'size: 80mm auto; margin: 2mm;';

    final containerWidthMm = isHalfA4 ? 98 : (isStrip80 ? 74 : 98);
    final formattedDate = _formatDateTime(ticket.date);

    final hasDiscount = ticket.discount > 0;
    final subtotal = ticket.subtotal;
    final discount = ticket.discount;

    final formattedRuc = _formatRuc(businessConfig.ruc);
    final formattedPhone = _formatPhone(businessConfig.phone);
    final logoHtml = _generateLogoHtml(businessConfig);
    final barcodeSvg = _generateBarcodeSvg();
    final barcodeNumber = ticket.id.replaceAll('TKT_', '');

    // Construcción de filas de productos respetando el orden del modal (PRODUCTO | CANT | TOTAL)
    final itemsRows = ticket.items.map((item) {
      final unitPrice = item.unitPrice.toStringAsFixed(2);
      final itemTotal = item.subtotal.toStringAsFixed(2);
      final qtyFormatted = item.unit == 'und'
          ? 'x${item.quantity.toInt()}'
          : '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(item.unit == 'kg' ? 3 : 2)} ${item.unit}';

      return '''
        <tr>
          <td class="col-desc">
            <div class="prod-name">${_escapeHtml(item.name)}</div>
            <div class="prod-pu">P.U. S/ $unitPrice</div>
          </td>
          <td class="col-cant">$qtyFormatted</td>
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
      color: #1a1a1a;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 11px;
      line-height: 1.25;
    }
    .ticket-container {
      width: ${containerWidthMm}mm;
      max-width: ${containerWidthMm}mm;
      margin: 0;
      padding: 6px 6px;
      background: #ffffff;
      ${isFullA4 ? 'border-right: 1.5px dashed #777777; padding-right: 10px;' : ''}
    }
    .text-center { text-align: center; }
    .text-right { text-align: right; }
    .text-left { text-align: left; }
    .bold { font-weight: bold; }
    .mono { font-family: "SF Mono", Monaco, "Roboto Mono", "Courier New", monospace; }

    /* Cabecera y Logo */
    .logo-wrapper {
      display: flex;
      justify-content: center;
      align-items: center;
      margin-bottom: 6px;
    }
    .logo-img {
      width: 44px;
      height: 44px;
      object-fit: contain;
      border-radius: 8px;
    }
    .business-name {
      font-size: 16px;
      font-weight: 800;
      letter-spacing: 0.8px;
      text-transform: uppercase;
      margin-bottom: 3px;
      color: #111111;
    }
    .business-meta {
      font-size: 10.5px;
      color: #444444;
      margin-bottom: 1.5px;
    }
    .ticket-title {
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 1px;
      color: #555555;
      margin-top: 5px;
    }
    .ticket-number {
      font-size: 13.5px;
      font-weight: 800;
      margin-bottom: 4px;
      color: #111111;
    }

    /* Divisores punteados idénticos a los del recibo térmico */
    .divider {
      border-top: 1px dashed #777777;
      margin: 6px 0;
      height: 0;
    }

    /* Metadatos */
    .meta-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 10.5px;
      margin-bottom: 2.5px;
    }
    .meta-label {
      color: #555555;
      font-weight: 500;
    }
    .badge {
      display: inline-block;
      padding: 1.5px 6px;
      border-radius: 4px;
      font-weight: 700;
      font-size: 9.5px;
      letter-spacing: 0.3px;
    }
    .badge-contado {
      background-color: #e8f5e9;
      color: #1b5e20;
      border: 1px solid #c8e6c9;
    }
    .badge-fiado {
      background-color: #fff3e0;
      color: #e65100;
      border: 1px solid #ffe0b2;
    }

    /* Tabla de ítems homologada al modal (PRODUCTO | CANT | TOTAL) */
    table.items-table {
      width: 100%;
      border-collapse: collapse;
      margin: 4px 0;
    }
    table.items-table th {
      border-bottom: 1px dashed #777777;
      padding: 3px 0;
      font-weight: 700;
      font-size: 10px;
      color: #555555;
    }
    table.items-table td {
      padding: 3.5px 0;
      vertical-align: top;
    }
    .col-desc { width: 52%; text-align: left; }
    .col-cant { width: 20%; text-align: center; }
    .col-total { width: 28%; text-align: right; }
    .prod-name {
      font-weight: 600;
      font-size: 11px;
      color: #1a1a1a;
      line-height: 1.2;
    }
    .prod-pu {
      font-size: 9.5px;
      color: #666666;
      margin-top: 1px;
    }

    /* Totales */
    .totals-area {
      margin-top: 3px;
    }
    .total-row {
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 11px;
      margin-bottom: 2px;
    }
    .grand-total {
      font-size: 13px;
      font-weight: 800;
      padding-top: 2px;
    }
    .grand-total-amount {
      font-size: 17px;
      font-weight: 900;
      color: ${ticket.isCredit ? '#e65100' : '#111111'};
    }

    /* Desglose de Fiado */
    .credit-box {
      background-color: #fff8e1;
      border: 1px solid #ffe082;
      border-radius: 6px;
      padding: 6px 8px;
      margin: 6px 0;
      font-size: 10px;
    }

    /* Código de Barras Vectorial SVG */
    .barcode-box {
      margin-top: 8px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .barcode-svg {
      width: 140px;
      height: 28px;
      display: block;
      margin: 0 auto;
    }
    .barcode-number {
      font-size: 9.5px;
      letter-spacing: 2px;
      color: #555555;
      margin-top: 3.5px;
    }

    /* Despedida y Branding */
    .footer-msg {
      font-size: 10.5px;
      font-weight: 700;
      margin-top: 5px;
      white-space: pre-line;
      color: #1a1a1a;
      letter-spacing: 0.5px;
    }
    .branding-badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      background-color: #f1f3f9;
      border: 0.8px solid #d6dbe8;
      border-radius: 4px;
      padding: 2.5px 8px;
      margin-top: 7px;
      font-size: 8.5px;
      font-weight: 600;
      color: #333333;
      letter-spacing: 0.3px;
    }
    .bolt-icon {
      color: #4353ff;
      margin-right: 4px;
      font-size: 11px;
    }

    /* Guía de corte inferior para impresión en hojas */
    .cut-guide-bottom {
      margin-top: 14px;
      padding-top: 6px;
      text-align: center;
      border-top: 1.5px dashed #000000;
    }
    .cut-scissors-text {
      font-size: 10.5px;
      font-weight: 700;
      letter-spacing: 1px;
    }
    .cut-hint {
      font-size: 9px;
      color: #555555;
      margin-top: 2px;
      font-weight: 600;
    }
  </style>
</head>
<body>
  <div class="ticket-container">
    <!-- Encabezado de Negocio con Logo e Identidad Fiscal -->
    <div class="text-center">
      $logoHtml
      <div class="business-name">${_escapeHtml(businessConfig.businessName)}</div>
      ${businessConfig.showRucOnTicket && formattedRuc.isNotEmpty ? '<div class="business-meta mono">${_escapeHtml(formattedRuc)}</div>' : ''}
      ${businessConfig.showAddressOnTicket && businessConfig.address.trim().isNotEmpty ? '<div class="business-meta mono">${_escapeHtml(businessConfig.address.trim())}</div>' : ''}
      ${businessConfig.showPhoneOnTicket && formattedPhone.isNotEmpty ? '<div class="business-meta mono">${_escapeHtml(formattedPhone)}</div>' : ''}
      <div class="ticket-title mono">COMPROBANTE DE CAJA</div>
      <div class="ticket-number mono">${_escapeHtml(ticket.ticketNumber)}</div>
    </div>

    <div class="divider"></div>

    <!-- Metadatos de la Venta -->
    <div class="meta-row mono">
      <span class="meta-label">FECHA:</span>
      <span class="bold">$formattedDate</span>
    </div>
    <div class="meta-row mono">
      <span class="meta-label">CAJERO:</span>
      <span>${_escapeHtml(ticket.cashierName)}</span>
    </div>
    <div class="meta-row mono">
      <span class="meta-label">TIPO:</span>
      <span class="badge ${ticket.isCredit ? 'badge-fiado' : 'badge-contado'}">${ticket.isCredit ? 'VENTA AL FIADO' : 'AL CONTADO'}</span>
    </div>
    ${ticket.customerName != null && ticket.customerName!.trim().isNotEmpty ? '''
    <div class="meta-row mono">
      <span class="meta-label">CLIENTE:</span>
      <span class="bold">${_escapeHtml(ticket.customerName!.trim())}</span>
    </div>
    ''' : ''}

    <div class="divider"></div>

    <!-- Tabla de Productos (PRODUCTO | CANT | TOTAL) -->
    <table class="items-table">
      <thead>
        <tr class="mono">
          <th class="col-desc">PRODUCTO</th>
          <th class="col-cant">CANT</th>
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
      <div class="total-row mono">
        <span class="meta-label">SUBTOTAL:</span>
        <span class="bold">S/ ${subtotal.toStringAsFixed(2)}</span>
      </div>
      <div class="total-row mono" style="color: #2e7d32;">
        <span class="bold">DESCUENTO:</span>
        <span class="bold">- S/ ${discount.toStringAsFixed(2)}</span>
      </div>
      <div class="divider" style="margin: 4px 0;"></div>
      ''' : ''}
      <div class="total-row grand-total">
        <span>${ticket.isCredit ? 'TOTAL A FIAR:' : 'TOTAL A PAGAR:'}</span>
        <span class="grand-total-amount mono">S/ ${ticket.total.toStringAsFixed(2)}</span>
      </div>
    </div>

    ${ticket.isCredit && ticket.previousDebt != null && ticket.newDebt != null ? '''
    <div class="credit-box mono">
      <div class="total-row">
        <span>Saldo Anterior:</span>
        <span>S/ ${ticket.previousDebt!.toStringAsFixed(2)}</span>
      </div>
      <div class="total-row" style="color: #e65100; font-weight: bold;">
        <span>Fiado de Hoy:</span>
        <span>+ S/ ${ticket.total.toStringAsFixed(2)}</span>
      </div>
      <div style="border-top: 1px dashed #d7ccc8; margin: 4px 0;"></div>
      <div class="total-row" style="color: #c62828; font-weight: bold;">
        <span>NUEVA DEUDA:</span>
        <span>S/ ${ticket.newDebt!.toStringAsFixed(2)}</span>
      </div>
    </div>
    ''' : ''}

    <div class="divider"></div>

    <!-- Despedida y Código de Barras -->
    <div class="text-center">
      <div class="footer-msg">${_escapeHtml(businessConfig.ticketFooterMessage.isNotEmpty ? businessConfig.ticketFooterMessage : '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO')}</div>

      ${businessConfig.showBarcodeOnTicket ? '''
      <div class="barcode-box">
        $barcodeSvg
        <div class="barcode-number mono">* $barcodeNumber *</div>
      </div>
      ''' : ''}

      ${businessConfig.showEddamCoreBranding ? '''
      <div class="branding-badge mono">
        <span class="bolt-icon">&#9889;</span>
        <span>Tecnolog&iacute;a impulsada por EddamCore</span>
      </div>
      ''' : ''}
    </div>

    <!-- Guía de corte inferior solicitada por el usuario -->
    <div class="cut-guide-bottom mono">
      <div class="cut-scissors-text">&#9986; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - &#9986;</div>
      <div class="cut-hint">CORTAR AQU&Iacute; (FIN DEL COMPROBANTE)</div>
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
