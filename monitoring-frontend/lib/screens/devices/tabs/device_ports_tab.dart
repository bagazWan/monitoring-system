import 'package:flutter/material.dart';
import '../../../models/librenms_port.dart';
import '../../../services/port_service.dart';

class DevicePortsTab extends StatefulWidget {
  final int? deviceId;
  final int? switchId;

  const DevicePortsTab({super.key, this.deviceId, this.switchId});

  @override
  State<DevicePortsTab> createState() => _DevicePortsTabState();
}

class _DevicePortsTabState extends State<DevicePortsTab> {
  final _portService = PortsService();
  bool _loadingPorts = true;
  List<LibreNMSPort> _ports = [];

  @override
  void initState() {
    super.initState();
    _fetchPorts();
  }

  Future<void> _fetchPorts() async {
    if (widget.deviceId == null && widget.switchId == null) return;
    setState(() => _loadingPorts = true);
    try {
      final ports = await _portService.getPorts(
        deviceId: widget.deviceId,
        switchId: widget.switchId,
      );
      if (mounted) setState(() => _ports = ports);
    } catch (e) {
      debugPrint("Error loading ports: $e");
    } finally {
      if (mounted) setState(() => _loadingPorts = false);
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
    if (_loadingPorts) return const Center(child: CircularProgressIndicator());
    if (_ports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.router_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("No ports found",
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _ports.length,
      itemBuilder: (context, index) {
        final port = _ports[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor:
                  port.enabled ? Colors.blue[50] : Colors.grey[100],
              child: Icon(Icons.settings_ethernet,
                  color: port.enabled ? Colors.blue[700] : Colors.grey),
            ),
            title: Text(port.ifName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${port.ifType ?? 'Unknown'} • ${port.ifOperStatus}",
                style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Enabled",
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: port.enabled,
                        onChanged: (v) => _toggleEnabled(port, v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Uplink",
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: port.isUplink,
                        activeThumbColor: Colors.orange,
                        onChanged: (v) => _toggleUplink(port, v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
