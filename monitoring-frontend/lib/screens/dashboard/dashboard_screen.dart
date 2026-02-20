import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/dashboard_stats.dart';
import '../../models/location.dart';
import '../../services/device_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/filter_dropdown.dart';
import '../../widgets/summary_card.dart';
import '../../widgets/visual_feedback.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DeviceService _deviceService = DeviceService();

  late Future<DashboardStats> _dashboardStatsFuture;
  Timer? _refreshTimer;
  StreamSubscription<StatusChangeEvent>? _statusSubscription;
  StreamSubscription<WebSocketConnectionState>? _connectionSubscription;

  List<Location> _locations = [];
  bool _isLoadingLocations = true;
  String? _selectedLocationName; // null == All

  @override
  void initState() {
    super.initState();
    _dashboardStatsFuture = _deviceService.getDashboardStats();
    _initLocations();
    _initWebSocket();

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

  int? _resolveSelectedLocationId() {
    if (_selectedLocationName == null) return null;
    final match = _locations.where((l) => l.name == _selectedLocationName);
    if (match.isEmpty) return null;
    return match.first.id;
  }

  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {
      _dashboardStatsFuture = _deviceService.getDashboardStats(
          locationId: _resolveSelectedLocationId());
    });
  }

  Future<void> _handleManualRefresh() async {
    _refreshDashboard();
    await _dashboardStatsFuture;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
                  const SizedBox(height: 14),
                  _buildFilterRow(),
                  const SizedBox(height: 20),
                  _buildGridSummary(stats, offlineCount),
                  const SizedBox(height: 30),
                  _buildTopDownSection(stats),
                  const SizedBox(height: 30),
                  _buildVisualizationPlaceholder(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    if (_isLoadingLocations) {
      return const SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final locationNames = _locations.map((e) => e.name).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        SizedBox(
          width: 220,
          child: FilterDropdown(
            label: "Location",
            value: _selectedLocationName,
            items: locationNames,
            onChanged: (value) {
              setState(() {
                _selectedLocationName = value;
                _dashboardStatsFuture = _deviceService.getDashboardStats(
                  locationId: _resolveSelectedLocationId(),
                );
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridSummary(DashboardStats stats, int offlineCount) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 4;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 2;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: constraints.maxWidth < 600 ? 3.0 : 1.8,
          children: [
            SummaryCard(
              title: "Availability",
              value: "${stats.uptimePercentage.toStringAsFixed(2)}%",
              icon: Icons.health_and_safety_outlined,
              iconColor: Colors.green,
              subtitle: "${stats.onlineDevices}/${stats.totalDevices} online",
            ),
            SummaryCard(
              title: "Active Alerts",
              value: stats.activeAlerts.toString(),
              icon: Icons.warning_amber_rounded,
              iconColor: Colors.orange,
              subtitle: "Unresolved issues",
            ),
            SummaryCard(
              title: "Devices Down",
              value: offlineCount.toString(),
              icon: Icons.portable_wifi_off,
              iconColor: Colors.redAccent,
              subtitle: "Current offline count",
            ),
            SummaryCard(
              title: "Observed Throughput",
              value: stats.totalBandwidth == null
                  ? "N/A"
                  : "${stats.totalBandwidth!.toStringAsFixed(2)} Mbps",
              icon: Icons.speed,
              iconColor: Colors.purple,
              subtitle: stats.totalBandwidth == null
                  ? "No valid LibreNMS rate data"
                  : "Aggregate in+out traffic",
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopDownSection(DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Top Down Locations",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (stats.topDownLocations.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text("No down locations right now."),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.topDownLocations.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final item = stats.topDownLocations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withOpacity(0.12),
                    child: Text("${index + 1}",
                        style: const TextStyle(color: Colors.red)),
                  ),
                  title: Text(item.locationName),
                  trailing: Text(
                    "${item.offlineCount} offline",
                    style: const TextStyle(
                        color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVisualizationPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Performance Visualizations",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(
            child: Text("Uptime, Latency, and Bandwidth trend charts"),
          ),
        ),
      ],
    );
  }
}
