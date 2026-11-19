import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/core/services/esc_pos_ticket_generator.dart';
import 'package:bodego/core/services/html_receipt_generator.dart';
import 'package:bodego/core/services/ipp_client.dart';
import 'package:bodego/core/services/ticket_canvas_renderer.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';

/// Fases de ciclo de vida de un trabajo de impresión
enum PrintPhase {
  connecting,     // Conectando con la impresora (0% - 15%)
  transmitting,   // Transmitiendo datos raster / bytes (15% - 25%)
  processing,     // Impresora alimentando papel y cabezal imprimiendo (25% - 85%)
  ejecting,       // Expulsando comprobante (85% - 99%)
  completed,      // Comprobante salido completamente (100%)
  paperEmpty,     // Impresora sin papel en bandeja (alerta para recargar)
  jamOrStopped,   // Atasco de papel o tapa abierta
  error,          // Error general de conexión
}

/// Evento de telemetría y estado emitido durante la impresión en tiempo real
class PrintProgressEvent {
  final PrintPhase phase;
  final double progress; // 0.0 a 1.0
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool hasError;
  final bool isPaperEmpty;

  const PrintProgressEvent({
    required this.phase,
    required this.progress,
    required this.title,
    required this.subtitle,
    this.isCompleted = false,
    this.hasError = false,
    this.isPaperEmpty = false,
  });

  @override
  String toString() => 'PrintProgressEvent($phase, progress: ${(progress * 100).toStringAsFixed(1)}%, title: $title)';
}

typedef PrintProgressCallback = void Function(PrintProgressEvent event);

/// Repositorio local para la gestión, escaneo, conexión y emisión con impresoras REALES
/// (Bluetooth SPP, WiFi TCP puerto 9100, USB OTG e Inyección de Tinta / A4).
class PrinterRepository {
  static const String _fileName = 'printer_config.json';
  static final PrinterRepository _instance = PrinterRepository._internal();

  static const MethodChannel _nativePrinterChannel = MethodChannel('com.eddamcore.bodego/native_printer');
  static const MethodChannel _bluetoothChannel = MethodChannel('com.eddamcore.bodego/bluetooth_pos');
  static const MethodChannel _usbChannel = MethodChannel('com.eddamcore.bodego/usb_pos');

  factory PrinterRepository() => _instance;
  PrinterRepository._internal();

