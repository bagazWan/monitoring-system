class LibreNMSPort {
  final int id;
  final int portId;
  final String ifName;
  final String? ifType;
  final String? ifOperStatus;
  bool enabled;
  bool isUplink;

  LibreNMSPort({
    required this.id,
    required this.portId,
    required this.ifName,
    this.ifType,
    this.ifOperStatus,
    required this.enabled,
    required this.isUplink,
  });

  factory LibreNMSPort.fromJson(Map<String, dynamic> json) {
    return LibreNMSPort(
      id: json['id'],
      portId: json['port_id'],
      ifName: json['if_name'] ?? '',
      ifType: json['if_type'],
      ifOperStatus: json['if_oper_status'],
      enabled: json['enabled'] ?? false,
      isUplink: json['is_uplink'] ?? false,
    );
  }
}
