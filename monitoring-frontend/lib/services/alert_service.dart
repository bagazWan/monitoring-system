import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/alert.dart';
import '../services/auth_service.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Alert>> getActiveAlerts() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.alerts}/active'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Alert.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load active alerts');
    }
  }

  Future<List<Alert>> getAlertLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? severity,
    String? status = 'cleared',
  }) async {
    final headers = await _getHeaders();

    String query = 'status_filter=$status';

    if (severity != null && severity.isNotEmpty) {
      query += '&severity=${Uri.encodeQueryComponent(severity)}';
    }

    if (startDate != null) {
      query +=
          '&start_date=${Uri.encodeQueryComponent(startDate.toIso8601String())}';
    }

    if (endDate != null) {
      final endInclusive =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      query +=
          '&end_date=${Uri.encodeQueryComponent(endInclusive.toIso8601String())}';
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.alerts}/?$query'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Alert.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load alert logs');
    }
  }

  Future<void> resolveAlert(int alertId, String resolutionNote) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.alerts}/$alertId'),
      headers: headers,
      body: json.encode({
        'status': 'cleared',
        'message': resolutionNote,
        'cleared_at': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resolve alert');
    }
  }
}
