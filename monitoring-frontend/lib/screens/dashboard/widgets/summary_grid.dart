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
        int crossAxisCount = 4;
        if (constraints.maxWidth < 600) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 1100) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1400) {
          crossAxisCount = 4;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: constraints.maxWidth < 600 ? 3.0 : 1.8,
          children: [
            _DeviceTypeStatsCard(
              types: stats.deviceTypeStats,
              totalDevices: stats.totalDevices,
            ),
            SummaryCard(
              title: "Devices Down",
              value: offlineCount.toString(),
              icon: Icons.portable_wifi_off,
              iconColor: Colors.redAccent,
              subtitle: "Current offline devices",
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
                  ? "No valid LibreNMS rate data"
                  : "Aggregate in + out traffic",
            ),
          ],
        );
      },
    );
  }
}

class _DeviceTypeStatsCard extends StatefulWidget {
  final List<DeviceTypeStats> types;
  final int totalDevices;

  const _DeviceTypeStatsCard({
    required this.types,
    required this.totalDevices,
  });

  @override
  State<_DeviceTypeStatsCard> createState() => _DeviceTypeStatsCardState();
}

class _DeviceTypeStatsCardState extends State<_DeviceTypeStatsCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Device Stats",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const Icon(
                Icons.router,
                color: Colors.blueGrey,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${widget.totalDevices} total registered",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: false,
              thickness: 6,
              radius: const Radius.circular(8),
              child: widget.types.isEmpty
                  ? Center(
                      child: Text(
                        "No devices",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      primary: false,
                      padding: const EdgeInsets.only(right: 12),
                      itemCount: widget.types.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = widget.types[index];
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.deviceType,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              item.count.toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
