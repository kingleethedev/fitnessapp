// lib/core/services/api_service.dart
// lib/core/services/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://fitnessapp-4oeh.onrender.com/api';
  
  // Track if a refresh is already in progress
  static bool _isRefreshing = false;
  static final List<Completer> _pendingRequests = [];
  
  // Timer for auto-refresh
  Timer? _refreshTimer;
  
  // Token expiration tracking
  DateTime? _tokenExpiryTime;
  
  // =========================
  // INITIALIZATION
  // =========================
  Future<void> init() async {
    await _loadTokenAndSetupRefresh();
  }
  
  Future<void> _loadTokenAndSetupRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    
    if (token != null) {
      // Decode JWT token to get expiry
      _tokenExpiryTime = _getTokenExpiry(token);
      
      if (_tokenExpiryTime != null) {
        _scheduleAutoRefresh();
      }
    }
  }
  
  DateTime? _getTokenExpiry(String token) {
    try {
      // JWT tokens are base64 encoded
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      // Decode the payload (second part)
      String payload = parts[1];
      // Add padding if needed
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      
      final decoded = utf8.decode(base64.decode(payload));
      final jsonData = json.decode(decoded);
      
      // exp is in seconds since epoch
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (jsonData['exp'] * 1000).toInt()
      );
      
      print('🔐 Token expires at: $expiry');
      return expiry;
    } catch (e) {
      print('❌ Error decoding token: $e');
      return null;
    }
  }
  
  void _scheduleAutoRefresh() {
    if (_tokenExpiryTime == null) return;
    
    // Cancel existing timer
    _refreshTimer?.cancel();
    
    // Calculate time until expiry (refresh 5 minutes before expiry)
    const refreshBuffer = Duration(minutes: 5);
    final timeUntilExpiry = _tokenExpiryTime!.difference(DateTime.now());
    final timeToRefresh = timeUntilExpiry - refreshBuffer;
    
    if (timeToRefresh.isNegative) {
      // Token already expired or about to expire, refresh now
      print('🔄 Token near expiry, refreshing now...');
      _refreshToken();
    } else if (timeToRefresh.inSeconds > 0) {
      // Schedule refresh
      print('⏰ Scheduling token refresh in ${timeToRefresh.inMinutes} minutes');
      _refreshTimer = Timer(timeToRefresh, () => _refreshToken());
    }
  }
  
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

    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: data != null ? jsonEncode(data) : null,
      );

      print('📥 Response: ${response.statusCode}');

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
  // RESPONSE HANDLER (WITH QUEUE)
  // =========================
  Future<dynamic> _handleResponse(
    http.Response response,
    Function retryRequest,
  ) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    // 🚨 TOKEN EXPIRED → QUEUE REQUESTS
    if (response.statusCode == 401) {
      print('🔄 Token expired, queuing request...');

      // If already refreshing, wait for it to complete
      if (_isRefreshing) {
        final completer = Completer();
        _pendingRequests.add(completer);
        await completer.future;
        // Retry the request after refresh
        return await retryRequest();
      }

      _isRefreshing = true;

      try {
        final refreshed = await _refreshToken();

        if (refreshed) {
          print('✅ Token refreshed, retrying queued requests...');
          
          // Complete all pending requests
          for (var completer in _pendingRequests) {
            completer.complete();
          }
          _pendingRequests.clear();
          
          // Retry the original request
          return await retryRequest();
        } else {
          // Refresh failed completely
          for (var completer in _pendingRequests) {
            completer.completeError('Session expired');
          }
          _pendingRequests.clear();
          throw Exception('Session expired');
        }
      } finally {
        _isRefreshing = false;
      }
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
    String? refreshToken = prefs.getString('refresh_token');

    if (refreshToken == null) {
      print('❌ No refresh token found');
      return false;
    }

    try {
      // Try multiple possible refresh token endpoints
      List<String> refreshEndpoints = [
        '/auth/token/refresh/',
        '/auth/refresh/',
        '/token/refresh/',
        '/refresh/',
      ];
      
      for (var endpoint in refreshEndpoints) {
        print('🔄 Attempting to refresh token at: $endpoint');
        
        try {
          final response = await http.post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refreshToken}),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final newAccess = data['access'];
            
            // Also update refresh token if server sends a new one
            final newRefresh = data['refresh'] ?? refreshToken;

            // Save both tokens
            await prefs.setString('access_token', newAccess);
            await prefs.setString('access', newAccess);
            await prefs.setString('token', newAccess);
            await prefs.setString('auth_token', newAccess);
            await prefs.setString('refresh_token', newRefresh);

            // Update expiry tracking
            _tokenExpiryTime = _getTokenExpiry(newAccess);
            _scheduleAutoRefresh();

            print('🔐 Token refreshed successfully using: $endpoint');
            return true;
          } else if (response.statusCode == 200) {
            // Success
            return true;
          } else {
            print('⚠️ Endpoint $endpoint returned ${response.statusCode}, trying next...');
          }
        } catch (e) {
          print('⚠️ Error with endpoint $endpoint: $e');
        }
      }
      
      // If we get here, all endpoints failed
      print('❌ All refresh token endpoints failed');
      await _clearAllTokens();
      return false;
    } catch (e) {
      print('❌ Token refresh error: $e');
      return false;
    }
  }
  
  // Public method to refresh token from outside
  Future<bool> refreshTokenPublic() async {
    return await _refreshToken();
  }
  
  // =========================
  // CLEAR ALL TOKENS
  // =========================
  Future<void> _clearAllTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('access');
    await prefs.remove('token');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
  }
  
  // =========================
  // SAVE TOKENS ON LOGIN
  // =========================
  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('access', access);
    await prefs.setString('token', access);
    await prefs.setString('auth_token', access);
    await prefs.setString('refresh_token', refresh);
    
    // Setup auto-refresh
    _tokenExpiryTime = _getTokenExpiry(access);
    _scheduleAutoRefresh();
  }
  
  // =========================
  // DISPOSE
  // =========================
  void dispose() {
    _refreshTimer?.cancel();
  }
}