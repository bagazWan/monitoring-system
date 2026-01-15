import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;
  final bool isTechnicianOrAdmin;
  final VoidCallback? onResolve;

  const AlertCard({
    super.key,
    required this.alert,
    this.isTechnicianOrAdmin = false,
    this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    IconData severityIcon;

    switch (alert.severity.toLowerCase()) {
      case 'critical':
        severityColor = Colors.red[700]!;
        severityIcon = Icons.error_outline;
        break;
      case 'warning':
        severityColor = Colors.orange[800]!;
        severityIcon = Icons.warning_amber_rounded;
        break;
      default:
        severityColor = Colors.blue[700]!;
        severityIcon = Icons.info_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(severityIcon, size: 14, color: severityColor),
                      const SizedBox(width: 4),
                      Text(
                        alert.severity.toUpperCase(),
                        style: TextStyle(
                            color: severityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd MMM HH:mm').format(alert.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alert.deviceName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  alert.locationName,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(alert.alertType,
                      style: TextStyle(fontSize: 10, color: Colors.grey[700])),
                )
              ],
            ),
            const Divider(height: 24),
            Text(
              alert.message,
              style: const TextStyle(fontSize: 14, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (isTechnicianOrAdmin && alert.status == 'active') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onResolve,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("Resolve Incident"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
