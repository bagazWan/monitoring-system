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
        'subtitle': 'Atur nilai parameter ambang batas',
        'icon': Icons.admin_panel_settings_outlined,
        'view': const SystemConfigTab(),
      });
    }

    if (_selectedTabIndex >= tabs.length) {
      _selectedTabIndex = 0;
    }

    final isMobile = MediaQuery.of(context).size.width < 800;

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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: isMobile ? 80 : 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: tabs.length,
                              itemBuilder: (context, index) {
                                final isActive = index == _selectedTabIndex;
                                final tab = tabs[index];
                                return _buildTabItem(
                                  title: tab['title'],
                                  subtitle: tab['subtitle'],
                                  icon: tab['icon'],
                                  isActive: isActive,
                                  isMobile: isMobile,
                                  onTap: () =>
                                      setState(() => _selectedTabIndex = index),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: tabs[_selectedTabIndex]['view'] as Widget,
                    ),
                  ),
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
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.05) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? Colors.blueAccent : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        padding:
            EdgeInsets.symmetric(horizontal: isMobile ? 0 : 20, vertical: 16),
        child: isMobile
            ? Center(
                child: Icon(icon,
                    color: isActive ? Colors.blueAccent : Colors.grey[600]))
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
