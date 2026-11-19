import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/printer_repository.dart';
import 'package:bodego/presentation/screens/settings/widgets/printer_scanner_modal.dart';

enum PrintProcessState {
  connecting,
  printing,
  paperEmpty,
  success,
  error,
  noPrinter,
}

/// Modal interactivo que muestra el flujo animado de impresión térmica en tiempo real:
/// 1. Verificación de enlace Bluetooth/WiFi/USB
/// 2. Animación física del ticket emergiendo de la ranura de la impresora
/// 3. Confirmación de éxito o gestión de errores con opción de vincular o reintentar
class ThermalPrintProgressModal extends StatefulWidget {
  final SaleTicket ticket;
  final VoidCallback? onCompleted;

  const ThermalPrintProgressModal({
    super.key,
    required this.ticket,
    this.onCompleted,
  });

  /// Despliega el modal de progreso de impresión térmica centrado
  static Future<void> show(
    BuildContext context, {
    required SaleTicket ticket,
    VoidCallback? onCompleted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ThermalPrintProgressModal(
        ticket: ticket,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<ThermalPrintProgressModal> createState() => _ThermalPrintProgressModalState();
}

class _ThermalPrintProgressModalState extends State<ThermalPrintProgressModal>
    with TickerProviderStateMixin {
  final PrinterRepository _printerRepo = PrinterRepository();

  PrintProcessState _state = PrintProcessState.connecting;
  PrinterConfig? _printerConfig;
  String _statusMessage = 'Preparando impresión...';
  String? _customSubtitle;
  double _printProgress = 0.0;
  int _lastHapticTick = 0;

  late final AnimationController _pulseController;
  late final AnimationController _paperController;
  late final AnimationController _successController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _paperController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _paperController.addListener(() {
      setState(() {
        _printProgress = _paperController.value;
      });
      final currentTick = (_paperController.value * 10).floor();
      if (currentTick != _lastHapticTick && currentTick > 0 && currentTick < 10) {
        _lastHapticTick = currentTick;
        HapticFeedback.selectionClick();
      }
    });

    _startPrintingFlow();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _paperController.dispose();
    _successController.dispose();
    super.dispose();
  }

  /// Inicia el flujo secuencial de conexión e impresión con telemetría en tiempo real
  Future<void> _startPrintingFlow({bool forceSimulation = false}) async {
    setState(() {
      _state = PrintProcessState.connecting;
      _statusMessage = 'Preparando impresión...';
      _customSubtitle = null;
      _printProgress = 0.0;
    });
    _paperController.reset();
    _lastHapticTick = 0;

    final config = await _printerRepo.getConfig();
    _printerConfig = config;

    // Modo simulación manual o cuando no hay impresora configurada
    if (forceSimulation || (!config.isInkjet && !config.isConnected)) {
      if (!forceSimulation && !config.isConnected) {
        if (!mounted) return;
        setState(() {
          _state = PrintProcessState.noPrinter;
          _statusMessage = 'No hay impresora vinculada';
        });
        return;
      }

      setState(() {
        _state = PrintProcessState.printing;
        _statusMessage = 'Simulando impresión de comprobante...';
        _customSubtitle = 'Modo de prueba virtual';
      });

      final sw = Stopwatch()..start();
      const simMs = 3000;
      while (sw.elapsedMilliseconds < simMs) {
        if (!mounted) return;
        final prog = (sw.elapsedMilliseconds / simMs).clamp(0.0, 0.98);
        setState(() {
          _printProgress = prog;
          _paperController.value = prog;
          _statusMessage = 'Simulando impresión (${(prog * 100).toInt()}%)...';
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _successController.forward(from: 0.0);
      setState(() {
        _state = PrintProcessState.success;
        _statusMessage = '¡Comprobante simulado con éxito!';
        _printProgress = 1.0;
        _paperController.value = 1.0;
      });
      widget.onCompleted?.call();
      return;
    }

    // Despacha la impresión con trazabilidad de progreso y estado en tiempo real
    final printResult = await _printerRepo.printSaleTicketDetailed(
      widget.ticket,
      config: config,
      onProgress: (event) {
        if (!mounted) return;
        setState(() {
          _printProgress = event.progress;
          _paperController.value = event.progress;
          _statusMessage = event.title;
          _customSubtitle = event.subtitle;

          if (event.isPaperEmpty) {
            _state = PrintProcessState.paperEmpty;
          } else if (event.hasError) {
            _state = PrintProcessState.error;
          } else if (event.isCompleted) {
            _state = PrintProcessState.success;
          } else {
            _state = PrintProcessState.printing;
          }
        });
      },
    );

    if (!mounted) return;

    if (printResult.success) {
      HapticFeedback.heavyImpact();
      _successController.forward(from: 0.0);
      setState(() {
        _state = PrintProcessState.success;
        _statusMessage = printResult.message;
        _printProgress = 1.0;
        _paperController.value = 1.0;
      });
      widget.onCompleted?.call();
    } else {
      setState(() {
        _state = PrintProcessState.error;
        _statusMessage = printResult.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E2235) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Cabecera con número de ticket
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _printerConfig?.isInkjet == true
                              ? Icons.local_printshop_rounded
                              : Icons.print_rounded,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _printerConfig?.isInkjet == true
                            ? 'Impresora Tinta / A4'
                            : 'Impresión Térmica',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey[300]!,
                      ),
                    ),
                    child: Text(
                      widget.ticket.ticketNumber,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 2. Zona Central: Ilustración y animaciones dinámicas según estado
              _buildCentralVisual(theme, isDark),

              const SizedBox(height: 18),

              // 3. Texto descriptivo del estado
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 4),

              // Subtítulo con el nombre del dispositivo
              Text(
                _getDeviceSubtitle(),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // 4. Barra de progreso o divisor
              if (_state == PrintProcessState.printing || _state == PrintProcessState.connecting)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _state == PrintProcessState.printing ? _printProgress : null,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                )
              else
                const Divider(height: 1),

              const SizedBox(height: 14),

              // 5. Botones de acción según el estado
              _buildActionButtons(theme, isDark),
            ],
          ),
        ),
      ),
    );
  }

