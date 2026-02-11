import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../models/location.dart';
import '../../services/device_service.dart';
import 'register_node_screen.dart';
import 'tabs/device_general_tab.dart';
import 'tabs/device_ports_tab.dart';

class DeviceConfigScreen extends StatefulWidget {
  final BaseNode node;
  const DeviceConfigScreen({super.key, required this.node});

  @override
  State<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends State<DeviceConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _deviceService = DeviceService();

  List<Location> _locations = [];
  bool _hasChanges = false;
  int? _currentLibreNmsId;
  late BaseNode _currentNode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentNode = widget.node;
    _currentLibreNmsId = widget.node.librenmsId;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _fetchLocations();
    _fetchNodeDetails();
  }

  Future<void> _fetchNodeDetails() async {
    if (_currentNode.id == null) return;
    try {
      final freshNode =
          await _deviceService.getNode(_currentNode.nodeKind, _currentNode.id!);
      if (mounted) {
        setState(() {
          _currentNode = freshNode;
          _currentLibreNmsId = freshNode.librenmsId;
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

  Future<void> _onSave(Map<String, dynamic> data) async {
    if (_currentNode.id == null) return;
    try {
      await _deviceService.updateNode(
          _currentNode.nodeKind, _currentNode.id!, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Settings saved successfully")));
        setState(() => _hasChanges = true);
        _fetchNodeDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _onDangerAction(String action) async {
    if (_currentNode.id == null) return;

    switch (action) {
      case 'reconnect':
        await _reconnectDevice();
        break;
      case 'unregister':
        await _unregisterDevice();
        break;
      case 'delete':
        await _deleteDevice();
        break;
    }
  }

  Future<void> _reconnectDevice() async {
    final success = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RegisterNodeScreen(initialData: _currentNode)));

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
    final confirm = await _showConfirmationDialog(
      "Stop Monitoring?",
      "This will remove the device from LibreNMS monitoring.\n\nThe record will remain in the database as 'Offline'.",
      "Unregister",
      Colors.orange,
    );

    if (confirm == true) {
      try {
        await _deviceService.unregisterNode(
            _currentNode.nodeKind, _currentNode.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Device unregistered (Monitoring Stopped)")));
          setState(() {
            _hasChanges = true;
            _currentLibreNmsId = null;
          });
          _fetchNodeDetails();
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _deleteDevice() async {
    final confirm = await _showConfirmationDialog(
      "Delete device completely?",
      "This will permanently delete device from the database.\n\nHistory and configuration will be lost.",
      "Delete",
      Colors.red,
    );

    if (confirm == true) {
      try {
        await _deviceService.deleteNode(
            _currentNode.nodeKind, _currentNode.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Device deleted successfully")));
          Navigator.pop(context, true);
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<bool?> _showConfirmationDialog(
      String title, String content, String buttonLabel, Color color) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: color, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: Text(buttonLabel)),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $message")));
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
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          title: Text(_currentNode.name,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.blue[700],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.blue[700],
            indicatorWeight: 3,
            tabs: const [
              Tab(
                  text: "General Settings",
                  icon: Icon(Icons.settings_outlined)),
              Tab(text: "Port Management", icon: Icon(Icons.hub_outlined)),
            ],
          ),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: TabBarView(
              controller: _tabController,
              children: [
                DeviceGeneralTab(
                  node: _currentNode,
                  locations: _locations,
                  currentLibreNmsId: _currentLibreNmsId,
                  onSave: _onSave,
                  onDangerAction: _onDangerAction,
                ),
                DevicePortsTab(
                  deviceId: _currentNode.nodeKind == 'device'
                      ? _currentNode.id
                      : null,
                  switchId: _currentNode.nodeKind == 'switch'
                      ? _currentNode.id
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
