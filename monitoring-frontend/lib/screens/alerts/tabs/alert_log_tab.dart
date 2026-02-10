import 'dart:async';
import 'package:flutter/material.dart';
import '../alert_filter_bar.dart';
import '../dialogs/alert_details_dialog.dart';
import '../../../models/alert.dart';
import '../../../services/alert_service.dart';
import '../../../services/websocket_service.dart';
import '../../../../widgets/data_table.dart';
import '../../../../widgets/visual_feedback.dart';

class AlertLogTab extends StatefulWidget {
  const AlertLogTab({super.key});

  @override
  State<AlertLogTab> createState() => _AlertLogTabState();
}

class _AlertLogTabState extends State<AlertLogTab> {
  DateTimeRange? _selectedDateRange;
  List<Alert> _allLogs = [];
  List<Alert> _filteredLogs = [];

  bool _isLoading = false;
  StreamSubscription? _alertsRefreshSub;

  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  String? _error;
  String? _selectedSeverity;
  String? _selectedStatus;
  String? _selectedLocation;
  List<String> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _alertsRefreshSub = WebSocketService().alertsRefresh.listen((_) {
      if (mounted) _fetchLogs();
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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await AlertService().getAlertLogs(
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
      );

      if (!mounted) return;
      setState(() {
        _allLogs = logs;
        _extractLocations();
        _applyFilters();
      });
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _extractLocations() {
    _locations = _allLogs
        .map((a) => a.locationName)
        .where((loc) => loc.isNotEmpty && loc != ' - ')
        .toSet()
        .toList()
      ..sort();
  }

  void _applyFilters() {
    final filtered = _allLogs.where((l) {
      if (_selectedSeverity != null && l.severity != _selectedSeverity)
        return false;
      if (_selectedStatus != null && l.status != _selectedStatus) return false;
      if (_selectedLocation != null && l.locationName != _selectedLocation)
        return false;
      return true;
    }).toList();

    setState(() => _filteredLogs = filtered);
  }

  void _clearFilters() {
    setState(() {
      _selectedDateRange = null;
      _selectedSeverity = null;
      _selectedStatus = null;
      _selectedLocation = null;
    });
    _fetchLogs();
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
        AlertFilterBar(
          onRefresh: _fetchLogs,
          selectedDateRange: _selectedDateRange,
          onDateRangeChanged: (range) {
            setState(() => _selectedDateRange = range);
            _fetchLogs();
          },
          selectedSeverity: _selectedSeverity,
          onSeverityChanged: (v) {
            setState(() => _selectedSeverity = v);
            _applyFilters();
          },
          selectedStatus: _selectedStatus,
          onStatusChanged: (v) {
            setState(() => _selectedStatus = v);
            _applyFilters();
          },
          selectedLocation: _selectedLocation,
          locations: _locations,
          onLocationChanged: (v) {
            setState(() => _selectedLocation = v);
            _applyFilters();
          },
          onClear: (_selectedDateRange != null ||
                  _selectedSeverity != null ||
                  _selectedStatus != null ||
                  _selectedLocation != null)
              ? _clearFilters
              : null,
        ),
        Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? AsyncErrorWidget(error: _error!, onRetry: _fetchLogs)
                    : _filteredLogs.isEmpty
                        ? EmptyStateWidget(
                            message: _allLogs.isEmpty
                                ? "No logs found"
                                : "No logs match filters",
                            icon: Icons.history,
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20.0),
                            child: CustomDataTable(
                              columns: const [
                                DataColumn(
                                    label: Text('Created',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Cleared',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Severity',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Device',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(
                                    label: Text('Location',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('')),
                              ],
                              rows: _filteredLogs.map((a) {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(_fmt(a.createdAt.toLocal()))),
                                    DataCell(Text(a.clearedAt != null
                                        ? _fmt(a.clearedAt!.toLocal())
                                        : "-")),
                                    DataCell(
                                        _SeverityLabel(severity: a.severity)),
                                    DataCell(
                                      SizedBox(
                                        width: 180,
                                        child: Text(
                                          a.deviceName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(a.locationName)),
                                    DataCell(
                                      IconButton(
                                        tooltip: "Details",
                                        icon: const Icon(Icons.open_in_new,
                                            size: 18, color: Colors.blue),
                                        onPressed: () => _openDetails(a),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          )),
      ],
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
