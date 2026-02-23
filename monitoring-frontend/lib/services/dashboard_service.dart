import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/dashboard_stats.dart';
import '../services/auth_service.dart';

class DashboardService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<DashboardStats> getDashboardStats(
      {int? locationId, int? topDownWindowDays}) async {
    final params = <String, String>{};
    if (locationId != null) {
      params['location_id'] = locationId.toString();
    }
    if (topDownWindowDays != null) {
      params['top_down_window'] = topDownWindowDays.toString();
    }

    final uri = Uri.parse(ApiConfig.dashboardStats)
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return DashboardStats.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load dashboard stats');
  }

  Future<DashboardTraffic> getDashboardTraffic({int? locationId}) async {
    final params = <String, String>{};
    if (locationId != null) {
      params['location_id'] = locationId.toString();
    }

    final uri = Uri.parse(ApiConfig.dashboardTraffic)
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return DashboardTraffic.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load dashboard traffic');
  }

  Future<UptimeTrendResponse> getUptimeTrend(
      {int days = 7, int? locationId}) async {
    final params = <String, String>{'days': days.toString()};
    if (locationId != null) {
      params['location_id'] = locationId.toString();
    }

    final uri = Uri.parse(ApiConfig.dashboardUptimeTrend)
        .replace(queryParameters: params);

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return UptimeTrendResponse.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load uptime trend');
  }
}
