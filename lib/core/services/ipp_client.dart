import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Resultado del envío o diagnóstico de impresión directa por red (IPP o RAW)
class IppPrintResult {
  final bool success;
  final int statusCode;
  final String message;
  final int latencyMs;
  final int? jobId;
  final String? jobUri;
  final int? initialJobState;

  const IppPrintResult({
    required this.success,
    this.statusCode = 0,
    required this.message,
    this.latencyMs = 0,
    this.jobId,
    this.jobUri,
    this.initialJobState,
  });

  @override
  String toString() => 'IppPrintResult(success: $success, statusCode: $statusCode, jobId: $jobId, jobState: $initialJobState, message: $message, latency: ${latencyMs}ms)';
}

/// Cliente de Impresión Directa IPP (Internet Printing Protocol - RFC 8010 / RFC 8011)
/// y Socket RAW (Puerto 9100) en Dart puro para imprimir en impresoras Wi-Fi
/// (Canon MegaTank G3110, Epson EcoTank, HP Smart Tank, Brother) con CERO ventanas de Android.
class IppClient {
  static const int defaultIppPort = 631;
  static const int defaultRawPort = 9100;

  // Tags estándar de delimitación y tipos de datos del protocolo IPP
  static const int tagOperationAttributes = 0x01;
  static const int tagJobAttributes = 0x02;
  static const int tagEndOfAttributes = 0x03;
  static const int tagPrinterAttributes = 0x04;
  static const int tagUnsupportedAttributes = 0x05;

  static const int tagInteger = 0x21;
  static const int tagBoolean = 0x22;
  static const int tagEnum = 0x23;
  static const int tagTextWithoutLanguage = 0x41;
  static const int tagNameWithoutLanguage = 0x42;
  static const int tagKeyword = 0x44;
  static const int tagUri = 0x45;
  static const int tagCharset = 0x47;
  static const int tagNaturalLanguage = 0x48;
  static const int tagMimeMediaType = 0x49;

  // Operation IDs de IPP (RFC 8011)
  static const int opPrintJob = 0x0002;
  static const int opValidateJob = 0x0004;
  static const int opGetJobAttributes = 0x0009;
  static const int opGetPrinterAttributes = 0x000B;

  /// Prueba la conectividad de red con la impresora midiendo la latencia de respuesta
  /// e identificando automáticamente el modelo y si admite documentos PDF directos por hardware.
  static Future<({
    bool success,
    int latencyMs,
    String message,
    String? detectedModel,
    bool supportsDirectPdf,
  })> testConnection(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    final cleanIp = ip.trim();
    if (cleanIp.isEmpty) {
      return (
        success: false,
        latencyMs: 0,
        message: 'La dirección IP no puede estar vacía',
        detectedModel: null,
        supportsDirectPdf: false,
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(cleanIp, port, timeout: timeout);
      stopwatch.stop();
      await socket.close();

      // Si es puerto IPP (631), consultamos Get-Printer-Attributes para identificar modelo y capacidades
      if (port == defaultIppPort) {
        try {
          final diagStopwatch = Stopwatch()..start();
          final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 2000);
          final payload = buildGetPrinterAttributesPayload(printerIp: cleanIp, printerPort: port);

          final request = await client.post(cleanIp, port, '/ipp/print').timeout(const Duration(milliseconds: 2000));
          request.headers.set(HttpHeaders.contentTypeHeader, 'application/ipp');
          request.headers.set(HttpHeaders.userAgentHeader, 'BodeGo-Diagnostics/1.0');
          request.headers.set('Connection', 'close');
          request.contentLength = payload.length;
          request.add(payload);

          final response = await request.close().timeout(const Duration(milliseconds: 2500));
          if (response.statusCode >= 200 && response.statusCode < 300) {
            final respBytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
            diagStopwatch.stop();
            client.close();

            final info = parsePrinterAttributes(Uint8List.fromList(respBytes));
            final model = info.model;
            final supportsPwg = info.formats.any((f) => f.toLowerCase() == 'image/pwg-raster');
            final supportsPdf = info.formats.any((f) => f.toLowerCase() == 'application/pdf');
            final supportsDirect = supportsPwg || supportsPdf;

            if (model != null && model.isNotEmpty) {
              if (supportsDirect) {
                return (
                  success: true,
                  latencyMs: stopwatch.elapsedMilliseconds,
                  message: '$model en línea (${stopwatch.elapsedMilliseconds} ms) • Compatible con 0 ventanas (PWG-Raster)',
                  detectedModel: model,
                  supportsDirectPdf: true,
                );
              } else {
                return (
                  success: true,
                  latencyMs: stopwatch.elapsedMilliseconds,
                  message: '$model en línea (${stopwatch.elapsedMilliseconds} ms) • Requiere Servicio Android Print',
                  detectedModel: model,
                  supportsDirectPdf: false,
                );
              }
            }
          }
          client.close();
        } catch (_) {
          // Si falla la consulta de atributos, continuamos con el éxito del socket
        }
      }

      return (
        success: true,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'Impresora en línea (${stopwatch.elapsedMilliseconds} ms)',
        detectedModel: null,
        supportsDirectPdf: false,
      );
    } catch (e) {
      stopwatch.stop();
      return (
        success: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        message: 'No responde en $cleanIp:$port (${e.toString().split(':').last.trim()})',
        detectedModel: null,
        supportsDirectPdf: false,
      );
    }
  }

