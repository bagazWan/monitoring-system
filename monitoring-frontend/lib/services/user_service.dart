import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class UserService {
  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

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

    final response = await http.get(
      uri,
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      return UserPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load users: ${response.body}');
    }
  }

  Future<void> createUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.users),
      headers: await _getHeaders(),
      body: jsonEncode(userData),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create user: ${response.body}');
    }
  }

  Future<void> updateUser(int id, Map<String, dynamic> userData) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.users}/$id'),
      headers: await _getHeaders(),
      body: jsonEncode(userData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update user: ${response.body}');
    }
  }

  Future<void> deleteUser(int id) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.users}/$id'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete user: ${response.body}');
    }
  }
}
