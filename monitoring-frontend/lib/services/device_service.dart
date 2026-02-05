import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/dashboard_stats.dart';
import '../models/device.dart';
import '../models/location.dart';
import '../models/switch_summary.dart';
import '../services/auth_service.dart';

class DeviceService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final response = await http.get(Uri.parse(ApiConfig.dashboardStats));

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

  Future<BaseNode> getNode(String nodeKind, int id) async {
    final endpoint = nodeKind == 'switch' ? 'switches' : 'devices';
    final response = await http.get(
      Uri.parse('${ApiConfig.url}/$endpoint/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (nodeKind == 'switch') {
        return BaseNode.fromSwitchJson(json);
      } else {
        return BaseNode.fromDeviceJson(json);
      }
    } else {
      throw Exception('Failed to load node details');
    }
  }

  Future<void> syncFromLibreNMS() async {
    final response = await http.post(
      Uri.parse(ApiConfig.syncLibreNMS),
      headers: await _getHeaders(),
      body: jsonEncode({
        "default_location_id": 1,
        "update_existing": true,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Sync failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getLiveDetails(int id, String nodeType) async {
    // nodeType will be devices or switches
    final t = nodeType.toLowerCase();
    final String base = (t == 'switch' || t == 'switches')
        ? ApiConfig.switches
        : ApiConfig.devices;

    final response = await http.get(
      Uri.parse('$base/$id/live-details'),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load live data for $nodeType ID: $id');
    }
  }

  Future<List<Location>> getLocations() async {
    final response = await http.get(Uri.parse(ApiConfig.locations));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Location.fromJson(j)).toList();
    }
    throw Exception('Failed to load locations');
  }

  Future<List<SwitchSummary>> getSwitches() async {
    final response = await http.get(Uri.parse(ApiConfig.switches));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => SwitchSummary.fromJson(j)).toList();
    }
    throw Exception('Failed to load switches');
  }

  Future<Map<String, dynamic>> registerLibreNMS(
      Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(ApiConfig.registerLibreNMS),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Register failed: ${response.body}');
    }
  }

  Future<void> updateNode(
      String nodeKind, int id, Map<String, dynamic> data) async {
    final endpoint = nodeKind == 'switch' ? 'switches' : 'devices';
    final response = await http.patch(
      Uri.parse('${ApiConfig.url}/$endpoint/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update node: ${response.body}');
    }
  }

  Future<void> unregisterNode(String nodeKind, int id) async {
    final endpoint = nodeKind == 'switch' ? 'switch' : 'device';
    final response = await http.delete(
      Uri.parse('${ApiConfig.registerLibreNMS}/$endpoint/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unregister node: ${response.body}');
    }
  }

  Future<void> deleteNode(String nodeKind, int id) async {
    final endpoint = nodeKind == 'switch' ? 'switches' : 'devices';
    final response = await http.delete(
      Uri.parse('${ApiConfig.url}/$endpoint/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete node: ${response.body}');
    }
  }
}