  /// Construye el paquete IPP Get-Printer-Attributes (0x000B) según RFC 8011
  static Uint8List buildGetPrinterAttributesPayload({
    required String printerIp,
    required int printerPort,
    int requestId = 1,
  }) {
    final buffer = BytesBuilder();
    buffer.add([0x01, 0x01]); // Versión IPP 1.1
    buffer.add([0x00, 0x0B]); // Operation ID: Get-Printer-Attributes
    final reqIdBytes = ByteData(4)..setInt32(0, requestId, Endian.big);
    buffer.add(reqIdBytes.buffer.asUint8List());
    buffer.addByte(tagOperationAttributes);

    void addAttr(int tag, String name, String value) {
      buffer.addByte(tag);
      final nameBytes = utf8.encode(name);
      final nameLen = ByteData(2)..setInt16(0, nameBytes.length, Endian.big);
      buffer.add(nameLen.buffer.asUint8List());
      buffer.add(nameBytes);

      final valBytes = utf8.encode(value);
      final valLen = ByteData(2)..setInt16(0, valBytes.length, Endian.big);
      buffer.add(valLen.buffer.asUint8List());
      buffer.add(valBytes);
    }

    addAttr(tagCharset, 'attributes-charset', 'utf-8');
    addAttr(tagNaturalLanguage, 'attributes-natural-language', 'es');
    addAttr(tagUri, 'printer-uri', 'ipp://$printerIp:$printerPort/ipp/print');
    buffer.addByte(tagEndOfAttributes);

    return buffer.toBytes();
  }

  /// Construye el paquete IPP Get-Job-Attributes (0x0009) para monitorear el progreso real
  static Uint8List buildGetJobAttributesPayload({
    required String printerIp,
    required int printerPort,
    required int jobId,
    int requestId = 2,
  }) {
    final buffer = BytesBuilder();
    buffer.add([0x01, 0x01]); // IPP 1.1
    buffer.add([0x00, 0x09]); // Operation ID: Get-Job-Attributes
    final reqIdBytes = ByteData(4)..setInt32(0, requestId, Endian.big);
    buffer.add(reqIdBytes.buffer.asUint8List());
    buffer.addByte(tagOperationAttributes);

    void addStringAttr(int tag, String name, String value) {
      buffer.addByte(tag);
      final nameBytes = utf8.encode(name);
      final nameLen = ByteData(2)..setInt16(0, nameBytes.length, Endian.big);
      buffer.add(nameLen.buffer.asUint8List());
      buffer.add(nameBytes);

      final valBytes = utf8.encode(value);
      final valLen = ByteData(2)..setInt16(0, valBytes.length, Endian.big);
      buffer.add(valLen.buffer.asUint8List());
      buffer.add(valBytes);
    }

    void addIntAttr(int tag, String name, int value) {
      buffer.addByte(tag);
      final nameBytes = utf8.encode(name);
      final nameLen = ByteData(2)..setInt16(0, nameBytes.length, Endian.big);
      buffer.add(nameLen.buffer.asUint8List());
      buffer.add(nameBytes);

      final valBytes = ByteData(4)..setInt32(0, value, Endian.big);
      final valLen = ByteData(2)..setInt16(0, 4, Endian.big);
      buffer.add(valLen.buffer.asUint8List());
      buffer.add(valBytes.buffer.asUint8List());
    }

    addStringAttr(tagCharset, 'attributes-charset', 'utf-8');
    addStringAttr(tagNaturalLanguage, 'attributes-natural-language', 'es');
    addStringAttr(tagUri, 'printer-uri', 'ipp://$printerIp:$printerPort/ipp/print');
    addIntAttr(tagInteger, 'job-id', jobId);

    buffer.addByte(tagEndOfAttributes);
    return buffer.toBytes();
  }

