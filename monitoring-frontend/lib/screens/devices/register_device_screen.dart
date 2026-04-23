import 'package:flutter/material.dart';
import '../../services/device_service.dart';
import '../../models/location.dart';
import '../../models/switch_summary.dart';
import '../../models/device.dart';
import '../../models/network_node.dart';
import 'widgets/quick_add_location_dialog.dart';
import 'widgets/location_search_picker_dialog.dart';

part 'widgets/register_device_layout.dart';
part 'widgets/register_device_form_inputs.dart';
part 'widgets/register_device_form_components.dart';

class RegisterDeviceScreen extends StatefulWidget {
  final BaseNode? initialData;
  const RegisterDeviceScreen({super.key, this.initialData});

  @override
  State<RegisterDeviceScreen> createState() => _RegisterDeviceScreenState();
}

class _RegisterDeviceScreenState extends State<RegisterDeviceScreen>
    with
        RegisterDeviceFormInputs,
        RegisterDeviceFormComponents,
        RegisterDeviceLayout {
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
  bool _snmpEnabled = true;

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
      final locations = await _service.getAllLocationOptions();
      final switches = await _service.getSwitches();
      final nodes = await _service.getNetworkNodes();
      if (!mounted) return;
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

  Future<void> _openQuickAddLocationDialog() async {
    final created = await showDialog<Location>(
      context: context,
      builder: (context) => QuickAddLocationDialog(service: _service),
    );

    if (created != null) {
      final refreshed = await _service.getAllLocationOptions();
      if (!mounted) return;
      setState(() {
        _locations = refreshed;
        _selectedLocationId = created.id;
      });
    }
  }

  Future<void> _pickLocationWithSearch() async {
    final selectedId = await showDialog<int>(
      context: context,
      builder: (_) => LocationSearchPickerDialog(locations: _locations),
    );
    if (selectedId != null) {
      setState(() => _selectedLocationId = selectedId);
    }
  }

  String _selectedLocationLabel() {
    final match = _locations.where((l) => l.id == _selectedLocationId);
    if (match.isEmpty) return "Select location...";
    final location = match.first;
    if ((location.groupName ?? '').isNotEmpty) {
      return "${location.name} • ${location.groupName}";
    }
    return location.name;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final payload = {
        "hostname": _hostnameController.text.trim(),
        "snmp_enabled": _snmpEnabled,
        "force_add": _forceAdd,
        "node_type": _nodeType,
        "name": _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        "description": _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        "location_id": _selectedLocationId,
        if (_snmpEnabled) ...{
          "community": _communityController.text.trim(),
          "snmp_version": _snmpController.text.trim(),
          "port": int.tryParse(_portController.text) ?? 161,
          "transport": _transportController.text.trim(),
        },
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
    return buildRegisterDeviceScreen(context);
  }
}
