import 'package:flutter/material.dart';
import '../../services/device_service.dart';
import '../../models/location.dart';
import '../../models/switch_summary.dart';
import '../../models/device.dart';

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

  // Controllers
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

  List<Location> _locations = [];
  List<SwitchSummary> _switches = [];

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadDropdowns();
  }

  void _initControllers() {
    final d = widget.initialData;
    // Pre-fill if data exists, otherwise use defaults
    _hostnameController = TextEditingController(text: d?.ipAddress ?? "");
    _nameController = TextEditingController(text: d?.name ?? "");
    _deviceTypeController = TextEditingController(text: d?.deviceType ?? "");
    _descriptionController = TextEditingController(text: d?.description ?? "");

    // SNMP Details
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
      setState(() {
        _locations = locations;
        _switches = switches;
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
        "device_type": _deviceTypeController.text.trim().isEmpty
            ? null
            : _deviceTypeController.text.trim(),
        "location_id": _selectedLocationId,
        "switch_id": _selectedSwitchId,
        "description": _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(isEditing ? "Reconnect Device" : "Register New Device"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSectionTitle("Connection Details"),
              _buildCard([
                _buildNodeTypeSelector(),
                const SizedBox(height: 16),
                _buildTextField("Hostname / IP Address", _hostnameController,
                    required: true, icon: Icons.lan),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField("Port", _portController,
                            keyboard: TextInputType.number)),
                    const SizedBox(width: 16),
                    Expanded(
                        child:
                            _buildTextField("Transport", _transportController)),
                  ],
                ),
              ]),
              const SizedBox(height: 20),
              _buildSectionTitle("SNMP Configuration"),
              _buildCard([
                _buildTextField("Community String", _communityController,
                    icon: Icons.key, required: true),
                const SizedBox(height: 16),
                _buildTextField("SNMP Version", _snmpController),
              ]),
              const SizedBox(height: 20),
              _buildSectionTitle("Identification & Location"),
              _buildCard([
                _buildTextField("Display Name", _nameController,
                    icon: Icons.label),
                const SizedBox(height: 16),
                _buildTextField(
                    "Device Kind (e.g. CCTV)", _deviceTypeController),
                const SizedBox(height: 16),
                _buildDropdown("Location", _selectedLocationId, _locations,
                    (val) => setState(() => _selectedLocationId = val)),
                const SizedBox(height: 16),
                if (_nodeType == 'device')
                  _buildDropdown(
                      "Connected Switch (Parent)",
                      _selectedSwitchId,
                      _switches,
                      (val) => setState(() => _selectedSwitchId = val)),
                if (_nodeType == 'device') const SizedBox(height: 16),
                _buildTextField("Description", _descriptionController,
                    maxLines: 3),
              ]),
              const SizedBox(height: 20),
              CheckboxListTile(
                title: const Text("Force Add"),
                subtitle: const Text("Ignore ICMP check (Add even if offline)"),
                value: _forceAdd,
                onChanged: (v) => setState(() => _forceAdd = v!),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: _loading ? const SizedBox() : const Icon(Icons.check),
                  label: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? "Update Connection" : "Register Node"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _loading ? null : _submit,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700])),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildNodeTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            title: const Text("Device"),
            value: "device",
            groupValue: _nodeType,
            onChanged: (v) => setState(() => _nodeType = v!),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            title: const Text("Switch"),
            value: "switch",
            groupValue: _nodeType,
            onChanged: (v) => setState(() => _nodeType = v!),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
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
      validator:
          required ? (v) => v == null || v.isEmpty ? "Required" : null : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