  /// Retorna el subtítulo contextual de la impresora activa
  String _getDeviceSubtitle() {
    if (_customSubtitle != null && _customSubtitle!.isNotEmpty) {
      return _customSubtitle!;
    }

    final isInkjet = _printerConfig?.isInkjet ?? false;
    final formatLabel = _printerConfig?.inkjetPaperFormat == 'half_a4_vertical'
        ? 'Media Hoja A4 (105mm)'
        : (_printerConfig?.inkjetPaperFormat == 'full_a4' ? 'Hoja A4 Completa' : 'Tira 80mm');

    switch (_state) {
      case PrintProcessState.connecting:
        if (isInkjet) {
          return 'Formato $formatLabel con guía de corte ✂...';
        }
        final name = _printerConfig?.deviceName ?? 'Dispositivo Térmico';
        return 'Buscando $name (${_printerConfig?.connectionType.toUpperCase() ?? "BT"})...';
      case PrintProcessState.printing:
        if (isInkjet) {
          final model = _printerConfig?.inkjetPrinterModel.isNotEmpty == true
              ? _printerConfig!.inkjetPrinterModel
              : 'Epson EcoTank';
          return 'Despachando a $model ($formatLabel)...';
        }
        final name = _printerConfig?.deviceName ?? 'POS-5802DD';
        final pct = (_printProgress * 100).toInt();
        return 'Enviando a $name ($pct%)...';
      case PrintProcessState.paperEmpty:
        return 'Coloca papel en la bandeja de la impresora para continuar';
      case PrintProcessState.success:
        if (isInkjet) {
          final model = _printerConfig?.inkjetPrinterModel.isNotEmpty == true
              ? _printerConfig!.inkjetPrinterModel
              : 'Epson EcoTank';
          return 'Enviado exitosamente a $model';
        }
        final name = _printerConfig?.deviceName ?? 'Impresora Térmica';
        return 'Enviado exitosamente a $name';
      case PrintProcessState.noPrinter:
        return 'Vincula una impresora 58mm o 80mm vía Bluetooth o WiFi.';
      case PrintProcessState.error:
        return isInkjet
            ? 'Verifica que la impresora esté encendida y conectada a la red WiFi.'
            : 'Verifica que la impresora esté encendida y tenga papel.';
    }
  }

