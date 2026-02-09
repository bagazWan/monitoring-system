import 'tabs/active_alerts_tab.dart';
import 'tabs/alert_log_tab.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

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
    if (!mounted) return;
    setState(() {
      _isTechnicianOrAdmin = (user.role == 'admin' || user.role == 'teknisi');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            child: const Text(
              'Incident Log',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue[700],
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Active Alerts'),
                Tab(text: 'Alerts Log'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ActiveAlertsTab(isTechnicianOrAdmin: _isTechnicianOrAdmin),
                const AlertLogTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
