import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../../../models/location.dart';

class LocationDetailsContent extends StatelessWidget {
  final Location location;
  final List<BaseNode> nodesAtLocation;
  final bool isSheet;

  const LocationDetailsContent({
    super.key,
    required this.location,
    required this.nodesAtLocation,
    this.isSheet = false,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'offline':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding =
        isSheet ? const EdgeInsets.all(16) : const EdgeInsets.all(12);

    return Padding(
      padding: padding,
      child: ListView(
        children: [
          Text(
            location.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (location.address != null) ...[
            const SizedBox(height: 4),
            Text(location.address!),
          ],
          const SizedBox(height: 12),
          Text("Nodes at location: ${nodesAtLocation.length}"),
          const SizedBox(height: 8),
          ...nodesAtLocation.map((n) {
            final status = (n.status ?? 'unknown').toLowerCase();
            return ListTile(
              dense: true,
              title: Text(n.name),
              subtitle: Text("${n.nodeKind.toUpperCase()} • ${n.ipAddress}"),
              trailing: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _statusColor(status),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
