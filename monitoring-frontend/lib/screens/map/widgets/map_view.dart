import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../config/map_tile_config.dart';
import '../../../models/device.dart';
import '../../../models/location.dart';
import '../../../models/map_topology.dart';
import '../../map/widgets/zoom_debug.dart';

class MapView extends StatefulWidget {
  final MapTopology topology;
  final List<Location> visibleLocations;
  final Map<int, Location> locationById;
  final Map<int, List<BaseNode>> nodesByLocation;
  final LatLng center;
  final void Function(Location loc, List<BaseNode> nodesAtLoc) onLocationTap;
  final bool showRoutes;

  const MapView({
    super.key,
    required this.topology,
    required this.visibleLocations,
    required this.locationById,
    required this.nodesByLocation,
    required this.center,
    required this.onLocationTap,
    required this.showRoutes,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  StreamSubscription<MapEvent>? _mapSub;
  double _currentZoom = 0;

  @override
  void initState() {
    super.initState();
    _mapSub = _mapController.mapEventStream.listen((event) {
      final z = _mapController.camera.zoom;
      if ((z - _currentZoom).abs() >= 0.01) {
        if (mounted) setState(() => _currentZoom = z);
      }
    });
  }

  @override
  void dispose() {
    _mapSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topo = widget.topology;

    // nodeId -> location LatLng
    final nodeById = {for (final n in topo.networkNodes) n.id: n};
    LatLng? nodeLatLng(int nodeId) {
      final n = nodeById[nodeId];
      if (n == null) return null;
      final loc = widget.locationById[n.locationId];
      if (loc == null) return null;
      return LatLng(loc.latitude, loc.longitude);
    }

    // Polylines (still green for now)
    final polylines = <Polyline>[];
    for (final r in topo.foRoutes) {
      final start = nodeLatLng(r.startNodeId);
      final end = nodeLatLng(r.endNodeId);
      if (start == null || end == null) continue;
      polylines.add(
        Polyline(
          points: [start, end],
          strokeWidth: 4,
          color: Colors.green,
        ),
      );
    }

    // Markers
    final markers = widget.visibleLocations.map((loc) {
      final nodesAtLoc = widget.nodesByLocation[loc.id] ?? [];

      final anyOffline =
          nodesAtLoc.any((n) => (n.status ?? '').toLowerCase() == 'offline');
      final anyOnline =
          nodesAtLoc.any((n) => (n.status ?? '').toLowerCase() == 'online');
      final Color statusColor =
          anyOffline ? Colors.red : (anyOnline ? Colors.green : Colors.orange);

      return Marker(
        width: 18,
        height: 18,
        point: LatLng(loc.latitude, loc.longitude),
        child: GestureDetector(
          onTap: () => widget.onLocationTap(loc, nodesAtLoc),
          child: Container(
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
          ),
        ),
      );
    }).toList();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.center,
            initialZoom: 13.20,
            minZoom: 13,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: MapTileConfig.urlTemplate,
              userAgentPackageName: 'com.mmn.networkMonitoring',
              tileProvider: NetworkTileProvider(silenceExceptions: true),
            ),
            if (widget.showRoutes) PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: DebugPill(text: 'Zoom: ${_currentZoom.toStringAsFixed(2)}'),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              MapTileConfig.attribution,
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ),
      ],
    );
  }
}
