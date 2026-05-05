import 'dart:async';
import 'package:flutter/material.dart';
import 'widgets/network_activity_chart.dart';
import 'widgets/summary_grid.dart';
import 'widgets/top_down.dart';
import 'widgets/dashboard_charts.dart';
import '../../models/dashboard_stats.dart';
import '../../services/location_service.dart';
import '../../services/device_service.dart';
import '../../services/dashboard_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/common/visual_feedback.dart';
import '../../widgets/components/filter_dropdown.dart';
import '../../utils/location_group_formatter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final LocationService _locationService = LocationService();
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

  final ValueNotifier<List<String>> _locationFilters = ValueNotifier([]);
  final ValueNotifier<List<String>> _deviceTypes = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingFilters = ValueNotifier(true);
  final ValueNotifier<String?> _selectedLocationFilter = ValueNotifier(null);
  final ValueNotifier<String?> _selectedDeviceType = ValueNotifier(null);
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
    _initFilters();
    _initWebSocket();

    _scrollController.addListener(_checkLazyLoadTargets);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkLazyLoadTargets());
  }

  Future<void> _initFilters() async {
    try {
      final groups = await _locationService.getLocationGroups();
      final types = await _deviceService.getDeviceTypes();
      if (!mounted) return;

      _locationFilters.value = LocationGroupFormatter.formatNames(groups);
      _deviceTypes.value = types;
      _isLoadingFilters.value = false;
    } catch (_) {
      if (!mounted) return;
      _isLoadingFilters.value = false;
    }
  }

  void _initWebSocket() {
    final wsService = WebSocketService();
    wsService.connect();

    _connectionSubscription = wsService.connectionState.listen((_) {});

    _statusSubscription = wsService.statusChanges.listen((_) {
      if (!mounted) return;
      _refreshDashboard();
      if (_chartsInitialized) _refreshUptimeTrend();
    });

    _alertRefreshSub = wsService.alertsRefresh.listen((_) {
      if (!mounted) return;
      _refreshDashboard();
      if (_chartsInitialized) _refreshUptimeTrend();
    });
  }

  void _startChartData() {
    if (_chartsInitialized) return;
    _chartsInitialized = true;
    _refreshTraffic();
    _refreshUptimeTrend();

    _localChartTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshTraffic();
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
        deviceType: _selectedDeviceType.value,
        topDownWindowDays: _topDownWindowDays.value,
      );

      if (!mounted) return;
      _dashboardStats.value = stats;
    } catch (e) {
      if (!mounted) return;
      _statsError.value = e;
    } finally {
      if (mounted) _isStatsLoading.value = false;
    }
  }

  Future<void> _refreshTraffic() async {
    try {
      final traffic = await _dashboardService.getDashboardTraffic(
        locationName: _resolveSelectedLocationFilter(),
        deviceType: _selectedDeviceType.value,
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
      if (updated.length > _maxTrafficPoints) updated.removeAt(0);
      _trafficData.value = updated;

      final updatedRaw = List<DashboardTraffic>.from(_rawTrafficData.value)
        ..add(traffic);
      if (updatedRaw.length > _maxTrafficPoints) updatedRaw.removeAt(0);
      _rawTrafficData.value = updatedRaw;

      _isTrafficLoading.value = false;
    } catch (_) {
      if (mounted) _isTrafficLoading.value = false;
    }
  }

  Future<void> _refreshUptimeTrend() async {
    try {
      final trend = await _dashboardService.getUptimeTrend(
        days: 7,
        locationName: _resolveSelectedLocationFilter(),
        deviceType: _selectedDeviceType.value,
      );
      if (!mounted) return;

      _uptimeTrendData.value = List<UptimeTrendPoint>.from(trend.data);
      _isUptimeLoading.value = false;
    } catch (_) {
      if (mounted) _isUptimeLoading.value = false;
    }
  }

  void _onFilterChanged() {
    _refreshDashboard();
    _trafficData.value = [];
    _rawTrafficData.value = [];
    _isTrafficLoading.value = true;
    if (_chartsInitialized) {
      _refreshTraffic();
      _refreshUptimeTrend();
    }
  }

  Future<void> _handleManualRefresh() async {
    await _refreshDashboard();
    if (_chartsInitialized) {
      await _refreshTraffic();
      await _refreshUptimeTrend();
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
    return position.dy < MediaQuery.of(ctx).size.height;
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
    _locationFilters.dispose();
    _deviceTypes.dispose();
    _isLoadingFilters.dispose();
    _selectedLocationFilter.dispose();
    _selectedDeviceType.dispose();
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
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ListenableBuilder(
              listenable: Listenable.merge(
                  [_isStatsLoading, _statsError, _dashboardStats]),
              builder: (context, _) {
                final loading = _isStatsLoading.value;
                final error = _statsError.value;
                final stats = _dashboardStats.value;

                if (loading && stats == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (error != null) {
                  return AsyncErrorWidget(
                      error: error, onRetry: _handleManualRefresh);
                }
                if (stats == null) {
                  return const EmptyStateWidget(
                      message: "Tidak ada data dashboard yang tersedia",
                      icon: Icons.dashboard_customize_outlined);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Overview",
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isLoadingFilters,
                      builder: (context, isLoading, _) {
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: 220,
                              child: FilterDropdown(
                                label: "Lokasi",
                                value: _selectedLocationFilter.value,
                                items: _locationFilters.value,
                                onChanged: (val) {
                                  _selectedLocationFilter.value = val;
                                  _onFilterChanged();
                                },
                              ),
                            ),
                            SizedBox(
                              width: 220,
                              child: FilterDropdown(
                                label: "Perangkat",
                                value: _selectedDeviceType.value,
                                items: _deviceTypes.value,
                                onChanged: (val) {
                                  _selectedDeviceType.value = val;
                                  _onFilterChanged();
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    DashboardSummaryGrid(
                        stats: stats,
                        offlineCount: stats.totalDevices - stats.onlineDevices),
                    const SizedBox(height: 30),
                    ValueListenableBuilder<bool>(
                      valueListenable: _chartsVisible,
                      builder: (context, visible, _) {
                        if (!visible) {
                          return Container(
                            key: _chartsKey,
                            height: 320,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade200)),
                            child: Text("Geser untuk memuat grafik",
                                style: TextStyle(color: Colors.grey[500])),
                          );
                        }

                        return Container(
                          key: _chartsKey,
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              _trafficData,
                              _isTrafficLoading,
                              _uptimeTrendData,
                              _isUptimeLoading,
                              _rawTrafficData,
                            ]),
                            builder: (context, _) {
                              return DashboardCharts(
                                trafficData: _trafficData.value,
                                rawTrafficData: _rawTrafficData.value,
                                isTrafficLoading: _isTrafficLoading.value,
                                uptimeData: _uptimeTrendData.value,
                                isUptimeLoading: _isUptimeLoading.value,
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    ValueListenableBuilder<bool>(
                      valueListenable: _topDownVisible,
                      builder: (context, visible, _) {
                        if (!visible) {
                          return Container(
                            key: _topDownKey,
                            height: 220,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.grey.shade200)),
                            child: Text("Geser untuk memuat data",
                                style: TextStyle(color: Colors.grey[500])),
                          );
                        }
                        return Container(
                          key: _topDownKey,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _topDownWindowDays,
                            builder: (context, windowDays, _) {
                              return DashboardTopDown(
                                stats: stats,
                                selectedWindowDays: windowDays,
                                onWindowChanged: (window) {
                                  _topDownWindowDays.value = window;
                                  _refreshDashboard();
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
