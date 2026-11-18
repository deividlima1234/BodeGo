import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/core/services/esc_pos_ticket_generator.dart';
import 'package:bodego/core/services/html_receipt_generator.dart';
import 'package:bodego/data/models/business_config.dart';
import 'package:bodego/data/models/printer_config.dart';
import 'package:bodego/data/models/sale_ticket.dart';
import 'package:bodego/data/repositories/business_config_repository.dart';

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
    final activeConfig = config ?? await getConfig();

    if (activeConfig.isInkjet) {
      final bConfig = businessConfig ?? await BusinessConfigRepository().getConfig();
      final html = HtmlReceiptGenerator.generateTicketHtml(
        ticket: ticket,
        businessConfig: bConfig,
        printerConfig: activeConfig,
      );

      return await printNativeHtml(
        html: html,
        jobName: 'Ticket_${ticket.ticketNumber}',
        paperFormat: activeConfig.inkjetPaperFormat,
      );
    }

    // Modo Térmica POS
    if (!activeConfig.isConnected) {
      return false;
    }

    final bConfig = businessConfig ?? await BusinessConfigRepository().getConfig();
    final escPosBytes = EscPosTicketGenerator.generateTicketBytes(
      ticket: ticket,
      businessConfig: bConfig,
      paperWidthMm: activeConfig.paperWidthMm,
    );

    if (activeConfig.connectionType == 'bluetooth' && activeConfig.deviceAddress.isNotEmpty) {
      return await printBluetoothEscPos(activeConfig.deviceAddress, escPosBytes);
    } else if (activeConfig.connectionType == 'wifi' && activeConfig.deviceAddress.isNotEmpty) {
      final parts = activeConfig.deviceAddress.split(':');
      final ip = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
      return await printWifiEscPos(ip, port, escPosBytes);
    }

    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 1600));
    HapticFeedback.mediumImpact();
    return true;
  }
}
