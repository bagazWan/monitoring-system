import 'package:flutter/material.dart';
import '../../../services/user_service.dart';
import '../../../widgets/common/loading_button.dart';

class NotificationSettingsTab extends StatefulWidget {
  const NotificationSettingsTab({super.key});

  @override
  State<NotificationSettingsTab> createState() =>
      _NotificationSettingsTabState();
}

class _NotificationSettingsTabState extends State<NotificationSettingsTab> {
  bool _enablePopups = true;
  String _notificationLevel = 'all';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    setState(() => _isLoading = true);

    try {
      final userService = UserService();
      final userData = await userService.getCurrentUser();
      final settings = userData['notification_setting'];

      if (settings != null) {
        setState(() {
          _enablePopups = settings['enable_popups'] ?? true;
          _notificationLevel = settings['notification_level'] ?? 'all';
        });
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final userService = UserService();

      await userService.updateOwnNotifications(
          _enablePopups, _notificationLevel);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preferensi notifikasi berhasil disimpan"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Gagal menyimpan pengaturan"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Preferensi Notifikasi",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text("Aktifkan Notifikasi Popup",
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text(
                "Tampilkan notifikasi di sudut layar saat alert baru muncul."),
            activeColor: Colors.blueAccent,
            value: _enablePopups,
            onChanged: _isLoading
                ? null
                : (val) => setState(() => _enablePopups = val),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          const Text("Tingkat Notifikasi",
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text("Semua Alert (Info, Warning, Critical)"),
            subtitle: const Text(
                "Termasuk pemberitahuan saat perangkat kembali online (Info)."),
            value: 'all',
            groupValue: _notificationLevel,
            onChanged: _isLoading
                ? null
                : (val) => setState(() => _notificationLevel = val!),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            title: const Text("Hanya Warning & Critical"),
            value: 'warning_critical',
            groupValue: _notificationLevel,
            onChanged: _isLoading
                ? null
                : (val) => setState(() => _notificationLevel = val!),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            title: const Text("Hanya Critical"),
            value: 'critical',
            groupValue: _notificationLevel,
            onChanged: _isLoading
                ? null
                : (val) => setState(() => _notificationLevel = val!),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: LoadingButton(
              isLoading: _isLoading,
              onPressed: _saveSettings,
              label: "Simpan",
              icon: Icons.save,
              backgroundColor: Colors.blueAccent,
              width: 140,
            ),
          ),
        ],
      ),
    );
  }
}
