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
    final response = await http.get(
      Uri.parse('${ApiConfig.alerts}/active'),
      headers: await _getHeaders(),
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
    String? status, // null = all
  }) async {
    final queryParams = <String>[];

    if (status != null && status.isNotEmpty) {
      queryParams.add('status_filter=${Uri.encodeQueryComponent(status)}');
    }

    if (severity != null && severity.isNotEmpty && severity != 'all') {
      queryParams.add('severity=${Uri.encodeQueryComponent(severity)}');
    }

    if (startDate != null) {
      queryParams.add(
          'start_date=${Uri.encodeQueryComponent(startDate.toIso8601String())}');
    }

    if (endDate != null) {
      final endInclusive =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      queryParams.add(
          'end_date=${Uri.encodeQueryComponent(endInclusive.toIso8601String())}');
    }

    final query = queryParams.isEmpty ? '' : '?${queryParams.join('&')}';

    final response = await http.get(Uri.parse('${ApiConfig.alerts}/$query'),
        headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Alert.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load alert logs');
    }
  }

  Future<void> acknowledgeAlert(int alertId, String resolutionNote) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.alerts}/$alertId'),
      headers: await _getHeaders(),
      body: json.encode({
        'resolution_note': resolutionNote,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resolve alert');
    }
  }
}
