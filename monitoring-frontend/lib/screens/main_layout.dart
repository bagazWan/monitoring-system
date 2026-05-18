import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/layout/side_menu.dart';
import '../../widgets/components/alert_notification.dart';
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
import 'settings/setting_screen.dart';

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
    if (_currentPageIndex == 5 && index != 5) {
      _checkUser();
    }
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

      final popupsEnabled =
          _currentUser?.notificationSetting?.enablePopups ?? true;
      if (!popupsEnabled) return;

      final notifLevel =
          _currentUser?.notificationSetting?.notificationLevel ?? 'all';
      if (notifLevel == 'critical' && severity != 'critical') return;
      if (notifLevel == 'warning_critical' &&
          (severity != 'critical' && severity != 'warning')) return;

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

  Widget _buildDrawerItem(IconData icon, String title, int index,
      {int badgeCount = 0}) {
    final isSelected = _currentPageIndex == index;
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: isSelected ? Colors.blueAccent : Colors.grey[700]),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blueAccent : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withOpacity(0.05),
      onTap: () {
        Navigator.pop(context);
        _goToPage(index);
      },
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
      SettingsScreen(currentUser: _currentUser),
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
    ];

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: Colors.grey[50],
              elevation: 0,
              scrolledUnderElevation: 0,
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
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: _handleLogout,
                  tooltip: "Logout",
                ),
                const SizedBox(width: 8),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              backgroundColor: Colors.white,
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(color: Colors.blueAccent),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 30,
                            child: Icon(Icons.person,
                                size: 35, color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentUser?.username ?? 'Admin',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _buildDrawerItem(Icons.dashboard, "Home", 0),
                        _buildDrawerItem(Icons.router, "Perangkat", 1),
                        _buildDrawerItem(Icons.location_on, "Peta", 2),
                        _buildDrawerItem(Icons.notifications, "Alert", 3,
                            badgeCount: _unreadAlertCount),
                        _buildDrawerItem(Icons.analytics, "Analitik", 4),
                        const Divider(),
                        _buildDrawerItem(Icons.settings, "Pengaturan", 5),
                        if (isAdmin) _buildDrawerItem(Icons.people, "User", 6),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
      bottomNavigationBar: (isMobile && _currentPageIndex <= 4)
          ? BottomNavigationBar(
              currentIndex: _currentPageIndex,
              onTap: _goToPage,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.blueAccent,
              unselectedItemColor: Colors.grey,
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
