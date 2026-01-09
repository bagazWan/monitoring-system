import 'package:flutter/material.dart';
import '../models/device.dart';

class DeviceCard extends StatelessWidget {
  final BaseNode node;

  const DeviceCard({super.key, required this.node});

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
        leading: _buildStatusDot(node.status),
        title: Text(
          node.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle:
            Text(node.ipAddress, style: TextStyle(color: Colors.grey[600])),
        trailing: _buildTypeBadge(node.deviceType ?? 'Device'),
        // childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4.0),
            child: Divider(height: 1),
          ),
          // const Divider(),
          _buildInfoRow("MAC Address", node.macAddress ?? "N/A"),
          _buildInfoRow("Location", node.locationName ?? "Not Set"),
          _buildInfoRow("Description", node.description ?? "No description"),
          _buildInfoRow("Last Replaced", node.lastReplacedAt ?? "N/A"),
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
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
