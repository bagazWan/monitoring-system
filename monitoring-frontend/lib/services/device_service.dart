import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/device.dart';
import '../models/location.dart';
import '../models/switch_summary.dart';
import '../models/network_node.dart';
import '../services/auth_service.dart';

class DeviceService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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

  Future<Map<String, Map<String, dynamic>>> getBulkLiveDetails(
      List<BaseNode> nodes) async {
    if (nodes.isEmpty) return {};

    final Map<String, Map<String, dynamic>> results = {};
    final deviceIds = nodes
        .where((n) => n.nodeKind == 'device' && n.id != null)
        .map((n) => n.id!)
        .toList();
    final switchIds = nodes
        .where((n) => n.nodeKind == 'switch' && n.id != null)
        .map((n) => n.id!)
        .toList();
    final futures = <Future<http.Response>>[];

    if (deviceIds.isNotEmpty) {
      futures.add(http.post(
        Uri.parse('${ApiConfig.devices}/bulk-live-details'),
        headers: await _getHeaders(),
        body: jsonEncode({'device_ids': deviceIds}),
      ));
    } else {
      futures.add(Future.value(http.Response('[]', 200)));
    }

    if (switchIds.isNotEmpty) {
      futures.add(http.post(
        Uri.parse('${ApiConfig.switches}/bulk-live-details'),
        headers: await _getHeaders(),
        body: jsonEncode({'switch_ids': switchIds}),
      ));
    } else {
      futures.add(Future.value(http.Response('[]', 200)));
    }

    final responses = await Future.wait(futures);

    if (deviceIds.isNotEmpty && responses[0].statusCode == 200) {
      final List<dynamic> data = jsonDecode(responses[0].body);
      for (var item in data) {
        results['device_${item['device_id']}'] = item;
      }
    }

    if (switchIds.isNotEmpty && responses[1].statusCode == 200) {
      final List<dynamic> data = jsonDecode(responses[1].body);
      for (var item in data) {
        results['switch_${item['switch_id']}'] = item;
      }
    }
    return results;
  }

  Future<List<Location>> getLocations() async {
    final response = await http.get(
      Uri.parse(ApiConfig.locations),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((j) => Location.fromJson(j)).toList();
      }
      if (data is Map<String, dynamic>) {
        final items = data['items'] as List? ?? [];
        return items.map((j) => Location.fromJson(j)).toList();
      }
    }
    throw Exception('Failed to load locations');
  }

  Future<List<NetworkNode>> getNetworkNodes() async {
    final response = await http.get(
      Uri.parse(ApiConfig.networkNodes),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return data.map((json) => NetworkNode.fromJson(json)).toList();
      }
      if (data is Map<String, dynamic>) {
        final items = data['items'] as List? ?? [];
        return items.map((json) => NetworkNode.fromJson(json)).toList();
      }
    }
    throw Exception('Failed to load network nodes');
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

  Future<NodePage> getNodesPage({
    String? search,
    String? locationName,
    String? deviceType,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }
    if (deviceType != null && deviceType.isNotEmpty) {
      params['device_type'] = deviceType;
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }

    final uri =
        Uri.parse(ApiConfig.deviceNodes).replace(queryParameters: params);

    final response = await http.get(uri, headers: await _getHeaders());
    if (response.statusCode == 200) {
      return NodePage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load devices');
  }

  Future<List<String>> getDeviceTypes() async {
    final response = await http.get(Uri.parse(ApiConfig.deviceTypes));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e.toString()).toList();
    }
    throw Exception('Failed to load device types');
  }
}
