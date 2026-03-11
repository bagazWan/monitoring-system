import 'package:latlong2/latlong.dart';

class FORoute {
  final int id;
  final int startNodeId;
  final int endNodeId;
  final double? length;
  final String? description;
  final List<LatLng>? waypoints;

  FORoute(
      {required this.id,
      required this.startNodeId,
      required this.endNodeId,
      this.length,
      this.description,
      this.waypoints});

  factory FORoute.fromJson(Map<String, dynamic> json) {
    List<LatLng>? parsedWaypoints;
    if (json['waypoints'] != null) {
      parsedWaypoints = (json['waypoints'] as List).map((w) {
        final lat = (w['latitude'] as num?)?.toDouble() ?? 0.0;
        final lng = (w['longitude'] as num?)?.toDouble() ?? 0.0;
        return LatLng(lat, lng);
      }).toList();
    }

    return FORoute(
        id: json['routes_id'],
        startNodeId: json['start_node_id'],
        endNodeId: json['end_node_id'],
        length: (json['length_m'] as num?)?.toDouble(),
        description: json['description'],
        waypoints: parsedWaypoints);
  }

  Map<String, dynamic> toJson() {
    return {
      'start_node_id': startNodeId,
      'end_node_id': endNodeId,
      'length_m': length,
      'description': description,
      if (waypoints != null)
        'waypoints': waypoints!
            .map((w) => {'latitude': w.latitude, 'longitude': w.longitude})
            .toList(),
    };
  }
}

class FORoutePage {
  final List<FORoute> items;
  final int total;
  final int page;
  final int pageSize;

  FORoutePage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory FORoutePage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List? ?? [];
    return FORoutePage(
      items: raw.map((e) => FORoute.fromJson(e)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      pageSize: json['page_size'] ?? 10,
    );
  }
}
