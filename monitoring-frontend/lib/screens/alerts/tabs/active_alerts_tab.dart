import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/alert.dart';
import '../../../services/alert_service.dart';
import '../../../services/websocket_service.dart';
import '../../../widgets/alert_card.dart';
import '../dialogs/alert_acknowledge_dialog.dart';

class ActiveAlertsTab extends StatefulWidget {
  final bool isTechnicianOrAdmin;
  const ActiveAlertsTab({super.key, required this.isTechnicianOrAdmin});

  @override
  State<ActiveAlertsTab> createState() => _ActiveAlertsTabState();
}

class _ActiveAlertsTabState extends State<ActiveAlertsTab> {
  late Future<List<Alert>> _activeFuture;
  StreamSubscription? _alertsRefreshSub;

  @override
  void initState() {
    super.initState();
    _refresh();

    _alertsRefreshSub = WebSocketService().alertsRefresh.listen((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void dispose() {
    _alertsRefreshSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _activeFuture = AlertService().getActiveAlerts();
    });
  }

  Future<void> _openAcknowledgeDialog(Alert alert) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertAcknowledgeDialog(alert: alert),
    );

    if (!mounted) return;
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: FutureBuilder<List<Alert>>(
        future: _activeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No active alert"));
          }

          final alerts = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return AlertCard(
                alert: alert,
                isTechnicianOrAdmin: widget.isTechnicianOrAdmin,
                onResolve: () => _openAcknowledgeDialog(alert),
              );
            },
          );
        },
      ),
    );
  }
}
