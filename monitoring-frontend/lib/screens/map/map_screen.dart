import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../models/user.dart';
import '../../models/device.dart';
import '../../models/location.dart';
import '../../models/map_topology.dart';
import '../../services/map_service.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import 'widgets/map_details_panel.dart';
import 'widgets/map_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double desktopBreakpoint = 900;
  final _service = MapService();
  StreamSubscription<StatusChangeEvent>? _statusSubscription;

  User? _currentUser;
  bool get _isAdmin => _currentUser?.role == 'admin';
  bool _loading = true;
  String? _error;
  MapTopology? _topology;

  bool _hideEmptyLocations = true;
  bool _showRoutes = true;
  Location? _selectedLocation;
  List<BaseNode> _selectedNodesAtLocation = const [];
  bool _panelExpanded = false;

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _load();
    _initWebSocket();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshDataSilent() async {
    try {
      final topo = await _service.getTopology();
      if (mounted) {
        setState(() {
          _topology = topo;
        });
      }
    } catch (e) {
      debugPrint("Background refresh failed: $e");
    }
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    _statusSubscription = wsService.statusChanges.listen((event) {
      if (mounted) {
        _refreshDataSilent();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${event.name} is now ${event.newStatus}'),
            backgroundColor: event.newStatus.toLowerCase() == 'online'
                ? Colors.green
                : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  Future<void> _checkUserRole() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (mounted) setState(() => _currentUser = user);
    } catch (e) {
      debugPrint("Failed to load user role: $e");
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final topo = await _service.getTopology();
      if (mounted) setState(() => _topology = topo);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onLocationSelected(
    BuildContext context, {
    required Location location,
    required List<BaseNode> nodesAtLocation,
  }) {
    if (_isDesktop(context)) {
      setState(() {
        _selectedLocation = location;
        _selectedNodesAtLocation = nodesAtLocation;
        _panelExpanded = true;
      });
      return;
    }

    MapDetailsPanel.showBottomSheet(
      context,
      location: location,
      nodesAtLocation: nodesAtLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Error: $_error"),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text("Retry")),
          ],
        ),
      );
    }

    final topo = _topology;
    if (topo == null) return const SizedBox.shrink();

    final isDesktop = _isDesktop(context);

    final locationById = {for (final l in topo.locations) l.id: l};
    final nodesByLocation = <int, List<BaseNode>>{};

    for (final d in topo.devices) {
      final locId = d.locationId;
      if (locId != null) (nodesByLocation[locId] ??= []).add(d);
    }
    for (final s in topo.switches) {
      final locId = s.locationId;
      if (locId != null) (nodesByLocation[locId] ??= []).add(s);
    }

    final visibleLocations = topo.locations.where((l) {
      final hasNodes = (nodesByLocation[l.id] ?? []).isNotEmpty;
      return _hideEmptyLocations ? hasNodes : true;
    }).toList();

    final center = visibleLocations.isNotEmpty
        ? LatLng(
            visibleLocations.first.latitude,
            visibleLocations.first.longitude,
          )
        : const LatLng(-5.1, 119.4);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Device Location Map",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Wrap(
                  runSpacing: 10,
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text("Hide empty locations"),
                      selected: _hideEmptyLocations,
                      backgroundColor: Colors.white,
                      selectedColor: Colors.white,
                      side: const BorderSide(color: Colors.black12),
                      onSelected: (v) =>
                          setState(() => _hideEmptyLocations = v),
                    ),
                    FilterChip(
                      label: const Text("Show routes"),
                      selected: _showRoutes,
                      backgroundColor: Colors.white,
                      selectedColor: Colors.white,
                      side: const BorderSide(color: Colors.black12),
                      onSelected: (v) => setState(() => _showRoutes = v),
                    ),
                    if (_isAdmin) ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.pushNamed(
                              context, '/location-management');
                          if (mounted && updated == true) {
                            await _load();
                          }
                        },
                        icon: const Icon(Icons.dataset, size: 18),
                        label: const Text("Location Master Data"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          )),
          SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.of(context).size.height * 0.90,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12, width: 1.0),
                ),
              ),
              clipBehavior: Clip.hardEdge,
              child: Row(
                children: [
                  Expanded(
                    child: MapView(
                      topology: topo,
                      visibleLocations: visibleLocations,
                      locationById: locationById,
                      nodesByLocation: nodesByLocation,
                      center: center,
                      showRoutes: _showRoutes,
                      onLocationTap: (loc, nodesAtLoc) => _onLocationSelected(
                        context,
                        location: loc,
                        nodesAtLocation: nodesAtLoc,
                      ),
                    ),
                  ),
                  if (isDesktop) ...[
                    Container(width: 1, color: Colors.grey.shade300),
                    MapDetailsPanel(
                      expanded: _panelExpanded,
                      onToggleExpanded: () =>
                          setState(() => _panelExpanded = !_panelExpanded),
                      onClose: () => setState(() {
                        _selectedLocation = null;
                        _selectedNodesAtLocation = const [];
                        _panelExpanded = false;
                      }),
                      location: _selectedLocation,
                      nodesAtLocation: _selectedNodesAtLocation,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
