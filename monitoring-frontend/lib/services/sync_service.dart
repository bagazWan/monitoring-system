import 'api_client.dart';
import '../config/api_config.dart';

class SyncService {
  final ApiClient _api = ApiClient();

  Future<void> syncFromLibreNMS() async {
    await _api.post(
      ApiConfig.syncLibreNMS,
      body: {
        "default_location_id": 1,
        "update_existing": true,
      },
    );
  }
}
