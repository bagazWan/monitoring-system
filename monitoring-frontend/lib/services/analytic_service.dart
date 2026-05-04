import 'api_client.dart';
import '../config/api_config.dart';
import '../models/analytics_data_point.dart';

class AnalyticsService {
  final ApiClient _api = ApiClient();

  Future<List<AnalyticsDataPoint>> getHistoricalMetrics({
    required DateTime startDate,
    required DateTime endDate,
    required String locationName,
  }) async {
    final endInclusive =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    final params = <String, String>{
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endInclusive.toUtc().toIso8601String(),
      'location_name': locationName,
    };

    final uri =
        Uri.parse(ApiConfig.analyticsHistory).replace(queryParameters: params);
    final response = await _api.get(uri.toString());

    return ApiClient.parseListOrItems<AnalyticsDataPoint>(
        response, AnalyticsDataPoint.fromJson);
  }
}
