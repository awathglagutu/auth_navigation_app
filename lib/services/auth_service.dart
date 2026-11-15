import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class UserProfile {
  const UserProfile(
      {required this.name, required this.email, required this.role});

  final String name;
  final String email;
  final String role;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? 'Student',
      );
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthService {
  static const _tokenKey = 'aster_session_token_v1';
  static const _timeout = Duration(seconds: 12);
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // A non-JSON response is reported as a service error below.
    }
    throw AuthApiException('The server returned an unreadable response.',
        statusCode: response.statusCode);
  }

  String _message(Map<String, dynamic> body, String fallback) =>
      body['message'] is String ? body['message'] as String : fallback;

  Future<void> register(
      {required String name,
      required String email,
      required String password}) async {
    try {
      final response = await _client
          .post(Uri.parse(ApiConfig.register),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({
                'name': name.trim(),
                'email': email.trim(),
                'password': password
              }))
          .timeout(_timeout);
      final body = await _decode(response);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true) {
        throw AuthApiException(_message(body, 'Registration failed.'),
            statusCode: response.statusCode);
      }
    } on AuthApiException {
      rethrow;
    } on Exception {
      throw const AuthApiException(
          'Could not reach the server. Check your connection and try again.');
    }
  }

  Future<String> login(
      {required String email, required String password}) async {
    try {
      final response = await _client
          .post(Uri.parse(ApiConfig.login),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'email': email.trim(), 'password': password}))
          .timeout(_timeout);
      final body = await _decode(response);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true ||
          body['token'] is! String) {
        throw AuthApiException(_message(body, 'Login failed.'),
            statusCode: response.statusCode);
      }
      final token = body['token'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      return token;
    } on AuthApiException {
      rethrow;
    } on Exception {
      throw const AuthApiException(
          'Could not reach the server. Check your connection and try again.');
    }
  }

  Future<String?> savedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<UserProfile> profile(String token) async {
    try {
      final response = await _client.get(Uri.parse(ApiConfig.profile),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token'
          }).timeout(_timeout);
      final body = await _decode(response);
      if (response.statusCode == 401) {
        throw AuthApiException(
            _message(body, 'Your session has expired. Please log in again.'),
            statusCode: 401);
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true ||
          body['user'] is! Map) {
        throw AuthApiException(_message(body, 'Could not load your profile.'),
            statusCode: response.statusCode);
      }
      return UserProfile.fromJson(
          Map<String, dynamic>.from(body['user'] as Map));
    } on AuthApiException {
      rethrow;
    } on Exception {
      throw const AuthApiException(
          'Could not reach the server. Check your connection and retry.');
    }
  }

  Future<void> logout() async {
    final token = await savedToken();
    try {
      if (token != null) {
        await _client
            .post(Uri.parse(ApiConfig.logout),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token'
                },
                body: jsonEncode({'token': token}))
            .timeout(_timeout);
      }
    } on Exception {
      // Always remove the local token, even if the server cannot be reached.
    } finally {
      await clearToken();
    }
  }
}
