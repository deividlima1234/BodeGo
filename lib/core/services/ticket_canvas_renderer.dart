import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:bodego/core/services/pwg_raster_encoder.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';

/// Renderizador de Comprobantes de Venta a Canvas y Mapa de Bits de Alta Resolución (300 DPI).
/// Dibuja el ticket de forma idéntica al modal de la app para su posterior codificación a PWG-Raster.
class TicketCanvasRenderer {
  /// Renderiza un ticket completo y lo devuelve codificado en formato PWG-Raster (image/pwg-raster)
  /// listo para ser enviado directamente por IPP (puerto 631) con CERO ventanas.
  static Future<Uint8List> renderTicketToPwg({
    required SaleTicket ticket,
    required BusinessConfig businessConfig,
    required PrinterConfig printerConfig,
    int dpi = 300,
  }) async {
    // Dimensiones estándar A4 a 300 DPI: 210mm x 297mm = 2480 x 3508 px
    const int pagePixelWidth = 2480;
    const int pagePixelHeight = 3508;

    final String paperFormat = printerConfig.inkjetPaperFormat;
    final double leftMargin;
    final double rightMargin;
    final double centerX;
    final bool isCenteredSheet;

    if (paperFormat == 'half_a4_vertical') {
      // Media Hoja A4 pre-cortada (105 mm x 297 mm):
      // En impresoras con bandeja trasera (Canon MegaTank G3110, Epson EcoTank, HP Smart Tank),
      // las guías laterales deslizan desde ambos lados hacia el CENTRO exacto de la bandeja.
      // Una hoja de 105 mm (1240 px) centrada en una bandeja de 210 mm (2480 px)
      // queda físicamente ubicada entre x = 620 px y x = 1860 px, con centro exacto en x = 1240 px.
      isCenteredSheet = true;
      const double sheetWidth = 1240.0;
      const double sheetLeft = (pagePixelWidth - sheetWidth) / 2; // 620.0
      leftMargin = sheetLeft + 50.0; // 670.0 (ancho de contenido = 1140 px = 96.5 mm, idéntico a Mopria)
      rightMargin = sheetLeft + sheetWidth - 50.0; // 1810.0
      centerX = 1240.0;
    } else if (paperFormat == 'continuous_strip_80mm' || paperFormat == 'strip_80mm') {
      // Tira de papel continuo de 80 mm pre-cortada centrada en bandeja (80 mm = 945 px a 300 DPI)
      isCenteredSheet = true;
      const double stripWidth = 945.0;
      const double sheetLeft = (pagePixelWidth - stripWidth) / 2; // 767.5
      leftMargin = sheetLeft + 40.0;
      rightMargin = sheetLeft + stripWidth - 40.0;
      centerX = 1240.0;
    } else {
      // Hoja A4 Completa (210 x 297 mm):
      // El comprobante se imprime en la columna izquierda (105 mm) y se dibuja
      // la línea vertical de corte en x = 1240 px para recortar la hoja tras imprimir.
      isCenteredSheet = false;
      leftMargin = 60.0;
      rightMargin = 1180.0;
      centerX = 620.0;
    }

    final double contentWidth = rightMargin - leftMargin;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, pagePixelWidth.toDouble(), pagePixelHeight.toDouble()),
    );

    // Fondo blanco puro en toda la hoja
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, pagePixelWidth.toDouble(), pagePixelHeight.toDouble()),
      bgPaint,
    );

    double currentY = 80.0;

    // Carga de logo personalizado si está configurado como archivo de imagen
    ui.Image? customLogoImage;
    if (businessConfig.logoType == 'file' && businessConfig.logoValue.trim().isNotEmpty) {
      final file = File(businessConfig.logoValue.trim());
      if (file.existsSync()) {
        try {
          final bytes = file.readAsBytesSync();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          customLogoImage = frame.image;
        } catch (_) {}
      }
    }

    // 1. Logo o Icono Comercial (Escalado homologado a Mopria)
    currentY = _drawLogoOrIcon(
      canvas: canvas,
      config: businessConfig,
      centerX: centerX,
      topY: currentY,
      customImage: customLogoImage,
    );

    currentY += 20.0;

    // 2. Nombre del Negocio (12 pt tipográfico = 50 px a 300 DPI)
    currentY = _drawCenteredText(
      canvas: canvas,
      text: businessConfig.businessName.toUpperCase(),
      fontSize: 50.0,
      fontWeight: FontWeight.bold,
      centerX: centerX,
      topY: currentY,
      maxWidth: contentWidth,
    );

    currentY += 10.0;

    // 3. RUC sanitizado (7.9 pt tipográfico = 33 px a 300 DPI)
    final rucText = _formatRuc(businessConfig.ruc);
    if (rucText.isNotEmpty) {
      currentY = _drawCenteredText(
        canvas: canvas,
        text: rucText,
        fontSize: 33.0,
        fontWeight: FontWeight.w500,
        centerX: centerX,
        topY: currentY,
        maxWidth: contentWidth,
      );
      currentY += 8.0;
    }

    // 4. Dirección del Negocio (7.7 pt = 32 px a 300 DPI)
    if (businessConfig.address.trim().isNotEmpty) {
      currentY = _drawCenteredText(
        canvas: canvas,
        text: businessConfig.address.trim(),
        fontSize: 32.0,
        fontWeight: FontWeight.normal,
        centerX: centerX,
        topY: currentY,
        maxWidth: contentWidth,
      );
      currentY += 8.0;
    }

    // 5. Teléfono sanitizado (7.7 pt = 32 px a 300 DPI)
    final phoneText = _formatPhone(businessConfig.phone);
    if (phoneText.isNotEmpty) {
      currentY = _drawCenteredText(
        canvas: canvas,
        text: phoneText,
        fontSize: 32.0,
        fontWeight: FontWeight.normal,
        centerX: centerX,
        topY: currentY,
        maxWidth: contentWidth,
      );
      currentY += 18.0;
    } else {
      currentY += 12.0;
    }

    // 6. Título y Número de Ticket (Homologados a 8.4 pt y 10.3 pt)
    currentY = _drawCenteredText(
      canvas: canvas,
      text: 'COMPROBANTE DE CAJA',
      fontSize: 35.0,
      fontWeight: FontWeight.bold,
      centerX: centerX,
      topY: currentY,
      maxWidth: contentWidth,
    );
    currentY += 8.0;

    currentY = _drawCenteredText(
      canvas: canvas,
      text: ticket.ticketNumber,
      fontSize: 43.0,
      fontWeight: FontWeight.w900,
      centerX: centerX,
      topY: currentY,
      maxWidth: contentWidth,
    );
    currentY += 24.0;

    // Línea divisoria punteada
    _drawDashedHorizontalLine(canvas, leftMargin, rightMargin, currentY);
    currentY += 24.0;

    // 7. Metadatos de la Venta: Fecha, Cajero, Tipo de Pago (7.9 pt = 33 px a 300 DPI)
    final dateStr =
        '${ticket.date.day.toString().padLeft(2, '0')}/${ticket.date.month.toString().padLeft(2, '0')}/${ticket.date.year} ${ticket.date.hour.toString().padLeft(2, '0')}:${ticket.date.minute.toString().padLeft(2, '0')}';
    currentY = _drawTwoColumnRow(
      canvas: canvas,
      leftText: 'FECHA:',
      rightText: dateStr,
      fontSize: 33.0,
      leftX: leftMargin,
      rightX: rightMargin,
      topY: currentY,
    );
    currentY += 14.0;

    if (ticket.cashierName.trim().isNotEmpty) {
      currentY = _drawTwoColumnRow(
        canvas: canvas,
        leftText: 'CAJERO:',
        rightText: ticket.cashierName.trim(),
        fontSize: 33.0,
        leftX: leftMargin,
        rightX: rightMargin,
        topY: currentY,
      );
      currentY += 14.0;
    }

    if (ticket.customerName != null && ticket.customerName!.trim().isNotEmpty) {
      currentY = _drawTwoColumnRow(
        canvas: canvas,
        leftText: 'CLIENTE:',
        rightText: ticket.customerName!.trim(),
        fontSize: 33.0,
        leftX: leftMargin,
        rightX: rightMargin,
        topY: currentY,
      );
      currentY += 14.0;
    }

    // Tipo de Pago con Badge
    final isCredit = ticket.isCredit;
    currentY = _drawTwoColumnRow(
      canvas: canvas,
      leftText: 'TIPO:',
      rightText: isCredit ? 'VENTA AL FIADO' : 'AL CONTADO',
      fontSize: 33.0,
      leftX: leftMargin,
      rightX: rightMargin,
      topY: currentY,
      rightBold: true,
    );
    currentY += 24.0;

    // Línea divisoria punteada
    _drawDashedHorizontalLine(canvas, leftMargin, rightMargin, currentY);
    currentY += 24.0;

    // 8. Cabecera de la Tabla de Productos: PRODUCTO, CANT, TOTAL (7.7 pt = 32 px a 300 DPI)
    final colProdWidth = contentWidth * 0.52;
    final colCantWidth = contentWidth * 0.20;
    final colTotalX = rightMargin;
    final colCantX = leftMargin + colProdWidth + (colCantWidth / 2);

    _drawText(
      canvas: canvas,
      text: 'PRODUCTO',
      fontSize: 32.0,
      fontWeight: FontWeight.bold,
      x: leftMargin,
      y: currentY,
    );
    _drawCenteredText(
      canvas: canvas,
      text: 'CANT',
      fontSize: 32.0,
      fontWeight: FontWeight.bold,
      centerX: colCantX,
      topY: currentY,
      maxWidth: colCantWidth,
    );
    _drawRightAlignedText(
      canvas: canvas,
      text: 'TOTAL',
      fontSize: 32.0,
      fontWeight: FontWeight.bold,
      rightX: colTotalX,
      topY: currentY,
    );

    currentY += 44.0;

    // 9. Filas de Productos (8.4 pt = 35 px, P.U. a 7.2 pt = 30 px a 300 DPI)
    for (final item in ticket.items) {
      final unitStr = item.unit != 'und'
          ? '${_formatQty(item.quantity)} ${item.unit}'
          : 'x${_formatQty(item.quantity)}';

      // Nombre del producto
      final nextY = _drawText(
        canvas: canvas,
        text: item.name,
        fontSize: 35.0,
        fontWeight: FontWeight.bold,
        x: leftMargin,
        y: currentY,
        maxWidth: colProdWidth,
      );

      // Cantidad en columna central
      _drawCenteredText(
        canvas: canvas,
        text: unitStr,
        fontSize: 34.0,
        fontWeight: FontWeight.normal,
        centerX: colCantX,
        topY: currentY,
        maxWidth: colCantWidth,
      );

      // Total en columna derecha
      _drawRightAlignedText(
        canvas: canvas,
        text: 'S/ ${item.subtotal.toStringAsFixed(2)}',
        fontSize: 35.0,
        fontWeight: FontWeight.bold,
        rightX: colTotalX,
        topY: currentY,
      );

      currentY = nextY + 6.0;

      // Subtítulo con Precio Unitario (P.U.)
      _drawText(
        canvas: canvas,
        text: 'P.U: S/ ${item.unitPrice.toStringAsFixed(2)}',
        fontSize: 30.0,
        fontWeight: FontWeight.normal,
        color: const Color(0xFF555555),
        x: leftMargin,
        y: currentY,
      );

      currentY += 44.0;
    }

    currentY += 8.0;
    _drawDashedHorizontalLine(canvas, leftMargin, rightMargin, currentY);
    currentY += 28.0;

    // 10. Desglose de Totales (Subtotal y Descuento)
    if (ticket.discount > 0) {
      currentY = _drawTwoColumnRow(
        canvas: canvas,
        leftText: 'SUBTOTAL:',
        rightText: 'S/ ${ticket.subtotal.toStringAsFixed(2)}',
        fontSize: 34.0,
        leftX: leftMargin,
        rightX: rightMargin,
        topY: currentY,
      );
      currentY += 14.0;

      currentY = _drawTwoColumnRow(
        canvas: canvas,
        leftText: 'DESCUENTO:',
        rightText: '-S/ ${ticket.discount.toStringAsFixed(2)}',
        fontSize: 34.0,
        leftX: leftMargin,
        rightX: rightMargin,
        topY: currentY,
      );
      currentY += 18.0;
      _drawDashedHorizontalLine(canvas, leftMargin, rightMargin, currentY);
      currentY += 24.0;
    }

    // Gran Total a Pagar (Homologado a 9.8 pt y 12.7 pt = 41 px y 53 px a 300 DPI)
    _drawText(
      canvas: canvas,
      text: ticket.isCredit ? 'TOTAL A FIAR:' : 'TOTAL A PAGAR:',
      fontSize: 41.0,
      fontWeight: FontWeight.w900,
      x: leftMargin,
      y: currentY,
    );
    _drawRightAlignedText(
      canvas: canvas,
      text: 'S/ ${ticket.total.toStringAsFixed(2)}',
      fontSize: 53.0,
      fontWeight: FontWeight.w900,
      rightX: rightMargin,
      topY: currentY - 4.0,
    );

    currentY += 72.0;
    _drawDashedHorizontalLine(canvas, leftMargin, rightMargin, currentY);
    currentY += 34.0;

    // Desglose de Deuda para ventas al fiado (idéntico a Mopria)
    if (ticket.isCredit && ticket.previousDebt != null && ticket.newDebt != null) {
      final creditBoxTop = currentY;
      const creditBoxPadding = 18.0;
      const creditRowHeight = 46.0;
      const creditBoxHeight = (creditRowHeight * 3) + (creditBoxPadding * 2);

      final creditRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(leftMargin, creditBoxTop, contentWidth, creditBoxHeight),
        const Radius.circular(8.0),
      );

      final creditBgPaint = Paint()
        ..color = const Color(0xFFFFF8E1)
        ..style = PaintingStyle.fill;
      final creditBorderPaint = Paint()
        ..color = const Color(0xFFFFE082)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRRect(creditRect, creditBgPaint);
      canvas.drawRRect(creditRect, creditBorderPaint);

      double cY = creditBoxTop + creditBoxPadding;

      cY = _drawTwoColumnRow(
        canvas: canvas,
        leftText: 'Saldo Anterior:',
        rightText: 'S/ ${ticket.previousDebt!.toStringAsFixed(2)}',
        fontSize: 32.0,
        leftX: leftMargin + creditBoxPadding,
        rightX: rightMargin - creditBoxPadding,
        topY: cY,
      );
      cY += 12.0;

      cY = _drawTwoColumnRow(
        canvas: canvas,
        leftText: 'Fiado de Hoy:',
        rightText: '+ S/ ${ticket.total.toStringAsFixed(2)}',
        fontSize: 32.0,
        leftX: leftMargin + creditBoxPadding,
        rightX: rightMargin - creditBoxPadding,
        topY: cY,
        rightBold: true,
      );
      cY += 12.0;

      _drawTwoColumnRow(
        canvas: canvas,
        leftText: 'Nuevo Saldo:',
        rightText: 'S/ ${ticket.newDebt!.toStringAsFixed(2)}',
        fontSize: 34.0,
        leftX: leftMargin + creditBoxPadding,
        rightX: rightMargin - creditBoxPadding,
        topY: cY,
        rightBold: true,
      );

      currentY = creditBoxTop + creditBoxHeight + 24.0;
      _drawDashedHorizontalLine(canvas, leftMargin, rightMargin, currentY);
      currentY += 30.0;
    }

    // 11. Mensaje de Agradecimiento (7.9 pt = 33 px a 300 DPI)
    final footerMsg = businessConfig.ticketFooterMessage.trim().isNotEmpty
        ? businessConfig.ticketFooterMessage.trim()
        : '¡GRACIAS POR SU COMPRA!\nVUELVA PRONTO';

    for (final line in footerMsg.split('\n')) {
      if (line.trim().isNotEmpty) {
        currentY = _drawCenteredText(
          canvas: canvas,
          text: line.trim(),
          fontSize: 33.0,
          fontWeight: FontWeight.bold,
          centerX: centerX,
          topY: currentY,
          maxWidth: contentWidth,
        );
        currentY += 8.0;
      }
    }

    currentY += 24.0;

    // 12. Código de Barras 100% Vectorial (Homologado a 28 px CSS = 88 px de altura)
    if (businessConfig.showBarcodeOnTicket) {
      currentY = _drawVectorBarcode(
        canvas: canvas,
        centerX: centerX,
        topY: currentY,
        codeText: '* ${ticket.ticketNumber.replaceAll('-', '')} *',
      );
      currentY += 28.0;
    }

    // 13. Branding EddamCore (6.5 pt = 27 px a 300 DPI)
    if (businessConfig.showEddamCoreBranding) {
      currentY = _drawBranding(
        canvas: canvas,
        centerX: centerX,
        topY: currentY,
      );
      currentY += 40.0;
    }

    // 14. Línea de Corte de Tijera Horizontal (Fin del Comprobante)
    _drawCutLineHorizontal(canvas, leftMargin, rightMargin, currentY);

    // 15. Si es hoja A4 completa, dibujar la línea vertical de corte de la hoja
    // Para media hoja pre-cortada o tira continua, NO dibujar línea vertical porque la hoja ya está cortada
    if (!isCenteredSheet) {
      _drawCutLineVertical(canvas, 1240.0, 40.0, pagePixelHeight.toDouble() - 40.0);
    }

    // Finalizar grabación y extraer imagen
    final picture = recorder.endRecording();
    final image = await picture.toImage(pagePixelWidth, pagePixelHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (byteData == null) {
      throw Exception('Fallo al extraer buffer RGBA del Canvas');
    }

    // Codificar a PWG-Raster universal sRGB de 24 bits a 300 DPI (srgb_8)
    // compatible nativamente con los firmwares de Canon MegaTank (G3110, G2110), Epson EcoTank y HP.
    final pwgBytes = PwgRasterEncoder.encodeRgba(
      rgbaBytes: byteData.buffer.asUint8List(),
      width: pagePixelWidth,
      height: pagePixelHeight,
      dpi: dpi,
      pageSizeName: 'iso_a4_210x297mm',
      colorSpace: PwgColorSpace.srgb8,
    );

    return pwgBytes;
  }

  // ==========================================
  // HELPERS DE DIBUJO VECTORIAL EN CANVAS
  // ==========================================

  static double _drawLogoOrIcon({
    required Canvas canvas,
    required BusinessConfig config,
    required double centerX,
    required double topY,
    ui.Image? customImage,
  }) {
    const double size = 136.0;
    final center = Offset(centerX, topY + (size / 2));

    // Si tiene archivo de logo personalizado cargado
    if (customImage != null) {
      canvas.save();
      // Recorte circular estético para el logo
      final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: (size / 2) - 2));
      canvas.clipPath(clipPath);

      final srcRect = Rect.fromLTWH(0, 0, customImage.width.toDouble(), customImage.height.toDouble());
      final dstRect = Rect.fromLTWH(centerX - (size / 2), topY, size, size);
      canvas.drawImageRect(customImage, srcRect, dstRect, Paint());
      canvas.restore();

      // Borde circular exterior elegante
      final borderPaint = Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawCircle(center, (size / 2) - 2, borderPaint);

      return topY + size;
    }

    // Icono predeterminado vectorial (Carrito de Compras / Tienda)
    final circlePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    canvas.drawCircle(center, (size / 2) - 2, circlePaint);

    // Carrito de compras vectorial estilizado en el centro (escalado para 136 px)
    final cartPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cartPath = Path();
    final ox = centerX - 32.0;
    final oy = topY + 34.0;

    cartPath.moveTo(ox, oy + 5);
    cartPath.lineTo(ox + 10, oy + 5);
    cartPath.lineTo(ox + 20, oy + 40);
    cartPath.lineTo(ox + 54, oy + 40);
    cartPath.lineTo(ox + 62, oy + 15);
    cartPath.lineTo(ox + 15, oy + 15);
    canvas.drawPath(cartPath, cartPaint);

    final wheelPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(ox + 25, oy + 50), 5.0, wheelPaint);
    canvas.drawCircle(Offset(ox + 49, oy + 50), 5.0, wheelPaint);

    return topY + size;
  }

  static double _drawCenteredText({
    required Canvas canvas,
    required String text,
    required double fontSize,
    required FontWeight fontWeight,
    required double centerX,
    required double topY,
    required double maxWidth,
    Color color = Colors.black,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);

    tp.paint(canvas, Offset(centerX - (tp.width / 2), topY));
    return topY + tp.height;
  }

  static double _drawText({
    required Canvas canvas,
    required String text,
    required double fontSize,
    required FontWeight fontWeight,
    required double x,
    required double y,
    double? maxWidth,
    Color color = Colors.black,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth ?? double.infinity);

    tp.paint(canvas, Offset(x, y));
    return y + tp.height;
  }

  static double _drawRightAlignedText({
    required Canvas canvas,
    required String text,
    required double fontSize,
    required FontWeight fontWeight,
    required double rightX,
    required double topY,
    Color color = Colors.black,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(rightX - tp.width, topY));
    return topY + tp.height;
  }

  static double _drawTwoColumnRow({
    required Canvas canvas,
    required String leftText,
    required String rightText,
    required double fontSize,
    required double leftX,
    required double rightX,
    required double topY,
    bool rightBold = false,
  }) {
    _drawText(
      canvas: canvas,
      text: leftText,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      x: leftX,
      y: topY,
    );

    _drawRightAlignedText(
      canvas: canvas,
      text: rightText,
      fontSize: fontSize,
      fontWeight: rightBold ? FontWeight.bold : FontWeight.normal,
      rightX: rightX,
      topY: topY,
    );

    return topY + fontSize + 4.0;
  }

  static void _drawDashedHorizontalLine(
    Canvas canvas,
    double x1,
    double x2,
    double y,
  ) {
    final paint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 2.0;

    const double dashWidth = 10.0;
    const double dashSpace = 8.0;
    double currentX = x1;

    while (currentX < x2) {
      canvas.drawLine(
        Offset(currentX, y),
        Offset((currentX + dashWidth).clamp(x1, x2), y),
        paint,
      );
      currentX += (dashWidth + dashSpace);
    }
  }

  static double _drawVectorBarcode({
    required Canvas canvas,
    required double centerX,
    required double topY,
    required String codeText,
  }) {
    const barPattern = [
      4, 2, 6, 2, 2, 4, 8, 2, 4, 6, 2, 4, 2, 8, 4, 2, 6, 2, 4, 2, 2, 6, 4, 2, 8, 2, 4, 6, 2, 4
    ];
    int totalPatternUnits = 0;
    for (final w in barPattern) {
      totalPatternUnits += w;
    }

    const double unitScale = 3.6; // Ancho total de barras homologado a Mopria (~403 px = 3.4 cm a 300 DPI)
    final double totalWidth = totalPatternUnits * unitScale;
    final double startX = centerX - (totalWidth / 2);
    const double barHeight = 88.0; // Homologado a 28 px CSS de Mopria (87.5 px a 300 DPI)
    final barPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    double currentX = startX;
    for (int i = 0; i < barPattern.length; i++) {
      final w = barPattern[i].toDouble() * unitScale;
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(currentX, topY, w, barHeight), barPaint);
      }
      currentX += w;
    }

    // Texto del código bajo las barras
    final nextY = topY + barHeight + 10.0;
    return _drawCenteredText(
      canvas: canvas,
      text: codeText,
      fontSize: 28.0,
      fontWeight: FontWeight.normal,
      centerX: centerX,
      topY: nextY,
      maxWidth: 600.0,
      color: const Color(0xFF333333),
    );
  }

  static double _drawBranding({
    required Canvas canvas,
    required double centerX,
    required double topY,
  }) {
    final boxPaint = Paint()
      ..color = const Color(0xFFF5F5F5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const double width = 560.0;
    const double height = 56.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, topY + (height / 2)), width: width, height: height),
      const Radius.circular(8.0),
    );

    canvas.drawRRect(rrect, boxPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Pequeño rayo vectorial estilizado monocromático
    final boltPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.fill;
    final boltPath = Path();
    final bx = centerX - 215.0;
    final by = topY + 15.0;
    boltPath.moveTo(bx + 9, by);
    boltPath.lineTo(bx, by + 14);
    boltPath.lineTo(bx + 8, by + 14);
    boltPath.lineTo(bx + 4, by + 25);
    boltPath.lineTo(bx + 15, by + 10);
    boltPath.lineTo(bx + 9, by + 10);
    boltPath.close();
    canvas.drawPath(boltPath, boltPaint);

    _drawCenteredText(
      canvas: canvas,
      text: 'Tecnología impulsada por EddamCore',
      fontSize: 27.0,
      fontWeight: FontWeight.w600,
      centerX: centerX + 8.0,
      topY: topY + 14.0,
      maxWidth: width,
      color: const Color(0xFF555555),
    );

    return topY + height;
  }

  static void _drawCutLineHorizontal(Canvas canvas, double x1, double x2, double y) {
    _drawDashedHorizontalLine(canvas, x1, x2, y);

    _drawCenteredText(
      canvas: canvas,
      text: '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
      fontSize: 28.0,
      fontWeight: FontWeight.normal,
      centerX: x1 + ((x2 - x1) / 2),
      topY: y + 10.0,
      maxWidth: x2 - x1,
      color: const Color(0xFF666666),
    );

    _drawCenteredText(
      canvas: canvas,
      text: '✂ CORTAR AQUÍ (FIN DEL COMPROBANTE)',
      fontSize: 32.0,
      fontWeight: FontWeight.bold,
      centerX: x1 + ((x2 - x1) / 2),
      topY: y + 42.0,
      maxWidth: x2 - x1,
      color: const Color(0xFF333333),
    );
  }

  static void _drawCutLineVertical(Canvas canvas, double x, double y1, double y2) {
    final paint = Paint()
      ..color = const Color(0xFF999999)
      ..strokeWidth = 2.0;

    const double dashLen = 16.0;
    const double dashSpace = 12.0;
    double currentY = y1;

    while (currentY < y2) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, (currentY + dashLen).clamp(y1, y2)),
        paint,
      );
      currentY += (dashLen + dashSpace);
    }
  }

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

  static String _formatPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return '';
    String clean = trimmed;
    final phoneRegex = RegExp(r'^(Tel\s*/?\s*Cel|Tel|Cel)\s*[:\.\-]?\s*', caseSensitive: false);
    while (phoneRegex.hasMatch(clean)) {
      clean = clean.replaceFirst(phoneRegex, '').trim();
    }
    return 'Tel / Cel: $clean';
  }

  static String _formatQty(double qty) {
    return (qty % 1 == 0) ? qty.toInt().toString() : qty.toStringAsFixed(2);
  }
}
