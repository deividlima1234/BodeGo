import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bodego/data/models/printer_config.dart';

/// Repositorio local para la gestión, escaneo, conexión y persistencia de impresoras térmicas.
class PrinterRepository {
  static const String _fileName = 'printer_config.json';
  static final PrinterRepository _instance = PrinterRepository._internal();

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

  /// Escanea y descubre impresoras térmicas según el tipo de conexión seleccionado
  Future<List<DiscoveredPrinter>> scanPrinters({String connectionType = 'bluetooth'}) async {
    // Simulamos el retardo natural de búsqueda en el aire (2.5 segundos)
    await Future.delayed(const Duration(milliseconds: 2200));

    if (connectionType == 'bluetooth') {
      return const [
        DiscoveredPrinter(
          id: 'bt_1',
          name: 'POS-5802DD (MTP-II)',
          address: 'DC:0D:30:4A:12:F1',
          type: 'bluetooth',
          rssi: -48,
          paperWidth: 58,
          isPaired: true,
        ),
        DiscoveredPrinter(
          id: 'bt_2',
          name: 'Xprinter XP-58IIH BT',
          address: '66:32:B1:8E:04:9A',
          type: 'bluetooth',
          rssi: -62,
          paperWidth: 58,
        ),
        DiscoveredPrinter(
          id: 'bt_3',
          name: 'GOOJPRT PT-210 Mobile',
          address: '88:21:40:99:A1:33',
          type: 'bluetooth',
          rssi: -75,
          paperWidth: 58,
        ),
        DiscoveredPrinter(
          id: 'bt_4',
          name: 'RPP-02N Thermal POS',
          address: '00:1B:35:11:7C:E9',
          type: 'bluetooth',
          rssi: -84,
          paperWidth: 58,
        ),
      ];
    } else if (connectionType == 'wifi') {
      return const [
        DiscoveredPrinter(
          id: 'wifi_1',
          name: 'EPSON TM-T20III (LAN POS)',
          address: '192.168.1.150:9100',
          type: 'wifi',
          rssi: -40,
          paperWidth: 80,
          isPaired: true,
        ),
        DiscoveredPrinter(
          id: 'wifi_2',
          name: 'BIXOLON SRP-330II Ethernet',
          address: '192.168.1.182:9100',
          type: 'wifi',
          rssi: -55,
          paperWidth: 80,
        ),
        DiscoveredPrinter(
          id: 'wifi_3',
          name: 'SUNMI Cloud WiFi Printer',
          address: '192.168.1.105:9100',
          type: 'wifi',
          rssi: -65,
          paperWidth: 80,
        ),
      ];
    } else {
      // USB OTG
      return const [
        DiscoveredPrinter(
          id: 'usb_1',
          name: 'POS-80 Series USB Thermal',
          address: 'USB:/dev/bus/usb/001/004',
          type: 'usb',
          rssi: -30,
          paperWidth: 80,
          isPaired: true,
        ),
        DiscoveredPrinter(
          id: 'usb_2',
          name: 'Generic 58mm ESC/POS USB',
          address: 'USB:/dev/bus/usb/001/005',
          type: 'usb',
          rssi: -30,
          paperWidth: 58,
        ),
      ];
    }
  }

  /// Ejecuta un ticket de prueba de impresión térmica
  Future<bool> printTestTicket(PrinterConfig config) async {
    HapticFeedback.heavyImpact();
    // Simulamos el tiempo de alimentación de cabezal térmico y corte de papel
    await Future.delayed(const Duration(milliseconds: 1400));
    HapticFeedback.mediumImpact();
    return true;
  }
}

