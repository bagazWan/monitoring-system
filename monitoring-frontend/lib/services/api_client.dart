import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  final http.Client _client;

  ApiClient._internal() : _client = http.Client();
  static const Duration _timeout = Duration(seconds: 15);

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static List<T> parseListOrItems<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (data is List) {
      return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'] ?? data['data'];
      if (items is List) {
        return items.map((e) => fromJson(e as Map<String, dynamic>)).toList();
      }
    }
    return [];
  }

  Future<dynamic> get(String url) async {
    try {
      final response = await _client
          .get(Uri.parse(url), headers: await _getHeaders())
          .timeout(_timeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final response = await _client
          .post(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<dynamic> patch(String url, {Map<String, dynamic>? body}) async {
    try {
      final response = await _client
          .patch(
            Uri.parse(url),
            headers: await _getHeaders(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(_timeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  Future<dynamic> delete(String url) async {
    try {
      final response = await _client
          .delete(Uri.parse(url), headers: await _getHeaders())
          .timeout(_timeout);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception('Request timed out');
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      AuthService().logout();
      throw Exception('Session expired');
    } else {
      String errorMessage = 'API Error (${response.statusCode})';
      try {
        final errorData = jsonDecode(response.body);
        if (errorData is Map && errorData.containsKey('detail')) {
          errorMessage = errorData['detail'].toString();
        }
      } catch (_) {
        errorMessage = 'Error: ${response.statusCode} - ${response.body}';
      }
      debugPrint(errorMessage);
      throw Exception(errorMessage);
    }
  }
}
