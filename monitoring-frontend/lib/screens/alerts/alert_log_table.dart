import 'package:flutter/material.dart';
import '../../../models/alert.dart';
import '../../../../widgets/data_table.dart';

class AlertLogTable extends StatelessWidget {
  final List<Alert> logs;
  final bool isAdmin;
  final String Function(DateTime) formatDate;
  final void Function(Alert) onDetails;
  final void Function(Alert) onDelete;

  const AlertLogTable({
    super.key,
    required this.logs,
    required this.isAdmin,
    required this.formatDate,
    required this.onDetails,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return CustomDataTable(
      columns: const [
        DataColumn(
            label:
                Text('Created', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Cleared', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Severity',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label:
                Text('Device', style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(
            label: Text('Location',
                style: TextStyle(fontWeight: FontWeight.bold))),
        DataColumn(label: Text('')),
      ],
      rows: logs.map((a) {
        return DataRow(
          cells: [
            DataCell(Text(formatDate(a.createdAt.toLocal()))),
            DataCell(Text(a.clearedAt != null
                ? formatDate(a.clearedAt!.toLocal())
                : "-")),
            DataCell(_SeverityLabel(severity: a.severity)),
            DataCell(
              SizedBox(
                width: 180,
                child: Text(
                  a.deviceName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
            DataCell(Text(a.locationName)),
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: "Details",
                    icon: const Icon(Icons.open_in_new,
                        size: 18, color: Colors.blue),
                    onPressed: () => onDetails(a),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: "Delete",
                      icon:
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => onDelete(a),
                    ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _SeverityLabel extends StatelessWidget {
  final String severity;
  const _SeverityLabel({required this.severity});

  @override
  Widget build(BuildContext context) {
    final s = severity.toLowerCase();
    final Color bg = s == 'critical'
        ? Colors.red[100]!
        : (s == 'warning' ? Colors.orange[100]! : Colors.blue[100]!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        severity.toUpperCase(),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
