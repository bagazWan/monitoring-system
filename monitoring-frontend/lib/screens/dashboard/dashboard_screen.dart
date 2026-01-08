import 'package:flutter/material.dart';
import 'dart:async';
import '../../widgets/summary_card.dart';
import '../../services/device_service.dart';
import '../../models/dashboard_stats.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardStats> _dashboardStatsFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _dashboardStatsFuture = DeviceService().getDashboardSummary();
    // polling every 30 seconds to refresh data
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _autoRefresh();
    });
  }

  void _autoRefresh() {
    if (mounted) {
      setState(() {
        _dashboardStatsFuture = DeviceService().getDashboardSummary();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleManualRefresh() async {
    _autoRefresh();
    await _dashboardStatsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleManualRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Overview",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<DashboardStats>(
                future: _dashboardStatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text("Error: ${snapshot.error}"),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: Text("No data available"));
                  }
                  final stats = snapshot.data!;

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
                        childAspectRatio: constraints.maxWidth < 600
                            ? 3.0
                            : (constraints.maxWidth < 1100 ? 2.0 : 1.8),
                        children: [
                          SummaryCard(
                            title: "Total Devices",
                            value: stats.totalDevices.toString(),
                            icon: Icons.devices,
                            iconColor: Colors.blueAccent,
                            subtitle: "All monitored devices",
                          ),
                          SummaryCard(
                            title: "Device Status",
                            value:
                                "${stats.onlineDevices}/${stats.totalDevices}",
                            icon: Icons.check_circle_outline,
                            iconColor: Colors.green,
                            subtitle: "Online / Total",
                          ),
                          SummaryCard(
                            title: "Active Alerts",
                            value: stats.activeAlerts.toString(),
                            icon: Icons.warning_amber_rounded,
                            iconColor: Colors.orange,
                            subtitle: "Unresolved issues",
                          ),
                          SummaryCard(
                            title: "Total Bandwidth",
                            value: stats.totalBandwidth == null
                                ? "N/A"
                                : "${stats.totalBandwidth!.toStringAsFixed(2)} Mbps",
                            icon: Icons.speed,
                            iconColor: Colors.purple,
                            subtitle: stats.totalBandwidth == null
                                ? "LibreNMS not connected"
                                : "Aggregate Real-time Traffic",
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 40),
              const Text(
                "Recent Network Activity",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child:
                    const Center(child: Text("Network Activity Placeholder")),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
