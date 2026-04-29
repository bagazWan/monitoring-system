import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/side_menu.dart';
import '../../widgets/alert_notification.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../services/websocket_service.dart';
import '../../models/user.dart';
import 'dashboard/dashboard_screen.dart';
import 'devices/device_list_screen.dart';
import 'alerts/alert_screen.dart';
import 'users/user_management_screen.dart';
import 'map/map_screen.dart';
import 'analytics/analytics_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentPageIndex = 0;
  StreamSubscription? _alertSub;
  User? _currentUser;

  int _unreadAlertCount = 0;

  static const int _alertsTabIndex = 3;

  Future<void> _checkUser() async {
    try {
      final user = await AuthService().getCurrentUser();
      setState(() => _currentUser = user);
    } catch (e) {
      print("Error fetching user: $e");
    }
  }

  void _goToPage(int index) {
    setState(() {
      _currentPageIndex = index;
      if (index == _alertsTabIndex) {
        _unreadAlertCount = 0;
      }
    });
  }

  String _sanitizeAlertMessage(String message) {
    final m = message.trim();
    if (m.toLowerCase().contains('nan ms')) {
      return 'Latency unavailable';
    }
    return m.isEmpty ? 'New System Alert' : m;
  }

  @override
  void initState() {
    super.initState();
    WebSocketService().connect();
    _checkUser();

    _alertSub = WebSocketService().alertStream.listen((alertData) {
      if (!mounted) return;

      final eventType =
          (alertData['event'] ?? 'raised').toString().toLowerCase();
      final alertType =
          (alertData['alert_type'] ?? '').toString().toLowerCase();

      final isCleared = eventType == 'cleared';
      final isOfflineType = alertType == 'offline';

      final shouldPopup = !isCleared || isOfflineType;
      if (!shouldPopup) return;

      final severity =
          (alertData['severity'] ?? 'info').toString().toLowerCase();
      final rawMessage =
          (alertData['message'] ?? 'New System Alert').toString();
      final message = _sanitizeAlertMessage(rawMessage);

      final deviceName = alertData['device_name']?.toString();
      final switchName = alertData['switch_name']?.toString();
      final locationName = alertData['location_name']?.toString();

      final deviceId = alertData['device_id'];
      final switchId = alertData['switch_id'];

      final label = deviceName ??
          switchName ??
          (deviceId != null
              ? 'Device ID: $deviceId'
              : (switchId != null ? 'Switch ID: $switchId' : null));

      final displayLabel = (locationName != null && locationName.isNotEmpty)
          ? '$label • $locationName'
          : label;

      final popupSeverity = isCleared ? 'info' : severity;

      setState(() {
        _unreadAlertCount += 1;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AlertNotification.show(
          context,
          message: message,
          severity: popupSeverity,
          event: eventType,
          deviceName: displayLabel,
          onTap: () {
            AlertNotification.dismiss();
            _goToPage(_alertsTabIndex);
          },
        );
      });
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
      await SyncService().syncFromLibreNMS();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sync selesai, Status terupdate.")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync gagal: $e")),
        );
      }
    }
  }

  Widget _buildAlertNavIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications),
        if (_unreadAlertCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadAlertCount > 99 ? '99+' : '$_unreadAlertCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    final isAdmin = _currentUser?.role == 'admin';

    final pages = <Widget>[
      const DashboardScreen(),
      const DeviceListScreen(),
      const MapScreen(),
      const AlertScreen(),
      const AnalyticsScreen(),
      if (isAdmin) const UserManagementScreen(),
    ];

    if (_currentPageIndex >= pages.length) {
      _currentPageIndex = 0;
    }

    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
      const BottomNavigationBarItem(
          icon: Icon(Icons.router), label: "Perangkat"),
      const BottomNavigationBarItem(
          icon: Icon(Icons.location_on), label: "Peta"),
      BottomNavigationBarItem(icon: _buildAlertNavIcon(), label: "Alert"),
      const BottomNavigationBarItem(
          icon: Icon(Icons.analytics), label: "Analitik"),
      if (isAdmin)
        const BottomNavigationBarItem(icon: Icon(Icons.people), label: "User"),
    ];

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.grey[50],
              elevation: 0,
              scrolledUnderElevation: 0,
              toolbarHeight: 56,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1.0),
                child: Container(
                  color: Colors.grey[300],
                  height: 1.0,
                ),
              ),
              actions: [
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.blue),
                    onPressed: () => _handleSync(context),
                    tooltip: "Sync ke LibreNMS",
                  ),
                TextButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: Colors.black87),
                  label: const Text(
                    "Logout",
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _currentPageIndex,
              onTap: _goToPage,
              type: BottomNavigationBarType.fixed,
              items: navItems,
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isMobile)
              SideMenu(
                selectedIndex: _currentPageIndex,
                onItemSelected: _goToPage,
                currentUser: _currentUser,
                unreadAlertCount: _unreadAlertCount,
                onSync: () => _handleSync(context),
                onLogout: _handleLogout,
              ),
            Expanded(
              child: Container(
                color: Colors.grey[50],
                child: pages[_currentPageIndex],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
