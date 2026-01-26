import 'dart:async';
import 'package:flutter/material.dart';
import 'alert_log_filter_bar.dart';
import '../dialogs/alert_details_dialog.dart';
import '../../../models/alert.dart';
import '../../../services/alert_service.dart';
import '../../../services/websocket_service.dart';

class AlertLogTab extends StatefulWidget {
  const AlertLogTab({super.key});

  @override
  State<AlertLogTab> createState() => _AlertLogTabState();
}

class _AlertLogTabState extends State<AlertLogTab> {
  DateTimeRange? _selectedDateRange;
  List<Alert> _logs = [];
  bool _isLoading = false;
  StreamSubscription? _alertsRefreshSub;

  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  void initState() {
    super.initState();
    _fetchLogs();

    _alertsRefreshSub = WebSocketService().alertsRefresh.listen((_) {
      if (!mounted) return;
      _fetchLogs();
    });
  }

  @override
  void dispose() {
    _alertsRefreshSub?.cancel();
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await AlertService().getAlertLogs(
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDetails(Alert alert) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDetailsDialog(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlertLogFilterBar(
          selectedDateRange: _selectedDateRange,
          onDateRangeChanged: (range) {
            setState(() => _selectedDateRange = range);
            _fetchLogs();
          },
          onRefresh: _fetchLogs,
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? const Center(child: Text("No logs found"))
                  : _isMobile
                      ? _AlertLogMobileList(
                          logs: _logs,
                          onOpenDetails: _openDetails,
                        )
                      : _AlertLogTable(
                          logs: _logs,
                          vController: _vController,
                          hController: _hController,
                          onOpenDetails: _openDetails,
                        ),
        ),
      ],
    );
  }
}

class _AlertLogMobileList extends StatelessWidget {
  final List<Alert> logs;
  final ValueChanged<Alert> onOpenDetails;

  const _AlertLogMobileList({
    required this.logs,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final a = logs[index];

        return InkWell(
          onTap: () => onOpenDetails(a),
          borderRadius: BorderRadius.circular(12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SeverityDot(severity: a.severity),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.deviceName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          a.locationName,
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${a.alertType} • ${a.severity}",
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Created: ${a.createdAt.toLocal()}",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Details",
                    onPressed: () => onOpenDetails(a),
                    icon: const Icon(Icons.open_in_new, size: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AlertLogTable extends StatelessWidget {
  final List<Alert> logs;
  final ScrollController vController;
  final ScrollController hController;
  final ValueChanged<Alert> onOpenDetails;

  const _AlertLogTable({
    required this.logs,
    required this.vController,
    required this.hController,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: vController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: vController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: hController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: hController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width,
              ),
              child: DataTable(
                columnSpacing: 12,
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Cleared')),
                  DataColumn(label: Text('Severity')),
                  DataColumn(label: Text('Device')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('')),
                ],
                rows: logs.map((a) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_fmt(a.createdAt.toLocal()))),
                      DataCell(Text(a.clearedAt != null
                          ? _fmt(a.clearedAt!.toLocal())
                          : "-")),
                      DataCell(_SeverityChip(severity: a.severity)),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            a.deviceName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 160,
                          child: Text(
                            a.locationName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          tooltip: "Details",
                          icon: const Icon(Icons.open_in_new, size: 18),
                          onPressed: () => onOpenDetails(a),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(DateTime dt) {
    final mm = dt.minute.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return "$dd/$mo $hh:$mm";
  }
}

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

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

class _SeverityDot extends StatelessWidget {
  final String severity;
  const _SeverityDot({required this.severity});

  @override
  Widget build(BuildContext context) {
    final s = severity.toLowerCase();
    final Color c = s == 'critical'
        ? Colors.red
        : (s == 'warning' ? Colors.orange : Colors.blue);

    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}
