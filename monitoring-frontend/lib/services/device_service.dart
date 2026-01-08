import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/dashboard_stats.dart';
import '../models/device.dart';

class DeviceService {
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final response = await http.get(Uri.parse(ApiConfig.deviceStats));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard stats');
    }
  }

  Future<DashboardStats> getDashboardSummary() async {
    final response = await http.get(Uri.parse(ApiConfig.dashboardStats));

    if (response.statusCode == 200) {
      return DashboardStats.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load dashboard summary');
    }
  }

  Future<List<BaseNode>> getAllNodes() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(ApiConfig.deviceList)),
        http.get(Uri.parse(ApiConfig.switchList)),
      ]);

      List<BaseNode> allNodes = [];

      if (responses[0].statusCode == 200) {
        final List devicesJson = jsonDecode(responses[0].body);
        allNodes.addAll(
            devicesJson.map((j) => BaseNode.fromDeviceJson(j)).toList());
      }

      if (responses[1].statusCode == 200) {
        final List switchesJson = jsonDecode(responses[1].body);
        allNodes.addAll(
            switchesJson.map((j) => BaseNode.fromSwitchJson(j)).toList());
      }

      return allNodes;
    } catch (e) {
      throw Exception("Failed to fetch nodes: $e");
    }
  }
}
