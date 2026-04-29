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

  Color _statusColor(String status, String? severity) {
    if (status == 'offline') return Colors.red;
    if (status == 'warning') return Colors.orange;

    final sev = (severity ?? '').toLowerCase();
    if (sev == 'red' || sev == 'critical') return Colors.red;
    if (sev == 'yellow' || sev == 'warning') return Colors.orange;
    return Colors.green;
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
          Text("Perangkat di lokasi: ${nodesAtLocation.length}"),
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
                  color: _statusColor(status, n.severity),
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
