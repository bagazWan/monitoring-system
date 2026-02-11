import 'package:flutter/material.dart';
import '../../services/device_service.dart';
import '../../models/location.dart';
import '../../models/switch_summary.dart';
import '../../models/device.dart';
import '../../models/network_node.dart';

class RegisterNodeScreen extends StatefulWidget {
  final BaseNode? initialData;

  const RegisterNodeScreen({super.key, this.initialData});

  @override
  State<RegisterNodeScreen> createState() => _RegisterNodeScreenState();
}

class _RegisterNodeScreenState extends State<RegisterNodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = DeviceService();
  bool _loading = false;

  late TextEditingController _hostnameController;
  late TextEditingController _nameController;
  late TextEditingController _communityController;
  late TextEditingController _snmpController;
  late TextEditingController _portController;
  late TextEditingController _transportController;
  late TextEditingController _deviceTypeController;
  late TextEditingController _descriptionController;

  String _nodeType = "device";
  bool _forceAdd = false;
  int? _selectedLocationId;
  int? _selectedSwitchId;
  int? _selectedNetworkNodeId;
  List<Location> _locations = [];
  List<SwitchSummary> _switches = [];
  List<NetworkNode> _networkNodes = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadDropdowns();
  }

  void _initControllers() {
    final d = widget.initialData;
    _hostnameController = TextEditingController(text: d?.ipAddress ?? "");
    _nameController = TextEditingController(text: d?.name ?? "");
    _deviceTypeController = TextEditingController(text: d?.deviceType ?? "");
    _descriptionController = TextEditingController(text: d?.description ?? "");
    _communityController = TextEditingController(text: "public");
    _snmpController = TextEditingController(text: "v2c");
    _portController = TextEditingController(text: "161");
    _transportController = TextEditingController(text: "udp");

    if (d != null) {
      _nodeType = d.nodeKind;
      _selectedLocationId = d.locationId;
    }
  }

  Future<void> _loadDropdowns() async {
    try {
      final locations = await _service.getLocations();
      final switches = await _service.getSwitches();
      final nodes = await _service.getNetworkNodes();
      setState(() {
        _locations = locations;
        _switches = switches;
        _networkNodes = nodes;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading dropdowns: $e")));
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final payload = {
        "hostname": _hostnameController.text.trim(),
        "community": _communityController.text.trim(),
        "snmp_version": _snmpController.text.trim(),
        "port": int.tryParse(_portController.text) ?? 161,
        "transport": _transportController.text.trim(),
        "force_add": _forceAdd,
        "node_type": _nodeType,
        "name": _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        "description": _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        "location_id": _selectedLocationId,
        if (_nodeType == 'device') ...{
          "device_type": _deviceTypeController.text.trim().isEmpty
              ? null
              : _deviceTypeController.text.trim(),
          "switch_id": _selectedSwitchId,
        },
        if (_nodeType == 'switch') ...{
          "node_id": _selectedNetworkNodeId,
        }
      };
      await _service.registerLibreNMS(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Node registered successfully")));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _hostnameController.dispose();
    _nameController.dispose();
    _communityController.dispose();
    _snmpController.dispose();
    _portController.dispose();
    _transportController.dispose();
    _deviceTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(isEditing ? "Reconnect Device" : "Register New Node",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildNodeTypeCard(),
                const SizedBox(height: 24),
                _buildSectionHeader("Network Connection", Icons.lan),
                _buildFormCard([
                  _buildResponsiveRow(
                    isNarrow: isNarrow,
                    children: [
                      _buildTextField("Hostname / IP", _hostnameController,
                          required: true),
                      _buildTextField("Port", _portController,
                          keyboard: TextInputType.number),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildResponsiveRow(
                    isNarrow: isNarrow,
                    children: [
                      _buildTextField("Transport", _transportController),
                      _buildTextField("SNMP Version", _snmpController),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField("Community String", _communityController,
                      required: true, icon: Icons.vpn_key),
                ]),
                const SizedBox(height: 24),
                _buildSectionHeader("Identity & Location", Icons.info_outline),
                _buildFormCard([
                  _buildResponsiveRow(
                    isNarrow: isNarrow,
                    children: [
                      _buildTextField("Display Name", _nameController),
                      _buildTextField(
                          "Type (e.g. CCTV)", _deviceTypeController),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildResponsiveRow(
                    isNarrow: isNarrow,
                    children: [
                      _buildDropdown(
                          "Location",
                          _selectedLocationId,
                          _locations,
                          (val) => setState(() => _selectedLocationId = val)),
                      if (_nodeType == 'device')
                        _buildDropdown(
                            "Parent Switch",
                            _selectedSwitchId,
                            _switches,
                            (val) => setState(() => _selectedSwitchId = val)),
                      if (_nodeType == 'switch') _buildNetworkNodeDropdown(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField("Description", _descriptionController,
                      maxLines: 3),
                ]),
                const SizedBox(height: 24),
                _buildOptionCard(),
                const SizedBox(height: 32),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            isEditing ? "UPDATE CONNECTION" : "REGISTER NODE",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(
      {required bool isNarrow, required List<Widget> children}) {
    if (isNarrow) {
      return Column(
        children: children
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: c,
                ))
            .toList(),
      );
    } else {
      List<Widget> rowChildren = [];
      for (int i = 0; i < children.length; i++) {
        rowChildren.add(Expanded(child: children[i]));
        if (i < children.length - 1) {
          rowChildren.add(const SizedBox(width: 16));
        }
      }
      return Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: rowChildren);
    }
  }

  Widget _buildNodeTypeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Text("Node Type:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          _buildRadioChip("Device", "device"),
          const SizedBox(width: 12),
          _buildRadioChip("Switch", "switch"),
        ],
      ),
    );
  }

  Widget _buildRadioChip(String label, String val) {
    final isSelected = _nodeType == val;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _nodeType = val);
      },
      selectedColor: Colors.blue[50],
      labelStyle: TextStyle(
          color: isSelected ? Colors.blue[700] : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      backgroundColor: Colors.grey[50],
      side: BorderSide(color: isSelected ? Colors.blue : Colors.grey[300]!),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildFormCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildOptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: CheckboxListTile(
        title: const Text("Force Add"),
        subtitle: const Text("Skip ICMP check (for firewalled devices)",
            style: TextStyle(fontSize: 12)),
        value: _forceAdd,
        activeColor: Colors.blue[700],
        onChanged: (v) => setState(() => _forceAdd = v!),
        secondary: Icon(Icons.shield_outlined, color: Colors.blue[700]),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool required = false,
      IconData? icon,
      TextInputType keyboard = TextInputType.text,
      int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      validator:
          required ? (v) => v == null || v.isEmpty ? "Required" : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            icon != null ? Icon(icon, size: 18, color: Colors.grey[500]) : null,
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 1.5)),
      ),
    );
  }

  Widget _buildDropdown(
      String label, int? value, List<dynamic> items, Function(int?) onChanged) {
    return DropdownButtonFormField<int>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem<int>(
                value: item.id,
                child: Text(item.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
      ),
    );
  }

  Widget _buildNetworkNodeDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedNetworkNodeId,
      items: _networkNodes
          .map((node) => DropdownMenuItem<int>(
                value: node.id,
                child: Text(node.name ?? "Node #${node.id} (${node.type})",
                    overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedNetworkNodeId = val),
      decoration: InputDecoration(
          labelText: "Network Node",
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!))),
    );
  }
}
