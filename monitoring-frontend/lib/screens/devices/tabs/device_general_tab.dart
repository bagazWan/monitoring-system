import 'package:flutter/material.dart';
import '../../../models/device.dart';
import '../../../models/location.dart';
import '../../../models/switch_summary.dart';
import '../../../models/network_node.dart';
import '../../../services/device_service.dart';
import '../../../widgets/location_search_picker_dialog.dart';

typedef SaveCallback = Future<void> Function(Map<String, dynamic> data);
typedef DangerActionCallback = Future<void> Function(String action);

class DeviceGeneralTab extends StatefulWidget {
  final BaseNode node;
  final List<Location> locations;
  final int? currentLibreNmsId;
  final SaveCallback onSave;
  final DangerActionCallback onDangerAction;

  const DeviceGeneralTab({
    super.key,
    required this.node,
    required this.locations,
    required this.currentLibreNmsId,
    required this.onSave,
    required this.onDangerAction,
  });

  @override
  State<DeviceGeneralTab> createState() => _DeviceGeneralTabState();
}

class _DeviceGeneralTabState extends State<DeviceGeneralTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _descController;
  late TextEditingController _typeController;
  int? _selectedLocationId;
  int? _selectedSwitchId;
  int? _selectedNetworkNodeId;

  List<Location> _locations = [];
  List<SwitchSummary> _switches = [];
  List<NetworkNode> _networkNodes = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.node.name);
    _ipController = TextEditingController(text: widget.node.ipAddress);
    _descController =
        TextEditingController(text: widget.node.description ?? "");
    _typeController = TextEditingController(text: widget.node.deviceType ?? "");
    _selectedLocationId = widget.node.locationId;
    if (widget.node.nodeKind == 'device') {
      _selectedSwitchId = widget.node.switchId;
    } else if (widget.node.nodeKind == 'switch') {
      _selectedNetworkNodeId = widget.node.nodeId;
    }
    _locations = List<Location>.from(widget.locations);
    _fetchDropdowns();
  }

  @override
  void didUpdateWidget(covariant DeviceGeneralTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) {
      _nameController.text = widget.node.name;
      _ipController.text = widget.node.ipAddress;
      _descController.text = widget.node.description ?? "";
      _selectedLocationId = widget.node.locationId;
      _selectedSwitchId = widget.node.switchId;
      _selectedNetworkNodeId = widget.node.nodeId;
    }

    if (oldWidget.locations != widget.locations &&
        widget.locations.isNotEmpty) {
      final mergedById = <int, Location>{
        for (final loc in _locations) loc.id: loc,
      };
      for (final loc in widget.locations) {
        mergedById[loc.id] = loc;
      }

      _locations = mergedById.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
  }

  String _selectedLocationLabel() {
    final match = _locations.where((l) => l.id == _selectedLocationId);
    if (match.isEmpty) return "Pilih lokasi...";
    final location = match.first;
    if ((location.groupName ?? '').isNotEmpty) {
      return "${location.name} • ${location.groupName}";
    }
    return location.name;
  }

  Future<void> _pickLocation() async {
    final selectedId = await showDialog<int>(
      context: context,
      builder: (_) => LocationSearchPickerDialog(locations: _locations),
    );
    if (selectedId != null) {
      setState(() => _selectedLocationId = selectedId);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave({
      "name": _nameController.text.trim(),
      "ip_address": _ipController.text.trim(),
      "description": _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      "location_id": _selectedLocationId,
      "device_type": _typeController.text.trim(),
      "switch_id": _selectedSwitchId,
      "node_id": _selectedNetworkNodeId,
    });
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _fetchDropdowns() async {
    final service = DeviceService();
    try {
      final allLocations = await service.getAllLocationOptions();
      if (mounted && allLocations.isNotEmpty) {
        setState(() {
          _locations = allLocations;
        });
      }

      if (widget.node.nodeKind == 'device') {
        final sw = await service.getSwitches();
        if (mounted) setState(() => _switches = sw);
      } else {
        final nodes = await service.getNetworkNodes();
        if (mounted) setState(() => _networkNodes = nodes);
      }
    } catch (e) {
      debugPrint("Error fetching dropdowns: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSwitch = widget.node.nodeKind == 'switch';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard("Informasi Identitas", [
              _buildTextField("Nama Tampilan", _nameController),
              const SizedBox(height: 16),
              _buildTextField("Alamat IP", _ipController),
              const SizedBox(height: 16),
              _buildTextField("Tipe Perangkat", _typeController,
                  required: false),
            ]),
            const SizedBox(height: 24),
            _buildSectionCard("Lokasi & Detail", [
              InkWell(
                onTap: _pickLocation,
                child: InputDecorator(
                  decoration: _inputDecoration("Lokasi"),
                  child: Text(_selectedLocationLabel()),
                ),
              ),
              const SizedBox(height: 16),
              if (!isSwitch)
                DropdownButtonFormField<int>(
                  value: _selectedSwitchId,
                  items: _switches
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSwitchId = val),
                  decoration: _inputDecoration("Switch/Hub terhubung"),
                ),
              if (isSwitch)
                DropdownButtonFormField<int>(
                  value: _selectedNetworkNodeId,
                  items: _networkNodes
                      .map((n) => DropdownMenuItem(
                          value: n.id, child: Text(n.name ?? "Node #${n.id}")))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => _selectedNetworkNodeId = val),
                  decoration: _inputDecoration("Node Jaringan yang digunakan"),
                ),
              const SizedBox(height: 16),
              _buildTextField("Deskripsi", _descController,
                  maxLines: 3, required: false),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: _saving ? const SizedBox() : const Icon(Icons.save),
                label: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SIMPAN PERUBAHAN",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: _saving ? null : _handleSave,
              ),
            ),
            const SizedBox(height: 40),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                  letterSpacing: 1.0)),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    final isUnmonitored = widget.currentLibreNmsId == null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          if (isUnmonitored) ...[
            _buildRealButton(
              title: "Hubung kembali ke monitoring",
              subtitle:
                  "Mengembalikan monitoring untuk perangkat ini di LibreNMS.",
              icon: Icons.link,
              color: Colors.green,
              onTap: () => widget.onDangerAction('reconnect'),
              isFilled: true,
            ),
          ] else ...[
            _buildRealButton(
              title: "Unregister (stop monitoring)",
              subtitle:
                  "simpan data di database tetapi berhenti menerima data.",
              icon: Icons.link_off,
              color: Colors.orange,
              onTap: () => widget.onDangerAction('unregister'),
              isFilled: false,
            ),
          ],
          const SizedBox(height: 12),
          _buildRealButton(
            title: "Hapus perangkat",
            subtitle: "Hapus permanen perangkat dan historinya.",
            icon: Icons.delete_forever,
            color: Colors.red,
            onTap: () => widget.onDangerAction('delete'),
            isFilled: true,
          ),
        ],
      ),
    );
  }

  Widget _buildRealButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
    required bool isFilled,
  }) {
    final childContent = Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: isFilled ? Colors.white70 : Colors.grey[700])),
            ],
          ),
        ),
      ],
    );

    if (isFilled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 1,
          ),
          onPressed: onTap,
          child: childContent,
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: color[800],
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            side: BorderSide(color: color[300]!, width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: childContent,
        ),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (v) =>
          (required && (v == null || v.isEmpty)) ? "Required" : null,
      decoration: _inputDecoration(label),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey[50],
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
    );
  }
}
