// lib/core/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://fitnessapp-4oeh.onrender.com/api';

  // =========================
  // HEADERS
  // =========================
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();

    String? token = prefs.getString('access_token') ??
        prefs.getString('access') ??
        prefs.getString('token') ??
        prefs.getString('auth_token');

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    print('📋 Headers: ${headers.keys}');
    print('📋 Auth header present: ${headers.containsKey('Authorization')}');

    return headers;
  }

  // =========================
  // GET
  // =========================
  Future<dynamic> get(String endpoint) async {
    final url = '$baseUrl$endpoint';
    print('🌐 GET: $url');

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(url), headers: headers);

      print('📥 Response: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      return await _handleResponse(
        response,
        () => get(endpoint), // retry
      );
    } catch (e) {
      print('❌ GET Error: $e');
      throw Exception('Network error: $e');
    }
  }

  // =========================
  // POST
  // =========================
  Future<dynamic> post(String endpoint, {dynamic data}) async {
    final url = '$baseUrl$endpoint';
    print('🌐 POST: $url');
    print('📤 Data: $data');

    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );

      print('📥 Response: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      return await _handleResponse(
        response,
        () => post(endpoint, data: data),
      );
    } catch (e) {
      print('❌ POST Error: $e');
      throw Exception('Network error: $e');
    }
  }

  // =========================
  // PATCH
  // =========================
  Future<dynamic> patch(String endpoint, {dynamic data}) async {
    final url = '$baseUrl$endpoint';
    print('🌐 PATCH: $url');

    try {
      final headers = await _getHeaders();

      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );

      print('📥 Response: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      return await _handleResponse(
        response,
        () => patch(endpoint, data: data),
      );
    } catch (e) {
      print('❌ PATCH Error: $e');
      throw Exception('Network error: $e');
    }
  }

  // =========================
  // DELETE
  // =========================
  Future<dynamic> delete(String endpoint, {dynamic data}) async {
    final url = '$baseUrl$endpoint';
    print('🌐 DELETE: $url');

    try {
      final headers = await _getHeaders();

      final request = http.Request('DELETE', Uri.parse(url))
        ..headers.addAll(headers);

      if (data != null) {
        request.body = jsonEncode(data);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 Response: ${response.statusCode}');
      print('📥 Body: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isNotEmpty) {
          return jsonDecode(responseBody);
        }
        return {'status': 'success'};
      }

      if (response.statusCode == 401) {
        await _refreshToken();
        return delete(endpoint, data: data); // retry once
      }

      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      print('❌ DELETE Error: $e');
      throw Exception('Network error: $e');
    }
  }

  // =========================
  // RESPONSE HANDLER (AUTO REFRESH CORE)
  // =========================
  Future<dynamic> _handleResponse(
    http.Response response,
    Function retryRequest,
  ) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    // 🚨 TOKEN EXPIRED → SILENT REFRESH
    if (response.statusCode == 401) {
      print('🔄 Token expired, refreshing...');

      final refreshed = await _refreshToken();

      if (refreshed) {
        print('✅ Token refreshed, retrying request...');
        return await retryRequest(); // silent retry
      }

      print('❌ Refresh failed - user must login again');
      throw Exception('Session expired');
    }

    print('❌ Server Error: ${response.statusCode}');
    print('❌ Response body: ${response.body}');
    throw Exception('Server error: ${response.statusCode}');
  }

  // =========================
  // REFRESH TOKEN (SILENT)
  // =========================
  Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      print('❌ No refresh token found');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final newAccess = data['access'];

        await prefs.setString('access_token', newAccess);
        await prefs.setString('access', newAccess);
        await prefs.setString('token', newAccess);
        await prefs.setString('auth_token', newAccess);

        print('🔐 Access token refreshed successfully');
        return true;
      }

      print('❌ Refresh token invalid');
      return false;
    } catch (e) {
      print('❌ Refresh error: $e');
      return false;
    }
  }
}