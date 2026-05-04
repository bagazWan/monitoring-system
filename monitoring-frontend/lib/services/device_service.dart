import 'api_client.dart';
import '../config/api_config.dart';
import '../models/device.dart';
import '../models/switch_summary.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final ApiClient _api = ApiClient();

  Future<List<BaseNode>> getAllNodes() async {
    final responses = await Future.wait([
      _api.get(ApiConfig.deviceList).catchError((_) => []),
      _api.get(ApiConfig.switchList).catchError((_) => []),
    ]);

    final List<BaseNode> allNodes = [];

    if (responses[0] != null) {
      allNodes.addAll(
          (responses[0] as List).map((j) => BaseNode.fromDeviceJson(j)));
    }
    if (responses[1] != null) {
      allNodes.addAll(
          (responses[1] as List).map((j) => BaseNode.fromSwitchJson(j)));
    }

    return allNodes;
  }

  Future<NodePage> getNodesPage({
    String? search,
    String? locationName,
    String? deviceType,
    String? status,
    int page = 1,
    int limit = 10,
  }) async {
    final params = {'page': page.toString(), 'limit': limit.toString()};

    if (search != null && search.isNotEmpty) params['search'] = search;
    if (locationName != null && locationName.isNotEmpty) {
      params['location_name'] = locationName;
    }
    if (deviceType != null && deviceType.isNotEmpty) {
      params['device_type'] = deviceType;
    }
    if (status != null && status.isNotEmpty) params['status'] = status;

    final uri =
        Uri.parse(ApiConfig.deviceNodes).replace(queryParameters: params);
    final response = await _api.get(uri.toString());

    return NodePage.fromJson(response);
  }

  Future<BaseNode> getNode(String nodeKind, int id) async {
    final endpoint = nodeKind == 'switch' ? 'switches' : 'devices';
    final response = await _api.get('${ApiConfig.url}/$endpoint/$id');

    return nodeKind == 'switch'
        ? BaseNode.fromSwitchJson(response)
        : BaseNode.fromDeviceJson(response);
  }

  Future<Map<String, dynamic>> getLiveDetails(int id, String nodeType) async {
    final t = nodeType.toLowerCase();
    final String base = (t == 'switch' || t == 'switches')
        ? ApiConfig.switches
        : ApiConfig.devices;

    return await _api.get('$base/$id/live-details');
  }

  Future<Map<String, Map<String, dynamic>>> getBulkLiveDetails(
      List<BaseNode> nodes) async {
    if (nodes.isEmpty) return {};

    final deviceIds = nodes
        .where((n) => n.nodeKind == 'device' && n.id != null)
        .map((n) => n.id!)
        .toList();
    final switchIds = nodes
        .where((n) => n.nodeKind == 'switch' && n.id != null)
        .map((n) => n.id!)
        .toList();

    final futures = <Future<dynamic>>[
      deviceIds.isNotEmpty
          ? _api.post('${ApiConfig.devices}/bulk-live-details',
              body: {'device_ids': deviceIds}).catchError((_) => [])
          : Future.value([]),
      switchIds.isNotEmpty
          ? _api.post('${ApiConfig.switches}/bulk-live-details',
              body: {'switch_ids': switchIds}).catchError((_) => [])
          : Future.value([]),
    ];

    final responses = await Future.wait(futures);
    final results = <String, Map<String, dynamic>>{};

    for (var item in (responses[0] as List)) {
      results['device_${item['device_id']}'] = item;
    }
    for (var item in (responses[1] as List)) {
      results['switch_${item['switch_id']}'] = item;
    }

    return results;
  }

  Future<List<SwitchSummary>> getSwitches() async {
    final response = await _api.get(ApiConfig.switches);
    return ApiClient.parseListOrItems<SwitchSummary>(
        response, SwitchSummary.fromJson);
  }

  Future<List<String>> getDeviceTypes() async {
    final response = await _api.get(ApiConfig.deviceTypes);
    return (response as List).map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> registerLibreNMS(
      Map<String, dynamic> payload) async {
    return await _api.post(ApiConfig.registerLibreNMS, body: payload);
  }

  Future<void> updateNode(
      String nodeKind, int id, Map<String, dynamic> data) async {
    final endpoint = nodeKind == 'switch' ? 'switches' : 'devices';
    await _api.patch('${ApiConfig.url}/$endpoint/$id', body: data);
  }

  Future<void> unregisterNode(String nodeKind, int id) async {
    final endpoint = nodeKind == 'switch' ? 'switch' : 'device';
    await _api.delete('${ApiConfig.registerLibreNMS}/$endpoint/$id');
  }

  Future<void> deleteNode(String nodeKind, int id) async {
    final endpoint = nodeKind == 'switch' ? 'switches' : 'devices';
    await _api.delete('${ApiConfig.url}/$endpoint/$id');
  }
}
