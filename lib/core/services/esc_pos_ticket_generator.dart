import 'dart:convert';
import 'dart:typed_data';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';

/// Generador de bytes de comandos ESC/POS puros para impresoras térmicas de tickets (58mm y 80mm)
/// compatible con Bluetooth SPP, TCP WiFi (puerto 9100) y USB OTG.
class EscPosTicketGenerator {
  // Comandos de control ESC/POS estándar
  static const List<int> _cmdInit = [0x1B, 0x40]; // ESC @ (Inicializar)
  static const List<int> _cmdAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> _cmdAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> _cmdAlignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const List<int> _cmdBoldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> _cmdBoldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> _cmdSizeNormal = [0x1D, 0x21, 0x00]; // GS ! 0
  static const List<int> _cmdSizeDoubleHeight = [0x1D, 0x21, 0x01]; // GS ! 1 (Doble alto)
  static const List<int> _cmdFeed3Lines = [0x1B, 0x64, 0x03]; // ESC d 3
  static const List<int> _cmdCutPaper = [0x1D, 0x56, 0x42, 0x00]; // GS V B 0 (Corte de papel)

  /// Sanitiza el RUC para evitar prefijos duplicados como "RUC: RUC:"
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

  /// Sanitiza el teléfono para evitar prefijos duplicados como "Tel / Cel: Tel / Cel:"
  static String _formatPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    String clean = trimmed;
    final phoneRegex = RegExp(r'^(Tel\s*/?\s*Cel|Tel|Cel)\s*[:\.\-]?\s*', caseSensitive: false);
    while (phoneRegex.hasMatch(clean)) {
      clean = clean.replaceFirst(phoneRegex, '').trim();
    }
    return 'Tel: $clean';
  }

  /// Genera los bytes ESC/POS completos listos para enviar a la ticketera
  static Uint8List generateTicketBytes({
    required SaleTicket ticket,
    required BusinessConfig businessConfig,
    int paperWidthMm = 58,
  }) {
    final List<int> bytes = [];
    final maxChars = paperWidthMm == 80 ? 48 : 32;

    void addText(String text, {bool bold = false, bool center = false, bool right = false, bool doubleHeight = false}) {
      if (center) {
        bytes.addAll(_cmdAlignCenter);
      } else if (right) {
        bytes.addAll(_cmdAlignRight);
      } else {
        bytes.addAll(_cmdAlignLeft);
      }

      if (doubleHeight) {
        bytes.addAll(_cmdSizeDoubleHeight);
      } else {
        bytes.addAll(_cmdSizeNormal);
      }

      if (bold) {
        bytes.addAll(_cmdBoldOn);
      } else {
        bytes.addAll(_cmdBoldOff);
      }

      // Convertimos caracteres con codificación Latin1 / ASCII para impresoras térmicas
      bytes.addAll(latin1.encode('$text\n'));
    }

    void addDivider() {
      bytes.addAll(_cmdAlignLeft);
      bytes.addAll(_cmdBoldOff);
      bytes.addAll(_cmdSizeNormal);
      bytes.addAll(latin1.encode('${'-' * maxChars}\n'));
    }

    void addKeyValue(String key, String value) {
      bytes.addAll(_cmdAlignLeft);
      bytes.addAll(_cmdBoldOff);
      bytes.addAll(_cmdSizeNormal);
      final space = maxChars - key.length - value.length;
      if (space > 0) {
        bytes.addAll(latin1.encode('$key${' ' * space}$value\n'));
      } else {
        bytes.addAll(latin1.encode('$key $value\n'));
      }
    }

    // 1. Inicialización
    bytes.addAll(_cmdInit);

    // 2. Encabezado de Negocio con Sanitización
    addText(businessConfig.businessName.toUpperCase(), bold: true, center: true, doubleHeight: true);

    final formattedRuc = _formatRuc(businessConfig.ruc);
    if (businessConfig.showRucOnTicket && formattedRuc.isNotEmpty) {
      addText(formattedRuc, center: true);
    }
    if (businessConfig.showAddressOnTicket && businessConfig.address.trim().isNotEmpty) {
      addText(businessConfig.address.trim(), center: true);
    }
    final formattedPhone = _formatPhone(businessConfig.phone);
    if (businessConfig.showPhoneOnTicket && formattedPhone.isNotEmpty) {
      addText(formattedPhone, center: true);
    }

    addText('COMPROBANTE DE CAJA', bold: true, center: true);
    addText(ticket.ticketNumber, bold: true, center: true);
    addDivider();

    // 3. Metadatos
    final dt = ticket.date;
    final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    addKeyValue('FECHA:', dateStr);
    addKeyValue('CAJERO:', ticket.cashierName);
    addKeyValue('TIPO:', ticket.isCredit ? 'VENTA AL FIADO' : 'AL CONTADO');
    if (ticket.customerName != null && ticket.customerName!.trim().isNotEmpty) {
      addKeyValue('CLIENTE:', ticket.customerName!.trim());
    }
    addDivider();

    // 4. Detalle de Productos homologado (PRODUCTO, CANT, TOTAL)
    if (paperWidthMm == 80) {
      addKeyValue('PRODUCTO', 'CANT    TOTAL');
    } else {
      addKeyValue('PRODUCTO', 'CANT  TOTAL');
    }
    addDivider();

    for (final item in ticket.items) {
      final qtyStr = item.unit == 'und'
          ? 'x${item.quantity.toInt()}'
          : '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(item.unit == 'kg' ? 3 : 2)} ${item.unit}';
      final totalStr = 'S/ ${item.subtotal.toStringAsFixed(2)}';
      final rightPart = '$qtyStr  $totalStr';

      if (item.name.length > (maxChars - rightPart.length - 2)) {
        addText(item.name, bold: true);
        addKeyValue('   P.U. S/ ${item.unitPrice.toStringAsFixed(2)}', rightPart);
      } else {
        addKeyValue(item.name, rightPart);
        if (item.quantity > 1 || item.unit != 'und') {
          bytes.addAll(_cmdAlignLeft);
          bytes.addAll(_cmdSizeNormal);
          bytes.addAll(latin1.encode('   P.U. S/ ${item.unitPrice.toStringAsFixed(2)}\n'));
        }
      }
    }
    addDivider();

    // 5. Totales y Descuentos
    if (ticket.discount > 0) {
      addKeyValue('SUBTOTAL:', 'S/ ${ticket.subtotal.toStringAsFixed(2)}');
      addKeyValue('DESCUENTO:', '- S/ ${ticket.discount.toStringAsFixed(2)}');
      addDivider();
    }

    // Total a pagar en doble alto y negrita
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_cmdSizeDoubleHeight);
    bytes.addAll(_cmdBoldOn);
    final totalLabel = ticket.isCredit ? 'TOTAL A FIAR:' : 'TOTAL A PAGAR:';
    final totalValue = 'S/ ${ticket.total.toStringAsFixed(2)}';
    final space = (maxChars ~/ 1.4) - totalLabel.length - totalValue.length;
    if (space > 0) {
      bytes.addAll(latin1.encode('$totalLabel${' ' * space.toInt()}$totalValue\n'));
    } else {
      bytes.addAll(latin1.encode('$totalLabel $totalValue\n'));
    }

    bytes.addAll(_cmdSizeNormal);
    bytes.addAll(_cmdBoldOff);
    addDivider();

    // Desglose de Fiado si aplica
    if (ticket.isCredit && ticket.newDebt != null) {
      if (ticket.previousDebt != null) {
        addKeyValue('Saldo Anterior:', 'S/ ${ticket.previousDebt!.toStringAsFixed(2)}');
        addKeyValue('Fiado de Hoy:', '+ S/ ${ticket.total.toStringAsFixed(2)}');
      }
      addKeyValue('NUEVA DEUDA:', 'S/ ${ticket.newDebt!.toStringAsFixed(2)}');
      addDivider();
    }

    // 6. Mensaje de Despedida
    final footer = businessConfig.ticketFooterMessage.isNotEmpty
        ? businessConfig.ticketFooterMessage
        : '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO';
    addText(footer, bold: true, center: true);

    // 7. Código de Barras ESC/POS Nativo (Code 39 estándar)
    if (businessConfig.showBarcodeOnTicket) {
      try {
        bytes.addAll(_cmdAlignCenter);
        // Altura de barras: 48 dots
        bytes.addAll([0x1D, 0x68, 48]);
        // Ancho de módulo: 2 (58mm) o 3 (80mm)
        bytes.addAll([0x1D, 0x77, paperWidthMm == 80 ? 3 : 2]);
        // Texto HRI debajo de las barras
        bytes.addAll([0x1D, 0x48, 0x02]);
        // Fuente HRI estándar
        bytes.addAll([0x1D, 0x66, 0x00]);

        // Code 39 estándar ESC/POS: GS k 69 <len> <data>
        final barcodeData = ticket.ticketNumber.replaceAll('-', '').toUpperCase();
        final codeBytes = latin1.encode(barcodeData);
        bytes.addAll([0x1D, 0x6B, 69, codeBytes.length]);
        bytes.addAll(codeBytes);
        bytes.addAll(latin1.encode('\n'));
      } catch (e) {
        // En caso de que la ticketera no soporte el comando de código de barras
      }
    }

    // 8. Marca de Identidad EddamCore
    if (businessConfig.showEddamCoreBranding) {
      addText('Tecnologia impulsada por EddamCore', center: true);
    }

    // 9. Alimentación de papel y corte
    bytes.addAll(_cmdFeed3Lines);
    bytes.addAll(_cmdCutPaper);

    return Uint8List.fromList(bytes);
  }
}
