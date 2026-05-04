import 'api_client.dart';
import '../config/api_config.dart';
import '../models/librenms_port.dart';

class PortsService {
  final ApiClient _api = ApiClient();

  Future<List<LibreNMSPort>> getPorts({int? deviceId, int? switchId}) async {
    final params = <String, String>{};
    if (deviceId != null) params['device_id'] = deviceId.toString();
    if (switchId != null) params['switch_id'] = switchId.toString();

    final uri = Uri.parse(ApiConfig.libreNMSPorts).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await _api.get(uri.toString());

    return ApiClient.parseListOrItems<LibreNMSPort>(
        response, LibreNMSPort.fromJson);
  }

  Future<void> updatePort(int portRowId, Map<String, dynamic> payload) async {
    await _api.patch('${ApiConfig.libreNMSPorts}/$portRowId', body: payload);
  }

  Future<void> resyncPorts({int? deviceId, int? switchId}) async {
    final params = <String, String>{};
    if (deviceId != null) params['device_id'] = deviceId.toString();
    if (switchId != null) params['switch_id'] = switchId.toString();

    final uri = Uri.parse('${ApiConfig.libreNMSPorts}/resync').replace(
      queryParameters: params.isEmpty ? null : params,
    );

    await _api.post(uri.toString());
  }
}
