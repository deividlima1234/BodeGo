import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:bodego/core/services/sound_service.dart';

/// Modal / Pantalla de escáner moderna, inteligente y profesional adaptada al tema de la app.
class ModernBarcodeScanner extends StatefulWidget {
  /// Si es true, el escáner se mantiene abierto para escanear múltiples productos sucesivamente (Caja POS).
  /// Si es false, se cierra inmediatamente al capturar el primer código (Formularios).
  final bool isContinuousMode;

  /// Título contextual mostrado en la parte superior.
  final String title;

  /// Subtítulo o instrucción para el usuario.
  final String subtitle;

  /// Callback para el modo continuo cuando se detecta un código válido.
  /// Debe retornar un mensaje descriptivo si se agregó con éxito o null.
  final Future<String?> Function(String barcode)? onBarcodeScanned;

  /// Widget opcional que se muestra en la parte inferior (ej. barra de estado del carrito).
  final Widget? bottomBar;

  const ModernBarcodeScanner({
    super.key,
    this.isContinuousMode = false,
    this.title = 'Escanear Código de Barras',
    this.subtitle = 'Enfoca el código de barras dentro del marco',
    this.onBarcodeScanned,
    this.bottomBar,
  });

  /// Método estático de utilidad para abrir el escáner en modo captura única.
  static Future<String?> scanSingle(
    BuildContext context, {
    String title = 'Escanear Código de Barras',
    String subtitle = 'Enfoca el código de barras dentro del marco',
  }) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ModernBarcodeScanner(
          isContinuousMode: false,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }

  /// Método estático de utilidad para abrir el escáner en modo ráfaga continuo (Caja POS).
  static Future<void> openContinuous(
    BuildContext context, {
    required Future<String?> Function(String barcode) onBarcodeScanned,
    Widget? bottomBar,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ModernBarcodeScanner(
          isContinuousMode: true,
          title: 'Caja - Escáner Continuo',
          subtitle: 'Apunta a los productos para agregarlos al carrito',
          onBarcodeScanned: onBarcodeScanned,
          bottomBar: bottomBar,
        ),
      ),
    );
  }

  @override
  State<ModernBarcodeScanner> createState() => _ModernBarcodeScannerState();
}

