import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../node_config_screen.dart';

class DeviceCard extends StatelessWidget {
  final BaseNode node;
  final bool isAdmin;
  final VoidCallback? onRefresh;
  final ValueListenable<String?>? statusListenable;
  final ValueListenable<Map<String, dynamic>?>? liveStatsListenable;

  const DeviceCard({
    super.key,
    required this.node,
    this.isAdmin = false,
    this.onRefresh,
    this.statusListenable,
    this.liveStatsListenable,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
        leading: ValueListenableBuilder<String?>(
          valueListenable: statusListenable ?? ValueNotifier(node.status),
          builder: (context, value, _) {
            final color =
                (value?.toLowerCase() == 'online') ? Colors.green : Colors.red;
            return _buildStatusDot(color);
          },
        ),
        title: Text(
          node.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle:
            Text(node.ipAddress, style: TextStyle(color: Colors.grey[600])),
        trailing: _buildTypeBadge(node.deviceType ?? 'Device'),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4.0),
            child: Divider(height: 1),
          ),
          ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: liveStatsListenable ??
                ValueNotifier<Map<String, dynamic>?>(null),
            builder: (context, liveStats, _) {
              String trafficText = "Loading...";
              bool isIdle = false;
              bool isLive = false;

              if (liveStats != null) {
                final double inMbps = (liveStats['in_mbps'] ?? 0).toDouble();
                final double outMbps = (liveStats['out_mbps'] ?? 0).toDouble();
                final String liveStatus = liveStats['status'] ?? 'unknown';

                if (liveStatus == 'offline') {
                  trafficText = "Device is Offline";
                } else {
                  if (inMbps == 0 && outMbps == 0) {
                    trafficText = "No Traffic (Idle or Disabled)";
                    isIdle = true;
                  } else {
                    trafficText =
                        "${inMbps.toStringAsFixed(2)} Mbps In • ${outMbps.toStringAsFixed(2)} Mbps Out";
                    isLive = true;
                  }
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text("Live Traffic:",
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13)),
                          ),
                          Expanded(
                            child: Text(
                              trafficText,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isLive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isLive
                                    ? Colors.blue[700]
                                    : isIdle
                                        ? Colors.grey[400]
                                        : Colors.black87,
                                fontStyle: isIdle
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.settings,
                              size: 20, color: Colors.grey),
                          tooltip: "Configure Device",
                          onPressed: () async {
                            final shouldRefresh = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeviceConfigScreen(node: node),
                              ),
                            );
                            if (shouldRefresh == true) {
                              onRefresh?.call();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          _buildInfoRow("MAC Address", node.macAddress ?? "N/A"),
          _buildInfoRow("Location", node.locationName ?? "Not Set"),
          _buildInfoRow("Description", node.description ?? "-"),
          _buildInfoRow("Last Replaced", node.lastReplacedAt ?? "-"),
        ],
      ),
    );
  }

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  Widget _buildTypeBadge(String type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.toUpperCase(),
        style: const TextStyle(
            fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text("$label:",
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
