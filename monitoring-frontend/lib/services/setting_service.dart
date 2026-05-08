import 'api_client.dart';
import '../config/api_config.dart';
import '../models/setting.dart';

class SettingsService {
  final ApiClient _api = ApiClient();

  Future<SystemConfig> getSystemConfig() async {
    final response = await _api.get('${ApiConfig.settings}/system');
    return SystemConfig.fromJson(response);
  }

  Future<Map<String, List<ThresholdRule>>> getAllRules() async {
    final response = await _api.get('${ApiConfig.settings}/rules');

    final Map<String, List<ThresholdRule>> rulesMap = {};
    if (response is Map) {
      response.forEach((key, value) {
        if (value is List) {
          rulesMap[key.toString()] = value
              .map((ruleJson) => ThresholdRule.fromJson(ruleJson))
              .toList();
        }
      });
    }
    return rulesMap;
  }

  Future<void> updateBulkSettings({
    required SystemConfig systemConfig,
    String? targetDeviceType,
    List<ThresholdRule>? thresholdRules,
  }) async {
    final payload = <String, dynamic>{
      'system_config': systemConfig.toJson(),
    };

    if (thresholdRules != null) {
      payload['threshold_rules'] = thresholdRules.map((r) {
        final ruleJson = r.toJson();
        ruleJson['device_type'] = targetDeviceType?.toLowerCase() ?? '';
        return ruleJson;
      }).toList();
    }

    String url = '${ApiConfig.settings}/bulk';
    if (targetDeviceType != null) {
      final uri = Uri.parse(url).replace(queryParameters: {
        'target_device_type': targetDeviceType.toLowerCase()
      });
      url = uri.toString();
    }

    await _api.put(url, body: payload);
  }
}
