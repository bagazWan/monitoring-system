class BaseNode {
  final int? id;
  final String name;
  final String ipAddress;
  final String? macAddress;
  final String? deviceType;
  final String nodeKind;
  String? status;
  final String? locationName;
  final int? locationId;
  final int? switchId;
  final int? nodeId;
  final String? description;
  final String? lastReplacedAt;
  final int? librenmsId;

  BaseNode({
    required this.id,
    required this.name,
    required this.ipAddress,
    this.macAddress,
    this.deviceType,
    required this.nodeKind,
    this.status,
    this.locationName,
    this.locationId,
    this.switchId,
    this.nodeId,
    this.description,
    this.lastReplacedAt,
    this.librenmsId,
  });

  factory BaseNode.fromDeviceJson(Map<String, dynamic> json) {
    return BaseNode(
        id: json['device_id'],
        name: json['name'],
        ipAddress: json['ip_address'],
        macAddress: json['mac_address'],
        deviceType: json['device_type'],
        nodeKind: 'device',
        status: json['status'],
        locationId: json['location_id'],
        locationName: json['location_name'],
        switchId: json['switch_id'],
        description: json['description'],
        lastReplacedAt: json['last_replaced_at'],
        librenmsId: json['librenms_device_id']);
  }

  Map<String, dynamic> toDeviceCreateJson() {
    return {
      'name': name,
      'ip_address': ipAddress,
      'mac_address': macAddress,
      'device_type': deviceType,
      'node_kind': nodeKind,
      'status': status,
      'location_id': locationId,
      'switch_id': switchId,
      'description': description
    };
  }

  factory BaseNode.fromSwitchJson(Map<String, dynamic> json) {
    return BaseNode(
        id: json['switch_id'],
        name: json['name'],
        ipAddress: json['ip_address'],
        status: json['status'],
        nodeKind: 'switch',
        deviceType: 'Switch',
        locationName: json['location_name'],
        locationId: json['location_id'],
        nodeId: json['node_id'],
        description: json['description'],
        lastReplacedAt: json['last_replaced_at'],
        librenmsId: json['librenms_device_id']);
  }

  Map<String, dynamic> toSwitchCreateJson() {
    return {
      'name': name,
      'ip_address': ipAddress,
      'status': status,
      'location_id': locationId,
      'node_id': nodeId,
      'node_kind': nodeKind,
      'description': description
    };
  }
}

class NodePage {
  final List<BaseNode> items;
  final int total;
  final int page;
  final int pageSize;

  NodePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory NodePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? [];
    return NodePage(
      items: raw.map((e) {
        if (e['node_kind'] == 'switch') {
          return BaseNode.fromSwitchJson({
            ...e,
            'switch_id': e['id'],
          });
        }
        return BaseNode.fromDeviceJson({
          ...e,
          'device_id': e['id'],
        });
      }).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
    );
  }
}
