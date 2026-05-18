import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../models/user.dart';
import '../../models/device.dart';
import '../../models/location.dart';
import '../../models/map_topology.dart';
import '../../services/location_service.dart';
import '../../services/map_service.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import '../../providers/metrics_provider.dart';
import '../../utils/location_group_formatter.dart';
import 'widgets/map_details_panel.dart';
import 'widgets/map_view.dart';
import 'widgets/map_filter_drawer.dart';
import 'widgets/map_summary_box.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const double desktopBreakpoint = 900;
  final _service = MapService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  Map<String, List<String>> _filterHierarchy = {};
  Set<String> _hiddenLocations = {};

  bool _isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _load();
    _loadGroups();
    _initWebSocket();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await LocationService().getLocationGroups();
      final formatted = LocationGroupFormatter.formatNames(groups);

      String? currentParent;
      final Map<String, List<String>> hierarchy = {};

      for (var name in formatted) {
        bool isChild = name.contains('↳');
        String cleanName = name.replaceAll('↳', '').trim();

        if (isChild) {
          if (currentParent != null) {
            hierarchy[currentParent]!.add(cleanName);
          }
        } else {
          currentParent = cleanName;
          hierarchy[currentParent] = [];
        }
      }

      if (mounted) {
        setState(() {
          _filterHierarchy = hierarchy;
          _hiddenLocations.clear();
        });
      }
    } catch (e) {
      debugPrint("Failed to load groups: $e");
    }
  }

  void _toggleFilter(String item, bool isChecked,
      {bool isParent = false, String? parentName}) {
    setState(() {
      if (isChecked) {
        _hiddenLocations.remove(item);
        if (isParent) {
          _filterHierarchy[item]
              ?.forEach((child) => _hiddenLocations.remove(child));
        }
      } else {
        _hiddenLocations.add(item);
        if (isParent) {
          _filterHierarchy[item]
              ?.forEach((child) => _hiddenLocations.add(child));
        }
      }
    });
  }

  Future<void> _refreshDataSilent() async {
    try {
      final topo = await _service.getTopology();
      if (mounted) setState(() => _topology = topo);
    } catch (e) {
      debugPrint("Background refresh failed: $e");
    }
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    _statusSubscription = wsService.statusChanges.listen((event) {
      if (mounted) _refreshDataSilent();
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
    final metricsProvider = context.watch<MetricsProvider>();

    final locationById = {for (final l in topo.locations) l.id: l};
    final nodesByLocation = <int, List<BaseNode>>{};
    final filteredNodeStatuses = <int, String>{};

    bool passesFilter(BaseNode node, bool isSwitch) {
      final int nodeId = node.id ?? -1;
      final m = isSwitch
          ? metricsProvider.getSwitchMetrics(nodeId)
          : metricsProvider.getDeviceMetrics(nodeId);

      String locName = (m?['location_name'] ?? '').toString().trim();
      String groupName = (m?['location_group'] ?? '').toString().trim();
      String parentName = (m?['location_parent'] ?? '').toString().trim();

      bool isUnassigned =
          locName.isEmpty && groupName.isEmpty && parentName.isEmpty;

      if (_hiddenLocations.isNotEmpty && isUnassigned) {
        return false;
      }

      if (_hiddenLocations.contains(locName) ||
          _hiddenLocations.contains(groupName)) {
        return false;
      }

      if (groupName.isEmpty &&
          locName.isEmpty &&
          _hiddenLocations.contains(parentName)) {
        return false;
      }

      filteredNodeStatuses[nodeId] =
          (m?['status'] ?? node.status ?? 'offline').toString().toLowerCase();
      return true;
    }

    for (final d in topo.devices) {
      if (passesFilter(d, false)) {
        final locId = d.locationId;
        if (locId != null) (nodesByLocation[locId] ??= []).add(d);
      }
    }
    for (final s in topo.switches) {
      if (passesFilter(s, true)) {
        final locId = s.locationId;
        if (locId != null) (nodesByLocation[locId] ??= []).add(s);
      }
    }

    final visibleLocations = topo.locations.where((l) {
      final hasNodes = (nodesByLocation[l.id] ?? []).isNotEmpty;
      return _hideEmptyLocations ? hasNodes : true;
    }).toList();

    int totalCount = 0;
    int onlineCount = 0;
    int offlineCount = 0;
    Map<String, Map<String, int>> typeStats = {};

    void processNodeStats(BaseNode node, bool isSwitch) {
      final int nodeId = node.id ?? -1;
      final m = isSwitch
          ? metricsProvider.getSwitchMetrics(nodeId)
          : metricsProvider.getDeviceMetrics(nodeId);

      String statusStr = (node.status ?? '').toLowerCase();
      String sevStr = (node.severity ?? '').toLowerCase();
      bool isOffline = (statusStr == 'offline' ||
          statusStr == 'down' ||
          sevStr == 'red' ||
          sevStr == 'critical');

      if (m != null) {
        String mStatus = (m['status'] ?? '').toString().toLowerCase();
        isOffline = (mStatus == 'offline' ||
            mStatus == 'down' ||
            mStatus == 'critical');
      }

      String type = 'Unknown';
      if (isSwitch) {
        type = 'Switch';
      } else {
        type = m?['device_type']?.toString() ?? 'Unknown';
        if (type == 'Unknown') {
          try {
            type = (node as dynamic).deviceType?.toString() ?? 'Unknown';
          } catch (_) {}
        }

        if (type.length > 1) {
          type = type[0].toUpperCase() + type.substring(1).toLowerCase();
        } else if (type.isNotEmpty) {
          type = type.toUpperCase();
        }
      }

      totalCount++;
      if (isOffline) {
        offlineCount++;
      } else {
        onlineCount++;
      }

      if (!typeStats.containsKey(type)) {
        typeStats[type] = {'total': 0, 'online': 0, 'offline': 0};
      }
      typeStats[type]!['total'] = typeStats[type]!['total']! + 1;
      if (isOffline) {
        typeStats[type]!['offline'] = typeStats[type]!['offline']! + 1;
      } else {
        typeStats[type]!['online'] = typeStats[type]!['online']! + 1;
      }
    }

    for (final d in topo.devices) {
      if (passesFilter(d, false)) {
        processNodeStats(d, false);
      }
    }
    for (final s in topo.switches) {
      if (passesFilter(s, true)) {
        processNodeStats(s, true);
      }
    }

    final center = visibleLocations.isNotEmpty
        ? LatLng(
            visibleLocations.first.latitude, visibleLocations.first.longitude)
        : const LatLng(-5.1, 119.4);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      endDrawer: MapFilterDrawer(
        filterHierarchy: _filterHierarchy,
        hiddenLocations: _hiddenLocations,
        onToggle: _toggleFilter,
        onReset: () => setState(() => _hiddenLocations.clear()),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Lokasi Perangkat",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Wrap(
                  runSpacing: 10,
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: const Text("Tampilkan jalur"),
                      selected: _showRoutes,
                      backgroundColor: Colors.white,
                      selectedColor: Colors.blue.shade50,
                      checkmarkColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.black12),
                      elevation: 0,
                      pressElevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSelected: (v) => setState(() => _showRoutes = v),
                    ),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _scaffoldKey.currentState?.openEndDrawer(),
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text("Filter Lokasi"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        side: const BorderSide(color: Colors.black12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (_isAdmin) ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          final updated = await Navigator.pushNamed(
                              context, '/location-management');
                          if (mounted && updated == true) await _load();
                        },
                        icon: const Icon(Icons.dataset, size: 18),
                        label: const Text("Master Data Lokasi"),
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
                border:
                    Border(top: BorderSide(color: Colors.black12, width: 1.0)),
              ),
              clipBehavior: Clip.hardEdge,
              child: Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        MapView(
                          topology: topo,
                          visibleLocations: visibleLocations,
                          locationById: locationById,
                          nodesByLocation: nodesByLocation,
                          center: center,
                          showRoutes: _showRoutes,
                          nodeStatuses: filteredNodeStatuses,
                          onLocationTap: (loc, nodesAtLoc) =>
                              _onLocationSelected(
                            context,
                            location: loc,
                            nodesAtLocation: nodesAtLoc,
                          ),
                        ),
                        MapSummaryBox(
                          totalDevices: totalCount,
                          totalOnline: onlineCount,
                          totalOffline: offlineCount,
                          typeStats: typeStats,
                        ),
                      ],
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
