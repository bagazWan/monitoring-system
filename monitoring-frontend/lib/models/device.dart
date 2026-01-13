class BaseNode {
  final int? id;
  final String name;
  final String ipAddress;
  final String? macAddress;
  final String? deviceType;
  String? status;
  final String? locationName;
  final int? locationId;
  final int? switchId;
  final int? nodeId;
  final String? description;
  final String? lastReplacedAt;

  BaseNode({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.macAddress,
    this.deviceType,
    this.status,
    this.locationName,
    this.locationId,
    this.switchId,
    this.nodeId,
    this.description,
    this.lastReplacedAt,
  });
  // Factory to create from Device JSON
  factory BaseNode.fromDeviceJson(Map<String, dynamic> json) {
    return BaseNode(
        id: json['device_id'],
        name: json['name'],
        ipAddress: json['ip_address'],
        macAddress: json['mac_address'],
        deviceType: json['device_type'],
        status: json['status'],
        locationName: json['location_name'],
        description: json['description'],
        lastReplacedAt: json['last_replaced_at']);
  }

  Map<String, dynamic> toDeviceCreateJson() {
    return {
      'name': name,
      'ip_address': ipAddress,
      'mac_address': macAddress,
      'device_type': deviceType,
      'status': status,
      'location_id': locationId,
      'switch_id': switchId,
      'description': description
    };
  }

  // Factory to create from Switch JSON
  factory BaseNode.fromSwitchJson(Map<String, dynamic> json) {
    return BaseNode(
        id: json['switch_id'],
        name: json['name'],
        ipAddress: json['ip_address'],
        status: json['status'],
        deviceType: 'Switch',
        locationName: json['location_name'],
        description: json['description'],
        lastReplacedAt: json['last_replaced_at']);
  }

  Map<String, dynamic> toSwitchCreateJson() {
    return {
      'name': name,
      'ip_address': ipAddress,
      'status': status,
      'location_id': locationId,
      'node_id': nodeId,
      'description': description
    };
  }
}
