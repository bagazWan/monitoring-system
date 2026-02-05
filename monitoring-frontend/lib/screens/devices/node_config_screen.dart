import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../models/librenms_port.dart';
import '../../models/location.dart';
import '../../services/port_service.dart';
import '../../services/device_service.dart';
import 'register_node_screen.dart';

class DeviceConfigScreen extends StatefulWidget {
  final BaseNode node;
  const DeviceConfigScreen({super.key, required this.node});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _portService = PortsService();
  final _deviceService = DeviceService();

  // Ports State
  bool _loadingPorts = true;
  List<LibreNMSPort> _ports = [];

  // General Settings State
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _descController;

  int? _selectedLocationId;
  List<Location> _locations = [];
  bool _saving = false;
  bool _loadingDetails = true;
  bool _hasChanges = false;
  int? _currentLibreNmsId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentLibreNmsId = widget.node.librenmsId;
    _nameController = TextEditingController(text: widget.node.name);
    _ipController = TextEditingController(text: widget.node.ipAddress);
    _descController =
        TextEditingController(text: widget.node.description ?? "");
    _selectedLocationId = widget.node.locationId;
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchLocations(),
      _fetchNodeDetails(),
      _fetchPorts(),
    ]);
  }

  Future<void> _fetchNodeDetails() async {
    if (widget.node.id == null) return;
    try {
      final freshNode =
          await _deviceService.getNode(widget.node.nodeKind, widget.node.id!);
      if (mounted) {
        setState(() {
          _selectedLocationId = freshNode.locationId;
          _descController.text = freshNode.description ?? "";
          _nameController.text = freshNode.name;
          _ipController.text = freshNode.ipAddress;
          _currentLibreNmsId = freshNode.librenmsId;
          _loadingDetails = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading fresh node details: $e");
    }
  }

  Future<void> _fetchLocations() async {
    try {
      final locs = await _deviceService.getLocations();
      if (mounted) setState(() => _locations = locs);
    } catch (e) {
      debugPrint("Error loading locations: $e");
    }
  }

  Future<void> _fetchPorts() async {
    if (widget.node.id == null) return;
    setState(() => _loadingPorts = true);
    try {
      final ports = await _portService.getPorts(
        deviceId: widget.node.nodeKind == 'device' ? widget.node.id : null,
        switchId: widget.node.nodeKind == 'switch' ? widget.node.id : null,
      );
      if (mounted) setState(() => _ports = ports);
    } catch (e) {
      debugPrint("Error loading ports: $e");
    } finally {
      if (mounted) setState(() => _loadingPorts = false);
    }
  }

  Future<void> _saveGeneralSettings() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.node.id == null) return;

    setState(() => _saving = true);
    try {
      final desc = _descController.text.trim();

      await _deviceService.updateNode(widget.node.nodeKind, widget.node.id!, {
        "name": _nameController.text.trim(),
        "ip_address": _ipController.text.trim(),
        "location_id": _selectedLocationId,
        "description": desc.isEmpty ? null : desc,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Settings saved successfully")));
        setState(() => _hasChanges = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reconnectDevice() async {
    final success = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterNodeScreen(
            initialData: BaseNode(
          id: widget.node.id,
          name: _nameController.text,
          ipAddress: _ipController.text,
          description: _descController.text,
          locationId: _selectedLocationId,
          nodeKind: widget.node.nodeKind,
          deviceType: widget.node.deviceType,
          macAddress: widget.node.macAddress,
          status: widget.node.status,
          locationName: widget.node.locationName,
          switchId: widget.node.switchId,
          nodeId: widget.node.nodeId,
          lastReplacedAt: widget.node.lastReplacedAt,
          librenmsId: null,
        )),
      ),
    );

    if (success == true) {
      await _fetchNodeDetails();
      if (mounted) {
        setState(() => _hasChanges = true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Device reconnected successfully")));
      }
    }
  }

  Future<void> _unregisterDevice() async {
    if (widget.node.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Stop Monitoring?"),
        content: const Text(
            "This will remove the device from LibreNMS monitoring.\n\n"
            "The record will remain in the database as 'Offline'."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Unregister"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deviceService.unregisterNode(
            widget.node.nodeKind, widget.node.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Device unregistered (Monitoring Stopped)")));

          setState(() {
            _hasChanges = true;
            _currentLibreNmsId = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _deleteDevice() async {
    if (widget.node.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete device completely ?"),
        content: const Text(
            "This will permanently delete device from the database.\n\n"
            "History and configuration will be lost."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deviceService.deleteNode(widget.node.nodeKind, widget.node.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Device deleted successfully")));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  Future<void> _toggleEnabled(LibreNMSPort port, bool value) async {
    setState(() => port.enabled = value);
    if (!value && port.isUplink) port.isUplink = false;
    try {
      await _portService.updatePort(
          port.id, {"enabled": port.enabled, "is_uplink": port.isUplink});
    } catch (e) {
      _fetchPorts();
    }
  }

  Future<void> _toggleUplink(LibreNMSPort port, bool value) async {
    if (value) {
      for (final p in _ports) {
        if (p.id != port.id && p.isUplink) p.isUplink = false;
      }
    }
    setState(() {
      port.isUplink = value;
      if (value) port.enabled = true;
    });
    try {
      await _portService.updatePort(
          port.id, {"enabled": port.enabled, "is_uplink": port.isUplink});
    } catch (e) {
      _fetchPorts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.of(context).pop(_hasChanges);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.node.name),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: "General Settings", icon: Icon(Icons.settings)),
              Tab(text: "Port Management", icon: Icon(Icons.router)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralTab(),
            _buildPortsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("Device Identity"),
            _buildTextField("Display Name", _nameController),
            const SizedBox(height: 16),
            _buildTextField("IP Address", _ipController),
            const SizedBox(height: 24),
            _buildSectionHeader("Location & Notes"),
            DropdownButtonFormField<int>(
              value: _selectedLocationId,
              items: _locations
                  .map(
                      (l) => DropdownMenuItem(value: l.id, child: Text(l.name)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedLocationId = val),
              decoration: const InputDecoration(
                  labelText: "Location", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            _buildTextField("Description", _descController,
                maxLines: 3, required: false),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: _saving ? const SizedBox() : const Icon(Icons.save),
                label: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white),
                onPressed: _saving ? null : _saveGeneralSettings,
              ),
            ),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    final isUnmonitored = _currentLibreNmsId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Divider(height: 40, thickness: 1),
        _buildSectionHeader("Management Actions", color: Colors.red[800]!),
        if (isUnmonitored) ...[
          const Text(
            "This device is currently offline/unmonitored.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text("Reconnect to monitoring"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _reconnectDevice,
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          const Text(
            "Stop monitoring but keep record in database:",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.link_off),
              label: const Text("Unregister (Stop Monitoring)"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange[800],
                side: BorderSide(color: Colors.orange[800]!),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _unregisterDevice,
            ),
          ),
          const SizedBox(height: 24),
        ],
        const Text(
          "Permanently remove device from database:",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text("Delete device completely"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _deleteDevice,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildPortsTab() {
    if (_loadingPorts) return const Center(child: CircularProgressIndicator());
    if (_ports.isEmpty) return const Center(child: Text("No ports found"));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ports.length,
      itemBuilder: (context, index) {
        final port = _ports[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(port.ifName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("${port.ifType} • ${port.ifOperStatus}",
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    const Text("Enable", style: TextStyle(fontSize: 10)),
                    Switch(
                        value: port.enabled,
                        onChanged: (v) => _toggleEnabled(port, v)),
                  ],
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    const Text("Uplink", style: TextStyle(fontSize: 10)),
                    Switch(
                        value: port.isUplink,
                        activeThumbColor: Colors.orange,
                        onChanged: (v) => _toggleUplink(port, v)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (v) =>
          (required && (v == null || v.isEmpty)) ? "Required" : null,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
