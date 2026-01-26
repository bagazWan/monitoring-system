import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/alert.dart';

class AlertDetailsDialog extends StatelessWidget {
  final Alert alert;
  const AlertDetailsDialog({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final dialogWidth = maxWidth < 800 ? maxWidth * 0.92 : 720.0;

        return AlertDialog(
          title: const Text("Alert Details"),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kv("Device", alert.deviceName),
                  _kv("Location", alert.locationName),
                  _kv("Severity", alert.severity),
                  _kv("Type", alert.alertType),
                  _kv("Created At", df.format(alert.createdAt.toLocal())),
                  _kv(
                    "Cleared At",
                    alert.clearedAt != null
                        ? df.format(alert.clearedAt!.toLocal())
                        : "-",
                  ),
                  const Divider(height: 24),
                  const Text(
                    "Alert Message",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(alert.message.isNotEmpty ? alert.message : "-"),
                  const SizedBox(height: 16),
                  const Text(
                    "Resolution Note",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (alert.resolutionNote != null &&
                            alert.resolutionNote!.trim().isNotEmpty)
                        ? alert.resolutionNote!
                        : "-",
                  ),
                  const SizedBox(height: 16),
                  _kv(
                    "Acknowledged By",
                    (alert.resolvedByFullName != null &&
                            alert.resolvedByFullName!.trim().isNotEmpty)
                        ? alert.resolvedByFullName!
                        : "-",
                  ),
                  _kv(
                    "Acknowledged At",
                    alert.acknowledgedAt != null
                        ? df.format(alert.acknowledgedAt!.toLocal())
                        : "-",
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          children: [
            TextSpan(
              text: "$k: ",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }
}
