import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../services/auth_service.dart';

class SyncService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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
}
