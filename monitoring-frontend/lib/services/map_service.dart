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

  Future<LocationPage> getLocationsPage({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final uri = Uri.parse(ApiConfig.locations).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return LocationPage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load locations');
  }

  Future<List<Location>> getLocations() async {
    final response = await http.get(Uri.parse(ApiConfig.locations),
        headers: await _getHeaders());
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

  Future<NetworkNodePage> getNetworkNodesPage({
    int page = 1,
    int limit = 10,
    String? search,
    int? locationId,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (locationId != null) {
      params['location_id'] = locationId.toString();
    }

    final uri =
        Uri.parse(ApiConfig.networkNodes).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return NetworkNodePage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load nodes');
  }

  Future<List<NetworkNode>> getNetworkNodes() async {
    final response = await http.get(
      Uri.parse(ApiConfig.networkNodes),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((j) => NetworkNode.fromJson(j)).toList();
      }
      if (data is Map<String, dynamic>) {
        final items = data['items'] as List? ?? [];
        return items.map((j) => NetworkNode.fromJson(j)).toList();
      }
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

  Future<FORoutePage> getFORoutesPage({
    int page = 1,
    int limit = 10,
    String? search,
    int? startNodeId,
    int? endNodeId,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (startNodeId != null) {
      params['start_node_id'] = startNodeId.toString();
    }
    if (endNodeId != null) {
      params['end_node_id'] = endNodeId.toString();
    }

    final uri = Uri.parse(ApiConfig.foRoutes).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      return FORoutePage.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load routes');
  }

  Future<List<FORoute>> getFORoutes() async {
    final response = await http.get(Uri.parse(ApiConfig.foRoutes),
        headers: await _getHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((j) => FORoute.fromJson(j)).toList();
      }
      if (data is Map<String, dynamic>) {
        final items = data['items'] as List? ?? [];
        return items.map((j) => FORoute.fromJson(j)).toList();
      }
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
