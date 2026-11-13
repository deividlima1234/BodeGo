import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/repositories/printer_repository.dart';

/// Modal profesional interactivo con animación de radar de escaneo
/// para descubrir, conectar y probar impresoras térmicas (Bluetooth, WiFi y USB).
class PrinterScannerModal extends StatefulWidget {
  const PrinterScannerModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PrinterScannerModal(),
    );
  }

  @override
  State<PrinterScannerModal> createState() => _PrinterScannerModalState();
}

class _PrinterScannerModalState extends State<PrinterScannerModal>
    with SingleTickerProviderStateMixin {
  final PrinterRepository _printerRepo = PrinterRepository();

  late final AnimationController _pulseController;
  String _selectedConnectionType = 'bluetooth'; // 'bluetooth', 'wifi', 'usb'
  bool _isScanning = true;
  String? _connectingId;
  String? _connectedId;

  List<DiscoveredPrinter> _discoveredPrinters = [];
  PrinterConfig? _currentConfig;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _loadCurrentAndScan();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAndScan() async {
    final config = await _printerRepo.getConfig();
    if (mounted) {
      setState(() {
        _currentConfig = config;
        _selectedConnectionType = config.connectionType;
      });
      _startScan();
    }
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredPrinters = [];
      _connectingId = null;
    });

    final results = await _printerRepo.scanPrinters(
      connectionType: _selectedConnectionType,
    );

    if (mounted) {
      setState(() {
        _discoveredPrinters = results;
        _isScanning = false;
        // Si la impresora guardada coincide con alguna descubierta, marcarla como conectada
        if (_currentConfig != null && _currentConfig!.isConnected) {
          final match = results.where((p) => p.address == _currentConfig!.deviceAddress).firstOrNull;
          if (match != null) {
            _connectedId = match.id;
          }
        }
      });
    }
  }

  Future<void> _handleConnect(DiscoveredPrinter printer) async {
    HapticFeedback.lightImpact();
    setState(() {
      _connectingId = printer.id;
    });

    // Simulamos el handshake de sincronización térmica
    await Future.delayed(const Duration(milliseconds: 1400));
    final updated = await _printerRepo.connectPrinter(printer);

    if (mounted) {
      HapticFeedback.mediumImpact();
      setState(() {
        _connectingId = null;
        _connectedId = printer.id;
        _currentConfig = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡${printer.name} conectada con éxito!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleTestPrint() async {
    if (_currentConfig == null) return;
    HapticFeedback.heavyImpact();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 20),
            Text(
              'Enviando comando de calibración ESC/POS...',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    await _printerRepo.printTestTicket(_currentConfig!);

    if (mounted) {
      Navigator.pop(context); // Cierra diálogo de espera
      _showTestPrintSuccessModal();
    }
  }

  void _showTestPrintSuccessModal() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.print_rounded, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('Ticket de Prueba Emitido', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9FB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  '*** TEST DE IMPRESIÓN BODEGO ***',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dispositivo: ${_currentConfig?.deviceName ?? "Térmica"}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
              Text(
                'Ancho Cabezal: ${_currentConfig?.paperWidthMm ?? 58} mm',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
              Text(
                'Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '¡CABEZAL TÉRMICO OPERANDO 100%!',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  '⚡ Impulsado por EddamCore POS Engine',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 8.5, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tirador superior de arrastre
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cabecera del Asistente
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.print_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Asistente de Impresora',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Vincula tu ticketera térmica en segundos',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Selector de Conexión: Bluetooth, WiFi, USB
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _buildMediaTypePill(
                  label: 'Bluetooth',
                  icon: Icons.bluetooth_rounded,
                  type: 'bluetooth',
                ),
                const SizedBox(width: 8),
                _buildMediaTypePill(
                  label: 'Red WiFi',
                  icon: Icons.wifi_rounded,
                  type: 'wifi',
                ),
                const SizedBox(width: 8),
                _buildMediaTypePill(
                  label: 'USB OTG',
                  icon: Icons.usb_rounded,
                  type: 'usb',
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),

          // Cuerpo interactivo: Radar animado o Lista de Resultados
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              children: [
                // ==========================================
                // RADAR DE ESCANEO ANIMADO
                // ==========================================
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ondas concéntricas animadas
                      CustomPaint(
                        size: const Size(160, 160),
                        painter: _RadarPulsePainter(
                          animation: _pulseController,
                          color: theme.colorScheme.primary,
                          isScanning: _isScanning,
                        ),
                      ),
                      // Ícono central pulsante
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconForType(_selectedConnectionType),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Mensaje de estado del escáner
                Center(
                  child: Column(
                    children: [
                      Text(
                        _isScanning
                            ? 'Buscando impresoras $_selectedConnectionType...'
                            : '${_discoveredPrinters.length} impresoras encontradas en el área',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isScanning
                            ? 'Asegúrate de que la impresora esté encendida'
                            : 'Selecciona tu equipo para vincular y calibrar',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Botón volver a escanear si no está escaneando
                if (!_isScanning) ...[
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _startScan,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Volver a Escanear', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ==========================================
                // LISTADO DE IMPRESORAS DESCUBIERTAS
                // ==========================================
                ..._discoveredPrinters.map((printer) {
                  final bool isConnecting = _connectingId == printer.id;
                  final bool isConnected = _connectedId == printer.id ||
                      (_currentConfig != null &&
                          _currentConfig!.isConnected &&
                          _currentConfig!.deviceAddress == printer.address);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isConnected
                            ? Colors.green.withOpacity(0.6)
                            : Colors.grey.withOpacity(0.2),
                        width: isConnected ? 1.8 : 1.0,
                      ),
                      boxShadow: [
                        if (isConnected)
                          BoxShadow(
                            color: Colors.green.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Icono de impresora con estado
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? Colors.green.withOpacity(0.12)
                                  : theme.colorScheme.primary.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.print_rounded,
                              size: 22,
                              color: isConnected ? Colors.green[700] : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Datos de la impresora
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        printer.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${printer.paperWidth} mm',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      printer.address,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildSignalBars(printer.rssi),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Botón de acción: Conectar / Conectando / Conectado
                          if (isConnecting)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          else if (isConnected)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded, size: 14, color: Colors.green[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Activa',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            ElevatedButton(
                              onPressed: () => _handleConnect(printer),
                              style: ElevatedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Vincular', style: TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                // ==========================================
                // SECCIÓN DE TEST DE IMPRESIÓN SI ESTÁ CONECTADA
                // ==========================================
                if (_connectedId != null || (_currentConfig != null && _currentConfig!.isConnected)) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified_rounded, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Impresora Calibrada y Lista',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Puedes emitir un ticket de calibración para comprobar el avance y corte de papel térmico.',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleTestPrint,
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: const Text('Imprimir Ticket de Prueba'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTypePill({
    required String label,
    required IconData icon,
    required String type,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedConnectionType == type;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (_selectedConnectionType != type) {
            setState(() {
              _selectedConnectionType = type;
            });
            _startScan();
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalBars(int rssi) {
    final int bars = rssi >= -50 ? 4 : (rssi >= -65 ? 3 : (rssi >= -80 ? 2 : 1));
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final bool active = index < bars;
        return Container(
          width: 2.5,
          height: 4.0 + (index * 2.5),
          margin: const EdgeInsets.symmetric(horizontal: 0.5),
          decoration: BoxDecoration(
            color: active ? Colors.green[600] : Colors.grey[300],
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'wifi':
        return Icons.wifi_rounded;
      case 'usb':
        return Icons.usb_rounded;
      default:
        return Icons.bluetooth_searching_rounded;
    }
  }
}

/// Pintor personalizado para el Radar con ondas concéntricas pulsantes
class _RadarPulsePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final bool isScanning;

  _RadarPulsePainter({
    required this.animation,
    required this.color,
    required this.isScanning,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final basePaint = Paint()
      ..color = color.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius, basePaint);

    if (!isScanning) return;

    // Dibujamos 3 ondas con desfase progresivo
    for (int i = 0; i < 3; i++) {
      final double progress = (animation.value + (i * 0.33)) % 1.0;
      final double radius = progress * maxRadius;
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);

      final wavePaint = Paint()
        ..color = color.withOpacity(opacity * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) => true;
}

