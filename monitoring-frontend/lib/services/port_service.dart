import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/librenms_port.dart';
import '../services/auth_service.dart';

class PortsService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<LibreNMSPort>> getPorts({
    int? deviceId,
    int? switchId,
  }) async {
    final headers = await _getHeaders();

    final query =
        deviceId != null ? '?device_id=$deviceId' : '?switch_id=$switchId';

    final response = await http.get(
      Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.apiVersion}/librenms-ports$query'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => LibreNMSPort.fromJson(j)).toList();
    }

    throw Exception('Failed to load ports: ${response.body}');
  }

  Future<void> updatePort(int portRowId, Map<String, dynamic> payload) async {
    final headers = await _getHeaders();

    final response = await http.patch(
      Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.apiVersion}/librenms-ports/$portRowId'),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update port: ${response.body}');
    }
  }
}
