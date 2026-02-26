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

part 'widgets/dashboard_screen_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with DashboardScreenWidgets {
  final DeviceService _deviceService = DeviceService();
  final DashboardService _dashboardService = DashboardService();
  final ScrollController _scrollController = ScrollController();

  Timer? _refreshTimer;
  Timer? _trafficTimer;
  StreamSubscription<StatusChangeEvent>? _statusSubscription;
  StreamSubscription<WebSocketConnectionState>? _connectionSubscription;

  final GlobalKey _chartsKey = GlobalKey();
  final ValueNotifier<bool> _chartsVisible = ValueNotifier(false);
  final GlobalKey _topDownKey = GlobalKey();
  final ValueNotifier<bool> _topDownVisible = ValueNotifier(false);

  bool _chartsInitialized = false;

  final ValueNotifier<List<Location>> _locations = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingLocations = ValueNotifier(true);
  final ValueNotifier<String?> _selectedLocationName = ValueNotifier(null);

  final ValueNotifier<List<NetworkActivityData>> _trafficData =
      ValueNotifier([]);
  final int _maxTrafficPoints = 60;

  final ValueNotifier<List<UptimeTrendPoint>> _uptimeTrendData =
      ValueNotifier([]);
  final ValueNotifier<int> _topDownWindowDays = ValueNotifier(7);

  final ValueNotifier<bool> _isTrafficLoading = ValueNotifier(true);
  final ValueNotifier<bool> _isUptimeLoading = ValueNotifier(true);

  final ValueNotifier<bool> _isStatsLoading = ValueNotifier(true);
  final ValueNotifier<DashboardStats?> _dashboardStats = ValueNotifier(null);
  final ValueNotifier<Object?> _statsError = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
    _initLocations();
    _initWebSocket();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshDashboard();
      if (_chartsInitialized) {
        _refreshUptimeTrend();
      }
    });

    _scrollController.addListener(_checkLazyLoadTargets);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkLazyLoadTargets());
  }

  Future<void> _initLocations() async {
    try {
      final locations = await _deviceService.getLocations();
      if (!mounted) return;

      locations
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _locations.value = locations;
      _isLoadingLocations.value = false;
    } catch (_) {
      if (!mounted) return;
      _locations.value = [];
      _isLoadingLocations.value = false;
    }
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    wsService.connect();

    _connectionSubscription = wsService.connectionState.listen((_) {});
    _statusSubscription = wsService.statusChanges.listen((_) {
      if (!mounted) return;
      _refreshDashboard();
      if (_chartsInitialized) {
        _refreshUptimeTrend();
      }
    });
  }

  void _startChartData() {
    if (_chartsInitialized) return;
    _chartsInitialized = true;
    _refreshTraffic();
    _refreshUptimeTrend();
    _trafficTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshTraffic();
    });
  }

  int? _resolveSelectedLocationId() {
    final selected = _selectedLocationName.value;
    if (selected == null) return null;
    final match = _locations.value.where((l) => l.name == selected);
    if (match.isEmpty) return null;
    return match.first.id;
  }

  Future<void> _refreshDashboard() async {
    _isStatsLoading.value = true;
    _statsError.value = null;

    try {
      final stats = await _dashboardService.getDashboardStats(
        locationId: _resolveSelectedLocationId(),
        topDownWindowDays: _topDownWindowDays.value,
      );
      _dashboardStats.value = stats;
    } catch (e) {
      _statsError.value = e;
    } finally {
      _isStatsLoading.value = false;
    }
  }

  Future<void> _refreshTraffic() async {
    try {
      final traffic = await _dashboardService.getDashboardTraffic(
        locationId: _resolveSelectedLocationId(),
      );

      if (!mounted) return;

      if (traffic.inboundMbps == null && traffic.outboundMbps == null) {
        _isTrafficLoading.value = false;
        return;
      }

      final dataPoint = NetworkActivityData(
        timestamp: traffic.timestamp,
        inbound: traffic.inboundMbps ?? 0,
        outbound: traffic.outboundMbps ?? 0,
      );

      final updated = List<NetworkActivityData>.from(_trafficData.value)
        ..add(dataPoint);
      if (updated.length > _maxTrafficPoints) {
        updated.removeAt(0);
      }

      _trafficData.value = updated;
      _isTrafficLoading.value = false;
    } catch (_) {
      if (!mounted) return;
      _isTrafficLoading.value = false;
    }
  }

  Future<void> _refreshUptimeTrend() async {
    try {
      final trend = await _dashboardService.getUptimeTrend(
        days: 7,
        locationId: _resolveSelectedLocationId(),
      );
      if (!mounted) return;

      _uptimeTrendData.value = List<UptimeTrendPoint>.from(trend.data);
      _isUptimeLoading.value = false;
    } catch (_) {
      if (!mounted) return;
      _isUptimeLoading.value = false;
    }
  }

  Future<void> _handleManualRefresh() async {
    await _refreshDashboard();
    if (_chartsInitialized) {
      await _refreshTraffic();
      await _refreshUptimeTrend();
    }
  }

  void _resetTrafficData() {
    _trafficData.value = [];
    _isTrafficLoading.value = true;
    if (_chartsInitialized) {
      _refreshTraffic();
    }
  }

  void _checkLazyLoadTargets() {
    if (!_chartsVisible.value && _isKeyVisible(_chartsKey)) {
      _chartsVisible.value = true;
      _startChartData();
    }
    if (!_topDownVisible.value && _isKeyVisible(_topDownKey)) {
      _topDownVisible.value = true;
    }
  }

  bool _isKeyVisible(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;

    final position = box.localToGlobal(Offset.zero);
    final viewportHeight = MediaQuery.of(ctx).size.height;
    return position.dy < viewportHeight;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _trafficTimer?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scrollController.dispose();

    _chartsVisible.dispose();
    _topDownVisible.dispose();
    _locations.dispose();
    _isLoadingLocations.dispose();
    _selectedLocationName.dispose();
    _trafficData.dispose();
    _uptimeTrendData.dispose();
    _topDownWindowDays.dispose();
    _isTrafficLoading.dispose();
    _isUptimeLoading.dispose();
    _isStatsLoading.dispose();
    _dashboardStats.dispose();
    _statsError.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return buildDashboardScreen(context);
  }
}