  /// Parsea todos los atributos IPP de una respuesta binaria (RFC 8010 / RFC 8011)
  /// Retorna un mapa tipado con valores String, int (tag 0x21/0x23), bool (0x22) o List si hay múltiples valores.
  static Map<String, dynamic> parseIppAttributes(Uint8List data) {
    final Map<String, dynamic> result = {};
    if (data.length < 8) return result;

    int pos = 8;
    String currentName = '';

    while (pos < data.length) {
      final tag = data[pos];
      if (tag == tagEndOfAttributes) break;

      // Saltamos tags delimitadores de grupos (operation, job, printer, etc.)
      if (tag >= 0x01 && tag <= 0x05) {
        pos++;
        continue;
      }

      if (pos + 3 > data.length) break;
      final nameLen = ByteData.sublistView(data, pos + 1, pos + 3).getUint16(0, Endian.big);
      pos += 3;

      if (nameLen > 0) {
        if (pos + nameLen > data.length) break;
        currentName = utf8.decode(data.sublist(pos, pos + nameLen), allowMalformed: true);
        pos += nameLen;
      }

      if (pos + 2 > data.length) break;
      final valLen = ByteData.sublistView(data, pos, pos + 2).getUint16(0, Endian.big);
      pos += 2;

      if (pos + valLen > data.length) break;
      final valBytes = data.sublist(pos, pos + valLen);
      pos += valLen;

      dynamic parsedValue;
      if (tag == tagInteger || tag == tagEnum) {
        if (valLen >= 4) {
          parsedValue = ByteData.sublistView(valBytes).getInt32(0, Endian.big);
        } else if (valLen == 2) {
          parsedValue = ByteData.sublistView(valBytes).getInt16(0, Endian.big);
        } else if (valLen == 1) {
          parsedValue = valBytes[0];
        } else {
          parsedValue = 0;
        }
      } else if (tag == tagBoolean) {
        parsedValue = valBytes.isNotEmpty && valBytes[0] != 0;
      } else {
        parsedValue = utf8.decode(valBytes, allowMalformed: true);
      }

      if (currentName.isNotEmpty) {
        if (result.containsKey(currentName)) {
          final existing = result[currentName];
          if (existing is List) {
            existing.add(parsedValue);
          } else {
            result[currentName] = [existing, parsedValue];
          }
        } else {
          result[currentName] = parsedValue;
        }
      }
    }
    return result;
  }

  /// Parsea los atributos IPP devueltos por la impresora para extraer el modelo y formatos soportados
  static ({String? model, List<String> formats}) parsePrinterAttributes(Uint8List data) {
    final attrs = parseIppAttributes(data);
    final rawModel = attrs['printer-make-and-model'];
    final rawFormats = attrs['document-format-supported'];

    final String? model = rawModel is String
        ? rawModel
        : (rawModel is List && rawModel.isNotEmpty ? rawModel.first.toString() : null);

    final List<String> formats = [];
    if (rawFormats is List) {
      formats.addAll(rawFormats.map((f) => f.toString()));
    } else if (rawFormats is String) {
      formats.add(rawFormats);
    }
    return (model: model, formats: formats);
  }

