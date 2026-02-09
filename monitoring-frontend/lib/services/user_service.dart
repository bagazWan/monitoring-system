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

  Future<List<User>> getUsers() async {
    final response = await http.get(
      Uri.parse(ApiConfig.users),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
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
