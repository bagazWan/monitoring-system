import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../services/device_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/device_card.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late Future<List<BaseNode>> _nodesFuture;
  List<BaseNode> _nodes = [];
  StreamSubscription<StatusChangeEvent>? _statusSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  bool _wsConnected = false;

  @override
  void initState() {
    super.initState();
    _nodesFuture = _fetchNodes();
    _initWebSocket();
  }

  Future<List<BaseNode>> _fetchNodes() async {
    final nodes = await DeviceService().getAllNodes();
    setState(() {
      _nodes = nodes;
    });
    return nodes;
  }

  void _initWebSocket() {
    final wsService = WebSocketService();

    // Connect to WebSocket
    wsService.connect();

    // Listen for connection state changes
    _connectionSubscription = wsService.connectionState.listen((connected) {
      if (mounted) {
        setState(() {
          _wsConnected = connected;
        });
      }
    });

    // Listen for status change events
    _statusSubscription = wsService.statusChanges.listen((event) {
      if (mounted) {
        _handleStatusChange(event);
      }
    });
  }

  void _handleStatusChange(StatusChangeEvent event) {
    setState(() {
      // Find and update the node with matching id and type
      for (int i = 0; i < _nodes.length; i++) {
        final node = _nodes[i];
        final isMatch = (event.nodeType == 'device' &&
                node.deviceType?.toLowerCase() != 'switch' &&
                node.id == event.id) ||
            (event.nodeType == 'switch' &&
                node.deviceType?.toLowerCase() == 'switch' &&
                node.id == event.id);

        if (isMatch) {
          // Update the status
          _nodes[i].status = event.newStatus;
          debugPrint(
            'Updated ${node.name} status to ${event.newStatus}',
          );
          break;
        }
      }
    });

    // Show snackbar notification for status changes
    if (mounted) {
      final color = event.newStatus == 'online' ? Colors.green : Colors.red;
      final icon =
          event.newStatus == 'online' ? Icons.check_circle : Icons.error;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${event.name} is now ${event.newStatus.toUpperCase()}',
                ),
              ),
            ],
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _nodesFuture = _fetchNodes();
    });
    await _nodesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.white,
        toolbarHeight: 0,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Device List",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<BaseNode>>(
                  future: _nodesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        _nodes.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError && _nodes.isEmpty) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (_nodes.isEmpty) {
                      return const Center(child: Text("No devices found"));
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _nodes.length,
                      itemBuilder: (context, index) {
                        return DeviceCard(
                          key: ValueKey(_nodes[index].id),
                          node: _nodes[index],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
