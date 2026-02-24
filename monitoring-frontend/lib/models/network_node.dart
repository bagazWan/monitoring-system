class NetworkNode {
  final int id;
  final int locationId;
  final String? name;
  final String type;
  final String? description;

  NetworkNode({
    required this.id,
    required this.locationId,
    this.name,
    required this.type,
    this.description,
  });

  factory NetworkNode.fromJson(Map<String, dynamic> json) {
    return NetworkNode(
      id: json['node_id'],
      locationId: json['location_id'],
      name: json['name'],
      type: json['node_type'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'name': name,
      'node_type': type,
      'description': description,
    };
  }
}

class NetworkNodePage {
  final List<NetworkNode> items;
  final int total;
  final int page;
  final int pageSize;

  NetworkNodePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory NetworkNodePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? [];
    return NetworkNodePage(
      items: raw.map((e) => NetworkNode.fromJson(e)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
    );
  }
}
