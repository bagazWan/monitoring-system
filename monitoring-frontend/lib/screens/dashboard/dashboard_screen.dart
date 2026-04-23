import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/metrics_provider.dart';
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

  StreamSubscription<StatusChangeEvent>? _statusSubscription;
  StreamSubscription<WebSocketConnectionState>? _connectionSubscription;
  StreamSubscription<void>? _alertRefreshSub;
  Timer? _localChartTimer;

  final GlobalKey _chartsKey = GlobalKey();
  final ValueNotifier<bool> _chartsVisible = ValueNotifier(false);
  final GlobalKey _topDownKey = GlobalKey();
  final ValueNotifier<bool> _topDownVisible = ValueNotifier(false);

  bool _chartsInitialized = false;

  final ValueNotifier<List<Location>> _rawLocations = ValueNotifier([]);
  final ValueNotifier<List<String>> _locationFilters = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingLocations = ValueNotifier(true);
  final ValueNotifier<String?> _selectedLocationFilter = ValueNotifier(null);

  final ValueNotifier<List<DashboardTraffic>> _rawTrafficData =
      ValueNotifier([]);
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

    _scrollController.addListener(_checkLazyLoadTargets);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkLazyLoadTargets());
  }

  Future<void> _initLocations() async {
    try {
      final groups = await _deviceService.getLocationGroups();
      if (!mounted) return;

      final List<String> formattedNames = [];

      final parents = groups.where((g) => g.parentId == null).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      for (final parent in parents) {
        formattedNames.add(parent.name);

        final children = groups
            .where((g) => g.parentId == parent.groupId)
            .toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        for (final child in children) {
          formattedNames.add("   ↳ ${child.name}");
        }
      }

      final accountedFor = groups
          .where((g) =>
              g.parentId == null || parents.any((p) => p.groupId == g.parentId))
          .map((e) => e.groupId)
          .toSet();
      final orphans = groups
          .where((g) => !accountedFor.contains(g.groupId))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final orphan in orphans) {
        formattedNames.add(orphan.name);
      }

      _locationFilters.value = formattedNames;
      _isLoadingLocations.value = false;
    } catch (_) {
      if (!mounted) return;
      _locationFilters.value = [];
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

    _alertRefreshSub = wsService.alertsRefresh.listen((_) {
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

    _localChartTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;

      final metrics = Provider.of<MetricsProvider>(context, listen: false);
      double currentIn = 0;
      double currentOut = 0;
      double totalLatency = 0;
      int latencyCount = 0;

      for (var d in metrics.allDeviceMetrics) {
        currentIn += (d['in_mbps'] ?? 0);
        currentOut += (d['out_mbps'] ?? 0);

        if (d['latency_ms'] != null) {
          totalLatency += (d['latency_ms'] as num).toDouble();
          latencyCount++;
        }
      }
      for (var s in metrics.allSwitchMetrics) {
        currentIn += (s['in_mbps'] ?? 0);
        currentOut += (s['out_mbps'] ?? 0);
      }

      double? avgLatency =
          latencyCount > 0 ? (totalLatency / latencyCount) : null;
      final now = DateTime.now();

      final newTrafficDataPoint = NetworkActivityData(
        timestamp: now,
        inbound: currentIn,
        outbound: currentOut,
      );

      final newRawDataPoint = DashboardTraffic(
        timestamp: now,
        inboundMbps: currentIn,
        outboundMbps: currentOut,
        latencyMs: avgLatency,
      );

      setState(() {
        final updatedTraffic =
            List<NetworkActivityData>.from(_trafficData.value)
              ..add(newTrafficDataPoint);
        if (updatedTraffic.length > _maxTrafficPoints) {
          updatedTraffic.removeAt(0);
        }
        _trafficData.value = updatedTraffic;

        final updatedRaw = List<DashboardTraffic>.from(_rawTrafficData.value)
          ..add(newRawDataPoint);
        if (updatedRaw.length > _maxTrafficPoints) {
          updatedRaw.removeAt(0);
        }
        _rawTrafficData.value = updatedRaw;
      });
    });
  }

  String? _resolveSelectedLocationFilter() {
    final raw = _selectedLocationFilter.value;
    if (raw == null) return null;
    return raw.replaceAll('↳', '').trim();
  }

  Future<void> _refreshDashboard() async {
    _isStatsLoading.value = true;
    _statsError.value = null;

    try {
      final stats = await _dashboardService.getDashboardStats(
        locationName: _resolveSelectedLocationFilter(),
        topDownWindowDays: _topDownWindowDays.value,
      );

      if (!mounted) return;
      _dashboardStats.value = stats;
    } catch (e) {
      if (!mounted) return;
      _statsError.value = e;
    } finally {
      if (mounted) {
        _isStatsLoading.value = false;
      }
    }
  }

  Future<void> _refreshTraffic() async {
    try {
      final traffic = await _dashboardService.getDashboardTraffic(
        locationName: _resolveSelectedLocationFilter(),
      );

      if (!mounted) return;

      if (traffic.inboundMbps == null &&
          traffic.outboundMbps == null &&
          traffic.latencyMs == null) {
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

      final updatedRaw = List<DashboardTraffic>.from(_rawTrafficData.value)
        ..add(traffic);
      if (updatedRaw.length > _maxTrafficPoints) {
        updatedRaw.removeAt(0);
      }
      _rawTrafficData.value = updatedRaw;

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
        locationName: _resolveSelectedLocationFilter(),
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
    _rawTrafficData.value = [];
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
    _localChartTimer?.cancel();
    _alertRefreshSub?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _scrollController.dispose();

    _chartsVisible.dispose();
    _topDownVisible.dispose();
    _rawLocations.dispose();
    _locationFilters.dispose();
    _isLoadingLocations.dispose();
    _selectedLocationFilter.dispose();
    _rawTrafficData.dispose();
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
