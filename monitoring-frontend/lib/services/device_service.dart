import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/dashboard_stats.dart';

class DeviceService {
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    final response = await http.get(Uri.parse(ApiConfig.deviceStats));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard stats');
    }
  }

  Future<DashboardStats> getDashboardSummary() async {
    final response = await http.get(Uri.parse(ApiConfig.dashboardStats));

    if (response.statusCode == 200) {
      return DashboardStats.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load dashboard summary');
    }
  }
}
