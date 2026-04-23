import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/analytics_data_point.dart';
import 'auth_service.dart';

class AnalyticsService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<AnalyticsDataPoint>> getHistoricalMetrics({
    required DateTime startDate,
    required DateTime endDate,
    required String locationName,
  }) async {
    final endInclusive =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final params = {
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endInclusive.toUtc().toIso8601String(),
      'location_name': locationName,
    };

    final uri =
        Uri.parse(ApiConfig.analyticsHistory).replace(queryParameters: params);
    final response = await http.get(uri, headers: await _getHeaders());

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => AnalyticsDataPoint.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load analytics history');
    }
  }
}
