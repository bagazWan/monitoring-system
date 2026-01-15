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
    WebSocketService().alertStream.listen((alertData) {
      if (mounted) {
        AlertNotification.show(
          context,
          message: alertData['message'] ?? 'New System Alert',
          severity: alertData['severity'] ?? 'info',
          deviceName:
              'Device ID: ${alertData['device_id'] ?? alertData['switch_id']}',
          onTap: () {
            AlertNotification.dismiss();
            // Navigate to the AlertScreen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AlertScreen(),
              ),
            );
          },
        );
      }
    });
  }

  @override
  void dispose() {
    WebSocketService().disconnect();
    super.dispose();
  }

  void _handleLogout() async {
    WebSocketService().disconnect();
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  // method for testing
  Future<void> _handleSync(BuildContext context) async {
    // Show loading dialog
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      await DeviceService().syncFromLibreNMS();

      if (context.mounted) {
        Navigator.pop(context); // Close loading
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
            onTap: () =>
                setState(() => _currentPageIndex = 0), // Go to Dashboard
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
          // sync button for testing only
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
      // Bottom navigation for mobile, Sidebar for web
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
                BottomNavigationBarItem(
                    icon: Icon(Icons.person), label: "Profile"),
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
