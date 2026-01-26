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
          ActiveAlertsTab(isTechnicianOrAdmin: _isTechnicianOrAdmin),
          const AlertLogTab(),
        ],
      ),
    );
  }
}
