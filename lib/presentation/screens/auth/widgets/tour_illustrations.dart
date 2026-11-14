import 'dart:math' as math;
import 'package:flutter/material.dart';

/// =========================================================================
/// 1. ILUSTRACIÓN DE VENTAS Y CATÁLOGO AL INSTANTE
/// Carrito dinámico, escáner láser, productos flotantes y chip de total.
/// =========================================================================
class SalesTourIllustration extends StatefulWidget {
  const SalesTourIllustration({super.key});

  @override
  State<SalesTourIllustration> createState() => _SalesTourIllustrationState();
}

class _SalesTourIllustrationState extends State<SalesTourIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 320,
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B).withOpacity(0.9),
                    const Color(0xFF0F172A).withOpacity(0.95),
                  ]
                : [
                    const Color(0xFFF0F4FF),
                    const Color(0xFFE8EEFF),
                  ],
          ),
          border: Border.all(
            color: const Color(0xFF4353FF).withOpacity(0.18),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4353FF).withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Movimiento suave sinusoidal
            final floatOffset = math.sin(t * 2 * math.pi) * 4.0;
            // Progreso del artículo entrando al carrito
            final item1Progress = (t * 2.0).clamp(0.0, 1.0);
            final item1Curve = Curves.easeOutBack.transform(item1Progress);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Carrito de Compras Vectorial Central
                Positioned(
                  left: 60,
                  top: 55 + floatOffset,
                  child: CustomPaint(
                    size: const Size(130, 110),
                    painter: _CartPainter(
                      color: const Color(0xFF4353FF),
                      wheelColor: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                ),

                // 2. Rayo láser escáner de código de barras
                Positioned(
                  left: 80,
                  top: 40 + (math.sin(t * 4 * math.pi) * 20.0 + 20.0),
                  child: Container(
                    width: 75,
                    height: 2,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D084).withOpacity(0.8),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                      gradient: const LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0xFF00D084),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Artículo Flotante 1: Caja de Leche (entra al carrito)
                Positioned(
                  left: 30 + (item1Curve * 65),
                  top: 20 + (item1Curve * 45) + floatOffset,
                  child: Transform.rotate(
                    angle: (1.0 - item1Curve) * -0.25,
                    child: Opacity(
                      opacity: item1Curve.clamp(0.2, 1.0),
                      child: Container(
                        width: 38,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          border: Border.all(
                            color: const Color(0xFF4353FF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4353FF),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 22,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5252).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Text(
                                  'LECHE',
                                  style: TextStyle(
                                    fontSize: 5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF5252),
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              width: 24,
                              height: 4,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Artículo 2: Botella dentro del carrito
                Positioned(
                  left: 122,
                  top: 50 + floatOffset,
                  child: Container(
                    width: 26,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 6,
                          color: const Color(0xFFFF5252),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 20,
                          height: 12,
                          color: Colors.white,
                          child: const Center(
                            child: Text(
                              'INKA',
                              style: TextStyle(
                                fontSize: 4.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 5. Badge flotante "+1" con rebote
                Positioned(
                  left: 140,
                  top: 25 - (math.sin(t * math.pi) * 12.0),
                  child: Opacity(
                    opacity: (math.sin(t * math.pi)).clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D084),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D084).withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 10, color: Colors.white),
                          Text(
                            '1 item',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 6. Chip animado de TOTAL en la esquina inferior derecha
                Positioned(
                  right: 18,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF00D084).withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00D084),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'TOTAL: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const Text(
                          'S/ 18.50',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00D084),
                          ),
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
    );
  }
}

class _CartPainter extends CustomPainter {
  final Color color;
  final Color wheelColor;

  _CartPainter({required this.color, required this.wheelColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    // Mango
    path.moveTo(8, 20);
    path.lineTo(28, 20);
    // Canasta
    path.lineTo(44, 75);
    path.lineTo(108, 75);
    path.lineTo(122, 32);
    path.lineTo(26, 32);

    canvas.drawPath(path, paint);

    // Malla interna del carrito
    final gridPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 1.5;

    canvas.drawLine(const Offset(52, 32), const Offset(62, 75), gridPaint);
    canvas.drawLine(const Offset(78, 32), const Offset(82, 75), gridPaint);
    canvas.drawLine(const Offset(102, 32), const Offset(98, 75), gridPaint);
    canvas.drawLine(const Offset(35, 52), const Offset(115, 52), gridPaint);

    // Ruedas
    final wheelPaint = Paint()
      ..color = wheelColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(54, 92), 7, wheelPaint);
    canvas.drawCircle(const Offset(98, 92), 7, wheelPaint);

    // Ejes internos
    canvas.drawCircle(
      const Offset(54, 92),
      2.5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const Offset(98, 92),
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// =========================================================================
/// 2. ILUSTRACIÓN DE CONTROL DE FIADOS Y CLIENTES
/// De libreta tradicional a tarjeta digital con deuda y límite de crédito.
/// =========================================================================
class FiadosTourIllustration extends StatefulWidget {
  const FiadosTourIllustration({super.key});

  @override
  State<FiadosTourIllustration> createState() => _FiadosTourIllustrationState();
}

class _FiadosTourIllustrationState extends State<FiadosTourIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 320,
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B).withOpacity(0.9),
                    const Color(0xFF0F172A).withOpacity(0.95),
                  ]
                : [
                    const Color(0xFFFFF9F2),
                    const Color(0xFFFFF1E0),
                  ],
          ),
          border: Border.all(
            color: const Color(0xFFFFA114).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFA114).withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final floatOffset = math.sin(t * 2 * math.pi) * 3.0;

            // Porcentaje dinámico de pago o crédito
            final creditProgress = 0.45 + (math.sin(t * 2 * math.pi) * 0.15);

            return Stack(
              children: [
                // 1. Cuaderno antiguo estilizado (a la izquierda)
                Positioned(
                  left: 20,
                  top: 45 + floatOffset,
                  child: Opacity(
                    opacity: 0.65,
                    child: Container(
                      width: 75,
                      height: 100,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (int i = 0; i < 4; i++) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              width: 50.0 - (i * 6),
                              height: 3,
                              color: Colors.grey.withOpacity(0.4),
                            ),
                          ],
                          const Spacer(),
                          const Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.history_edu_rounded,
                              size: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. Flecha / Flujo de Modernización central
                Positioned(
                  left: 102,
                  top: 85 + floatOffset,
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFA114).withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFA114),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFFFFA114),
                      ),
                    ],
                  ),
                ),

                // 3. Tarjeta Digital Inteligente del Cliente (a la derecha)
                Positioned(
                  right: 18,
                  top: 28 + (floatOffset * -1),
                  child: Container(
                    width: 175,
                    height: 145,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4353FF).withOpacity(0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4353FF).withOpacity(0.12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar y Nombre
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Color(0xFF4353FF), Color(0xFF707EFF)],
                                ),
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Doña Rosa',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Cliente Vecina',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: isDark ? Colors.white54 : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Badge de Deuda
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Deuda:',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF5252),
                                ),
                              ),
                              Text(
                                'S/ 45.00',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF5252),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Barra de Límite de Crédito
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Límite S/ 100',
                              style: TextStyle(
                                fontSize: 9,
                                color: isDark ? Colors.white54 : Colors.grey[600],
                              ),
                            ),
                            Text(
                              '${(creditProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4353FF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: creditProgress,
                            backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF4353FF),
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Badge animado de Abono/Pago realizado
                Positioned(
                  right: 32,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D084),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00D084).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Abono S/ 20.00',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
    );
  }
}

