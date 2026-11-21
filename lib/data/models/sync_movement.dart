/// Modelo de datos para un movimiento transaccional auditable en BodeGo.
/// Cada movimiento se almacena localmente en la cola offline y se sincroniza
/// con la pestaña MOVIMIENTOS_LOG de Google Sheets.
class SyncMovement {
  final String id;
  final DateTime timestamp;
  final String deviceId;
  final String type; // 'VENTA', 'ABONO_DEUDA', 'REPOSICION_STOCK', 'AJUSTE_STOCK', 'CATALOGO_UPDATE', 'CLIENTE_UPDATE'
  final String detail;
  final Map<String, dynamic> data;
  final bool isSynced;

  SyncMovement({
    required this.id,
    required this.timestamp,
    required this.deviceId,
    required this.type,
    required this.detail,
    required this.data,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'deviceId': deviceId,
        'type': type,
        'detail': detail,
        'data': data,
        'isSynced': isSynced,
      };

  factory SyncMovement.fromJson(Map<String, dynamic> json) => SyncMovement(
        id: json['id'] as String? ?? 'MOV_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        deviceId: json['deviceId'] as String? ?? 'DEV_UNKNOWN',
        type: json['type'] as String? ?? 'GENERAL',
        detail: json['detail'] as String? ?? '',
        data: json['data'] != null ? Map<String, dynamic>.from(json['data'] as Map) : {},
        isSynced: json['isSynced'] as bool? ?? false,
      );

  SyncMovement copyWith({
    String? id,
    DateTime? timestamp,
    String? deviceId,
    String? type,
    String? detail,
    Map<String, dynamic>? data,
    bool? isSynced,
  }) {
    return SyncMovement(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      deviceId: deviceId ?? this.deviceId,
      type: type ?? this.type,
      detail: detail ?? this.detail,
      data: data ?? this.data,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}

