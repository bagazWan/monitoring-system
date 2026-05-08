part of '../tabs/system_tab.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _SystemConfigFormSections on _SystemConfigTabState {
  Widget buildPollingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Pengaturan Polling",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    controller: _pingFreqCtrl,
                    label: "Frekuensi ping (detik)",
                    tooltip: "Interval poller mengecek perangkat")),
            const SizedBox(width: 24),
            Expanded(
                child: _buildTextField(
                    controller: _pingProbeCtrl,
                    label: "Jumlah paket per probe",
                    tooltip: "Jumlah paket ICMP dalam satu siklus")),
            const SizedBox(width: 24),
            Expanded(
                child: _buildTextField(
                    controller: _pingTimeoutCtrl,
                    label: "Timeout per paket (ms)",
                    tooltip: "Waktu tunggu maksimal balasan ping")),
          ],
        ),
      ],
    );
  }

  Widget buildSensitivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Pengaturan Status & Alert",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    controller: _offlineFailCtrl,
                    label: "Batas gagal ping (Offline)",
                    tooltip: "Kegagalan berturut-turut untuk status offline")),
            const SizedBox(width: 24),
            Expanded(
                child: _buildTextField(
                    controller: _recoverySuccCtrl,
                    label: "Syarat Sukses (Online)",
                    tooltip: "Sukses berturut-turut untuk pemulihan status")),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    controller: _alertRaiseCtrl,
                    label: "Siklus pemicu alert",
                    tooltip:
                        "Siklus threshold dilanggar sebelum alert muncul")),
            const SizedBox(width: 24),
            Expanded(
                child: _buildTextField(
                    controller: _alertClearCtrl,
                    label: "Siklus pemulihan alert",
                    tooltip: "Siklus threshold aman sebelum alert dihapus")),
          ],
        ),
      ],
    );
  }

  Widget buildRetentionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Retensi & Penyimpanan Histori",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildTextField(
                    controller: _histIntervalCtrl,
                    label: "Interval simpan (detik)",
                    tooltip: "Jeda penyimpanan histori metrik")),
            const SizedBox(width: 24),
            Expanded(
                child: _buildTextField(
                    controller: _histRetentionCtrl,
                    label: "Masa simpan trafik (hari)",
                    tooltip: "Batas penyimpanan data grafik/bandwidth")),
            const SizedBox(width: 24),
            Expanded(
                child: _buildTextField(
                    controller: _alertRetentionCtrl,
                    label: "Masa simpan log alert (hari)",
                    tooltip: "Batas penyimpanan histori alert")),
          ],
        ),
      ],
    );
  }

  Widget buildThresholdSection() {
    final currentRules = _rulesMap[_selectedDeviceType] ?? [];
    final bool canAddMore = currentRules.length < 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Ambang Batas (Threshold)",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: canAddMore
                  ? () {
                      setState(() {
                        _rulesMap[_selectedDeviceType]!.add(ThresholdRule(
                          metricType: 'latency',
                          condition: 'above',
                          warningValue: 0.0,
                          criticalValue: 0.0,
                        ));
                      });
                    }
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(canAddMore ? "Tambah Rule" : "Batas Rule Tercapai"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 300,
          child: DropdownButtonFormField<String>(
            value: _selectedDeviceType,
            decoration: InputDecoration(
              labelText: "Pilih Tipe Perangkat",
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: _deviceTypes
                .map((type) => DropdownMenuItem(
                    value: type, child: Text(type.toUpperCase())))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedDeviceType = val);
            },
          ),
        ),
        const SizedBox(height: 24),
        if (currentRules.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8)),
            child: const Text("Belum ada rule untuk perangkat ini",
                style: TextStyle(color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: currentRules.length,
            itemBuilder: (context, index) {
              return RuleCard(
                index: index,
                deviceType: _selectedDeviceType,
                rule: currentRules[index],
                onChanged: (updatedRule) {
                  setState(() {
                    _rulesMap[_selectedDeviceType]![index] = updatedRule;
                  });
                },
                onDelete: () {
                  setState(() {
                    _rulesMap[_selectedDeviceType]!.removeAt(index);
                  });
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon:
              const Icon(Icons.info_outline, size: 18, color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
