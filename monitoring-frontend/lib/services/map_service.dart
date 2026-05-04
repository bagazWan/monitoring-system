import 'api_client.dart';
import '../config/api_config.dart';
import '../models/map_topology.dart';
import '../models/network_node.dart';
import '../models/fo_route.dart';

class MapService {
  static final MapService _instance = MapService._internal();
  factory MapService() => _instance;
  MapService._internal();

  final ApiClient _api = ApiClient();

  Future<MapTopology> getTopology() async {
    final response = await _api.get(ApiConfig.mapTopology);
    return MapTopology.fromJson(response);
  }

  Future<NetworkNodePage> getNetworkNodesPage({
    int page = 1,
    int limit = 10,
    String? search,
    int? locationId,
  }) async {
    final params = {'page': page.toString(), 'limit': limit.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (locationId != null) params['location_id'] = locationId.toString();

    final uri =
        Uri.parse(ApiConfig.networkNodes).replace(queryParameters: params);
    final response = await _api.get(uri.toString());
    return NetworkNodePage.fromJson(response);
  }

  Future<List<NetworkNode>> getNetworkNodes() async {
    final response = await _api.get(ApiConfig.networkNodes);
    return ApiClient.parseListOrItems<NetworkNode>(
        response, NetworkNode.fromJson);
  }

  Future<void> createNetworkNode(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.networkNodes, body: data);
  }

  Future<void> updateNetworkNode(int id, Map<String, dynamic> data) async {
    await _api.patch('${ApiConfig.networkNodes}/$id', body: data);
  }

  Future<void> deleteNetworkNode(int id) async {
    await _api.delete('${ApiConfig.networkNodes}/$id');
  }

  Future<FORoutePage> getFORoutesPage({
    int page = 1,
    int limit = 10,
    String? search,
    int? startNodeId,
    int? endNodeId,
  }) async {
    final params = {'page': page.toString(), 'limit': limit.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (startNodeId != null) params['start_node_id'] = startNodeId.toString();
    if (endNodeId != null) params['end_node_id'] = endNodeId.toString();

    final uri = Uri.parse(ApiConfig.foRoutes).replace(queryParameters: params);
    final response = await _api.get(uri.toString());
    return FORoutePage.fromJson(response);
  }

  Future<List<FORoute>> getFORoutes() async {
    final response = await _api.get(ApiConfig.foRoutes);
    return ApiClient.parseListOrItems<FORoute>(response, FORoute.fromJson);
  }

  Future<void> createFORoute(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.foRoutes, body: data);
  }

  Future<void> updateFORoute(int id, Map<String, dynamic> data) async {
    await _api.patch('${ApiConfig.foRoutes}/$id', body: data);
  }

  Future<void> deleteFORoute(int id) async {
    await _api.delete('${ApiConfig.foRoutes}/$id');
  }
}
