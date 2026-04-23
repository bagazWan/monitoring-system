import 'package:flutter/material.dart';
import '../models/user.dart';

class SideMenu extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final User? currentUser;
  final int unreadAlertCount;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onSync,
    required this.onLogout,
    this.currentUser,
    this.unreadAlertCount = 0,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _manualToggle = true;

  Widget _buildAlertsIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications),
        if (widget.unreadAlertCount > 0)
          Positioned(
            right: -8,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.unreadAlertCount > 99
                    ? '99+'
                    : '${widget.unreadAlertCount}',
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
    double screenWidth = MediaQuery.of(context).size.width;
    bool isWideEnough = screenWidth > 1100;
    bool shouldExtend = isWideEnough && _manualToggle;

    const Color sidebarBg = Colors.white;
    const Color activeColor = Colors.blueAccent;
    const Color inactiveColor = Colors.black54;

    List<NavigationRailDestination> destinations = [
      const NavigationRailDestination(
          icon: Icon(Icons.dashboard), label: Text('Dashboard')),
      const NavigationRailDestination(
          icon: Icon(Icons.video_camera_back_rounded), label: Text('Devices')),
      const NavigationRailDestination(
          icon: Icon(Icons.location_on), label: Text('Map')),
      NavigationRailDestination(
          icon: _buildAlertsIcon(), label: const Text('Alerts')),
    ];

    bool isAdmin = widget.currentUser?.role == 'admin';

    if (isAdmin) {
      destinations.add(
        const NavigationRailDestination(
            icon: Icon(Icons.people), label: Text('Users')),
      );
    }

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
        destinations: destinations,
        trailing: Expanded(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isAdmin)
                    _buildBottomButton(
                      icon: Icons.sync,
                      label: 'Sync',
                      color: Colors.blue,
                      isExtended: shouldExtend,
                      onTap: widget.onSync,
                    ),
                  const SizedBox(height: 8),
                  _buildBottomButton(
                    icon: Icons.logout,
                    label: 'Logout',
                    color: Colors.black87,
                    isExtended: shouldExtend,
                    onTap: widget.onLogout,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isExtended,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          hoverColor: Colors.grey[100],
          child: SizedBox(
            width: isExtended ? 176 : 48,
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Icon(icon, color: color, size: 24),
                  ),
                ),
                if (isExtended) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
