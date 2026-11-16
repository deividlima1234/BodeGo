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

/// Información de la Caja Master guardada en un dispositivo secundario
class MasterDeviceInfo {
  final String masterMachineId;
  final String masterIp;
  final String businessName;
  final DateTime linkedAt;
  final DateTime? lastSyncAt;

  const MasterDeviceInfo({
    required this.masterMachineId,
    required this.masterIp,
    required this.businessName,
    required this.linkedAt,
    this.lastSyncAt,
  });

  Map<String, dynamic> toJson() => {
        'masterMachineId': masterMachineId,
        'masterIp': masterIp,
        'businessName': businessName,
        'linkedAt': linkedAt.toIso8601String(),
        'lastSyncAt': lastSyncAt?.toIso8601String(),
      };

  factory MasterDeviceInfo.fromJson(Map<String, dynamic> json) => MasterDeviceInfo(
        masterMachineId: json['masterMachineId'] as String? ?? 'BDG-MASTER',
        masterIp: json['masterIp'] as String? ?? '192.168.1.1',
        businessName: json['businessName'] as String? ?? 'BodeGo',
        linkedAt: json['linkedAt'] != null
            ? DateTime.parse(json['linkedAt'] as String)
            : DateTime.now(),
        lastSyncAt: json['lastSyncAt'] != null
            ? DateTime.parse(json['lastSyncAt'] as String)
            : null,
      );

  MasterDeviceInfo copyWith({
    String? masterMachineId,
    String? masterIp,
    String? businessName,
    DateTime? lastSyncAt,
  }) =>
      MasterDeviceInfo(
        masterMachineId: masterMachineId ?? this.masterMachineId,
        masterIp: masterIp ?? this.masterIp,
        businessName: businessName ?? this.businessName,
        linkedAt: linkedAt,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      );
}

