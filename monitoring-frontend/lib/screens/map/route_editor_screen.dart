import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_line_editor/flutter_map_line_editor.dart';
import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
import '../../config/map_tile_config.dart';
import '../../models/fo_route.dart';
import '../../services/map_service.dart';

class RouteEditorScreen extends StatefulWidget {
  final FORoute route;
  final LatLng startLocation;
  final LatLng endLocation;

  const RouteEditorScreen({
    super.key,
    required this.route,
    required this.startLocation,
    required this.endLocation,
  });

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final MapService _service = MapService();
  final MapController _mapController = MapController();

  bool _isSaving = false;
  late PolyEditor _polyEditor;
  List<LatLng> _points = [];

  @override
  void initState() {
    super.initState();
    _setupEditor();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _setupEditor() {
    if (widget.route.waypoints != null && widget.route.waypoints!.isNotEmpty) {
      _points = List<LatLng>.from(widget.route.waypoints!);
    } else {
      _points = [widget.startLocation, widget.endLocation];
    }

    _polyEditor = PolyEditor(
      addClosePathMarker: false,
      points: _points,
      pointIcon: const Icon(Icons.circle, size: 20, color: Colors.blueGrey),
      intermediateIcon: const Icon(Icons.lens, size: 15, color: Colors.white),
      callbackRefresh: (LatLng? _) {
        if (_points.isNotEmpty) {
          _points[0] = widget.startLocation;
        }
        if (_points.length > 1) {
          _points[_points.length - 1] = widget.endLocation;
        }
        if (mounted) setState(() {});
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_points.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(_points);
        if (bounds.southWest == bounds.northEast) {
          _mapController.move(bounds.center, 15.0);
        } else {
          _mapController.fitCamera(
            CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
          );
        }
      }
    });
  }

  Future<void> _saveRoute() async {
    setState(() => _isSaving = true);
    try {
      final waypointsJson = _points
          .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
          .toList();

      await _service.updateFORoute(widget.route.id, {
        'waypoints': waypointsJson,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Jalur garis tersimpan")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan jalur: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Garis Jalur FO",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveRoute,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text("Simpan Peta"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final dragMarkers = List<DragMarker>.from(_polyEditor.edit());

    if (dragMarkers.isNotEmpty) {
      dragMarkers.removeWhere(
          (m) => m.point == _points.first || m.point == _points.last);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.startLocation,
            initialZoom: 14.0,
            onTap: (_, ll) => _polyEditor.add(_points, ll),
          ),
          children: [
            TileLayer(
              urlTemplate: MapTileConfig.urlTemplate,
              userAgentPackageName: 'com.mmn.networkMonitoring',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _points,
                  color: Colors.lightBlue,
                  strokeWidth: 4.0,
                  useStrokeWidthInMeter: false,
                  borderColor: Colors.black45,
                  borderStrokeWidth: 2.0,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.startLocation,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Marker(
                  point: widget.endLocation,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            DragMarkers(markers: dragMarkers),
          ],
        ),
      ],
    );
  }
}
