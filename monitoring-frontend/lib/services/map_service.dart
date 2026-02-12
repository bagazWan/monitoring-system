import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/map_topology.dart';
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
}
