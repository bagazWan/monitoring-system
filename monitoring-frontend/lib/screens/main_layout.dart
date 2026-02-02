import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/side_menu.dart';
import '../../widgets/alert_notification.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/websocket_service.dart';
import 'dashboard/dashboard_screen.dart';
import 'devices/device_list_screen.dart';
import 'alerts/alert_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentPageIndex = 0;
  StreamSubscription? _alertSub;

  final List<Widget> _pages = [
    const DashboardScreen(),
    const DeviceListScreen(),
    const Center(child: Text("Map Visualization")),
    const AlertScreen(),
    const Center(child: Text("Profile Settings")),
  ];

  @override
  void initState() {
    super.initState();
    WebSocketService().connect();

    _alertSub = WebSocketService().alertStream.listen((alertData) {
      if (!mounted) return;

      final severity = (alertData['severity'] ?? 'info').toString();
      final message = (alertData['message'] ?? 'New System Alert').toString();

      final deviceId = alertData['device_id'];
      final switchId = alertData['switch_id'];

      AlertNotification.show(
        context,
        message: message,
        severity: severity,
        deviceName: deviceId != null
            ? 'Device ID: $deviceId'
            : (switchId != null ? 'Switch ID: $switchId' : null),
        onTap: () {
          AlertNotification.dismiss();
          setState(() => _currentPageIndex = 3);
        },
      );
    });
  }

  @override
  void dispose() {
    _alertSub?.cancel();
    WebSocketService().disconnect();
    super.dispose();
  }

  void _handleLogout() async {
    WebSocketService().disconnect();
    await AuthService().logout();
  }

  Future<void> _handleSync(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await DeviceService().syncFromLibreNMS();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sync Complete, Statuses updated.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync Failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    const Color headerColor = Colors.white;
    final Color dividerColor = Colors.grey[300]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: headerColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: dividerColor, height: 1.0),
        ),
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 2.0),
          child: GestureDetector(
            onTap: () => setState(() => _currentPageIndex = 0),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo_mmn.png',
                    height: 95,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.blue),
            onPressed: () => _handleSync(context),
            tooltip: "Sync with LibreNMS",
          ),
          TextButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Colors.black87),
            label:
                const Text("Logout", style: TextStyle(color: Colors.black87)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _currentPageIndex,
              onTap: (index) => setState(() => _currentPageIndex = index),
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard), label: "Home"),
                BottomNavigationBarItem(
                    icon: Icon(Icons.router), label: "Devices"),
                BottomNavigationBarItem(
                    icon: Icon(Icons.location_on), label: "Map"),
                BottomNavigationBarItem(
                    icon: Icon(Icons.notifications), label: "Alerts"),
                // BottomNavigationBarItem(
                //     icon: Icon(Icons.person), label: "Profile"),
              ],
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            SideMenu(
              selectedIndex: _currentPageIndex,
              onItemSelected: (index) =>
                  setState(() => _currentPageIndex = index),
            ),
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: _pages[_currentPageIndex],
            ),
          ),
        ],
      ),
    );
  }
}
