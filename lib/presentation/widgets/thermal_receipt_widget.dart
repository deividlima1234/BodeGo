import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';

/// Clipper personalizado para generar los bordes dentados (dientes de sierra / zigzag)
/// característicos del corte de papel en impresoras térmicas de tickets.
class ZigZagClipper extends CustomClipper<Path> {
  final double toothHeight;

  const ZigZagClipper({this.toothHeight = 7.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    // Calculamos el número de dientes para que encajen exactamente en el ancho
    final int toothCount = (size.width / 14.0).round().clamp(8, 80);
    final double toothWidth = size.width / toothCount;

    // 1. Borde superior dentado (de izquierda a derecha)
    path.moveTo(0, toothHeight);
    for (int i = 0; i < toothCount; i++) {
      final double xStart = i * toothWidth;
      path.lineTo(xStart + toothWidth / 2, 0);
      path.lineTo(xStart + toothWidth, toothHeight);
    }

    // 2. Lado derecho hacia abajo
    path.lineTo(size.width, size.height - toothHeight);

    // 3. Borde inferior dentado (de derecha a izquierda)
    for (int i = toothCount; i > 0; i--) {
      final double xStart = i * toothWidth;
      path.lineTo(xStart - toothWidth / 2, size.height);
      path.lineTo(xStart - toothWidth, size.height - toothHeight);
    }

    // 4. Lado izquierdo hacia arriba
    path.lineTo(0, toothHeight);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant ZigZagClipper oldClipper) =>
      oldClipper.toothHeight != toothHeight;
}

/// Línea separadora punteada estilo recibo de ticket.
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    this.height = 1,
    this.color = const Color(0xFF9E9E9E),
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return SizedBox(
          width: boxWidth,
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: color),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Widget visual que renderiza un comprobante de pago con formato físico de ticket térmico,
/// con soporte dinámico de logo de negocio, identidad fiscal, mensaje de despedida
/// y marca de agua oficial "Tecnología impulsada por EddamCore".
class ThermalReceiptWidget extends StatelessWidget {
  final SaleTicket ticket;
  final BusinessConfig? customConfig;

