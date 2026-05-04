import 'api_client.dart';
import '../config/api_config.dart';
import '../models/location.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final ApiClient _api = ApiClient();

  Future<LocationPage> getLocationsPage(
      {int page = 1, int limit = 10, String? search}) async {
    final params = {'page': page.toString(), 'limit': limit.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;

    final uri = Uri.parse(ApiConfig.locations).replace(queryParameters: params);
    final response = await _api.get(uri.toString());
    return LocationPage.fromJson(response);
  }

  Future<List<Location>> getLocations({int? limit}) async {
    final params = limit != null ? {'limit': limit.toString()} : null;
    final uri = Uri.parse(ApiConfig.locations).replace(queryParameters: params);

    final response = await _api.get(uri.toString());
    return ApiClient.parseListOrItems<Location>(response, Location.fromJson);
  }

  Future<List<Location>> getLocationOptions() async {
    final response = await _api.get(ApiConfig.locationOptions);
    return ApiClient.parseListOrItems<Location>(response, Location.fromJson)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<String>> getLocationsWithNodes() async {
    final response = await _api.get('${ApiConfig.locations}/with-nodes');
    return (response as List).map((e) => e.toString()).toList();
  }

  Future<Location> createLocation(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.locations, body: data);
    return Location.fromJson(response);
  }

  Future<void> updateLocation(int id, Map<String, dynamic> data) async {
    await _api.patch('${ApiConfig.locations}/$id', body: data);
  }

  Future<void> deleteLocation(int id) async {
    await _api.delete('${ApiConfig.locations}/$id');
  }

  Future<List<LocationGroup>> getLocationGroups() async {
    final response = await _api.get(ApiConfig.locationGroups);
    return ApiClient.parseListOrItems<LocationGroup>(
        response, LocationGroup.fromJson);
  }

  Future<void> createLocationGroup(Map<String, dynamic> data) async {
    await _api.post(ApiConfig.locationGroups, body: data);
  }

  Future<void> updateLocationGroup(int id, Map<String, dynamic> data) async {
    await _api.patch('${ApiConfig.locationGroups}/$id', body: data);
  }

  Future<void> deleteLocationGroup(int id) async {
    await _api.delete('${ApiConfig.locationGroups}/$id');
  }
}
