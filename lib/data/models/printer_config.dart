/// Modelo de Configuración de la Impresora en BodeGo (Térmica POS e Inyección de Tinta / A4).
class PrinterConfig {
  final String printerType; // 'thermal' (POS) o 'inkjet_system' (Epson, HP, Canon, etc.)
  final String inkjetPaperFormat; // 'half_a4_vertical' (105x297mm con corte final), 'full_a4' (210x297mm), 'strip_80mm'
  final String inkjetPrinterModel; // Modelo seleccionado para tinta (ej: 'Epson EcoTank L7590')
  final String deviceName;
  final String deviceAddress;
  final String connectionType; // 'bluetooth', 'wifi', 'usb'
  final int paperWidthMm; // 58 o 80 (para térmica)
  final bool autoPrintOnSale;
  final bool soundOnPrint;
  final int numberOfCopies; // 1 o 2
  final bool isConnected;
  final DateTime? lastConnectedAt;

  const PrinterConfig({
    this.printerType = 'thermal',
    this.inkjetPaperFormat = 'half_a4_vertical',
    this.inkjetPrinterModel = 'Epson EcoTank L7590',
    this.deviceName = 'Sin impresora vinculada',
    this.deviceAddress = '',
    this.connectionType = 'bluetooth',
    this.paperWidthMm = 58,
    this.autoPrintOnSale = true,
    this.soundOnPrint = true,
    this.numberOfCopies = 1,
    this.isConnected = false,
    this.lastConnectedAt,
  });

  bool get isInkjet => printerType == 'inkjet_system';
  bool get isThermal => printerType == 'thermal';
  bool get isReadyToPrint => isInkjet || isConnected;

  PrinterConfig copyWith({
    String? printerType,
    String? inkjetPaperFormat,
    String? inkjetPrinterModel,
    String? deviceName,
    String? deviceAddress,
    String? connectionType,
    int? paperWidthMm,
    bool? autoPrintOnSale,
    bool? soundOnPrint,
    int? numberOfCopies,
    bool? isConnected,
    DateTime? lastConnectedAt,
  }) {
    return PrinterConfig(
      printerType: printerType ?? this.printerType,
      inkjetPaperFormat: inkjetPaperFormat ?? this.inkjetPaperFormat,
      inkjetPrinterModel: inkjetPrinterModel ?? this.inkjetPrinterModel,
      deviceName: deviceName ?? this.deviceName,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      connectionType: connectionType ?? this.connectionType,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      autoPrintOnSale: autoPrintOnSale ?? this.autoPrintOnSale,
      soundOnPrint: soundOnPrint ?? this.soundOnPrint,
      numberOfCopies: numberOfCopies ?? this.numberOfCopies,
      isConnected: isConnected ?? this.isConnected,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'printerType': printerType,
      'inkjetPaperFormat': inkjetPaperFormat,
      'inkjetPrinterModel': inkjetPrinterModel,
      'deviceName': deviceName,
      'deviceAddress': deviceAddress,
      'connectionType': connectionType,
      'paperWidthMm': paperWidthMm,
      'autoPrintOnSale': autoPrintOnSale,
      'soundOnPrint': soundOnPrint,
      'numberOfCopies': numberOfCopies,
      'isConnected': isConnected,
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  factory PrinterConfig.fromJson(Map<String, dynamic> json) {
    return PrinterConfig(
      printerType: json['printerType'] as String? ?? 'thermal',
      inkjetPaperFormat: json['inkjetPaperFormat'] as String? ?? 'half_a4_vertical',
      inkjetPrinterModel: json['inkjetPrinterModel'] as String? ?? 'Epson EcoTank L7590',
      deviceName: json['deviceName'] as String? ?? 'Sin impresora vinculada',
      deviceAddress: json['deviceAddress'] as String? ?? '',
      connectionType: json['connectionType'] as String? ?? 'bluetooth',
      paperWidthMm: json['paperWidthMm'] as int? ?? 58,
      autoPrintOnSale: json['autoPrintOnSale'] as bool? ?? true,
      soundOnPrint: json['soundOnPrint'] as bool? ?? true,
      numberOfCopies: json['numberOfCopies'] as int? ?? 1,
      isConnected: json['isConnected'] as bool? ?? false,
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.tryParse(json['lastConnectedAt'] as String)
          : null,
    );
  }
}

/// Dispositivo de impresora térmica detectado durante el escaneo
class DiscoveredPrinter {
  final String id;
  final String name;
  final String address;
  final String type; // 'bluetooth', 'wifi', 'usb'
  final int rssi; // Señal (ej: -50 dBm)
  final int paperWidth; // 58 o 80
  final bool isPaired;

  const DiscoveredPrinter({
    required this.id,
    required this.name,
    required this.address,
    required this.type,
    required this.rssi,
    required this.paperWidth,
    this.isPaired = false,
  });
}
