import 'package:flutter/material.dart';
import '../../widgets/side_menu.dart';
import '../../services/auth_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentPageIndex = 0;

  // List of pages to display in the content area
  final List<Widget> _pages = [
    const Center(child: Text("Dashboard")),
    const Center(child: Text("Devices List")),
    const Center(child: Text("Map Visualization")),
    const Center(child: Text("Notifications Center")),
    const Center(child: Text("Profile Settings")),
  ];

  void _handleLogout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    final Color headerColor = Colors.white;
    final Color dividerColor = Colors.grey[300]!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: headerColor,
        elevation: 0,
        toolbarHeight: 80,
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
                    height: 100,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
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
                BottomNavigationBarItem(icon: Icon(Icons.map), label: "Map"),
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
