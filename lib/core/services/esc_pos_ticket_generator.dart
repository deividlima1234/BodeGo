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

    // 2. Encabezado de Negocio
    addText(businessConfig.businessName.toUpperCase(), bold: true, center: true, doubleHeight: true);

    if (businessConfig.showRucOnTicket && businessConfig.ruc.trim().isNotEmpty) {
      addText('RUC: ${businessConfig.ruc.trim()}', center: true);
    }
    if (businessConfig.showAddressOnTicket && businessConfig.address.trim().isNotEmpty) {
      addText(businessConfig.address.trim(), center: true);
    }
    if (businessConfig.showPhoneOnTicket && businessConfig.phone.trim().isNotEmpty) {
      addText('Tel: ${businessConfig.phone.trim()}', center: true);
    }

    addText('COMPROBANTE DE CAJA', bold: true, center: true);
    addText(ticket.ticketNumber, bold: true, center: true);
    addDivider();

    // 3. Metadatos
    final dt = ticket.date;
    final dateStr = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    addKeyValue('FECHA:', dateStr);
    addKeyValue('CAJERO:', ticket.cashierName);
    addKeyValue('TIPO:', ticket.isCredit ? 'VENTA AL FIADO' : 'AL CONTADO');
    if (ticket.customerName != null && ticket.customerName!.trim().isNotEmpty) {
      addKeyValue('CLIENTE:', ticket.customerName!.trim());
    }
    addDivider();

    // 4. Detalle de Productos
    if (paperWidthMm == 80) {
      addKeyValue('CANT  PRODUCTO', 'P.U.    TOTAL');
    } else {
      addKeyValue('CANT  PRODUCTO', 'TOTAL');
    }
    addDivider();

    for (final item in ticket.items) {
      final name = item.name.length > (maxChars - 14) ? item.name.substring(0, maxChars - 14) : item.name;
      final line1Left = '${item.quantity}x $name';
      final line1Right = 'S/ ${item.subtotal.toStringAsFixed(2)}';
      addKeyValue(line1Left, line1Right);

      // Sublínea de precio unitario si hay espacio o es 58mm
      if (item.quantity > 1) {
        bytes.addAll(_cmdAlignLeft);
        bytes.addAll(_cmdSizeNormal);
        bytes.addAll(latin1.encode('   (P.U. S/ ${item.unitPrice.toStringAsFixed(2)})\n'));
      }
    }
    addDivider();

    // 5. Totales y Descuentos
    if (ticket.discount > 0) {
      addKeyValue('SUBTOTAL:', 'S/ ${ticket.subtotal.toStringAsFixed(2)}');
      addKeyValue('DESCUENTO:', '- S/ ${ticket.discount.toStringAsFixed(2)}');
    }

    // Total a pagar en doble alto y negrita
    bytes.addAll(_cmdAlignLeft);
    bytes.addAll(_cmdSizeDoubleHeight);
    bytes.addAll(_cmdBoldOn);
    final totalLabel = 'TOTAL:';
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

    // 6. Mensaje de Despedida y Branding
    final footer = businessConfig.ticketFooterMessage.isNotEmpty
        ? businessConfig.ticketFooterMessage
        : '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO';
    addText(footer, bold: true, center: true);

    if (businessConfig.showEddamCoreBranding) {
      addText('Tecnologia impulsada por EddamCore', center: true);
    }

    // 7. Alimentación de papel y corte
    bytes.addAll(_cmdFeed3Lines);
    bytes.addAll(_cmdCutPaper);

    return Uint8List.fromList(bytes);
  }
}
