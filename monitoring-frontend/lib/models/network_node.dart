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
