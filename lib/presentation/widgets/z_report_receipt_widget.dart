import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/repositories/report_repository.dart';
import 'package:bodego/presentation/screens/auth/pin_login_screen.dart';
import 'package:bodego/presentation/widgets/thermal_receipt_widget.dart';

/// Widget de Comprobante Oficial de Cierre de Turno y Arqueo de Caja (Ticket Z)
/// con bordes dentados térmicos realistas.
class ZReportReceiptWidget extends StatelessWidget {
  final ZReportTicket zReport;

  const ZReportReceiptWidget({
    super.key,
    required this.zReport,
  });

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    const Color ticketBg = Colors.white;
    const Color textColor = Color(0xFF1A1A1A);
    const Color mutedTextColor = Color(0xFF616161);
    final double diff = zReport.difference;
    final bool isBalanced = diff.abs() < 0.01;

    return ClipPath(
      clipper: const ZigZagClipper(toothHeight: 7.0),
      child: Container(
        width: double.infinity,
        color: ticketBg,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera Oficial
            Center(
              child: Column(
                children: [
                  Text(
                    zReport.businessName.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CIERRE DE TURNO / TICKET Z',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const DashedDivider(),
            const SizedBox(height: 8),

            // Metadatos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('EMISIÓN:', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: mutedTextColor)),
                Text(_formatDateTime(zReport.closureDate), style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('RESPONSABLE:', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: mutedTextColor)),
                Text(zReport.cashierName, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),

            const SizedBox(height: 10),
            const DashedDivider(),
            const SizedBox(height: 8),

            // Sección 1: Desglose de Ventas
            const Center(
              child: Text(
                '--- RESUMEN DE VENTAS ---',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: mutedTextColor),
              ),
            ),
            const SizedBox(height: 6),
            _buildRow('Ventas en Efectivo:', 'S/ ${zReport.cashSales.toStringAsFixed(2)}'),
            const SizedBox(height: 2),
            _buildRow('Ventas al Fiado:', 'S/ ${zReport.creditSales.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _buildRow(
              'TOTAL VENDIDO:',
              'S/ ${zReport.totalSales.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 13,
            ),
            const SizedBox(height: 4),
            _buildRow('Comprobantes emitidos:', '${zReport.transactionCount} tickets'),
            const SizedBox(height: 2),
            _buildRow('Productos despachados:', '${zReport.itemsSoldCount % 1 == 0 ? zReport.itemsSoldCount.toInt() : zReport.itemsSoldCount.toStringAsFixed(2)} ítems'),

            const SizedBox(height: 10),
            const DashedDivider(),
            const SizedBox(height: 8),

            // Sección 2: Arqueo de Dinero en Gaveta
            const Center(
              child: Text(
                '--- ARQUEO DE EFECTIVO ---',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold, color: mutedTextColor),
              ),
            ),
            const SizedBox(height: 6),
            _buildRow('Fondo Inicial de Apertura:', 'S/ ${zReport.initialCash.toStringAsFixed(2)}'),
            const SizedBox(height: 2),
            _buildRow('(+) Ingresos Efectivo:', '+ S/ ${zReport.cashSales.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            _buildRow(
              'TOTAL ESPERADO:',
              'S/ ${zReport.expectedCash.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 13,
            ),
            const SizedBox(height: 2),
            _buildRow(
              'DINERO FÍSICO CONTADO:',
              'S/ ${zReport.countedCash.toStringAsFixed(2)}',
              isBold: true,
              fontSize: 13,
            ),

            const SizedBox(height: 10),

            // Sección 3: Resultado de Cuadre
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isBalanced
                    ? Colors.green.withOpacity(0.12)
                    : diff > 0
                        ? Colors.blue.withOpacity(0.12)
                        : Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isBalanced
                      ? Colors.green
                      : diff > 0
                          ? Colors.blue
                          : Colors.red,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isBalanced
                        ? 'RESULTADO: CUADRE EXACTO'
                        : diff > 0
                            ? 'RESULTADO: SOBRANTE'
                            : 'RESULTADO: FALTANTE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isBalanced
                          ? Colors.green[900]
                          : diff > 0
                              ? Colors.blue[900]
                              : Colors.red[900],
                    ),
                  ),
                  Text(
                    'S/ ${diff.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isBalanced
                          ? Colors.green[900]
                          : diff > 0
                              ? Colors.blue[900]
                              : Colors.red[900],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const DashedDivider(),
            const SizedBox(height: 20),

            // Línea de firma del cajero
            Center(
              child: Column(
                children: [
                  Container(
                    width: 180,
                    height: 1,
                    color: Colors.black45,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Firma: ${zReport.cashierName}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const DashedDivider(),
            const SizedBox(height: 10),

            // Pie y código de barras decorativo
            Center(
              child: Column(
                children: [
                  const Text(
                    'FIN DE TURNO - BODEGO POS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildBarcodeGraphic(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFD6DBE8), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF4353FF)),
                        SizedBox(width: 4),
                        Text(
                          'Tecnología impulsada por EddamCore',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
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

  Widget _buildRow(String label, String value, {bool isBold = false, double fontSize = 11}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            color: isBold ? Colors.black : const Color(0xFF616161),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            color: Colors.black,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBarcodeGraphic() {
    const double barHeight = 22.0;
    final barPattern = [
      3, 1, 2, 1, 4, 1, 2, 2, 1, 3, 1, 4, 2, 1, 3, 1, 2, 1, 4, 1, 3, 2, 1, 4
    ];

    return SizedBox(
      height: barHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: barPattern.asMap().entries.map((entry) {
          final isBlack = entry.key % 2 == 0;
          return Container(
            width: entry.value.toDouble(),
            height: barHeight,
            color: isBlack ? Colors.black87 : Colors.white,
          );
        }).toList(),
      ),
    );
  }
}

/// Diálogo modal interactivo para visualizar, imprimir y confirmar el Cierre de Turno Z.
class ZReportModal extends StatelessWidget {
  final ZReportTicket zReport;

  const ZReportModal({super.key, required this.zReport});

  static Future<void> show(BuildContext context, ZReportTicket zReport) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ZReportModal(zReport: zReport),
    );
  }

  void _handlePrint(BuildContext context) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.print_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Imprimiendo Ticket Z de Cierre de Caja...'),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleShare(BuildContext context) {
    HapticFeedback.lightImpact();
    final buffer = StringBuffer();
    buffer.writeln('📊 *CIERRE DE CAJA (TICKET Z) - ${zReport.businessName.toUpperCase()}*');
    buffer.writeln('Fecha: ${zReport.closureDate.day}/${zReport.closureDate.month}/${zReport.closureDate.year}');
    buffer.writeln('Cajero: ${zReport.cashierName}');
    buffer.writeln('--------------------------------');
    buffer.writeln('Fondo Inicial: S/ ${zReport.initialCash.toStringAsFixed(2)}');
    buffer.writeln('Ventas Efectivo: S/ ${zReport.cashSales.toStringAsFixed(2)}');
    buffer.writeln('Ventas Fiado: S/ ${zReport.creditSales.toStringAsFixed(2)}');
    buffer.writeln('*Total Vendido: S/ ${zReport.totalSales.toStringAsFixed(2)}*');
    buffer.writeln('--------------------------------');
    buffer.writeln('Esperado en Gaveta: S/ ${zReport.expectedCash.toStringAsFixed(2)}');
    buffer.writeln('Físico Contado: S/ ${zReport.countedCash.toStringAsFixed(2)}');
    final diff = zReport.difference;
    if (diff.abs() < 0.01) {
      buffer.writeln('Cuadre: ¡EXACTO!');
    } else if (diff > 0) {
      buffer.writeln('Cuadre: SOBRANTE S/ ${diff.toStringAsFixed(2)}');
    } else {
      buffer.writeln('Cuadre: FALTANTE S/ ${diff.abs().toStringAsFixed(2)}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen del Cierre Z copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera superior
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.assignment_turned_in_rounded, color: Colors.blueAccent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Comprobante de Cierre Z',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),

            // Ticket Z físico en contenedor scrolleable
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
                    child: ZReportReceiptWidget(zReport: zReport),
                  ),
                ),
              ),
            ),

            // Acciones inferiores
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handlePrint(context),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Imprimir Z'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    tooltip: 'Copiar resumen',
                    onPressed: () => _handleShare(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const PinLoginScreen()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.lock_rounded, size: 18),
                      label: const Text('Bloquear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
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

