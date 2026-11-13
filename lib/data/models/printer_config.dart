/// Modelo de Configuración de la Impresora Térmica en BodeGo.
class PrinterConfig {
  final String deviceName;
  final String deviceAddress;
  final String connectionType; // 'bluetooth', 'wifi', 'usb'
  final int paperWidthMm; // 58 o 80
  final bool autoPrintOnSale;
  final bool soundOnPrint;
  final int numberOfCopies; // 1 o 2
  final bool isConnected;
  final DateTime? lastConnectedAt;

  const PrinterConfig({
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

  PrinterConfig copyWith({
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