class _ModernBarcodeScannerState extends State<ModernBarcodeScanner>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _laserAnimController;

  // Control inteligente anti-duplicados (debounce de 1.2 segundos para el mismo código)
  String? _lastScannedCode;
  DateTime? _lastScannedTime;
  bool _isProcessing = false;

  // Notificación flotante de producto agregado o alerta
  String? _toastMessage;
  bool _isToastSuccess = true;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _laserAnimController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  /// Procesa el código detectado aplicando debounce y feedback háptico.
  Future<void> _handleBarcode(String rawCode) async {
    final cleanCode = rawCode.trim();
    if (cleanCode.isEmpty || _isProcessing) return;

    final now = DateTime.now();
    if (_lastScannedCode == cleanCode && _lastScannedTime != null) {
      final difference = now.difference(_lastScannedTime!);
      if (difference.inMilliseconds < 1300) {
        // Ignorar duplicados del mismo código en ráfaga accidental
        return;
      }
    }

    _lastScannedCode = cleanCode;
    _lastScannedTime = now;
    _isProcessing = true;

    // Feedback háptico y pitido clásico de escáner instantáneo
    HapticFeedback.mediumImpact();
    SoundService.playScannerBeep();

    if (!widget.isContinuousMode) {
      // Modo Captura Única: retornar y salir
      if (mounted) {
        Navigator.pop(context, cleanCode);
      }
      return;
    }

    // Modo Continuo (Caja): procesar con el callback proporcionado
    if (widget.onBarcodeScanned != null) {
      try {
        final resultMessage = await widget.onBarcodeScanned!(cleanCode);
        if (mounted && resultMessage != null) {
          _showToast(resultMessage, isSuccess: true);
        }
      } catch (e) {
        if (mounted) {
          _showToast('Error al procesar: $e', isSuccess: false);
        }
      }
    }

    // Pequeño retardo para volver a permitir el siguiente escaneo
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showToast(String message, {bool isSuccess = true}) {
    _toastTimer?.cancel();
    setState(() {
      _toastMessage = message;
      _isToastSuccess = isSuccess;
    });
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final accentColor = colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Visor de la Cámara nativa
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  _handleBarcode(raw);
                  break;
                }
              }
            },
          ),

          // 2. Capa Oscura Semi-transparente con Ventana de Enfoque Recortada
          LayoutBuilder(
            builder: (context, constraints) {
              final scanWidth = constraints.maxWidth * 0.78;
              final scanHeight = scanWidth * 0.70;
              final left = (constraints.maxWidth - scanWidth) / 2;
              final top = (constraints.maxHeight - scanHeight) / 2 - 40;

              return Stack(
                children: [
                  // Máscara opaca alrededor de la ventana
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.65),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                            backgroundBlendMode: BlendMode.dstOut,
                          ),
                        ),
                        Positioned(
                          left: left,
                          top: top,
                          width: scanWidth,
                          height: scanHeight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Retícula de Enfoque con Esquinas Iluminadas (Corner Brackets)
                  Positioned(
                    left: left,
                    top: top,
                    width: scanWidth,
                    height: scanHeight,
                    child: CustomPaint(
                      painter: _ScannerReticlePainter(
                        color: accentColor,
                        cornerLength: 28,
                        strokeWidth: 4.0,
                        borderRadius: 16,
                      ),
                    ),
                  ),

                  // Línea Láser Animada que Oscila Verticalmente
                  Positioned(
                    left: left + 8,
                    top: top,
                    width: scanWidth - 16,
                    height: scanHeight,
                    child: AnimatedBuilder(
                      animation: _laserAnimController,
                      builder: (context, child) {
                        final laserTop = _laserAnimController.value * (scanHeight - 4);
                        return Stack(
                          children: [
                            Positioned(
                              top: laserTop,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.0),
                                      accentColor,
                                      accentColor,
                                      primaryColor.withOpacity(0.0),
                                    ],
                                    stops: const [0.0, 0.25, 0.75, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          // 3. Barra Superior con Controles (Volver, Título, Linterna, Cámara)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Botón Cerrar
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Textos de Encabezado
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Botón Linterna (Torch)
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _scannerController,
                    builder: (context, state, child) {
                      final isTorchOn = state.torchState == TorchState.on;
                      return CircleAvatar(
                        backgroundColor: isTorchOn ? accentColor : Colors.black45,
                        child: IconButton(
                          icon: Icon(
                            isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: isTorchOn ? Colors.black : Colors.white,
                            size: 20,
                          ),
                          tooltip: isTorchOn ? 'Apagar Linterna' : 'Encender Linterna',
                          onPressed: () => _scannerController.toggleTorch(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Botón Alternar Cámara
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 20),
                      tooltip: 'Cambiar Cámara',
                      onPressed: () => _scannerController.switchCamera(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Toast / Notificación Flotante de Escaneo (debajo del visor)
          if (_toastMessage != null)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.16,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _toastMessage != null ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isToastSuccess
                        ? colorScheme.surface
                        : colorScheme.error.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isToastSuccess ? accentColor : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isToastSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        color: _isToastSuccess ? primaryColor : Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _toastMessage!,
                          style: TextStyle(
                            color: _isToastSuccess ? colorScheme.onSurface : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Barra Inferior fija (si se pasa `bottomBar`, ej. Carrito en vivo)
          if (widget.bottomBar != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: widget.bottomBar!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Custom Painter para dibujar las esquinas iluminadas (Corner Brackets) de la retícula.
class _ScannerReticlePainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double borderRadius;

  _ScannerReticlePainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final l = cornerLength;

    // Esquina Superior Izquierda
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Esquina Superior Derecha
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Esquina Inferior Izquierda
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Esquina Inferior Derecha
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerReticlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}
