import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../node_config_screen.dart';
import '../../../utils/bandwidth_formatter.dart';

class DeviceCard extends StatelessWidget {
  final BaseNode node;
  final bool isAdmin;
  final bool canViewIp;
  final VoidCallback? onRefresh;
  final Map<String, dynamic>? liveStats;
  final String? currentStatus;

  const DeviceCard({
    super.key,
    required this.node,
    this.isAdmin = false,
    this.canViewIp = false,
    this.onRefresh,
    this.liveStats,
    this.currentStatus,
  });

  Color _resolveStatusColor(String? status, Map<String, dynamic>? stats) {
    final s = (status ?? '').toLowerCase();
    if (s == 'offline') return Colors.grey.shade600;

    String norm(dynamic v) => (v ?? '').toString().toLowerCase();
    final bw = norm(stats?['severity']);
    final lat = norm(stats?['latency_severity']);

    bool isCritical(String x) => x == 'critical' || x == 'red';
    bool isWarning(String x) => x == 'warning' || x == 'yellow';

    if (isCritical(bw) || isCritical(lat)) return Colors.red;
    if (isWarning(bw) || isWarning(lat) || s == 'warning') return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final activeStatusColor =
        _resolveStatusColor(currentStatus ?? node.status, liveStats);

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
        leading: _buildStatusDot(activeStatusColor),
        title: Text(
          node.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: canViewIp
            ? Text(node.ipAddress, style: TextStyle(color: Colors.grey[600]))
            : null,
        trailing: _buildTypeBadge(node.deviceType ?? 'Perangkat'),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4.0),
            child: Divider(height: 1),
          ),
          _buildLiveStatsRow(context),

          // _buildInfoRow("MAC Address", node.macAddress ?? "N/A"),
          _buildInfoRow("Lokasi", node.locationName ?? "Belum diatur"),
          _buildInfoRow("Deskripsi", node.description ?? "-"),
          // _buildInfoRow("Last Replaced", node.lastReplacedAt ?? "-"),
        ],
      ),
    );
  }

  Widget _buildLiveStatsRow(BuildContext context) {
    String trafficText = "Menunggu data ...";
    bool isIdle = false;
    bool isLive = false;
    String latencyText = "-";

    if (liveStats != null) {
      final double inMbps = (liveStats!['in_mbps'] ?? 0).toDouble();
      final double outMbps = (liveStats!['out_mbps'] ?? 0).toDouble();
      final String liveStatus =
          (liveStats!['status'] ?? 'unknown').toString().toLowerCase();

      final rawLatency = liveStats!['latency_ms'] ?? liveStats!['latency'];
      if (rawLatency != null) {
        latencyText = "${(rawLatency as num).toDouble().toStringAsFixed(2)} ms";
      }

      if (liveStatus == 'offline') {
        trafficText = "Perangkat offline";
        latencyText = "-";
      } else {
        if (inMbps == 0 && outMbps == 0) {
          trafficText = "Tidak ada trafik";
          isIdle = true;
        } else {
          trafficText =
              "${BandwidthFormatter.format(inMbps)} In • ${BandwidthFormatter.format(outMbps)} Out";
          isLive = true;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text("Trafik:",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ),
                    Expanded(
                      child: Text(
                        trafficText,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isLive ? FontWeight.bold : FontWeight.normal,
                          color: isLive
                              ? Colors.blue[700]
                              : isIdle
                                  ? Colors.grey[400]
                                  : Colors.black87,
                          fontStyle:
                              isIdle ? FontStyle.italic : FontStyle.normal,
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
                    tooltip: "Konfigurasi Perangkat",
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceConfigScreen(node: node),
                        ),
                      ).then((_) => onRefresh?.call());
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: Text("Latensi:",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ),
              Text(latencyText, style: const TextStyle(fontSize: 13)),
            ],
          ),
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
