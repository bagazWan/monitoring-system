import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/map_topology.dart';
import '../models/location.dart';
import '../models/network_node.dart';
import '../models/fo_route.dart';
import 'auth_service.dart';

class MapService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<MapTopology> getTopology() async {
    final response = await http.get(
      Uri.parse(ApiConfig.mapTopology),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return MapTopology.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load topology: ${response.body}');
  }

  Future<List<Location>> getLocations() async {
    final response = await http.get(Uri.parse(ApiConfig.locations),
        headers: await _getHeaders());
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => Location.fromJson(j)).toList();
    }
    throw Exception('Failed to load locations');
  }

  Future<void> createLocation(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConfig.locations),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Create failed');
    }
  }

  Future<void> updateLocation(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.locations}/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200) throw Exception('Update failed');
  }

  Future<void> deleteLocation(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.locations}/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Delete failed');
    }
  }

  Future<List<NetworkNode>> getNetworkNodes() async {
    final response = await http.get(
      Uri.parse(ApiConfig.networkNodes),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => NetworkNode.fromJson(j)).toList();
    }
    throw Exception('Failed to load nodes');
  }

  Future<void> createNetworkNode(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConfig.networkNodes),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Create failed');
    }
  }

  Future<void> updateNetworkNode(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
        Uri.parse('${ApiConfig.networkNodes}/$id'),
        headers: await _getHeaders(),
        body: jsonEncode(data));

    if (response.statusCode != 200) throw Exception('Update failed');
  }

  Future<void> deleteNetworkNode(int id) async {
    final response = await http.delete(
        Uri.parse('${ApiConfig.networkNodes}/$id'),
        headers: await _getHeaders());

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Delete failed');
    }
  }

  Future<List<FORoute>> getFORoutes() async {
    final response = await http.get(Uri.parse(ApiConfig.foRoutes),
        headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((j) => FORoute.fromJson(j)).toList();
    }
    throw Exception('Failed to load routes');
  }

  Future<void> createFORoute(Map<String, dynamic> data) async {
    final response = await http.post(Uri.parse(ApiConfig.foRoutes),
        headers: await _getHeaders(), body: jsonEncode(data));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Create failed');
    }
  }

  Future<void> updateFORoute(int id, Map<String, dynamic> data) async {
    final response = await http.patch(Uri.parse('${ApiConfig.foRoutes}/$id'),
        headers: await _getHeaders(), body: jsonEncode(data));

    if (response.statusCode != 200) throw Exception('Update failed');
  }

  Future<void> deleteFORoute(int id) async {
    final response = await http.delete(Uri.parse('${ApiConfig.foRoutes}/$id'),
        headers: await _getHeaders());

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Delete failed');
    }
  }
}