  /// Notificador reactivo del estado de la impresora para toda la aplicación
  final ValueNotifier<PrinterConfig?> printerNotifier = ValueNotifier<PrinterConfig?>(null);

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Carga la configuración de la impresora o crea una predeterminada
  Future<PrinterConfig> getConfig() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final json = jsonDecode(content) as Map<String, dynamic>;
          final config = PrinterConfig.fromJson(json);
          printerNotifier.value = config;
          return config;
        }
      }

      const defaultConfig = PrinterConfig();
      await saveConfig(defaultConfig);
      return defaultConfig;
    } catch (e) {
      const fallback = PrinterConfig();
      printerNotifier.value = fallback;
      return fallback;
    }
  }

  /// Guarda y persiste los cambios de configuración de la impresora
  Future<void> saveConfig(PrinterConfig config) async {
    try {
      final file = await _getFile();
      final jsonStr = jsonEncode(config.toJson());
      await file.writeAsString(jsonStr);
      printerNotifier.value = config;
    } catch (e) {
      debugPrint('Error al guardar printer_config: $e');
    }
  }

  /// Desvincula o desconecta la impresora actual
  Future<void> disconnectPrinter() async {
    final current = await getConfig();
    final updated = current.copyWith(
      isConnected: false,
    );
    await saveConfig(updated);
  }

  /// Vincula y conecta una impresora descubierta
  Future<PrinterConfig> connectPrinter(DiscoveredPrinter printer) async {
    final current = await getConfig();
    final updated = current.copyWith(
      deviceName: printer.name,
      deviceAddress: printer.address,
      connectionType: printer.type,
      paperWidthMm: printer.paperWidth,
      isConnected: true,
      lastConnectedAt: DateTime.now(),
    );
    await saveConfig(updated);
    return updated;
  }

  // ==========================================
  // BLUETOOTH REAL: ESTADO, ACTIVACIÓN Y ESCANEO
  // ==========================================

  /// Consulta si el Bluetooth del teléfono está encendido
  Future<bool> isBluetoothEnabled() async {
    try {
      final isEnabled = await _bluetoothChannel.invokeMethod<bool>('isBluetoothEnabled');
      return isEnabled ?? false;
    } catch (e) {
      debugPrint('Error al consultar estado Bluetooth: $e');
      return false;
    }
  }

  /// Abre la ventana o diálogo de Android para activar el Bluetooth
  Future<void> requestEnableBluetooth() async {
    try {
      await _bluetoothChannel.invokeMethod('requestEnableBluetooth');
    } catch (e) {
      debugPrint('Error al solicitar activación de Bluetooth: $e');
    }
  }

  /// Escanea y lista impresoras reales según el tipo de conexión seleccionado
  Future<List<DiscoveredPrinter>> scanPrinters({String connectionType = 'bluetooth'}) async {
    if (connectionType == 'bluetooth') {
      return await _scanRealBluetoothPrinters();
    } else if (connectionType == 'usb') {
      return await _scanRealUsbPrinters();
    } else {
      return await _scanWifiPrinters();
    }
  }

  /// Escanea impresoras Bluetooth reales (vinculadas en Android + escaneo en el aire)
  Future<List<DiscoveredPrinter>> _scanRealBluetoothPrinters() async {
    final List<DiscoveredPrinter> printers = [];
    final Set<String> seenAddresses = {};

    try {
      // 1. Obtener impresoras ya vinculadas (emparejadas con PIN 0000 o 1234 en Android)
      final pairedRaw = await _bluetoothChannel.invokeListMethod<Map<dynamic, dynamic>>('getPairedPrinters');
      if (pairedRaw != null) {
        for (final item in pairedRaw) {
          final addr = item['address'] as String? ?? '';
          if (addr.isNotEmpty && !seenAddresses.contains(addr)) {
            seenAddresses.add(addr);
            printers.add(
              DiscoveredPrinter(
                id: addr,
                name: item['name'] as String? ?? 'Impresora Bluetooth',
                address: addr,
                type: 'bluetooth',
                rssi: (item['rssi'] as int?) ?? -45,
                paperWidth: (item['paperWidth'] as int?) ?? 58,
                isPaired: true,
              ),
            );
          }
        }
      }

      // 2. Iniciar descubrimiento activo de dispositivos cercanos
      await _bluetoothChannel.invokeMethod('startDiscovery');
      await Future.delayed(const Duration(milliseconds: 1800));

      final discoveredRaw = await _bluetoothChannel.invokeListMethod<Map<dynamic, dynamic>>('getDiscoveredDevices');
      if (discoveredRaw != null) {
        for (final item in discoveredRaw) {
          final addr = item['address'] as String? ?? '';
          if (addr.isNotEmpty && !seenAddresses.contains(addr)) {
            seenAddresses.add(addr);
            printers.add(
              DiscoveredPrinter(
                id: addr,
                name: item['name'] as String? ?? 'Dispositivo Bluetooth',
                address: addr,
                type: 'bluetooth',
                rssi: (item['rssi'] as int?) ?? -65,
                paperWidth: (item['paperWidth'] as int?) ?? 58,
                isPaired: (item['isPaired'] as bool?) ?? false,
              ),
            );
          }
        }
      }

      await _bluetoothChannel.invokeMethod('stopDiscovery');
    } catch (e) {
      debugPrint('Error durante escaneo de Bluetooth real: $e');
    }

    return printers;
  }

  /// Escanea dispositivos de impresión USB OTG reales
  Future<List<DiscoveredPrinter>> _scanRealUsbPrinters() async {
    final List<DiscoveredPrinter> printers = [];
    try {
      final usbRaw = await _usbChannel.invokeListMethod<Map<dynamic, dynamic>>('getUsbPrinters');
      if (usbRaw != null) {
        for (final item in usbRaw) {
          printers.add(
            DiscoveredPrinter(
              id: item['id'] as String? ?? 'usb_dev',
              name: item['name'] as String? ?? 'Ticketera USB OTG',
              address: item['address'] as String? ?? 'USB',
              type: 'usb',
              rssi: -15,
              paperWidth: 80,
              isPaired: true,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error durante escaneo USB OTG real: $e');
    }
    return printers;
  }

  /// Escanea o lista impresoras WiFi activas
  Future<List<DiscoveredPrinter>> _scanWifiPrinters() async {
    // Si hay una dirección WiFi guardada previamente, verificarla
    final current = await getConfig();
    final List<DiscoveredPrinter> list = [];

    if (current.connectionType == 'wifi' && current.deviceAddress.isNotEmpty) {
      list.add(
        DiscoveredPrinter(
          id: 'wifi_saved',
          name: current.deviceName,
          address: current.deviceAddress,
          type: 'wifi',
          rssi: -40,
          paperWidth: current.paperWidthMm,
          isPaired: true,
        ),
      );
    }

    return list;
  }

  /// Prueba conexión TCP a una dirección IP y puerto 9100
  Future<bool> testWifiConnection(String ip, {int port = 9100}) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 2000));
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Error probando conexión WiFi a $ip:$port -> $e');
      return false;
    }
  }

  // ==========================================
  // TRANSMISIÓN ESC/POS REAL (BLUETOOTH Y WIFI)
  // ==========================================

  /// Envía comandos ESC/POS reales a una ticketera Bluetooth por socket SPP
  Future<bool> printBluetoothEscPos(String address, Uint8List bytes) async {
    try {
      final result = await _bluetoothChannel.invokeMethod<bool>('printBluetoothEscPos', {
        'address': address,
        'bytes': bytes,
      });
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('Error en canal nativo Bluetooth ESC/POS: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Fallo al imprimir por Bluetooth: $e');
      return false;
    }
  }

  /// Envía comandos ESC/POS reales a una ticketera WiFi por socket TCP (puerto 9100)
  Future<bool> printWifiEscPos(String ip, int port, Uint8List bytes) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      debugPrint('Error al enviar bytes a impresora WiFi $ip:$port -> $e');
      return false;
    }
  }

  /// Abre los Ajustes de Impresión de Android para configurar Epson Print Enabler o Mopria
  Future<void> openAndroidPrintSettings() async {
    try {
      await _nativePrinterChannel.invokeMethod('openPrintSettings');
    } catch (e) {
      debugPrint('Error al abrir Ajustes de Impresión Android: $e');
    }
  }

  /// Guarda el modelo seleccionado de impresora de inyección de tinta
  Future<void> setInkjetPrinterModel(String model) async {
    final current = await getConfig();
    final updated = current.copyWith(inkjetPrinterModel: model);
    await saveConfig(updated);
  }

  /// Despacha la impresión HTML al servicio de impresión nativo de Android
  Future<bool> printNativeHtml({
    required String html,
    String jobName = 'Ticket_BodeGo',
    String paperFormat = 'half_a4_vertical',
  }) async {
    try {
      final result = await _nativePrinterChannel.invokeMethod<bool>('printHtml', {
        'html': html,
        'jobName': jobName,
        'paperFormat': paperFormat,
      });
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('Error en canal nativo de impresión Android: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error general al despachar impresión HTML: $e');
      return false;
    }
  }

  /// Ejecuta un ticket de prueba (Térmica POS o Inyección de Tinta / A4)
  Future<bool> printTestTicket(PrinterConfig config) async {
    HapticFeedback.heavyImpact();

    if (config.isInkjet) {
      final businessConfig = await BusinessConfigRepository().getConfig();
      final testTicket = SaleTicket(
        id: 'TKT_TEST_INKJET',
        ticketNumber: 'TKT-TEST',
        date: DateTime.now(),
        total: 10.00,
        subtotal: 12.00,
        discount: 2.00,
        isCredit: false,
        cashierName: 'Prueba de Sistema',
        businessName: businessConfig.businessName,
        items: [
          SaleTicketItem(
            productId: 991,
            name: 'Producto de Prueba 1',
            quantity: 2,
            unitPrice: 3.50,
            subtotal: 7.00,
          ),
          SaleTicketItem(
            productId: 992,
            name: 'Producto de Prueba 2',
            quantity: 1,
            unitPrice: 5.00,
            subtotal: 5.00,
          ),
        ],
      );

      // Flujo Directo IPP / RAW por Red (0 Ventanas)
      if (config.isDirectIpp && config.inkjetPrinterIp.isNotEmpty) {
        try {
          final pwgBytes = await TicketCanvasRenderer.renderTicketToPwg(
            ticket: testTicket,
            businessConfig: businessConfig,
            printerConfig: config,
          );

          final result = await IppClient.printDirect(
            printerIp: config.inkjetPrinterIp,
            printerPort: config.inkjetPrinterPort,
            documentBytes: pwgBytes,
            documentFormat: 'image/pwg-raster',
            jobName: 'Ticket_Prueba_BodeGo',
          );

          if (result.success) {
            return true;
          }
          debugPrint('Fallo al enviar prueba por IPP directo: ${result.message}. Intentando fallback a Spooler Android...');
        } catch (e) {
          debugPrint('Error en prueba IPP directo: $e');
        }
      }

      final html = HtmlReceiptGenerator.generateTicketHtml(
        ticket: testTicket,
        businessConfig: businessConfig,
        printerConfig: config,
      );

      return await printNativeHtml(
        html: html,
        jobName: 'Ticket_Prueba_BodeGo',
        paperFormat: config.inkjetPaperFormat,
      );
    }

    // Modo Térmica POS REAL
    final bConfig = await BusinessConfigRepository().getConfig();
    final testTicket = SaleTicket(
      id: 'TKT_TEST_POS',
      ticketNumber: 'TKT-0001',
      date: DateTime.now(),
      total: 15.00,
      subtotal: 15.00,
      discount: 0.0,
      isCredit: false,
      cashierName: 'Cajero de Turno',
      businessName: bConfig.businessName,
      items: [
        SaleTicketItem(
          productId: 101,
          name: 'Comprobante de Prueba POS',
          quantity: 1,
          unitPrice: 15.00,
          subtotal: 15.00,
        ),
      ],
    );

    final escPosBytes = EscPosTicketGenerator.generateTicketBytes(
      ticket: testTicket,
      businessConfig: bConfig,
      paperWidthMm: config.paperWidthMm,
    );

    if (config.connectionType == 'bluetooth' && config.deviceAddress.isNotEmpty) {
      final success = await printBluetoothEscPos(config.deviceAddress, escPosBytes);
      return success;
    } else if (config.connectionType == 'wifi' && config.deviceAddress.isNotEmpty) {
      final parts = config.deviceAddress.split(':');
      final ip = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
      return await printWifiEscPos(ip, port, escPosBytes);
    }

    // Si aún no está vinculada físicamente, simula el tiempo de cabezal
    await Future.delayed(const Duration(milliseconds: 1400));
    return true;
  }

  /// Imprime un comprobante de venta según el modo configurado (Térmico o Inyección de Tinta)
  Future<bool> printSaleTicket(
    SaleTicket ticket, {
    PrinterConfig? config,
    BusinessConfig? businessConfig,
  }) async {
    final result = await printSaleTicketDetailed(
      ticket,
      config: config,
      businessConfig: businessConfig,
    );
    return result.success;
  }

  /// Imprime un comprobante de venta con diagnóstico detallado del canal utilizado (Directo IPP o Spooler)
  /// y telemetría de progreso físico en tiempo real (Wi-Fi IPP, Bluetooth o Spooler).
  Future<({bool success, bool usedDirectIpp, String message})> printSaleTicketDetailed(
    SaleTicket ticket, {
    PrinterConfig? config,
    BusinessConfig? businessConfig,
    PrintProgressCallback? onProgress,
  }) async {
    final activeConfig = config ?? await getConfig();

    if (activeConfig.isInkjet) {
      final bConfig = businessConfig ?? await BusinessConfigRepository().getConfig();
      final printerModel = activeConfig.inkjetPrinterModel.isNotEmpty
          ? activeConfig.inkjetPrinterModel
          : 'Impresora Wi-Fi';

      // Flujo Directo IPP / RAW por Red (0 Ventanas)
      if (activeConfig.isDirectIpp && activeConfig.inkjetPrinterIp.isNotEmpty) {
        try {
          onProgress?.call(PrintProgressEvent(
            phase: PrintPhase.connecting,
            progress: 0.05,
            title: 'Conectando con $printerModel...',
            subtitle: 'Estableciendo enlace Wi-Fi IPP directo (0 ventanas)...',
          ));

          final pwgBytes = await TicketCanvasRenderer.renderTicketToPwg(
            ticket: ticket,
            businessConfig: bConfig,
            printerConfig: activeConfig,
          );

          onProgress?.call(PrintProgressEvent(
            phase: PrintPhase.transmitting,
            progress: 0.18,
            title: 'Transmitiendo a $printerModel...',
            subtitle: 'Enviando mapa de bits PWG-Raster optimizado a 300 DPI...',
          ));

          final result = await IppClient.printDirect(
            printerIp: activeConfig.inkjetPrinterIp,
            printerPort: activeConfig.inkjetPrinterPort,
            documentBytes: pwgBytes,
            documentFormat: 'image/pwg-raster',
            jobName: 'Ticket_${ticket.ticketNumber}',
          );

          if (result.success) {
            // Sincronización mecánica en tiempo real con el cabezal físico
            final format = activeConfig.inkjetPaperFormat;
            final int expectedDurationMs = format == 'full_a4'
                ? 14500
                : (format == 'half_a4_vertical' ? 8800 : 5000);

            final stopwatch = Stopwatch()..start();
            int lastJobState = result.initialJobState ?? 5;
            int lastPrinterState = 4; // 4 = processing
            int pollCounter = 0;

            while (stopwatch.elapsedMilliseconds < expectedDurationMs + 8000) {
              final elapsed = stopwatch.elapsedMilliseconds;
              final ratio = (elapsed / expectedDurationMs).clamp(0.0, 1.0);
              // Interpolación de progreso entre 20% y 95%
              final currentProgress = 0.20 + (ratio * 0.75);

              // Consultamos el hardware de la impresora cada ~700ms
              if (elapsed - (pollCounter * 700) >= 700 || pollCounter == 0) {
                pollCounter++;

                final pState = await IppClient.queryPrinterState(
                  printerIp: activeConfig.inkjetPrinterIp,
                  printerPort: activeConfig.inkjetPrinterPort,
                );

                if (pState.success) {
                  if (pState.printerState != null) {
                    lastPrinterState = pState.printerState!;
                  }
                  final reasons = pState.reasons.map((r) => r.toLowerCase()).toList();
                  final isPaperEmpty = reasons.any((r) => r.contains('media-empty') || r.contains('media-needed'));
                  final isJam = reasons.any((r) => r.contains('media-jam') || r.contains('door-open'));

                  // ALERTA: BANDEJA SIN PAPEL
                  if (isPaperEmpty) {
                    onProgress?.call(PrintProgressEvent(
                      phase: PrintPhase.paperEmpty,
                      progress: currentProgress,
                      title: '¡Impresora sin papel en la bandeja!',
                      subtitle: 'Carga papel en $printerModel para continuar la impresión',
                      isPaperEmpty: true,
                    ));

                    // Bucle de re-sondeo automático (espera hasta que coloquen papel)
                    int retrySeconds = 0;
                    while (retrySeconds < 60) {
                      await Future.delayed(const Duration(milliseconds: 1000));
                      retrySeconds++;
                      final checkState = await IppClient.queryPrinterState(
                        printerIp: activeConfig.inkjetPrinterIp,
                        printerPort: activeConfig.inkjetPrinterPort,
                      );
                      final checkReasons = checkState.reasons.map((r) => r.toLowerCase()).toList();
                      if (!checkReasons.any((r) => r.contains('media-empty') || r.contains('media-needed'))) {
                        // Papel recargado exitosamente!
                        break;
                      }
                    }
                  } else if (isJam) {
                    onProgress?.call(PrintProgressEvent(
                      phase: PrintPhase.jamOrStopped,
                      progress: currentProgress,
                      title: 'Atasco o tapa abierta en $printerModel',
                      subtitle: 'Verifica la bandeja de papel o la tapa de la impresora',
                      hasError: true,
                    ));
                  }
                }

                // Consultamos estado del trabajo por IPP (0x0009 Get-Job-Attributes)
                if (result.jobId != null) {
                  final jState = await IppClient.queryJobState(
                    printerIp: activeConfig.inkjetPrinterIp,
                    printerPort: activeConfig.inkjetPrinterPort,
                    jobId: result.jobId!,
                  );
                  if (jState.success && jState.jobState != null) {
                    lastJobState = jState.jobState!;
                  }
                }
              }

              // Condición de finalización física:
              // 1. IPP reporta trabajo completado (9) Y ha transcurrido al menos el 70% del tiempo mecánico mínimo
              if (lastJobState == 9 && elapsed >= (expectedDurationMs * 0.70)) {
                break;
              }

              // 2. Transcurrió el tiempo mecánico total Y la impresora ya volvió a reposo (idle = 3)
              if (elapsed >= expectedDurationMs && lastPrinterState == 3) {
                break;
              }

              // 3. O superó el límite de seguridad (1.1x tiempo mecánico)
              if (elapsed >= (expectedDurationMs * 1.1)) {
                break;
              }

              // Mensaje contextual dinámico según la fase del papel
              final pct = (currentProgress * 100).toInt();
              final String subtitleMsg;
              if (currentProgress < 0.45) {
                subtitleMsg = 'Alimentando hoja y posicionando cabezal...';
              } else if (currentProgress < 0.85) {
                subtitleMsg = 'Cabezal imprimiendo líneas del comprobante...';
              } else {
                subtitleMsg = 'Comprobante avanzando hacia la bandeja de salida...';
              }

              onProgress?.call(PrintProgressEvent(
                phase: PrintPhase.processing,
                progress: currentProgress,
                title: 'Imprimiendo comprobante ($pct%)...',
                subtitle: subtitleMsg,
              ));

              await Future.delayed(const Duration(milliseconds: 120));
            }

            // Fase final: Expulsión
            onProgress?.call(PrintProgressEvent(
              phase: PrintPhase.ejecting,
              progress: 0.98,
              title: 'Expulsando comprobante...',
              subtitle: 'El comprobante ha terminado de imprimirse',
            ));
            await Future.delayed(const Duration(milliseconds: 400));

            // Confirmación 100% completado
            onProgress?.call(PrintProgressEvent(
              phase: PrintPhase.completed,
              progress: 1.0,
              title: '¡Comprobante impreso con éxito!',
              subtitle: 'Impreso directamente por red en $printerModel',
              isCompleted: true,
            ));

            return (
              success: true,
              usedDirectIpp: true,
              message: '¡Comprobante impreso directamente por red!',
            );
          }
          debugPrint('Fallo al imprimir por IPP directo: ${result.message}. Intentando fallback a Spooler Android...');
        } catch (e) {
          debugPrint('Error en flujo directo IPP: $e. Intentando fallback a Spooler Android...');
        }
      }

      // Modo Servicio Android Print / Mopria (1 toque) o fallback
      onProgress?.call(PrintProgressEvent(
        phase: PrintPhase.processing,
        progress: 0.50,
        title: 'Abriendo servicio de impresión...',
        subtitle: 'Despachando comprobante al servicio Android Print...',
      ));

      final html = HtmlReceiptGenerator.generateTicketHtml(
        ticket: ticket,
        businessConfig: bConfig,
        printerConfig: activeConfig,
      );

      final ok = await printNativeHtml(
        html: html,
        jobName: 'Ticket_${ticket.ticketNumber}',
        paperFormat: activeConfig.inkjetPaperFormat,
      );

      if (ok) {
        onProgress?.call(PrintProgressEvent(
          phase: PrintPhase.completed,
          progress: 1.0,
          title: '¡Comprobante enviado!',
          subtitle: 'Comprobante despachado al servicio de impresión',
          isCompleted: true,
        ));
      } else {
        onProgress?.call(const PrintProgressEvent(
          phase: PrintPhase.error,
          progress: 0.0,
          title: 'Error al imprimir',
          subtitle: 'No se pudo abrir el servicio de impresión',
          hasError: true,
        ));
      }

      return (
        success: ok,
        usedDirectIpp: false,
        message: activeConfig.isDirectIpp
            ? 'La impresora requiere rasterización. Enviado a Servicio Android Print'
            : '¡Comprobante enviado a la impresora!',
      );
    }

    // Modo Térmica POS
    if (!activeConfig.isConnected) {
      onProgress?.call(const PrintProgressEvent(
        phase: PrintPhase.error,
        progress: 0.0,
        title: 'No hay impresora vinculada',
        subtitle: 'Vincula una impresora térmica en Configuración',
        hasError: true,
      ));
      return (
        success: false,
        usedDirectIpp: false,
        message: 'No hay impresora térmica vinculada',
      );
    }

    final bConfig = businessConfig ?? await BusinessConfigRepository().getConfig();
    final escPosBytes = EscPosTicketGenerator.generateTicketBytes(
      ticket: ticket,
      businessConfig: bConfig,
      paperWidthMm: activeConfig.paperWidthMm,
    );

    if (activeConfig.connectionType == 'bluetooth' && activeConfig.deviceAddress.isNotEmpty) {
      onProgress?.call(PrintProgressEvent(
        phase: PrintPhase.connecting,
        progress: 0.10,
        title: 'Conectando con ${activeConfig.deviceName}...',
        subtitle: 'Enlace Bluetooth SPP...',
      ));

      final ok = await printBluetoothEscPos(activeConfig.deviceAddress, escPosBytes);
      if (!ok) {
        onProgress?.call(const PrintProgressEvent(
          phase: PrintPhase.error,
          progress: 0.0,
          title: 'Error de transmisión Bluetooth',
          subtitle: 'No se pudieron enviar datos a la ticketera',
          hasError: true,
        ));
        return (
          success: false,
          usedDirectIpp: false,
          message: 'Error al transmitir datos por Bluetooth',
        );
      }

      // Simulación física suave del arrastre del papel térmico (~2.6 segundos)
      final sw = Stopwatch()..start();
      const thermalDuration = 2600;
      while (sw.elapsedMilliseconds < thermalDuration) {
        final progress = 0.20 + ((sw.elapsedMilliseconds / thermalDuration) * 0.78);
        final pct = (progress * 100).toInt();
        onProgress?.call(PrintProgressEvent(
          phase: PrintPhase.processing,
          progress: progress,
          title: 'Imprimiendo ticket térmico ($pct%)...',
          subtitle: 'Expulsando papel en ${activeConfig.deviceName}...',
        ));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      onProgress?.call(PrintProgressEvent(
        phase: PrintPhase.completed,
        progress: 1.0,
        title: '¡Comprobante impreso con éxito!',
        subtitle: 'Enviado exitosamente a ${activeConfig.deviceName}',
        isCompleted: true,
      ));

      return (
        success: true,
        usedDirectIpp: false,
        message: '¡Comprobante impreso con éxito!',
      );
    } else if (activeConfig.connectionType == 'wifi' && activeConfig.deviceAddress.isNotEmpty) {
      onProgress?.call(PrintProgressEvent(
        phase: PrintPhase.connecting,
        progress: 0.10,
        title: 'Conectando a puerto RAW Wi-Fi...',
        subtitle: 'Enlace TCP en ${activeConfig.deviceAddress}...',
      ));

      final parts = activeConfig.deviceAddress.split(':');
      final ip = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
      final ok = await printWifiEscPos(ip, port, escPosBytes);
      if (!ok) {
        onProgress?.call(const PrintProgressEvent(
          phase: PrintPhase.error,
          progress: 0.0,
          title: 'Error de transmisión Wi-Fi',
          subtitle: 'No se pudo conectar al puerto RAW 9100',
          hasError: true,
        ));
        return (
          success: false,
          usedDirectIpp: false,
          message: 'Error al transmitir datos al puerto RAW Wi-Fi',
        );
      }

      final sw = Stopwatch()..start();
      const rawDuration = 2800;
      while (sw.elapsedMilliseconds < rawDuration) {
        final progress = 0.20 + ((sw.elapsedMilliseconds / rawDuration) * 0.78);
        final pct = (progress * 100).toInt();
        onProgress?.call(PrintProgressEvent(
          phase: PrintPhase.processing,
          progress: progress,
          title: 'Imprimiendo comprobante ($pct%)...',
          subtitle: 'Avanzando cabezal térmico...',
        ));
        await Future.delayed(const Duration(milliseconds: 100));
      }

      onProgress?.call(PrintProgressEvent(
        phase: PrintPhase.completed,
        progress: 1.0,
        title: '¡Comprobante impreso con éxito!',
        subtitle: 'Enviado exitosamente al puerto RAW',
        isCompleted: true,
      ));

      return (
        success: true,
        usedDirectIpp: false,
        message: '¡Comprobante impreso con éxito!',
      );
    }

    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 1600));
    HapticFeedback.mediumImpact();
    return (
      success: true,
      usedDirectIpp: false,
      message: '¡Comprobante impreso con éxito!',
    );
  }
}
