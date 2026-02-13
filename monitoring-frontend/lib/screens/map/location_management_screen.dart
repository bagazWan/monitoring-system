import 'package:flutter/material.dart';
import 'tabs/location_tab.dart';
import 'tabs/network_node_tab.dart';
import 'tabs/fo_route_tab.dart';

class LocationManagementScreen extends StatefulWidget {
  const LocationManagementScreen({super.key});

  @override
  State<LocationManagementScreen> createState() =>
      _LocationManagementScreenState();
}

class _LocationManagementScreenState extends State<LocationManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Location Master Data",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[700],
          indicatorColor: Colors.blue[700],
          tabs: const [
            Tab(text: "Locations", icon: Icon(Icons.location_on)),
            Tab(text: "Network Nodes", icon: Icon(Icons.lan)),
            Tab(text: "FO Routes", icon: Icon(Icons.route)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          LocationTab(),
          NetworkNodeTab(),
          FORouteTab(),
        ],
      ),
    );
  }
}
