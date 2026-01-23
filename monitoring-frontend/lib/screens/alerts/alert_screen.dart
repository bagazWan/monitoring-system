import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/alert.dart';
import '../../services/alert_service.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/alert_card.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isTechnicianOrAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = await AuthService().getCurrentUser();
    setState(() {
      _isTechnicianOrAdmin = (user.role == 'admin' || user.role == 'teknisi');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Incident Log',
          style: TextStyle(
              color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue[700],
          tabs: const [
            Tab(text: 'Active Alerts'),
            Tab(text: 'Alerts Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActiveAlertsList(isTechnicianOrAdmin: _isTechnicianOrAdmin),
          const _AlertsLogTab(),
        ],
      ),
    );
  }
}

class _ActiveAlertsList extends StatefulWidget {
  final bool isTechnicianOrAdmin;
  const _ActiveAlertsList({required this.isTechnicianOrAdmin});

  @override
  State<_ActiveAlertsList> createState() => _ActiveAlertsListState();
}

class _ActiveAlertsListState extends State<_ActiveAlertsList> {
  late Future<List<Alert>> _activeFuture;
  StreamSubscription? _alertsRefreshSub;

  @override
  void initState() {
    super.initState();
    _refresh();

    // Refresh active list whenever an alert event is pushed from websocket
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

  void _showResolveDialog(Alert alert) {
    final noteController = TextEditingController(text: alert.message);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Acknowledge / Note"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resolution Note :",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              try {
                await AlertService()
                    .acknowledgeAlert(alert.alertId, noteController.text);
                Navigator.pop(context);
                _refresh();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Note saved"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text("Error: $e"), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text("Save Note"),
          )
        ],
      ),
    );
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return AlertCard(
                alert: snapshot.data![index],
                isTechnicianOrAdmin: widget.isTechnicianOrAdmin,
                onResolve: () => _showResolveDialog(snapshot.data![index]),
              );
            },
          );
        },
      ),
    );
  }
}

class _AlertsLogTab extends StatefulWidget {
  const _AlertsLogTab();

  @override
  State<_AlertsLogTab> createState() => _AlertsLogTabState();
}

class _AlertsLogTabState extends State<_AlertsLogTab> {
  DateTimeRange? _selectedDateRange;
  List<Alert> _logs = [];
  bool _isLoading = false;
  StreamSubscription? _alertsRefreshSub;

  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();

    // Refresh logs when websocket gets alert events
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
      setState(() => _logs = logs);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filter
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.calendar_month, size: 18),
                label: Text(
                  _selectedDateRange == null
                      ? "Filter Date"
                      : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDateRange = picked);
                    _fetchLogs();
                  }
                },
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.refresh), onPressed: _fetchLogs),
            ],
          ),
        ),

        // Table
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
                  ? const Center(child: Text("No logs found"))
                  : Scrollbar(
                      controller: _vController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _vController,
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: _hController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _hController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: MediaQuery.of(context).size.width,
                              ),
                              child: DataTable(
                                columnSpacing: 24,
                                headingRowColor:
                                    MaterialStateProperty.all(Colors.grey[100]),
                                columns: const [
                                  DataColumn(label: Text('Created At')),
                                  DataColumn(label: Text('Cleared At')),
                                  DataColumn(label: Text('Severity')),
                                  DataColumn(label: Text('Device')),
                                  DataColumn(label: Text('Location')),
                                  DataColumn(label: Text('Acknowledged By')),
                                  DataColumn(label: Text('Message')),
                                ],
                                rows: _logs.map((alert) {
                                  return DataRow(cells: [
                                    DataCell(Text(DateFormat('dd/MM HH:mm')
                                        .format(alert.createdAt.toLocal()))),
                                    DataCell(Text(alert.clearedAt != null
                                        ? DateFormat('dd/MM HH:mm')
                                            .format(alert.clearedAt!.toLocal())
                                        : "-")),
                                    DataCell(Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: alert.severity.toLowerCase() ==
                                                'critical'
                                            ? Colors.red[100]
                                            : Colors.orange[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(alert.severity.toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold)),
                                    )),
                                    DataCell(Text(alert.deviceName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold))),
                                    DataCell(Text(alert.locationName)),
                                    DataCell(Row(
                                      children: [
                                        const Icon(Icons.person_outline,
                                            size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(alert.resolvedByFullName ?? "-"),
                                      ],
                                    )),
                                    DataCell(SizedBox(
                                      width: 200,
                                      child: Text(alert.message,
                                          overflow: TextOverflow.ellipsis),
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
