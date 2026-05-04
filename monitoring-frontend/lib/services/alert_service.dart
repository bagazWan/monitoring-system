import 'api_client.dart';
import '../config/api_config.dart';
import '../models/alert.dart';
import '../services/location_service.dart';

class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final ApiClient _api = ApiClient();

  Future<List<Alert>> getActiveAlerts(
      {String? severity, String? locationName}) async {
    final params = <String, String>{};

    if (severity != null && severity.isNotEmpty && severity != 'all') {
      params['severity'] = severity;
    }
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }

    final uri = Uri.parse('${ApiConfig.alerts}/active')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await _api.get(uri.toString());

    return ApiClient.parseListOrItems<Alert>(response, Alert.fromJson);
  }

  Future<List<String>> getAlertLocations({String? status}) async {
    final locations = await LocationService().getLocationOptions();

    final options = locations
        .map((loc) => loc.groupName?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return options;
  }

  Future<AlertPage> getAlertLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? severity,
    String? status,
    String? locationName,
    int page = 1,
    int limit = 10,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty) params['status_filter'] = status;
    if (severity != null && severity.isNotEmpty && severity != 'all') {
      params['severity'] = severity;
    }
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }
    if (startDate != null) params['start_date'] = startDate.toIso8601String();

    if (endDate != null) {
      final endInclusive =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      params['end_date'] = endInclusive.toIso8601String();
    }

    final uri = Uri.parse('${ApiConfig.alerts}/')
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await _api.get(uri.toString());

    return AlertPage.fromJson(response);
  }

  Future<void> acknowledgeAlert(int alertId, String resolutionNote) async {
    await _api.patch(
      '${ApiConfig.alerts}/$alertId',
      body: {'resolution_note': resolutionNote},
    );
  }

  Future<void> deleteAlert(int alertId) async {
    await _api.delete('${ApiConfig.alerts}/$alertId');
  }

  Future<int> deleteAlertLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? severity,
    String? status,
    String? locationName,
  }) async {
    final params = <String, String>{};

    if (status != null && status.isNotEmpty) params['status_filter'] = status;
    if (severity != null && severity.isNotEmpty && severity != 'all') {
      params['severity'] = severity;
    }
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }
    if (startDate != null) params['start_date'] = startDate.toIso8601String();

    if (endDate != null) {
      final endInclusive =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      params['end_date'] = endInclusive.toIso8601String();
    }

    final uri = Uri.parse('${ApiConfig.alerts}/')
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await _api.delete(uri.toString());

    return (response['deleted'] ?? 0) as int;
  }
}
