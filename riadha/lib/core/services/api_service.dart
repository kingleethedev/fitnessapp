// lib/core/services/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // Get base URL from .env file
  static String get baseUrl {
    final url = dotenv.env['API_BASE_URL'];
    if (url == null || url.isEmpty) {
      print('⚠️ [API] API_BASE_URL not found in .env, using fallback');
      return 'https://fitnessapp-4oeh.onrender.com/api';
    }
    return url;
  }
  
  // Track if a refresh is already in progress
  static bool _isRefreshing = false;
  static final List<Completer> _pendingRequests = [];
  
  // Timer for auto-refresh
  Timer? _refreshTimer;
  
  // Token expiration tracking
  DateTime? _tokenExpiryTime;
  
  // Constructor
  ApiService();
  
  // =========================
  // INITIALIZATION
  // =========================
  Future<void> init() async {
    print('🔧 [API] Initializing ApiService...');
    print('📍 [API] Base URL: $baseUrl');
    
    // Verify .env configuration
    _verifyEnvConfiguration();
    
    await _loadTokenAndSetupRefresh();
    print('✅ [API] ApiService initialized');
  }
  
  void _verifyEnvConfiguration() {
    final apiUrl = dotenv.env['API_BASE_URL'];
    final paypalClientId = dotenv.env['PAYPAL_CLIENT_ID'];
    
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 Environment Configuration:');
    print('API_BASE_URL: ${apiUrl != null ? "✅ Loaded ($apiUrl)" : "❌ Missing"}');
    print('PAYPAL_CLIENT_ID: ${paypalClientId != null ? "✅ Loaded (length: ${paypalClientId.length})" : "⚠️ Not in .env (sandbox mode only)"}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (apiUrl == null || apiUrl.isEmpty) {
      print('⚠️ WARNING: API_BASE_URL not found in .env file!');
    }
  }
  
  // Helper method to check if endpoint is public (no auth required)
  bool _isPublicEndpoint(String endpoint) {
    final publicEndpoints = [
      '/auth/register/',
      '/auth/login/',
      '/auth/firebase_auth/',
      '/auth/firebase_google_auth/',
      '/auth/password/forgot/',
      '/auth/password/reset/',
      '/webhooks/paypal/',
      '/test/',
    ];
    
    return publicEndpoints.any((e) => endpoint.contains(e));
  }
  
  Future<void> _loadTokenAndSetupRefresh() async {
    print('🔐 [API] Loading token and setting up refresh...');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token != null) {
      print('✅ [API] Token found, checking expiry...');
      _tokenExpiryTime = _getTokenExpiry(token);
      
      if (_tokenExpiryTime != null) {
        _scheduleAutoRefresh();
      }
    } else {
      print('⚠️ [API] No token found');
    }
  }
  
  DateTime? _getTokenExpiry(String token) {
    try {
      print('🔐 [API] Decoding JWT token...');
      final parts = token.split('.');
      if (parts.length != 3) {
        print('❌ [API] Invalid JWT format - wrong number of parts');
        return null;
      }
      
      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      final decoded = utf8.decode(base64.decode(payload));
      final jsonData = json.decode(decoded);
      
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (jsonData['exp'] * 1000).toInt()
      );
      
      print('🔐 [API] Token expires at: $expiry');
      final now = DateTime.now();
      print('🔐 [API] Current time: $now');
      print('🔐 [API] Time until expiry: ${expiry.difference(now).inMinutes} minutes');
      return expiry;
    } catch (e) {
      print('❌ [API] Error decoding token: $e');
      return null;
    }
  }
  
  void _scheduleAutoRefresh() {
    if (_tokenExpiryTime == null) {
      print('⚠️ [API] No expiry time, skipping auto-refresh setup');
      return;
    }
    
    _refreshTimer?.cancel();
    
    const refreshBuffer = Duration(minutes: 5);
    final timeUntilExpiry = _tokenExpiryTime!.difference(DateTime.now());
    final timeToRefresh = timeUntilExpiry - refreshBuffer;
    
    if (timeToRefresh.isNegative) {
      print('🔄 [API] Token near expiry, refreshing now...');
      _refreshToken();
    } else if (timeToRefresh.inSeconds > 0) {
      print('⏰ [API] Scheduling token refresh in ${timeToRefresh.inMinutes} minutes');
      _refreshTimer = Timer(timeToRefresh, () => _refreshToken());
    } else {
      print('⚠️ [API] No refresh scheduled - token may be expired');
    }
  }
  
  // =========================
  // HEADERS
  // =========================
  Future<Map<String, String>> _getHeaders({String? endpoint}) async {
    print('📋 [API] Building request headers...');
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    
    // Only add authorization for non-public endpoints
    final isPublic = endpoint != null && _isPublicEndpoint(endpoint);
    
    if (!isPublic) {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('access_token') ??
          prefs.getString('access') ??
          prefs.getString('token') ??
          prefs.getString('auth_token');
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        print('✅ [API] Authorization header added (token length: ${token.length})');
      } else {
        print('⚠️ [API] No token available for authorization');
      }
    } else {
      print('🔓 [API] Public endpoint - skipping authorization header');
    }
    
    print('📋 [API] Headers: ${headers.keys}');
    return headers;
  }

  // =========================
  // GET REQUEST
  // =========================
  Future<dynamic> get(String endpoint) async {
    final url = '$baseUrl$endpoint';
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌐 [API] GET Request');
    print('📍 [API] URL: $url');
    print('⏰ [API] Time: ${DateTime.now()}');

    try {
      final headers = await _getHeaders(endpoint: endpoint);
      print('📤 [API] Sending GET request...');
      
      final stopwatch = Stopwatch()..start();
      final response = await http.get(Uri.parse(url), headers: headers);
      stopwatch.stop();
      
      print('📥 [API] Response received in ${stopwatch.elapsedMilliseconds}ms');
      print('📥 [API] Status code: ${response.statusCode}');
      print('📥 [API] Response body preview: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}');

      return await _handleResponse(
        response,
        () => get(endpoint),
      );
    } catch (e) {
      print('❌ [API] GET Error: $e');
      print('❌ [API] Error type: ${e.runtimeType}');
      print('❌ [API] Stack trace: ${StackTrace.current}');
      throw Exception('Network error: $e');
    } finally {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // =========================
  // POST REQUEST
  // =========================
  Future<dynamic> post(String endpoint, {dynamic data}) async {
    final url = '$baseUrl$endpoint';
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌐 [API] POST Request');
    print('📍 [API] URL: $url');
    print('⏰ [API] Time: ${DateTime.now()}');
    if (data != null) {
      print('📤 [API] Data: ${jsonEncode(data)}');
      print('📤 [API] Data size: ${jsonEncode(data).length} bytes');
    } else {
      print('📤 [API] Data: null');
    }

    try {
      final headers = await _getHeaders(endpoint: endpoint);
      print('📤 [API] Sending POST request...');
      
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );
      stopwatch.stop();
      
      print('📥 [API] Response received in ${stopwatch.elapsedMilliseconds}ms');
      print('📥 [API] Status code: ${response.statusCode}');
      print('📥 [API] Response body: ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');

      return await _handleResponse(
        response,
        () => post(endpoint, data: data),
      );
    } on http.ClientException catch (e) {
      print('❌ [API] HTTP Client Exception: $e');
      print('❌ [API] Check if server is reachable');
      print('❌ [API] Possible CORS or network issue');
      rethrow;
    } catch (e) {
      print('❌ [API] POST Error: $e');
      print('❌ [API] Error type: ${e.runtimeType}');
      print('❌ [API] Stack trace: ${StackTrace.current}');
      throw Exception('Network error: $e');
    } finally {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // =========================
  // PATCH REQUEST
  // =========================
  Future<dynamic> patch(String endpoint, {dynamic data}) async {
    final url = '$baseUrl$endpoint';
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌐 [API] PATCH Request');
    print('📍 [API] URL: $url');
    if (data != null) print('📤 [API] Data: ${jsonEncode(data)}');

    try {
      final headers = await _getHeaders(endpoint: endpoint);
      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );

      print('📥 [API] Response: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('⚠️ [API] Unexpected status code: ${response.statusCode}');
        print('⚠️ [API] Response body: ${response.body}');
      }

      return await _handleResponse(
        response,
        () => patch(endpoint, data: data),
      );
    } catch (e) {
      print('❌ [API] PATCH Error: $e');
      throw Exception('Network error: $e');
    } finally {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // =========================
  // DELETE REQUEST
  // =========================
  Future<dynamic> delete(String endpoint, {dynamic data}) async {
    final url = '$baseUrl$endpoint';
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🌐 [API] DELETE Request');
    print('📍 [API] URL: $url');

    try {
      final headers = await _getHeaders(endpoint: endpoint);

      final request = http.Request('DELETE', Uri.parse(url))
        ..headers.addAll(headers);

      if (data != null) {
        request.body = jsonEncode(data);
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('📥 [API] Response: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isNotEmpty) {
          return jsonDecode(responseBody);
        }
        return {'status': 'success'};
      }

      if (response.statusCode == 401) {
        print('🔄 [API] Token expired during DELETE, refreshing...');
        await _refreshToken();
        return delete(endpoint, data: data);
      }

      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      print('❌ [API] DELETE Error: $e');
      throw Exception('Network error: $e');
    } finally {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  // =========================
  // RESPONSE HANDLER
  // =========================
  Future<dynamic> _handleResponse(
    http.Response response,
    Function retryRequest,
  ) async {
    print('🔄 [API] Handling response with status: ${response.statusCode}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('✅ [API] Request successful (${response.statusCode})');
      if (response.body.isEmpty) {
        print('⚠️ [API] Empty response body');
        return null;
      }
      try {
        final jsonResponse = jsonDecode(response.body);
        print('✅ [API] JSON parsed successfully');
        return jsonResponse;
      } catch (e) {
        print('❌ [API] Failed to parse JSON: $e');
        print('❌ [API] Raw response: ${response.body}');
        throw Exception('Invalid JSON response');
      }
    }

    if (response.statusCode == 401) {
      // Don't try to refresh token for public endpoints
      final isPublic = _isPublicEndpoint(response.request?.url.path ?? '');
      if (isPublic) {
        print('🔓 [API] Public endpoint returned 401 - likely invalid credentials');
        throw Exception('Invalid credentials');
      }
      
      print('🔐 [API] 401 Unauthorized - Token may be expired');
      print('🔄 [API] Attempting token refresh...');

      if (_isRefreshing) {
        print('⏳ [API] Refresh already in progress, waiting...');
        final completer = Completer();
        _pendingRequests.add(completer);
        await completer.future;
        print('✅ [API] Refresh completed, retrying original request...');
        return await retryRequest();
      }

      _isRefreshing = true;

      try {
        final refreshed = await _refreshToken();

        if (refreshed) {
          print('✅ [API] Token refreshed successfully, retrying request...');
          
          for (var completer in _pendingRequests) {
            completer.complete();
          }
          _pendingRequests.clear();
          
          return await retryRequest();
        } else {
          print('❌ [API] Token refresh failed - session expired');
          for (var completer in _pendingRequests) {
            completer.completeError('Session expired');
          }
          _pendingRequests.clear();
          throw Exception('Session expired - please login again');
        }
      } finally {
        _isRefreshing = false;
      }
    }

    // Handle other error status codes
    print('❌ [API] Server Error: ${response.statusCode}');
    print('❌ [API] Response body: ${response.body}');
    
    // Try to parse error message from response
    try {
      final errorJson = jsonDecode(response.body);
      if (errorJson is Map && errorJson.containsKey('error')) {
        throw Exception(errorJson['error']);
      } else if (errorJson is Map && errorJson.containsKey('message')) {
        throw Exception(errorJson['message']);
      } else if (errorJson is Map && errorJson.containsKey('detail')) {
        throw Exception(errorJson['detail']);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Server error: ${response.statusCode}');
    }
  }

  // =========================
  // REFRESH TOKEN
  // =========================
  Future<bool> _refreshToken() async {
    print('🔄 [API] Starting token refresh process...');
    final prefs = await SharedPreferences.getInstance();
    String? refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      print('❌ [API] No refresh token found');
      return false;
    }
    
    print('✅ [API] Refresh token found, calling refresh endpoint...');

    try {
      final url = Uri.parse('$baseUrl/auth/token/refresh/');
      print('📍 [API] Refresh URL: $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      
      print('📥 [API] Refresh response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access'];
        final newRefresh = data['refresh'] ?? refreshToken;

        await prefs.setString('access_token', newAccess);
        await prefs.setString('access', newAccess);
        await prefs.setString('token', newAccess);
        await prefs.setString('auth_token', newAccess);
        await prefs.setString('refresh_token', newRefresh);

        print('✅ [API] New access token saved');
        
        _tokenExpiryTime = _getTokenExpiry(newAccess);
        _scheduleAutoRefresh();

        print('🔐 [API] Token refreshed successfully');
        return true;
      } else if (response.statusCode == 401) {
        print('❌ [API] Refresh token is invalid or expired');
        await _clearAllTokens();
        return false;
      } else {
        print('❌ [API] Token refresh failed: ${response.statusCode}');
        print('❌ [API] Response: ${response.body}');
        await _clearAllTokens();
        return false;
      }
    } catch (e) {
      print('❌ [API] Token refresh error: $e');
      print('❌ [API] Error type: ${e.runtimeType}');
      return false;
    }
  }
  
  // Public method to refresh token
  Future<bool> refreshTokenPublic() async {
    print('🔓 [API] Public token refresh requested');
    return await _refreshToken();
  }
  
  // =========================
  // TOKEN MANAGEMENT
  // =========================
  Future<void> _clearAllTokens() async {
    print('🗑️ [API] Clearing all tokens...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('access');
    await prefs.remove('token');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    print('✅ [API] All tokens cleared');
  }
  
  // Clear tokens publicly (useful for logout)
  Future<void> clearTokens() async {
    await _clearAllTokens();
  }
  
  Future<void> saveTokens(String access, String refresh) async {
    print('💾 [API] Saving tokens...');
    print('📝 [API] Access token length: ${access.length}');
    print('📝 [API] Refresh token length: ${refresh.length}');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('access', access);
    await prefs.setString('token', access);
    await prefs.setString('auth_token', access);
    await prefs.setString('refresh_token', refresh);
    
    print('✅ [API] Tokens saved successfully');
    
    _tokenExpiryTime = _getTokenExpiry(access);
    _scheduleAutoRefresh();
  }
  
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      print('🔑 [API] Access token retrieved (length: ${token.length})');
    } else {
      print('⚠️ [API] No access token found');
    }
    return token;
  }
  
  // =========================
  // FIREBASE AUTHENTICATION
  // =========================
  
  /// Authenticate with Firebase ID token
  Future<Map<String, dynamic>> firebaseAuth(String idToken, {String provider = 'FIREBASE'}) async {
    final url = Uri.parse('$baseUrl/auth/firebase_auth/');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔥 [API] Firebase authentication');
    print('📍 [API] URL: $url');
    print('🔑 [API] Provider: $provider');
    print('📝 [API] ID Token length: ${idToken.length}');
    
    try {
      final requestBody = {
        'id_token': idToken,
        'provider': provider,
      };
      print('📤 [API] Request body: ${jsonEncode(requestBody)}');
      
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      stopwatch.stop();
      
      print('📥 [API] Response received in ${stopwatch.elapsedMilliseconds}ms');
      print('📥 [API] Status code: ${response.statusCode}');
      print('📥 [API] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ [API] Firebase authentication successful');
        print('📝 [API] Saving tokens from Firebase auth...');
        await saveTokens(data['access'], data['refresh']);
        print('✅ [API] Firebase auth complete');
        return data;
      } else {
        print('❌ [API] Firebase auth failed with status: ${response.statusCode}');
        final error = jsonDecode(response.body);
        print('❌ [API] Error details: $error');
        throw Exception(error['error'] ?? 'Firebase authentication failed');
      }
    } catch (e) {
      print('❌ [API] Firebase auth error: $e');
      print('❌ [API] Error type: ${e.runtimeType}');
      rethrow;
    } finally {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }
  
  /// Google Sign-In authentication
  Future<Map<String, dynamic>> googleAuth(String idToken) async {
    print('🔐 [API] Google Sign-In authentication');
    return await firebaseAuth(idToken, provider: 'GOOGLE');
  }
  
  // =========================
  // PAYMENT METHODS (PayPal)
  // =========================
  
  /// Check if user is eligible for free trial
  Future<Map<String, dynamic>> checkTrialEligibility() async {
    print('🎯 [API] Checking trial eligibility');
    return await get('/payments/check_trial_eligibility/');
  }
  
  /// Start free trial
  Future<Map<String, dynamic>> startTrial() async {
    print('🎯 [API] Starting free trial');
    return await post('/payments/start_trial/');
  }
  
  /// Get subscription plan
  Future<Map<String, dynamic>> getSubscriptionPlan() async {
    print('🎯 [API] Getting subscription plan');
    return await get('/payments/plan/');
  }
  
  /// Get current subscription/trial status
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    print('🎯 [API] Getting subscription status');
    return await get('/payments/status/');
  }
  
  /// Create PayPal payment for subscription
  Future<Map<String, dynamic>> createPayPalPayment() async {
    print('💰 [API] Creating PayPal payment');
    return await post('/payments/create_payment/');
  }
  
  /// Create PayPal subscription
  Future<Map<String, dynamic>> createPayPalSubscription() async {
    print('💰 [API] Creating PayPal subscription');
    return await post('/payments/create_subscription/');
  }
  
  /// Execute PayPal payment after approval
  Future<Map<String, dynamic>> executePayPalPayment({
    required String paymentId,
    required String payerId,
  }) async {
    print('💰 [API] Executing PayPal payment');
    return await post('/payments/execute_payment/', data: {
      'payment_id': paymentId,
      'payer_id': payerId,
    });
  }
  
  /// Cancel subscription
  Future<Map<String, dynamic>> cancelSubscription() async {
    print('❌ [API] Cancelling subscription');
    return await post('/payments/cancel_subscription/');
  }
  
  /// Get payment history
  Future<Map<String, dynamic>> getPaymentHistory() async {
    print('📜 [API] Getting payment history');
    return await get('/payments/payment_history/');
  }
  
  // =========================
  // DISPOSE
  // =========================
  void dispose() {
    print('🧹 [API] Disposing ApiService...');
    _refreshTimer?.cancel();
    print('✅ [API] ApiService disposed');
  }
}