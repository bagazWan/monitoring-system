import 'package:flutter/material.dart';

class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _manualToggle = true;

  @override
  Widget build(BuildContext context) {
    //  Auto-collapse if width < 1100px
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWideEnough = screenWidth > 1100;
    bool shouldExtend = isWideEnough && _manualToggle;

    const Color sidebarBg = Colors.white;
    const Color activeColor = Colors.blueAccent;
    const Color inactiveColor = Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: Colors.grey[200]!)),
      ),
      child: NavigationRail(
        backgroundColor: sidebarBg,
        extended: shouldExtend,
        minExtendedWidth: 200,
        selectedIndex: widget.selectedIndex,
        onDestinationSelected: widget.onItemSelected,
        leading: IconButton(
          icon: Icon(shouldExtend ? Icons.menu_open : Icons.menu),
          onPressed: () => setState(() => _manualToggle = !_manualToggle),
        ),
        unselectedIconTheme: const IconThemeData(color: inactiveColor),
        selectedIconTheme: const IconThemeData(color: activeColor),
        unselectedLabelTextStyle: const TextStyle(color: inactiveColor),
        selectedLabelTextStyle:
            const TextStyle(color: activeColor, fontWeight: FontWeight.bold),
        destinations: const [
          NavigationRailDestination(
              icon: Icon(Icons.dashboard), label: Text('Dashboard')),
          NavigationRailDestination(
              icon: Icon(Icons.router), label: Text('Devices')),
          NavigationRailDestination(
              icon: Icon(Icons.location_on), label: Text('Map')),
          NavigationRailDestination(
              icon: Icon(Icons.notifications), label: Text('Alerts')),
          NavigationRailDestination(
              icon: Icon(Icons.person), label: Text('Profile')),
        ],
      ),
    );
  }
}
