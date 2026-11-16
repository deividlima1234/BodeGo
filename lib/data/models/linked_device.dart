/// Modelo de un dispositivo vinculado al ecosistema de la bodega (Multi-Equipo).
class LinkedDevice {
  final String id;
  final String name;
  final String machineId;
  final String role; // 'master' o 'secondary'
  final DateTime pairedAt;
  final DateTime? lastSyncAt;
  final String? ipAddress;
  final bool isActive;
  final String? passkey;

  const LinkedDevice({
    required this.id,
    required this.name,
    required this.machineId,
    this.role = 'secondary',
    required this.pairedAt,
    this.lastSyncAt,
    this.ipAddress,
    this.isActive = true,
    this.passkey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'machineId': machineId,
        'role': role,
        'pairedAt': pairedAt.toIso8601String(),
        'lastSyncAt': lastSyncAt?.toIso8601String(),
        'ipAddress': ipAddress,
        'isActive': isActive,
        'passkey': passkey,
      };

  factory LinkedDevice.fromJson(Map<String, dynamic> json) => LinkedDevice(
        id: json['id'] as String? ?? 'DEV-${DateTime.now().millisecondsSinceEpoch}',
        name: json['name'] as String? ?? 'Dispositivo Móvil',
        machineId: json['machineId'] as String? ?? 'BDG-UNKNOWN',
        role: json['role'] as String? ?? 'secondary',
        pairedAt: json['pairedAt'] != null
            ? DateTime.parse(json['pairedAt'] as String)
            : DateTime.now(),
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.parse(json['lastSyncAt'] as String)
            : null,
        ipAddress: json['ipAddress'] as String?,
        isActive: json['isActive'] as bool? ?? true,
        passkey: json['passkey'] as String?,
      );

  LinkedDevice copyWith({
    String? name,
    String? role,
    DateTime? lastSyncAt,
    String? ipAddress,
    bool? isActive,
    String? passkey,
  }) {
    return LinkedDevice(
      id: id,
      name: name ?? this.name,
      machineId: machineId,
      role: role ?? this.role,
      pairedAt: pairedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      ipAddress: ipAddress ?? this.ipAddress,
      isActive: isActive ?? this.isActive,
      passkey: passkey ?? this.passkey,
    );
  }
}

