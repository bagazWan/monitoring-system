import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device.dart';
import '../services/device_service.dart';

class DeviceCard extends StatefulWidget {
  final BaseNode node;
  const DeviceCard({super.key, required this.node});

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  Timer? _pollingTimer;
  bool _isExpanded = false;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _toggleTimer(bool expanded) {
    setState(() {
      _isExpanded = expanded;
      if (_isExpanded) {
        // Start polling every 5 seconds when expanded
        _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
          setState(() {}); // Rebuild to trigger FutureBuilder again
        });
      } else {
        _pollingTimer?.cancel(); // Stop polling when card is closed
      }
    });
  }

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
        onExpansionChanged: _toggleTimer,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 0),
        leading: _buildStatusDot(widget.node.status!),
        title: Text(
          widget.node.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(widget.node.ipAddress,
            style: TextStyle(color: Colors.grey[600])),
        trailing: _buildTypeBadge(widget.node.deviceType ?? 'Device'),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4.0),
            child: Divider(height: 1),
          ),
          FutureBuilder<Map<String, dynamic>>(
            future: DeviceService().getLiveDetails(
                widget.node.id!,
                widget.node.deviceType?.toLowerCase() == 'switch'
                    ? 'switches'
                    : 'devices'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !_isExpanded) {
                return const LinearProgressIndicator(minHeight: 2);
              }

              if (snapshot.hasData) {
                final data = snapshot.data!;
                final String liveStatus = data['status'] ?? 'unknown';

                if (widget.node.status != liveStatus) {
                  Future.microtask(() {
                    if (mounted) {
                      setState(() {
                        widget.node.status = liveStatus;
                      });
                    }
                  });
                }
                double inMbps = (data['in_mbps'] ?? 0).toDouble();
                double outMbps = (data['out_mbps'] ?? 0).toDouble();
                // String lastPolled = data['last_seen'] ?? "N/A";

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      "Live Traffic",
                      liveStatus == 'offline'
                          ? "Offline"
                          : "${inMbps.toStringAsFixed(2)} Mbps In / ${outMbps.toStringAsFixed(2)} Mbps Out",
                      isLive: true,
                    ),
                    // Padding(
                    //   padding: const EdgeInsets.only(left: 100),
                    //   child: Text(
                    //     "Last Polled: $lastPolled",
                    //     style: TextStyle(
                    //         fontSize: 11,
                    //         color: Colors.grey[500],
                    //         fontStyle: FontStyle.italic),
                    //   ),
                    // ),
                  ],
                );
              }
              return _buildInfoRow("Live Traffic", "Unavailable");
            },
          ),
          _buildInfoRow("MAC Address", widget.node.macAddress ?? "N/A"),
          _buildInfoRow("Location", widget.node.locationName ?? "Not Set"),
          _buildInfoRow(
              "Description", widget.node.description ?? "No description"),
          _buildInfoRow("Last Replaced", widget.node.lastReplacedAt ?? "N/A"),
        ],
      ),
    );
  }

  Widget _buildStatusDot(String status) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status.toLowerCase() == 'online' ? Colors.green : Colors.red,
      ),
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

  Widget _buildInfoRow(String label, String value, {bool isLive = false}) {
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isLive ? FontWeight.bold : FontWeight.normal,
                    color: isLive ? Colors.blue : Colors.black87,
                  ))),
        ],
      ),
    );
  }
}
