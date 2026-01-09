import 'package:flutter/material.dart';
import '../../models/device.dart';
import '../../services/device_service.dart';
import '../../widgets/device_card.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late Future<List<BaseNode>> _nodesFuture;

  @override
  void initState() {
    super.initState();
    _nodesFuture = DeviceService().getAllNodes();
  }

  Future<void> _refresh() async {
    setState(() {
      _nodesFuture = DeviceService().getAllNodes();
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Monitored devices",
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              FutureBuilder<List<BaseNode>>(
                future: _nodesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final nodes = snapshot.data ?? [];

                  if (nodes.isEmpty) {
                    return const Center(
                        child: Text("No devices registered in database."));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nodes.length,
                    itemBuilder: (context, index) {
                      return DeviceCard(node: nodes[index]);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