  /// Consulta el estado actual de un trabajo específico mediante IPP (0x0009 Get-Job-Attributes)
  static Future<({
    bool success,
    int? jobState,
    String? stateReasons,
    int? impressionsCompleted,
  })> queryJobState({
    required String printerIp,
    int printerPort = defaultIppPort,
    required int jobId,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final payload = buildGetJobAttributesPayload(
      printerIp: printerIp,
      printerPort: printerPort,
      jobId: jobId,
    );

    try {
      final request = await client.post(printerIp, printerPort, '/ipp/print').timeout(timeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/ipp');
      request.headers.set(HttpHeaders.userAgentHeader, 'BodeGo-IPP/1.0');
      request.headers.set('Connection', 'close');
      request.contentLength = payload.length;
      request.add(payload);

      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final respBytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
        client.close();
        final attrs = parseIppAttributes(Uint8List.fromList(respBytes));
        final dynamic rawState = attrs['job-state'];
        final int? state = rawState is int ? rawState : null;
        final reasons = attrs['job-state-reasons']?.toString();
        final dynamic rawImpressions = attrs['job-impressions-completed'];
        final int? impressions = rawImpressions is int ? rawImpressions : null;

        return (
          success: true,
          jobState: state,
          stateReasons: reasons,
          impressionsCompleted: impressions,
        );
      }
      client.close();
      return (success: false, jobState: null, stateReasons: null, impressionsCompleted: null);
    } catch (_) {
      client.close();
      return (success: false, jobState: null, stateReasons: null, impressionsCompleted: null);
    }
  }

  /// Consulta el estado físico del hardware de la impresora mediante IPP (0x000B Get-Printer-Attributes)
  /// Permite saber si el cabezal está en movimiento (printer-state: 4=processing, 3=idle, 5=stopped)
  /// y detectar si no hay papel (media-empty) o atasco (media-jam).
  static Future<({
    bool success,
    int? printerState,
    List<String> reasons,
  })> queryPrinterState({
    required String printerIp,
    int printerPort = defaultIppPort,
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    final payload = buildGetPrinterAttributesPayload(
      printerIp: printerIp,
      printerPort: printerPort,
    );

    try {
      final request = await client.post(printerIp, printerPort, '/ipp/print').timeout(timeout);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/ipp');
      request.headers.set(HttpHeaders.userAgentHeader, 'BodeGo-IPP/1.0');
      request.headers.set('Connection', 'close');
      request.contentLength = payload.length;
      request.add(payload);

      final response = await request.close().timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final respBytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
        client.close();
        final attrs = parseIppAttributes(Uint8List.fromList(respBytes));
        final dynamic rawState = attrs['printer-state'];
        final int? state = rawState is int ? rawState : null;
        final rawReasons = attrs['printer-state-reasons'];
        final List<String> reasonsList = [];
        if (rawReasons is List) {
          reasonsList.addAll(rawReasons.map((e) => e.toString()));
        } else if (rawReasons != null) {
          reasonsList.add(rawReasons.toString());
        }

        return (
          success: true,
          printerState: state,
          reasons: reasonsList,
        );
      }
      client.close();
      return (success: false, printerState: null, reasons: <String>[]);
    } catch (_) {
      client.close();
      return (success: false, printerState: null, reasons: <String>[]);
    }
  }

  /// Construye el paquete binario de petición IPP RFC 8011 (Print-Job)
  static Uint8List buildIppPrintJobPayload({
    required String printerIp,
    required int printerPort,
    required Uint8List documentBytes,
    String documentFormat = 'application/pdf',
    String jobName = 'Ticket_BodeGo',
    int requestId = 1,
  }) {
    final buffer = BytesBuilder();

    // 1. Versión IPP 1.1 (0x01, 0x01)
    buffer.add([0x01, 0x01]);

    // 2. Operation ID: Print-Job (0x0002)
    buffer.add([0x00, 0x02]);

    // 3. Request ID (4 bytes, Big Endian)
    final reqIdBytes = ByteData(4)..setInt32(0, requestId, Endian.big);
    buffer.add(reqIdBytes.buffer.asUint8List());

    // 4. Operation Attributes Tag (0x01)
    buffer.addByte(tagOperationAttributes);

    void addAttribute(int tag, String name, String value) {
      buffer.addByte(tag);
      final nameBytes = utf8.encode(name);
      final nameLen = ByteData(2)..setInt16(0, nameBytes.length, Endian.big);
      buffer.add(nameLen.buffer.asUint8List());
      buffer.add(nameBytes);

      final valBytes = utf8.encode(value);
      final valLen = ByteData(2)..setInt16(0, valBytes.length, Endian.big);
      buffer.add(valLen.buffer.asUint8List());
      buffer.add(valBytes);
    }

    // Atributos obligatorios según RFC 8011 (Operation Attributes)
    addAttribute(tagCharset, 'attributes-charset', 'utf-8');
    addAttribute(tagNaturalLanguage, 'attributes-natural-language', 'es-pe');
    addAttribute(tagUri, 'printer-uri', 'ipp://$printerIp:$printerPort/ipp/print');
    addAttribute(tagNameWithoutLanguage, 'requesting-user-name', 'BodeGo POS');
    addAttribute(tagNameWithoutLanguage, 'job-name', jobName);
    addAttribute(tagMimeMediaType, 'document-format', documentFormat);

    // 5. End of Attributes Tag (0x03)
    buffer.addByte(tagEndOfAttributes);

    // 6. Payload de datos del documento (PDF / bytes)
    buffer.add(documentBytes);

    return buffer.toBytes();
  }

  /// Envía un documento a la impresora mediante IPP (puerto 631) o RAW (puerto 9100)
  static Future<IppPrintResult> printDirect({
    required String printerIp,
    int printerPort = defaultIppPort,
    required Uint8List documentBytes,
    String documentFormat = 'application/pdf',
    String jobName = 'Ticket_BodeGo',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final cleanIp = printerIp.trim();
    if (cleanIp.isEmpty) {
      return const IppPrintResult(
        success: false,
        message: 'Dirección IP de impresora no configurada',
      );
    }

    final stopwatch = Stopwatch()..start();

    // MODO RAW SOCKET (Puerto 9100)
    if (printerPort == defaultRawPort) {
      try {
        final socket = await Socket.connect(cleanIp, printerPort, timeout: const Duration(seconds: 3));
        socket.add(documentBytes);
        await socket.flush();
        await socket.close();
        stopwatch.stop();

        return IppPrintResult(
          success: true,
          statusCode: 200,
          message: 'Documento transmitido con éxito al puerto RAW 9100',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } catch (e) {
        stopwatch.stop();
        return IppPrintResult(
          success: false,
          message: 'Error al enviar a socket RAW 9100: $e',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    }

    // MODO IPP (Puerto 631)
    try {
      final ippPayload = buildIppPrintJobPayload(
        printerIp: cleanIp,
        printerPort: printerPort,
        documentBytes: documentBytes,
        documentFormat: documentFormat,
        jobName: jobName,
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);

      // Probamos endpoints IPP estándar: /ipp/print, /ipp/printer o /ipp
      final endpoints = ['/ipp/print', '/ipp/printer', '/ipp'];
      HttpClientResponse? successResponse;
      int responseCode = 0;

      for (final endpoint in endpoints) {
        try {
          final request = await client.post(cleanIp, printerPort, endpoint).timeout(const Duration(seconds: 4));
          request.headers.set(HttpHeaders.contentTypeHeader, 'application/ipp');
          request.headers.set(HttpHeaders.userAgentHeader, 'BodeGo-IPP/1.0');
          request.headers.set('Connection', 'close');
          request.contentLength = ippPayload.length;
          request.add(ippPayload);

          final response = await request.close().timeout(timeout);
          responseCode = response.statusCode;

          if (response.statusCode >= 200 && response.statusCode < 300) {
            successResponse = response;
            break;
          }
        } catch (_) {
          // Intentar el siguiente endpoint
        }
      }

      stopwatch.stop();
      client.close();

      if (successResponse != null) {
        final respBytes = await successResponse.fold<List<int>>([], (a, b) => a..addAll(b));
        if (respBytes.length >= 4) {
          final ippStatusCode = (respBytes[2] << 8) | respBytes[3];
          if (ippStatusCode == 0x0000 || ippStatusCode == 0x0001) {
            final attrs = parseIppAttributes(Uint8List.fromList(respBytes));
            final dynamic rawJobId = attrs['job-id'];
            final int? jobId = rawJobId is int ? rawJobId : null;
            final dynamic rawJobUri = attrs['job-uri'];
            final String? jobUri = rawJobUri?.toString();
            final dynamic rawJobState = attrs['job-state'];
            final int? jobState = rawJobState is int ? rawJobState : null;

            return IppPrintResult(
              success: true,
              statusCode: ippStatusCode,
              message: '¡Trabajo de impresión IPP aceptado por la impresora! (0 ventanas)',
              latencyMs: stopwatch.elapsedMilliseconds,
              jobId: jobId,
              jobUri: jobUri,
              initialJobState: jobState,
            );
          } else {
            return IppPrintResult(
              success: false,
              statusCode: ippStatusCode,
              message: 'La impresora rechazó el formato PDF directo (Código IPP: 0x${ippStatusCode.toRadixString(16).padLeft(4, '0')}). Requiere driver de rasterización.',
              latencyMs: stopwatch.elapsedMilliseconds,
            );
          }
        }

        return IppPrintResult(
          success: true,
          statusCode: responseCode,
          message: '¡Trabajo de impresión IPP despachado con éxito! (0 ventanas)',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Si el servidor IPP respondió un código HTTP diferente o cerró
      if (responseCode > 0) {
        return IppPrintResult(
          success: false,
          statusCode: responseCode,
          message: 'La impresora respondió HTTP $responseCode en puerto IPP',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }

      return IppPrintResult(
        success: false,
        message: 'No se obtuvo respuesta del servicio IPP en $cleanIp:$printerPort',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('Error general en IppClient: $e');
      return IppPrintResult(
        success: false,
        message: 'Error de red IPP: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }
}

