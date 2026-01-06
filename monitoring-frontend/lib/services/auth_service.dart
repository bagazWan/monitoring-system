import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '/api_config.dart';
import '../models/user.dart';

class AuthService {
  final storage = FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.login),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': username,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Store token
      await storage.write(key: 'auth_token', value: data['access_token']);

      return data;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<void> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.register),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': fullName,
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return; // Success
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['detail'] ?? 'Registration failed');
    }
  }

  Future<User> getCurrentUser() async {
    final token = await storage.read(key: 'auth_token');

    if (token == null) {
      throw Exception('Not logged in');
    }

    final response = await http.get(
      Uri.parse(ApiConfig.me),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('Failed to get user');
    }
  }

  Future<void> logout() async {
    await storage.delete(key: 'auth_token');
  }

  // Check if logged in
  Future<bool> isLoggedIn() async {
    final token = await storage.read(key: 'auth_token');
    return token != null;
  }

  // Get token (for other services)
  Future<String?> getToken() async {
    return await storage.read(key: 'auth_token');
  }
}
