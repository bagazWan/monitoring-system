import 'package:flutter/material.dart';
import '../widgets/rule_card.dart';
import '../../../models/setting.dart';
import '../../../services/setting_service.dart';
import '../../../services/device_service.dart';
import '../../../widgets/common/loading_button.dart';

part '../widgets/system_form_section.dart';

class SystemConfigTab extends StatefulWidget {
  const SystemConfigTab({super.key});

  @override
  State<SystemConfigTab> createState() => _SystemConfigTabState();
}

class _SystemConfigTabState extends State<SystemConfigTab> {
  final SettingsService _settingsService = SettingsService();

  bool _isLoadingData = true;
  bool _isSavingConfig = false;

  // Global Config Controllers
  final _pingFreqCtrl = TextEditingController();
  final _pingProbeCtrl = TextEditingController();
  final _pingTimeoutCtrl = TextEditingController();
  final _offlineFailCtrl = TextEditingController();
  final _recoverySuccCtrl = TextEditingController();
  final _alertRaiseCtrl = TextEditingController();
  final _alertClearCtrl = TextEditingController();
  final _histIntervalCtrl = TextEditingController();
  final _histRetentionCtrl = TextEditingController();
  final _alertRetentionCtrl = TextEditingController();

  // Dynamic Rules State
  String _selectedDeviceType = '';
  List<String> _deviceTypes = [];
  Map<String, List<ThresholdRule>> _rulesMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoadingData = true);
    try {
      final config = await _settingsService.getSystemConfig();
      final rules = await _settingsService.getAllRules();
      final deviceType = await DeviceService().getDeviceTypes();

      List<String> uniqueTypes = deviceType
          .map((t) => t.toLowerCase().trim())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();

      if (uniqueTypes.isEmpty) {
        uniqueTypes = rules.keys.toList();
        if (uniqueTypes.isEmpty) uniqueTypes = ['cctv'];
      }

      if (!mounted) return;

      setState(() {
        _deviceTypes = uniqueTypes;
        _selectedDeviceType = _deviceTypes.first;
        _pingFreqCtrl.text = config.pingFrequency.toString();
        _pingProbeCtrl.text = config.pingProbeCount.toString();
        _pingTimeoutCtrl.text = config.pingTimeoutMs.toString();
        _offlineFailCtrl.text = config.offlineFailRequired.toString();
        _recoverySuccCtrl.text = config.recoverySuccessRequired.toString();
        _alertRaiseCtrl.text = config.alertRaiseStreak.toString();
        _alertClearCtrl.text = config.alertClearStreak.toString();
        _histIntervalCtrl.text = config.historyIntervalSeconds.toString();
        _histRetentionCtrl.text = config.historyRetentionDays.toString();
        _alertRetentionCtrl.text = config.alertRetentionDays.toString();

        _rulesMap = rules;
        for (var type in _deviceTypes) {
          _rulesMap.putIfAbsent(type, () => []);
        }
      });
    } catch (e) {
      debugPrint("Error loading settings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Gagal memuat konfigurasi"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isSavingConfig = true);

    try {
      final currentRules = _rulesMap[_selectedDeviceType] ?? [];

      final Set<String> seenCombinations = {};
      for (var rule in currentRules) {
        final combo = '${rule.metricType}_${rule.condition}';
        if (seenCombinations.contains(combo)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                "Terdapat rule yang sama. Pastikan Tipe Metrik dan Kondisi Pemicu tidak ada yang sama."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ));
          setState(() => _isSavingConfig = false);
          return;
        }
        seenCombinations.add(combo);
      }

      final updatedConfig = SystemConfig(
        pingFrequency: int.tryParse(_pingFreqCtrl.text) ?? 5,
        pingProbeCount: int.tryParse(_pingProbeCtrl.text) ?? 3,
        pingTimeoutMs: int.tryParse(_pingTimeoutCtrl.text) ?? 1000,
        offlineFailRequired: int.tryParse(_offlineFailCtrl.text) ?? 3,
        recoverySuccessRequired: int.tryParse(_recoverySuccCtrl.text) ?? 2,
        alertRaiseStreak: int.tryParse(_alertRaiseCtrl.text) ?? 2,
        alertClearStreak: int.tryParse(_alertClearCtrl.text) ?? 2,
        historyIntervalSeconds: int.tryParse(_histIntervalCtrl.text) ?? 300,
        historyRetentionDays: int.tryParse(_histRetentionCtrl.text) ?? 365,
        alertRetentionDays: int.tryParse(_alertRetentionCtrl.text) ?? 90,
      );

      await _settingsService.updateBulkSettings(
        systemConfig: updatedConfig,
        targetDeviceType: _selectedDeviceType,
        thresholdRules: currentRules,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Konfigurasi berhasil disimpan"),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Gagal menyimpan konfigurasi"),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  @override
  void dispose() {
    _pingFreqCtrl.dispose();
    _pingProbeCtrl.dispose();
    _pingTimeoutCtrl.dispose();
    _offlineFailCtrl.dispose();
    _recoverySuccCtrl.dispose();
    _alertRaiseCtrl.dispose();
    _alertClearCtrl.dispose();
    _histIntervalCtrl.dispose();
    _histRetentionCtrl.dispose();
    _alertRetentionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Konfigurasi Sistem",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          buildPollingSection(),
          const SizedBox(height: 32),
          buildSensitivitySection(),
          const SizedBox(height: 32),
          buildRetentionSection(),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 32), child: Divider()),
          buildThresholdSection(),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.centerRight,
            child: LoadingButton(
              isLoading: _isSavingConfig,
              onPressed: _saveConfiguration,
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