  const ThermalReceiptWidget({
    super.key,
    required this.ticket,
    this.customConfig,
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
    if (customConfig != null) {
      return _buildTicketCard(context, customConfig!);
    }

    final repo = BusinessConfigRepository();
    return ValueListenableBuilder<BusinessConfig?>(
      valueListenable: repo.configNotifier,
      builder: (context, liveConfig, _) {
        if (liveConfig != null) {
          return _buildTicketCard(context, liveConfig);
        }

        return FutureBuilder<BusinessConfig>(
          future: repo.getConfig(),
          builder: (context, snapshot) {
            final config = snapshot.data ??
                BusinessConfig(businessName: ticket.businessName);
            return _buildTicketCard(context, config);
          },
        );
      },
    );
  }

  Widget _buildTicketCard(BuildContext context, BusinessConfig config) {
    const Color ticketBg = Colors.white;
    const Color textColor = Color(0xFF1A1A1A);
    const Color mutedTextColor = Color(0xFF616161);

    // Ajuste de ancho de papel: 58mm o 80mm
    final double maxPaperWidth = config.paperWidthMm == 80 ? 380.0 : 320.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxPaperWidth),
        child: ClipPath(
          clipper: const ZigZagClipper(toothHeight: 7.0),
          child: Container(
            width: double.infinity,
            color: ticketBg,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ==========================================
                // CABECERA: LOGO DEL NEGOCIO Y DATOS FISCALES
                // ==========================================
                Center(
                  child: Column(
                    children: [
                      // Render del Logo (Preset térmico o imagen)
                      _buildLogoWidget(config),
                      const SizedBox(height: 8),

                      // Nombre de la Bodega
                      Text(
                        (config.businessName.isNotEmpty
                                ? config.businessName
                                : ticket.businessName)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // RUC
                      if (config.showRucOnTicket && config.ruc.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          config.ruc.trim().toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      // Dirección física
                      if (config.showAddressOnTicket && config.address.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          config.address.trim(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: mutedTextColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Teléfono / WhatsApp
                      if (config.showPhoneOnTicket && config.phone.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          config.phone.trim(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: mutedTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 6),
                      const Text(
                        'COMPROBANTE DE CAJA',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.0,
                          color: mutedTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticket.ticketNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                const DashedDivider(),
                const SizedBox(height: 8),

                // ==========================================
                // METADATOS: FECHA, CAJERO, TIPO Y CLIENTE
                // ==========================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('FECHA:',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: mutedTextColor)),
                    Text(_formatDateTime(ticket.date),
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textColor)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('CAJERO:',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: mutedTextColor)),
                    Text(ticket.cashierName,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: textColor)),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TIPO:',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: mutedTextColor)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: ticket.isCredit
                            ? Colors.orange.withOpacity(0.18)
                            : Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ticket.isCredit ? 'VENTA AL FIADO' : 'AL CONTADO',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ticket.isCredit
                              ? Colors.orange[900]
                              : Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
                if (ticket.customerName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('CLIENTE:',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: mutedTextColor)),
                      Expanded(
                        child: Text(
                          ticket.customerName!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),
                const DashedDivider(),
                const SizedBox(height: 6),

                // ==========================================
                // CABECERA DE ÍTEMS
                // ==========================================
                const Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text('PRODUCTO',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: mutedTextColor)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('CANT',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: mutedTextColor),
                          textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('TOTAL',
                          style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: mutedTextColor),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const DashedDivider(),
                const SizedBox(height: 6),

                // ==========================================
                // LISTADO DE PRODUCTOS
                // ==========================================
                ...ticket.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'P.U. S/ ${item.unitPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: mutedTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.unit == 'und'
                                ? 'x${item.quantity.toInt()}'
                                : '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(item.unit == 'kg' ? 3 : 2)} ${item.unit}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'S/ ${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 8),
                const DashedDivider(),
                const SizedBox(height: 8),

                // ==========================================
                // SUBTOTAL Y DESCUENTO (SI APLICA)
                // ==========================================
                if (ticket.discount > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SUBTOTAL:',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: mutedTextColor,
                        ),
                      ),
                      Text(
                        'S/ ${ticket.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DESCUENTO:',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      Text(
                        '- S/ ${ticket.discount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const DashedDivider(),
                  const SizedBox(height: 6),
                ],

                // ==========================================
                // TOTAL GENERAL
                // ==========================================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ticket.isCredit ? 'TOTAL A FIAR:' : 'TOTAL A PAGAR:',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'S/ ${ticket.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ticket.isCredit ? Colors.orange[900] : textColor,
                      ),
                    ),
                  ],
                ),

                // Desglose de saldo si fue Fiado
                if (ticket.isCredit &&
                    ticket.previousDebt != null &&
                    ticket.newDebt != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Saldo Anterior:',
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: mutedTextColor)),
                            Text('S/ ${ticket.previousDebt!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: textColor)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Fiado de Hoy:',
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: mutedTextColor)),
                            Text('+ S/ ${ticket.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: Colors.orange[900],
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('NUEVA DEUDA:',
                                style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent)),
                            Text('S/ ${ticket.newDebt!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const DashedDivider(),
                const SizedBox(height: 12),

                // ==========================================
                // PIE DE TICKET: MENSAJE, CÓDIGO Y MARCA EDDAMCORE
                // ==========================================
                Center(
                  child: Column(
                    children: [
                      // Mensaje de Agradecimiento Personalizado
                      if (config.ticketFooterMessage.trim().isNotEmpty) ...[
                        Text(
                          config.ticketFooterMessage.trim(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Código de Barras decorativo
                      if (config.showBarcodeOnTicket) ...[
                        _buildBarcodeGraphic(),
                        const SizedBox(height: 4),
                        Text(
                          '* ${ticket.id.replaceAll('TKT_', '')} *',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            letterSpacing: 2.0,
                            color: mutedTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Marca de Agua e Identidad Tecnológica EddamCore
                      if (config.showEddamCoreBranding) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F3F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: const Color(0xFFD6DBE8), width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded,
                                  size: 13, color: Color(0xFF4353FF)),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renderizador de logo de alta fidelidad térmica
  Widget _buildLogoWidget(BusinessConfig config) {
    if (config.logoType == 'file' && config.logoValue.isNotEmpty) {
      final file = File(config.logoValue);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _buildFallbackPresetIcon('storefront'),
          ),
        );
      }
    }

    return _buildFallbackPresetIcon(config.logoValue);
  }

  Widget _buildFallbackPresetIcon(String presetKey) {
    final entry = BusinessConfig.presets[presetKey] ??
        BusinessConfig.presets['storefront']!;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1A1A1A), width: 1.8),
      ),
      child: Center(
        child: Icon(
          entry.icon,
          size: 24,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  /// Gráfico decorativo de simulación de código de barras
  Widget _buildBarcodeGraphic() {
    const double barHeight = 24.0;
    final barPattern = [
      2, 1, 3, 1, 1, 2, 4, 1, 2, 3, 1, 2, 1, 4, 2, 1, 3, 1, 2, 1, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2
    ];

    return SizedBox(
      height: barHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: barPattern.asMap().entries.map((entry) {
          final isBlack = entry.key % 2 == 0;
          final width = entry.value.toDouble();
          return Container(
            width: width,
            height: barHeight,
            color: isBlack ? Colors.black87 : Colors.white,
          );
        }).toList(),
      ),
    );
  }
}
