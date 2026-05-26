// api_service.dart
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

  // =========================
  // PAYMENT METHODS (PayPal)
  // =========================
  
  /// Check if user is eligible for free trial
  Future<Map<String, dynamic>> checkTrialEligibility() async {
    final response = await get('/payments/check_trial_eligibility/');
    return response as Map<String, dynamic>;
  }
  
  /// Start free trial (7 days)
  Future<Map<String, dynamic>> startTrial() async {
    final response = await post('/payments/start_trial/');
    return response as Map<String, dynamic>;
  }
  
  /// Get subscription plan details
  Future<Map<String, dynamic>> getSubscriptionPlan() async {
    final response = await get('/payments/plan/');
    return response as Map<String, dynamic>;
  }
  
  /// Get current subscription/trial status
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    final response = await get('/payments/status/');
    return response as Map<String, dynamic>;
  }
  
  /// Create PayPal payment for subscription
  Future<Map<String, dynamic>> createPayPalPayment() async {
    final response = await post('/payments/create_payment/');
    return response as Map<String, dynamic>;
  }
  
  /// Create PayPal subscription (recurring)
  Future<Map<String, dynamic>> createPayPalSubscription() async {
    final response = await post('/payments/create_subscription/');
    return response as Map<String, dynamic>;
  }
  
  /// Execute PayPal payment after user approval
  Future<Map<String, dynamic>> executePayPalPayment({
    required String paymentId,
    required String payerId,
  }) async {
    final response = await post(
      '/payments/execute_payment/',
      data: {
        'payment_id': paymentId,
        'payer_id': payerId,
      },
    );
    return response as Map<String, dynamic>;
  }
  
  /// Cancel active subscription
  Future<Map<String, dynamic>> cancelSubscription() async {
    final response = await post('/payments/cancel_subscription/');
    return response as Map<String, dynamic>;
  }
  
  /// Get user's payment history
  Future<Map<String, dynamic>> getPaymentHistory() async {
    final response = await get('/payments/payment_history/');
    return response as Map<String, dynamic>;
  }
  
  /// Legacy method - kept for compatibility
  @Deprecated('Use createPayPalPayment() instead')
  Future<Map<String, dynamic>> createPaymentIntent() async {
    return await createPayPalPayment();
  }
}