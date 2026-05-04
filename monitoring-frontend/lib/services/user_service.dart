import 'api_client.dart';
import '../config/api_config.dart';
import '../models/user.dart';

class UserService {
  final ApiClient _api = ApiClient();

  Future<UserPage> getUsers({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final uri = Uri.parse(ApiConfig.users).replace(queryParameters: params);
    final response = await _api.get(uri.toString());
    return UserPage.fromJson(response);
  }

  Future<void> createUser(Map<String, dynamic> userData) async {
    await _api.post(ApiConfig.users, body: userData);
  }

  Future<void> updateUser(int id, Map<String, dynamic> userData) async {
    await _api.patch('${ApiConfig.users}/$id', body: userData);
  }

  Future<void> deleteUser(int id) async {
    await _api.delete('${ApiConfig.users}/$id');
  }

  Future<void> changeOwnPassword(String oldPassword, String newPassword) async {
    await _api.post('${ApiConfig.users}/me/change-password', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }
}
