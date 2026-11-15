import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  static const _timeout = Duration(seconds: 10);
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  // ─── Internal helpers ────────────────────────────────────────────────────

  /// Performs a POST with a 10-second timeout, logging URL + status + body.
  Future<http.Response> _post(String url,
      {required Map<String, String> headers,
      required String body}) async {
    debugPrint('[AuthService] POST $url');
    final response = await _client
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(_timeout);
    debugPrint(
        '[AuthService] ← ${response.statusCode} ${response.reasonPhrase}');
    debugPrint('[AuthService]   body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    return response;
  }

  /// Performs a GET with a 10-second timeout, logging URL + status + body.
  Future<http.Response> _get(String url,
      {required Map<String, String> headers}) async {
    debugPrint('[AuthService] GET  $url');
    final response =
        await _client.get(Uri.parse(url), headers: headers).timeout(_timeout);
    debugPrint(
        '[AuthService] ← ${response.statusCode} ${response.reasonPhrase}');
    debugPrint('[AuthService]   body: ${response.body.substring(0, response.body.length.clamp(0, 300))}');
    return response;
  }

  /// Wraps a low-level exception into a specific, diagnostic [AuthApiException].
  AuthApiException _diagnose(Object error, String url) {
    if (error is SocketException || error is http.ClientException) {
      return AuthApiException(
          'Cannot connect to server ($url). '
          'Check Wi-Fi/intranet connection, VPN, or server IP/port.');
    }
    if (error is TimeoutException) {
      return AuthApiException(
          'Server request timed out after 10 seconds ($url).');
    }
    if (error is AuthApiException) return error;
    // Unexpected error – surface it for easier debugging.
    debugPrint('[AuthService] Unexpected error: $error');
    return AuthApiException('Unexpected error: $error');
  }

  /// Decodes the JSON body, surfacing PHP warnings / 404 HTML as readable text.
  Future<Map<String, dynamic>> _decode(http.Response response) async {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Not JSON — probably a PHP warning or an HTML error page.
      final preview = response.body.length > 120
          ? '${response.body.substring(0, 120)}…'
          : response.body;
      throw AuthApiException(
          'Invalid server response (HTTP ${response.statusCode}): $preview',
          statusCode: response.statusCode);
    }
    throw AuthApiException('The server returned an unreadable response.',
        statusCode: response.statusCode);
  }

  String _message(Map<String, dynamic> body, String fallback) =>
      body['message'] is String ? body['message'] as String : fallback;

  // ─── Health check ────────────────────────────────────────────────────────

  /// Fires a GET to [ApiConfig.healthCheck] and logs the result.
  /// A 401 response proves the server is up and PHP/SQLite works.
  Future<void> healthCheck() async {
    final url = ApiConfig.healthCheck;
    debugPrint('[AuthService] Health-check → $url');
    try {
      final response =
          await _get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 401) {
        debugPrint('[AuthService] Health-check OK – server reachable (got 401 as expected without token).');
      } else {
        debugPrint('[AuthService] Health-check response: ${response.statusCode} – ${response.body.substring(0, response.body.length.clamp(0, 200))}');
      }
    } catch (e) {
      debugPrint('[AuthService] Health-check FAILED: $e');
    }
  }

  // ─── Auth methods ────────────────────────────────────────────────────────

  Future<void> register(
      {required String name,
      required String email,
      required String password}) async {
    final url = ApiConfig.register;
    try {
      final response = await _post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'name': name.trim(),
            'email': email.trim(),
            'password': password,
          }));
      final body = await _decode(response);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true) {
        throw AuthApiException(_message(body, 'Registration failed.'),
            statusCode: response.statusCode);
      }
    } on AuthApiException {
      rethrow;
    } catch (e) {
      throw _diagnose(e, url);
    }
  }

  Future<String> login(
      {required String email, required String password}) async {
    final url = ApiConfig.login;
    try {
      final response = await _post(url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'email': email.trim(), 'password': password}));
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
    } catch (e) {
      throw _diagnose(e, url);
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
    final url = ApiConfig.profile;
    try {
      final response = await _get(url, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
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
    } catch (e) {
      throw _diagnose(e, url);
    }
  }

  Future<void> logout() async {
    final token = await savedToken();
    final url = ApiConfig.logout;
    try {
      if (token != null) {
        await _post(url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'token': token}));
      }
    } catch (e) {
      // Always remove the local token even if the server cannot be reached.
      debugPrint('[AuthService] Logout request failed (token cleared anyway): $e');
    } finally {
      await clearToken();
    }
  }
}
