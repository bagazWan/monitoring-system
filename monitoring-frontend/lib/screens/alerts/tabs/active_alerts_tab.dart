import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/alert.dart';
import '../../../services/alert_service.dart';
import '../../../services/map_service.dart';
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
  bool _isLoading = true;
  String? _error;

  String? _selectedSeverity;
  String? _selectedLocation;
  List<String> _locations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
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

  Future<void> _loadLocations() async {
    try {
      final groups = await MapService().getLocationGroups();
      if (!mounted) return;

      final List<String> formattedNames = [];
      final parents = groups.where((g) => g.parentId == null).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      for (final parent in parents) {
        formattedNames.add(parent.name);
        final children = groups
            .where((g) => g.parentId == parent.groupId)
            .toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        for (final child in children) {
          formattedNames.add("   ↳ ${child.name}");
        }
      }

      final accountedFor = groups
          .where((g) =>
              g.parentId == null || parents.any((p) => p.groupId == g.parentId))
          .map((e) => e.groupId)
          .toSet();
      final orphans = groups
          .where((g) => !accountedFor.contains(g.groupId))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final orphan in orphans) {
        formattedNames.add(orphan.name);
      }

      setState(() => _locations = formattedNames);
    } catch (_) {}
  }

  Future<void> _fetchAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final cleanLocation = _selectedLocation?.replaceAll('↳', '').trim();
      final alerts = await AlertService().getActiveAlerts(
        severity: _selectedSeverity,
        locationName: cleanLocation,
      );

      if (mounted) {
        setState(() {
          _allAlerts = alerts;
          _allAlerts.sort((a, b) {
            if (a.severity == 'critical' && b.severity != 'critical') return -1;
            if (a.severity != 'critical' && b.severity == 'critical') return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          _isLoading = false;
        });
      }
      _loadLocations();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSeverity = null;
      _selectedLocation = null;
    });
    _fetchAlerts();
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
          onSeverityChanged: (val) {
            setState(() => _selectedSeverity = val);
            _fetchAlerts();
          },
          selectedLocation: _selectedLocation,
          locations: _locations,
          onLocationChanged: (val) {
            setState(() => _selectedLocation = val);
            _fetchAlerts();
          },
          onClear: (_selectedSeverity != null || _selectedLocation != null)
              ? _clearFilters
              : null,
        ),
        Expanded(
          child: _allAlerts.isEmpty
              ? const EmptyStateWidget(
                  message: "Tidak ada alert aktif",
                  icon: Icons.notifications_off_outlined,
                )
              : RefreshIndicator(
                  onRefresh: _fetchAlerts,
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _allAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = _allAlerts[index];
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
