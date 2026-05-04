import 'api_client.dart';
import '../config/api_config.dart';
import '../models/dashboard_stats.dart';

class DashboardService {
  final ApiClient _api = ApiClient();

  Future<DashboardStats> getDashboardStats(
      {String? locationName,
      int? topDownWindowDays,
      String? deviceType}) async {
    final params = <String, String>{};
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }
    if (deviceType != null && deviceType.isNotEmpty) {
      params['device_type'] = deviceType;
    }
    if (topDownWindowDays != null) {
      params['top_down_window'] = topDownWindowDays.toString();
    }

    final uri = Uri.parse(ApiConfig.dashboardStats)
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await _api.get(uri.toString());

    return DashboardStats.fromJson(response);
  }

  Future<DashboardTraffic> getDashboardTraffic(
      {String? locationName, String? deviceType}) async {
    final params = <String, String>{};
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }
    if (deviceType != null && deviceType.isNotEmpty) {
      params['device_type'] = deviceType;
    }

    final uri = Uri.parse(ApiConfig.dashboardTraffic)
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await _api.get(uri.toString());

    return DashboardTraffic.fromJson(response);
  }

  Future<UptimeTrendResponse> getUptimeTrend(
      {int days = 7, String? locationName, String? deviceType}) async {
    final params = <String, String>{'days': days.toString()};
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }
    if (deviceType != null && deviceType.isNotEmpty) {
      params['device_type'] = deviceType;
    }

    final uri = Uri.parse(ApiConfig.dashboardUptimeTrend)
        .replace(queryParameters: params);
    final response = await _api.get(uri.toString());

    return UptimeTrendResponse.fromJson(response);
  }
}
