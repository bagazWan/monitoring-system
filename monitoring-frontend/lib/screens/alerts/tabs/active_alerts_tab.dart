import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/alert.dart';
import '../../../services/alert_service.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/alert_card.dart';
import '../../../widgets/visual_feedback.dart';
import '../dialogs/alert_acknowledge_dialog.dart';
import '../alert_filter_bar.dart';

class ActiveAlertsTab extends StatefulWidget {
  final bool isTechnicianOrAdmin;
  const ActiveAlertsTab({super.key, required this.isTechnicianOrAdmin});

  @override
  State<ActiveAlertsTab> createState() => _ActiveAlertsTabState();
}

class _ActiveAlertsTabState extends State<ActiveAlertsTab> {
  StreamSubscription? _alertsRefreshSub;

  List<Alert> _allAlerts = [];
  List<Alert> _filteredAlerts = [];
  bool _isLoading = true;
  String? _error;

  String? _selectedSeverity;
  String? _selectedLocation;
  List<String> _locations = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
    _alertsRefreshSub = WebSocketService().alertsRefresh.listen((_) {
      if (mounted) _fetchAlerts();
    });
  }

  @override
  void dispose() {
    _alertsRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final alerts = await AlertService().getActiveAlerts();
      if (mounted) {
        setState(() {
          _allAlerts = alerts;
          _allAlerts.sort((a, b) {
            if (a.severity == 'critical' && b.severity != 'critical') return -1;
            if (a.severity != 'critical' && b.severity == 'critical') return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          _extractLocations();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _extractLocations() {
    _locations = _allAlerts
        .map((a) => a.locationName)
        .where((loc) => loc.isNotEmpty && loc != ' - ')
        .toSet()
        .toList()
      ..sort();
  }

  void _applyFilters() {
    _filteredAlerts = _allAlerts.where((alert) {
      if (_selectedSeverity != null && alert.severity != _selectedSeverity)
        return false;
      if (_selectedLocation != null && alert.locationName != _selectedLocation)
        return false;
      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedSeverity = null;
      _selectedLocation = null;
      _applyFilters();
    });
  }

  Future<void> _openAcknowledgeDialog(Alert alert) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertAcknowledgeDialog(alert: alert),
    );
    if (mounted && saved == true) _fetchAlerts();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AsyncErrorWidget(
        error: _error!,
        onRetry: _fetchAlerts,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlertFilterBar(
          selectedSeverity: _selectedSeverity,
          onSeverityChanged: (val) => setState(() {
            _selectedSeverity = val;
            _applyFilters();
          }),
          selectedLocation: _selectedLocation,
          locations: _locations,
          onLocationChanged: (val) => setState(() {
            _selectedLocation = val;
            _applyFilters();
          }),
          onClear: (_selectedSeverity != null || _selectedLocation != null)
              ? _clearFilters
              : null,
        ),
        Expanded(
          child: _filteredAlerts.isEmpty
              ? EmptyStateWidget(
                  message: _allAlerts.isEmpty
                      ? "No active alerts"
                      : "No active alerts match filters",
                  icon: Icons.notifications_off_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _fetchAlerts,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = _filteredAlerts[index];
                      return AlertCard(
                        alert: alert,
                        isTechnicianOrAdmin: widget.isTechnicianOrAdmin,
                        onResolve: () => _openAcknowledgeDialog(alert),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
