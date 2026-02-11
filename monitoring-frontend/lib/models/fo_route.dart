class FORoute {
  final int id;
  final int startNodeId;
  final int endNodeId;
  final int? length;
  final String? description;

  FORoute({
    required this.id,
    required this.startNodeId,
    required this.endNodeId,
    this.length,
    this.description,
  });

  factory FORoute.fromJson(Map<String, dynamic> json) {
    return FORoute(
      id: json['routes_id'],
      startNodeId: json['start_node_id'],
      endNodeId: json['end_node_id'],
      length: json['length_m'],
      description: json['description'],
    );
  }
}
