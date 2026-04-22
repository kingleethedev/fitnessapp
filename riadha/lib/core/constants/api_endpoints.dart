// api_endpoints.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_endpoints.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<Map<String, String>> _getHeaders() async {
    final token = await StorageService.getAuthToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> post(String endpoint, {dynamic data}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> put(String endpoint, {dynamic data}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}$endpoint'),
        headers: headers,
      );
      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized');
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  }
}