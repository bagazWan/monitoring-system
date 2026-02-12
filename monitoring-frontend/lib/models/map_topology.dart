import 'device.dart';
import 'fo_route.dart';
import 'location.dart';
import 'network_node.dart';

class MapTopology {
  final List<Location> locations;
  final List<NetworkNode> networkNodes;
  final List<FORoute> foRoutes;
  final List<BaseNode> devices;
  final List<BaseNode> switches;

  MapTopology({
    required this.locations,
    required this.networkNodes,
    required this.foRoutes,
    required this.devices,
    required this.switches,
  });

  factory MapTopology.fromJson(Map<String, dynamic> json) {
    final locs = (json['locations'] as List<dynamic>? ?? [])
        .map((e) => Location.fromJson(e))
        .toList();

    final nodes = (json['network_nodes'] as List<dynamic>? ?? [])
        .map((e) => NetworkNode.fromJson(e))
        .toList();

    final routes = (json['fo_routes'] as List<dynamic>? ?? [])
        .map((e) => FORoute.fromJson(e))
        .toList();

    final devs = (json['devices'] as List<dynamic>? ?? [])
        .map((e) => BaseNode.fromDeviceJson(e))
        .toList();

    final sws = (json['switches'] as List<dynamic>? ?? [])
        .map((e) => BaseNode.fromSwitchJson(e))
        .toList();

    return MapTopology(
      locations: locs,
      networkNodes: nodes,
      foRoutes: routes,
      devices: devs,
      switches: sws,
    );
  }
}
