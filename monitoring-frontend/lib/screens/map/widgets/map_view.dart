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
  final Map<int, String> nodeStatuses;

  const MapView({
    super.key,
    required this.topology,
    required this.visibleLocations,
    required this.locationById,
    required this.nodesByLocation,
    required this.center,
    required this.onLocationTap,
    required this.showRoutes,
    required this.nodeStatuses,
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MapController _mapController = MapController();
  StreamSubscription<MapEvent>? _mapSub;
  double _currentZoom = 0;

  String _nodeSeverity(BaseNode node) {
    final liveStatus = (widget.nodeStatuses[node.id ?? -1] ?? '').toLowerCase();
    final originalStatus = (node.status ?? '').toLowerCase();
    final sev = (node.severity ?? '').toLowerCase();

    if (liveStatus == 'offline' ||
        liveStatus == 'down' ||
        originalStatus == 'offline' ||
        originalStatus == 'down') {
      return 'grey';
    }

    if (sev == 'red' || sev == 'critical' || liveStatus == 'critical') {
      return 'red';
    }

    if (sev == 'yellow' || sev == 'warning' || liveStatus == 'warning') {
      return 'yellow';
    }

    return 'green';
  }

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
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topo = widget.topology;

    final nodeById = {for (final n in topo.networkNodes) n.id: n};
    LatLng? nodeLatLng(int nodeId) {
      final n = nodeById[nodeId];
      if (n == null) return null;
      final loc = widget.locationById[n.locationId];
      if (loc == null) return null;
      return LatLng(loc.latitude, loc.longitude);
    }

    final polylines = <Polyline>[];
    for (final r in topo.foRoutes) {
      final start = nodeLatLng(r.startNodeId);
      final end = nodeLatLng(r.endNodeId);
      if (start == null || end == null) continue;

      List<LatLng> path = [start, end];
      if (r.waypoints != null && r.waypoints!.isNotEmpty) {
        path = r.waypoints!;
      }

      polylines.add(
        Polyline(
          points: path,
          strokeWidth: 4,
          color: Colors.lightBlue,
          useStrokeWidthInMeter: false,
          borderColor: Colors.black45,
          borderStrokeWidth: 2.0,
        ),
      );
    }

    final markers = widget.visibleLocations.map((loc) {
      final nodesAtLoc = widget.nodesByLocation[loc.id] ?? [];

      Color statusColor;
      if (nodesAtLoc.isEmpty) {
        statusColor = Colors.grey;
      } else {
        int total = nodesAtLoc.length;
        int offlineCount = 0;
        int criticalCount = 0;
        int warningCount = 0;

        for (var n in nodesAtLoc) {
          String state = _nodeSeverity(n);
          if (state == 'grey') {
            offlineCount++;
          } else if (state == 'red') {
            criticalCount++;
          } else if (state == 'yellow') {
            warningCount++;
          }
        }

        if (offlineCount == total) {
          statusColor = Colors.grey;
        } else if (criticalCount == total || offlineCount > 0) {
          statusColor = Colors.red;
        } else if (criticalCount > 0 || warningCount > 0) {
          statusColor = Colors.orange;
        } else {
          statusColor = Colors.green;
        }
      }

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
            maxZoom: 20,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                const LatLng(-5.182394550307023,
                    119.3424239538415), // barat daya/kiri bawah
                const LatLng(-5.048174653312404,
                    119.56009381545908), // timur laut/kanan atas
              ),
            ),
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