  /// Renderiza la ilustración animada en el centro del modal
  Widget _buildCentralVisual(ThemeData theme, bool isDark) {
    if (_state == PrintProcessState.success) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: _successController,
          curve: Curves.elasticOut,
        ),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.18),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 56,
          ),
        ),
      );
    }

    if (_state == PrintProcessState.paperEmpty) {
      return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2),
        ),
        child: const Icon(
          Icons.note_alt_outlined,
          color: Colors.amber,
          size: 46,
        ),
      );
    }

    if (_state == PrintProcessState.noPrinter) {
      return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Icon(
          Icons.print_disabled_rounded,
          color: Colors.orange,
          size: 46,
        ),
      );
    }

    if (_state == PrintProcessState.error) {
      return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: const Icon(
          Icons.error_outline_rounded,
          color: Colors.redAccent,
          size: 46,
        ),
      );
    }

    // Ilustración de Impresora Térmica expulsando el ticket hacia arriba
    final primary = theme.colorScheme.primary;

    return SizedBox(
      height: 130,
      width: 170,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // A. Papel del ticket saliendo hacia arriba con animación suave
          Positioned(
            bottom: 38,
            child: AnimatedBuilder(
              animation: _paperController,
              builder: (context, child) {
                final double paperHeight = 15.0 + (_paperController.value * 65.0);
                return Container(
                  width: 100,
                  height: paperHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey[300]!, width: 0.8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Líneas simuladas de texto impreso
                      Container(
                        height: 3,
                        color: Colors.grey[700],
                        margin: const EdgeInsets.only(bottom: 3),
                      ),
                      Container(
                        height: 2,
                        color: Colors.grey[400],
                        margin: const EdgeInsets.only(bottom: 3),
                      ),
                      if (paperHeight > 35) ...[
                        Container(
                          height: 2,
                          color: Colors.grey[400],
                          margin: const EdgeInsets.only(bottom: 3),
                        ),
                        Container(
                          height: 3,
                          color: primary,
                          margin: const EdgeInsets.only(bottom: 3),
                        ),
                      ],
                      if (paperHeight > 60) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(width: 20, height: 2, color: Colors.grey[500]),
                            Container(width: 25, height: 2, color: Colors.black),
                          ],
                        ),
                        if (_printerConfig?.isInkjet == true) ...[
                          const SizedBox(height: 2),
                          const Text(
                            '✂ - - - - - - -',
                            style: TextStyle(
                              fontSize: 7,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // B. Cuerpo de la Impresora (Térmica POS o Multifuncional Epson/A4)
          Container(
            width: _printerConfig?.isInkjet == true ? 160 : 150,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2B314B) : const Color(0xFF1E2235),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Ranura de salida del papel
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: _printerConfig?.isInkjet == true ? 116 : 106,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Botón feed y luz LED de estado
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Row(
                    children: [
                      // LED parpadeante / continuo
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final glow = _state == PrintProcessState.printing
                              ? 0.5 + (_pulseController.value * 0.5)
                              : 1.0;
                          return Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_printerConfig?.isInkjet == true ? Colors.lightBlueAccent : Colors.greenAccent).withOpacity(glow),
                              boxShadow: [
                                BoxShadow(
                                  color: (_printerConfig?.isInkjet == true ? Colors.lightBlueAccent : Colors.greenAccent).withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _printerConfig?.isInkjet == true
                            ? (_printerConfig?.inkjetPrinterModel.split(' ').first.toUpperCase() ?? 'TINTA')
                            : 'POWER',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ícono de marca / tipo térmico
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: Icon(
                    _printerConfig?.isInkjet == true
                        ? Icons.local_printshop_rounded
                        : (_printerConfig?.connectionType == 'wifi'
                            ? Icons.wifi_rounded
                            : Icons.bluetooth_rounded),
                    color: Colors.white54,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Botones de acción inferiores según el estado del modal
  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    if (_state == PrintProcessState.success) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _startPrintingFlow(forceSimulation: true),
              icon: const Icon(Icons.replay_rounded, size: 16),
              label: const Text('Reimprimir', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    if (_state == PrintProcessState.noPrinter) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await PrinterScannerModal.show(context);
              },
              icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
              label: const Text('Vincular Impresora Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => _startPrintingFlow(forceSimulation: true),
            child: const Text(
              'Probar en Modo Simulación',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    if (_state == PrintProcessState.paperEmpty) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () => _startPrintingFlow(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    if (_state == PrintProcessState.error) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _startPrintingFlow(),
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    // Mientras se conecta o imprime: botón de cancelar discreto
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text(
        'Cancelar',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }
}
