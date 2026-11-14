import 'package:flutter/material.dart';

/// Widget Vectorial Nativo del Logo Oficial de BodeGo (Concepto A: Toldo Bodega + Carrito Go).
/// Implementado con CustomPainter para alto rendimiento a 60/120 FPS sin dependencias externas.
class BodeGoLogoWidget extends StatelessWidget {
  final double size;
  final bool withBackground;
  final double borderRadius;

  const BodeGoLogoWidget({
    super.key,
    this.size = 100.0,
    this.withBackground = true,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BodeGoLogoPainter(
          withBackground: withBackground,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

class _BodeGoLogoPainter extends CustomPainter {
  final bool withBackground;
  final double borderRadius;

  const _BodeGoLogoPainter({
    required this.withBackground,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final scale = s / 512.0;

    // 1. Contenedor de Fondo (si está habilitado)
    if (withBackground) {
      final rect = Rect.fromLTWH(0, 0, s, s);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius * (s / 100.0)));
      final bgPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4353FF), // Azul Rey Eléctrico
            Color(0xFF1E28B8), // Azul Índigo Profundo
          ],
        ).createShader(rect);

      // Sombra proyectada del ícono
      canvas.drawRRect(
        rrect.shift(Offset(0, 4 * scale)),
        Paint()
          ..color = const Color(0xFF4353FF).withOpacity(0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale),
      );

      canvas.drawRRect(rrect, bgPaint);
    }

    canvas.save();
    canvas.scale(scale);

    // 2. Líneas de Velocidad "Go" a la izquierda
    final speedPaint = Paint()
      ..color = (withBackground ? Colors.white : const Color(0xFF4353FF)).withOpacity(0.35)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(60, 210), const Offset(120, 210), speedPaint);
    canvas.drawLine(const Offset(40, 260), const Offset(110, 260), speedPaint);
    canvas.drawLine(const Offset(70, 310), const Offset(130, 310), speedPaint);

    // 3. Toldo Ondulado de Bodega
    final whitePaint = Paint()..color = withBackground ? Colors.white : const Color(0xFF2B3A67);
    final greenPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF00E699), Color(0xFF00A86B)],
      ).createShader(const Rect.fromLTWH(160, 140, 240, 80));

    // Viga superior blanca
    final beamRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(155, 132, 245, 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(beamRRect, whitePaint);

    // Caídas del toldo (Franjas alternas Blanco y Verde)
    _drawAwningFlap(canvas, 160, whitePaint);
    _drawAwningFlap(canvas, 220, greenPaint);
    _drawAwningFlap(canvas, 280, whitePaint);
    _drawAwningFlap(canvas, 340, greenPaint);

    // 4. Cesta y Chasis del Carrito "Go"
    final cartPath = Path()
      ..moveTo(175, 220)
      ..lineTo(375, 220)
      ..cubicTo(390, 220, 400, 232, 396, 248)
      ..lineTo(370, 330)
      ..cubicTo(366, 342, 355, 350, 342, 350)
      ..lineTo(210, 350)
      ..cubicTo(196, 350, 185, 340, 182, 326)
      ..lineTo(160, 220)
      ..close();

    canvas.drawPath(cartPath, whitePaint);

    // Franja aerodinámica Verde en la canasta
    final stripePath = Path()
      ..moveTo(188, 260)
      ..lineTo(385, 260)
      ..lineTo(377, 288)
      ..lineTo(194, 288)
      ..close();
    canvas.drawPath(stripePath, greenPaint);

    // Manija del carrito
    final handlePaint = Paint()
      ..color = whitePaint.color
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(135, 185), const Offset(165, 235), handlePaint);

    // 5. Ruedas en movimiento
    final outerWheelPaint = Paint()..color = whitePaint.color;
    final innerWheelPaint = Paint()..color = const Color(0xFF00D084);

    // Rueda trasera
    canvas.drawCircle(const Offset(230, 395), 24, outerWheelPaint);
    canvas.drawCircle(const Offset(230, 395), 13, innerWheelPaint);

    // Rueda delantera
    canvas.drawCircle(const Offset(345, 395), 24, outerWheelPaint);
    canvas.drawCircle(const Offset(345, 395), 13, innerWheelPaint);

    canvas.restore();
  }

  void _drawAwningFlap(Canvas canvas, double startX, Paint paint) {
    final path = Path()
      ..moveTo(startX, 140)
      ..lineTo(startX + 60, 140)
      ..lineTo(startX + 50, 200)
      ..cubicTo(startX + 40, 214, startX + 10, 214, startX, 200)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BodeGoLogoPainter oldDelegate) =>
      oldDelegate.withBackground != withBackground || oldDelegate.borderRadius != borderRadius;
}

