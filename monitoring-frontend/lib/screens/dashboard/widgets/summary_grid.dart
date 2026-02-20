import 'package:flutter/material.dart';
import '../../../models/dashboard_stats.dart';
import '../../../widgets/summary_card.dart';

class DashboardSummaryGrid extends StatelessWidget {
  final DashboardStats stats;
  final int offlineCount;

  const DashboardSummaryGrid({
    super.key,
    required this.stats,
    required this.offlineCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 5;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1400) {
          crossAxisCount = 3;
        }

        final cctvSubtitle = stats.cctvTotal == 0
            ? "No CCTV devices"
            : "${stats.cctvOnline}/${stats.cctvTotal} online";
        final cctvValue = stats.cctvTotal == 0
            ? "N/A"
            : "${stats.cctvUptimePercentage.toStringAsFixed(2)}%";

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: constraints.maxWidth < 600 ? 3.0 : 1.8,
          children: [
            SummaryCard(
              title: "Registered Devices Availability",
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
              subtitle: "Current offline devices",
            ),
            SummaryCard(
              title: "CCTV Availability",
              value: cctvValue,
              icon: Icons.videocam_outlined,
              iconColor: Colors.blueAccent,
              subtitle: cctvSubtitle,
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
                  : "Aggregate in + out traffic",
            ),
          ],
        );
      },
    );
  }
}
