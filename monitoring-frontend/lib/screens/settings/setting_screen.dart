import 'package:flutter/material.dart';
import '../../models/user.dart';
import 'tabs/notification_tab.dart';
import 'tabs/system_tab.dart';

class SettingsScreen extends StatefulWidget {
  final User? currentUser;
  const SettingsScreen({super.key, required this.currentUser});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedTabIndex = 0;
  bool get _isAdmin => widget.currentUser?.role == 'admin';

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tabs = [
      {
        'title': 'Preferensi Notifikasi',
        'subtitle': 'Atur peringatan dan alert sistem',
        'icon': Icons.notifications_active_outlined,
        'view': const NotificationSettingsTab(),
      },
    ];

    if (_isAdmin) {
      tabs.add({
        'title': 'Konfigurasi Sistem',
        'subtitle': 'Atur nilai parameter pada sistem',
        'icon': Icons.admin_panel_settings_outlined,
        'view': const SystemConfigTab(),
      });
    }

    if (_selectedTabIndex >= tabs.length) {
      _selectedTabIndex = 0;
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

    Widget tabListWidget = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: isMobile
          ? (tabs.length <= 3
              ? Row(
                  children: tabs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final tab = entry.value;
                    return Expanded(
                      child: _buildTabItem(
                        title: tab['title'],
                        subtitle: tab['subtitle'],
                        icon: tab['icon'],
                        isActive: index == _selectedTabIndex,
                        isMobile: isMobile,
                        onTap: () => setState(() => _selectedTabIndex = index),
                      ),
                    );
                  }).toList(),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tabs.length,
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    return _buildTabItem(
                      title: tab['title'],
                      subtitle: tab['subtitle'],
                      icon: tab['icon'],
                      isActive: index == _selectedTabIndex,
                      isMobile: isMobile,
                      onTap: () => setState(() => _selectedTabIndex = index),
                    );
                  },
                ))
          : ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                return _buildTabItem(
                  title: tab['title'],
                  subtitle: tab['subtitle'],
                  icon: tab['icon'],
                  isActive: index == _selectedTabIndex,
                  isMobile: isMobile,
                  onTap: () => setState(() => _selectedTabIndex = index),
                );
              },
            ),
    );

    Widget contentWidget = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: tabs[_selectedTabIndex]['view'] as Widget,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Pengaturan",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 60, child: tabListWidget),
                        const SizedBox(height: 16),
                        Expanded(child: contentWidget),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 300, child: tabListWidget),
                        const SizedBox(width: 24),
                        Expanded(child: contentWidget),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required bool isMobile,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.05) : Colors.transparent,
          border: Border(
            left: !isMobile && isActive
                ? const BorderSide(color: Colors.blueAccent, width: 4)
                : BorderSide.none,
            bottom: isMobile && isActive
                ? const BorderSide(color: Colors.blueAccent, width: 4)
                : BorderSide.none,
          ),
        ),
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 20, vertical: isMobile ? 0 : 16),
        child: isMobile
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isActive ? Colors.blueAccent : Colors.grey[600],
                      size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? Colors.blueAccent : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(icon,
                      color: isActive ? Colors.blueAccent : Colors.grey[600],
                      size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w500,
                            color:
                                isActive ? Colors.blueAccent : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
