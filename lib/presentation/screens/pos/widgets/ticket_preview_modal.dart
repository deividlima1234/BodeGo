import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/presentation/widgets/thermal_receipt_widget.dart';
import 'package:bodego/presentation/screens/pos/widgets/thermal_print_progress_modal.dart';

/// Modal interactivo que muestra el comprobante físico con bordes dentados
/// tras realizar una venta o desde el historial, con opciones de Imprimir y Compartir.
class TicketPreviewModal extends StatelessWidget {
  final SaleTicket ticket;
  final BusinessConfig? customConfig;

  const TicketPreviewModal({
    super.key,
    required this.ticket,
    this.customConfig,
  });

  /// Muestra el modal del ticket en pantalla completa o flotante centrado.
  static Future<void> show(
    BuildContext context,
    SaleTicket ticket, {
    BusinessConfig? customConfig,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TicketPreviewModal(
        ticket: ticket,
        customConfig: customConfig,
      ),
    );
  }

  void _handlePrint(BuildContext context) {
    ThermalPrintProgressModal.show(context, ticket: ticket);
  }

  void _handleCopyShare(BuildContext context) {
    HapticFeedback.lightImpact();
    final buffer = StringBuffer();
    buffer.writeln('🧾 *${ticket.businessName.toUpperCase()}*');
    buffer.writeln('Ticket: ${ticket.ticketNumber}');
    buffer.writeln('Fecha: ${ticket.date.day}/${ticket.date.month}/${ticket.date.year}');
    buffer.writeln('Tipo: ${ticket.isCredit ? "VENTA AL FIADO" : "VENTA AL CONTADO"}');
    if (ticket.customerName != null) {
      buffer.writeln('Cliente: ${ticket.customerName}');
    }
    buffer.writeln('--------------------------------');
    for (final item in ticket.items) {
      buffer.writeln('${item.formattedQuantity} x ${item.name} - S/ ${item.subtotal.toStringAsFixed(2)}');
    }
    buffer.writeln('--------------------------------');
    if (ticket.discount > 0) {
      buffer.writeln('Subtotal: S/ ${ticket.subtotal.toStringAsFixed(2)}');
      buffer.writeln('Descuento: - S/ ${ticket.discount.toStringAsFixed(2)}');
      buffer.writeln('--------------------------------');
    }
    buffer.writeln('*TOTAL: S/ ${ticket.total.toStringAsFixed(2)}*');
    if (ticket.isCredit && ticket.newDebt != null) {
      buffer.writeln('Nuevo Saldo Deudor: S/ ${ticket.newDebt!.toStringAsFixed(2)}');
    }
    buffer.writeln('');
    buffer.writeln('¡Gracias por su preferencia!');
    buffer.writeln('⚡ Tecnología impulsada por EddamCore');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen del ticket copiado al portapapeles para WhatsApp'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = ticket.isCredit;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera superior flotante con título y botón cerrar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCredit ? Icons.handshake_rounded : Icons.receipt_long_rounded,
                        color: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCredit ? 'Ticket de Fiado' : 'Ticket de Venta',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Contenedor scrollable que sostiene el ticket de papel
            Flexible(
              child: Container(
                color: Colors.black.withOpacity(0.08),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ThermalReceiptWidget(
                      ticket: ticket,
                      customConfig: customConfig,
                    ),
                  ),
                ),
              ),
            ),

            // Barra inferior con los botones "Imprimir", "Compartir" y "Guardar / Listo"
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Botón Imprimir
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handlePrint(context),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Imprimir'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Botón Compartir / WhatsApp
                  IconButton.filledTonal(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    tooltip: 'Copiar texto para WhatsApp',
                    onPressed: () => _handleCopyShare(context),
                  ),
                  const SizedBox(width: 8),

                  // Botón Guardar / Listo
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('Listo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCredit ? Colors.orange[800] : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