/// =========================================================================
/// 3. ILUSTRACIÓN DE IMPRESIÓN TÉRMICA BLUETOOTH
/// Impresora portátil POS emitiendo ondas inalámbricas y ticket saliendo.
/// =========================================================================
class ThermalPrintTourIllustration extends StatefulWidget {
  const ThermalPrintTourIllustration({super.key});

  @override
  State<ThermalPrintTourIllustration> createState() =>
      _ThermalPrintTourIllustrationState();
}

class _ThermalPrintTourIllustrationState
    extends State<ThermalPrintTourIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 320,
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E293B).withOpacity(0.9),
                    const Color(0xFF0F172A).withOpacity(0.95),
                  ]
                : [
                    const Color(0xFFF0FDF4),
                    const Color(0xFFE8F9EE),
                  ],
          ),
          border: Border.all(
            color: const Color(0xFF00D084).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D084).withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Alimentación gradual del papel (va subiendo suavemente)
            final paperShift = (t * 22.0) % 22.0;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Ondas de Radio Bluetooth
                Positioned(
                  left: 36,
                  top: 35,
                  child: CustomPaint(
                    size: const Size(60, 60),
                    painter: _BluetoothWavesPainter(
                      progress: t,
                      color: const Color(0xFF4353FF),
                    ),
                  ),
                ),

                // 2. Chip flotante "Bluetooth Conectado"
                Positioned(
                  left: 20,
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4353FF),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4353FF).withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_connected_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'POS 58mm',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. TICKET TÉRMICO (Saliendo hacia arriba)
                Positioned(
                  top: 24 - paperShift,
                  child: Container(
                    width: 130,
                    height: 125,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Encabezado Ticket
                        const Text(
                          '*** BODEGO POS ***',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Boleta de Venta Electrónica',
                          style: TextStyle(fontSize: 5.5, color: Colors.black54),
                        ),
                        const Divider(thickness: 0.8, height: 6, color: Colors.black38),

                        // Líneas de Items
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1x Arroz Costeño', style: TextStyle(fontSize: 6.5, color: Colors.black87)),
                            Text('S/ 4.50', style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('2x Leche Gloria', style: TextStyle(fontSize: 6.5, color: Colors.black87)),
                            Text('S/ 8.40', style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                        const Divider(thickness: 0.8, height: 6, color: Colors.black38),

                        // Total
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL:', style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.black)),
                            Text('S/ 12.90', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF4353FF))),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Código de barras simulado
                        Container(
                          height: 12,
                          width: double.infinity,
                          color: Colors.white,
                          child: CustomPaint(
                            painter: _BarcodePainter(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. CUERPO DE LA IMPRESORA TÉRMICA (Cubre la base del ticket)
                Positioned(
                  bottom: 22,
                  child: Container(
                    width: 160,
                    height: 75,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Ranura de salida del ticket
                        Positioned(
                          top: 10,
                          left: 20,
                          right: 20,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),

                        // Botón de encendido / LED
                        Positioned(
                          bottom: 15,
                          left: 20,
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00D084),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D084).withOpacity(0.8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ONLINE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Botón FEED
                        Positioned(
                          bottom: 12,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FEED',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
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
    );
  }
}

class _BluetoothWavesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BluetoothWavesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final p = (progress + (i * 0.33)) % 1.0;
      final radius = 10.0 + (p * 26.0);
      final opacity = (1.0 - p).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BluetoothWavesPainter oldDelegate) => true;
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    double x = 0;
    final rand = math.Random(42);

    while (x < size.width) {
      final barWidth = rand.nextBool() ? 1.5 : 3.0;
      canvas.drawRect(Rect.fromLTWH(x, 0, barWidth, size.height), paint);
      x += barWidth + (rand.nextBool() ? 2.0 : 1.0);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// =========================================================================
/// 4. ILUSTRACIÓN DE ARQUEO DE CAJA Y CIERRE Z
/// Cajón de dinero abierto con billetes, monedas y sello "Cuadre Exacto".
/// =========================================================================
class ZReportTourIllustration extends StatefulWidget {
  const ZReportTourIllustration({super.key});

  @override
  State<ZReportTourIllustration> createState() =>
      _ZReportTourIllustrationState();
}

class _ZReportTourIllustrationState extends State<ZReportTourIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        width: 320,
        height: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: theme.brightness == Brightness.dark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E293B),
                    Color(0xFF0F172A),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF5F3FF),
                    Color(0xFFECE7FF),
                  ],
                ),
          border: Border.all(
            color: const Color(0xFF4353FF).withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4353FF).withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Deslizamiento del cajón abriéndose y cerrándose suavemente
            final drawerSlide = math.sin(t * 2 * math.pi) * 8.0;

            // Escala del sello de cuadre con rebote elástico
            final sealScale = 0.95 + (math.sin(t * 2 * math.pi) * 0.05);

            return Stack(
              alignment: Alignment.center,
              children: [
                // 1. Base del Cajón de Dinero POS (Caja Fuerte)
                Positioned(
                  bottom: 25,
                  child: Container(
                    width: 220,
                    height: 90,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Bandeja interna deslizante del cajón
                Positioned(
                  bottom: 25 + drawerSlide,
                  child: Container(
                    width: 210,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Compartimento 1: Billetes Verdes (S/ 10, S/ 20)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < 2; i++)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D084).withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: Colors.white54, width: 0.5),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'S/ 20',
                                        style: TextStyle(
                                          fontSize: 6,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Compartimento 2: Billetes Azules (S/ 50, S/ 100)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < 2; i++)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4353FF).withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: Colors.white54, width: 0.5),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'S/ 50',
                                        style: TextStyle(
                                          fontSize: 6,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Compartimento 3: Monedas Doradas
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 3,
                                children: [
                                  for (int i = 0; i < 4; i++)
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          'S/1',
                                          style: TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. SELLO FLOTANTE DE CIERRE Z "CUADRE EXACTO"
                Positioned(
                  top: 22,
                  child: Transform.scale(
                    scale: sealScale,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF00D084),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D084).withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF00D084),
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'CIERRE Z CUADRADO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00D084),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Descuadre en caja: S/ 0.00',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

