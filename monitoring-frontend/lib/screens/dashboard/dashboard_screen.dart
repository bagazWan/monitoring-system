import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/dashboard_stats.dart';
import '../../models/location.dart';
import '../../services/device_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/visual_feedback.dart';
import 'widgets/network_activity_chart.dart';
import 'widgets/dashboard_filters.dart';
import 'widgets/summary_grid.dart';
import 'widgets/top_down.dart';
import 'widgets/dashboard_charts.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DeviceService _deviceService = DeviceService();
  final DashboardService _dashboardService = DashboardService();

  late Future<DashboardStats> _dashboardStatsFuture;
  Timer? _refreshTimer;
  Timer? _trafficTimer;
  StreamSubscription<StatusChangeEvent>? _statusSubscription;
  StreamSubscription<WebSocketConnectionState>? _connectionSubscription;

  List<Location> _locations = [];
  bool _isLoadingLocations = true;
  String? _selectedLocationName; // null == All

  final List<NetworkActivityData> _trafficData = [];
  final int _maxTrafficPoints = 60;
  final List<UptimeTrendPoint> _uptimeTrendData = [];
  int _topDownWindowDays = 7;
  bool _isTrafficLoading = true;
  bool _isUptimeLoading = true;

  @override
  void initState() {
    super.initState();
    _dashboardStatsFuture = _dashboardService.getDashboardStats(
      topDownWindowDays: _topDownWindowDays,
    );
    _initLocations();
    _initWebSocket();
    _initTraffic();
    _refreshUptimeTrend();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshDashboard();
    });
  }

  Future<void> _initLocations() async {
    try {
      final locations = await _deviceService.getLocations();
      if (!mounted) return;

      locations
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _locations = locations;
        _isLoadingLocations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locations = [];
        _isLoadingLocations = false;
      });
    }
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    wsService.connect();

    _connectionSubscription = wsService.connectionState.listen((_) {});
    _statusSubscription = wsService.statusChanges.listen((_) {
      if (!mounted) return;
      _refreshDashboard();
    });
  }

  void _initTraffic() {
    _refreshTraffic();
    _trafficTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshTraffic();
    });
  }

  int? _resolveSelectedLocationId() {
    if (_selectedLocationName == null) return null;
    final match = _locations.where((l) => l.name == _selectedLocationName);
    if (match.isEmpty) return null;
    return match.first.id;
  }

  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {
      _dashboardStatsFuture = _dashboardService.getDashboardStats(
        locationId: _resolveSelectedLocationId(),
        topDownWindowDays: _topDownWindowDays,
      );
    });
  }

  Future<void> _refreshTraffic() async {
    try {
      final traffic = await _dashboardService.getDashboardTraffic(
        locationId: _resolveSelectedLocationId(),
      );

      if (!mounted) return;

      if (traffic.inboundMbps == null && traffic.outboundMbps == null) {
        setState(() {
          _isTrafficLoading = false;
        });
        return;
      }

      final dataPoint = NetworkActivityData(
        timestamp: traffic.timestamp,
        inbound: traffic.inboundMbps ?? 0,
        outbound: traffic.outboundMbps ?? 0,
      );

      setState(() {
        _trafficData.add(dataPoint);
        if (_trafficData.length > _maxTrafficPoints) {
          _trafficData.removeAt(0);
        }
        _isTrafficLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isTrafficLoading = false;
      });
    }
  }

  Future<void> _refreshUptimeTrend() async {
    try {
      final trend = await _dashboardService.getUptimeTrend(days: 7);
      if (!mounted) return;
      setState(() {
        _uptimeTrendData
          ..clear()
          ..addAll(trend.data);
        _isUptimeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUptimeLoading = false;
      });
    }
  }

  Future<void> _handleManualRefresh() async {
    _refreshDashboard();
    await _refreshTraffic();
    await _refreshUptimeTrend();
    await _dashboardStatsFuture;
  }

  void _resetTrafficData() {
    setState(() {
      _trafficData.clear();
      _isTrafficLoading = true;
    });
    _refreshTraffic();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _trafficTimer?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<DashboardStats>(
            future: _dashboardStatsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return AsyncErrorWidget(
                  error: snapshot.error!,
                  onRetry: _handleManualRefresh,
                );
              }

              if (!snapshot.hasData) {
                return const EmptyStateWidget(
                  message: "No dashboard data available",
                  icon: Icons.dashboard_customize_outlined,
                );
              }

              final stats = snapshot.data!;
              final offlineCount = stats.totalDevices - stats.onlineDevices;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Overview",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DashboardFilters(
                    isLoading: _isLoadingLocations,
                    locations: _locations,
                    selectedLocationName: _selectedLocationName,
                    onLocationChanged: (value) {
                      setState(() {
                        _selectedLocationName = value;
                        _dashboardStatsFuture =
                            _dashboardService.getDashboardStats(
                          locationId: _resolveSelectedLocationId(),
                          topDownWindowDays: _topDownWindowDays,
                        );
                      });
                      _resetTrafficData();
                    },
                  ),
                  const SizedBox(height: 20),
                  DashboardSummaryGrid(
                    stats: stats,
                    offlineCount: offlineCount,
                  ),
                  const SizedBox(height: 30),
                  DashboardTopDown(
                    stats: stats,
                    selectedWindowDays: _topDownWindowDays,
                    onWindowChanged: (window) {
                      setState(() {
                        _topDownWindowDays = window;
                        _dashboardStatsFuture =
                            _dashboardService.getDashboardStats(
                          locationId: _resolveSelectedLocationId(),
                          topDownWindowDays: _topDownWindowDays,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  DashboardCharts(
                    trafficData: _trafficData,
                    isTrafficLoading: _isTrafficLoading,
                    uptimeData: _uptimeTrendData,
                    isUptimeLoading: _isUptimeLoading,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
