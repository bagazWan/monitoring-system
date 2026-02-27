import 'dart:async';
import 'package:flutter/material.dart';
import '../alert_filter_bar.dart';
import '../alert_log_table.dart';
import '../dialogs/alert_details_dialog.dart';
import '../dialogs/alert_delete_dialog.dart';
import '../../../models/alert.dart';
import '../../../services/alert_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/websocket_service.dart';
import '../../../../widgets/pagination.dart';
import '../../../../widgets/visual_feedback.dart';

class AlertLogTab extends StatefulWidget {
  const AlertLogTab({super.key});

  @override
  State<AlertLogTab> createState() => _AlertLogTabState();
}

class _AlertLogTabState extends State<AlertLogTab> {
  DateTimeRange? _selectedDateRange;
  List<Alert> _logs = [];
  int _totalItems = 0;

  bool _isLoading = false;
  bool _isAdmin = false;
  StreamSubscription? _alertsRefreshSub;

  String? _error;
  String? _selectedSeverity;
  String? _selectedStatus;
  String? _selectedLocation;
  List<String> _locations = [];

  int _currentPage = 1;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadLocations();
    _fetchLogs();
    _alertsRefreshSub = WebSocketService().alertsRefresh.listen((_) {
      if (mounted) _fetchLogs();
    });
  }

  @override
  void dispose() {
    _alertsRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = await AuthService().getCurrentUser();
      if (!mounted) return;
      setState(() => _isAdmin = user.role == 'admin');
    } catch (_) {}
  }

  Future<void> _loadLocations() async {
    try {
      final names = await AlertService().getAlertLocations();
      if (!mounted) return;
      setState(() => _locations = names);
    } catch (_) {}
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await AlertService().getAlertLogs(
        startDate: _selectedDateRange?.start,
        endDate: _selectedDateRange?.end,
        severity: _selectedSeverity,
        status: _selectedStatus,
        locationName: _selectedLocation,
        page: _currentPage,
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        _logs = page.items;
        _totalItems = page.total;
      });
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _error = e.toString());
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

  Future<void> _confirmDelete(Alert alert) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AlertDeleteConfirmDialog(
        title: "Delete alert",
        message: "Are you sure you want to delete this alert log?",
        confirmLabel: "Delete",
      ),
    );

    if (confirmed != true) return;

    await AlertService().deleteAlert(alert.alertId);

    if (!mounted) return;

    setState(() {
      _logs.removeWhere((item) => item.alertId == alert.alertId);
      _totalItems = (_totalItems - 1).clamp(0, _totalItems);
    });

    if (_logs.isEmpty && _currentPage > 1) {
      _currentPage -= 1;
    }

    await _fetchLogs();
    _loadLocations();
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDeleteConfirmDialog(
        title: "Delete filtered logs",
        message:
            "This will delete $_totalItems alert logs based on the current filters. Continue?",
        confirmLabel: "Delete All",
      ),
    );

    if (confirmed != true) return;

    await AlertService().deleteAlertLogs(
      startDate: _selectedDateRange?.start,
      endDate: _selectedDateRange?.end,
      severity: _selectedSeverity,
      status: _selectedStatus,
      locationName: _selectedLocation,
    );
    _currentPage = 1;
    await _fetchLogs();
    _loadLocations();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_totalItems / _pageSize).ceil().clamp(1, 9999);
    final start = _totalItems == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final end = (_currentPage * _pageSize).clamp(0, _totalItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlertFilterBar(
          onRefresh: _fetchLogs,
          selectedDateRange: _selectedDateRange,
          onDateRangeChanged: (range) {
            setState(() => _selectedDateRange = range);
            _currentPage = 1;
            _fetchLogs();
          },
          selectedSeverity: _selectedSeverity,
          onSeverityChanged: (v) {
            setState(() => _selectedSeverity = v);
            _currentPage = 1;
            _fetchLogs();
          },
          selectedStatus: _selectedStatus,
          onStatusChanged: (v) {
            setState(() => _selectedStatus = v);
            _currentPage = 1;
            _fetchLogs();
          },
          selectedLocation: _selectedLocation,
          locations: _locations,
          onLocationChanged: (v) {
            setState(() => _selectedLocation = v);
            _currentPage = 1;
            _fetchLogs();
          },
          onClear: (_selectedDateRange != null ||
                  _selectedSeverity != null ||
                  _selectedStatus != null ||
                  _selectedLocation != null)
              ? () {
                  setState(() {
                    _selectedDateRange = null;
                    _selectedSeverity = null;
                    _selectedStatus = null;
                    _selectedLocation = null;
                    _currentPage = 1;
                  });
                  _fetchLogs();
                }
              : null,
          trailingAction: _isAdmin
              ? ElevatedButton.icon(
                  onPressed: _totalItems == 0 ? null : _confirmDeleteAll,
                  icon: const Icon(Icons.delete_forever, size: 18),
                  label: const Text("Delete All"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                )
              : null,
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? AsyncErrorWidget(error: _error!, onRetry: _fetchLogs)
                  : _logs.isEmpty
                      ? const EmptyStateWidget(
                          message: "No logs found",
                          icon: Icons.history,
                        )
                      : ListView(
                          padding: const EdgeInsets.all(20.0),
                          children: [
                            AlertLogTable(
                              logs: _logs,
                              isAdmin: _isAdmin,
                              formatDate: _fmt,
                              onDetails: _openDetails,
                              onDelete: _confirmDelete,
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "Showing $start–$end of $_totalItems",
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            PaginationWidget(
                              currentPage: _currentPage,
                              totalPages: totalPages,
                              onPageChanged: (page) {
                                setState(() => _currentPage = page);
                                _fetchLogs();
                              },
                            ),
                          ],
                        ),
        ),
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
