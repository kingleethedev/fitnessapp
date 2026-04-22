import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  
  AuthProvider() {
    _checkAuthStatus(); // This runs when app starts
  }
  
  Future<void> _checkAuthStatus() async {
    print('🔐 Checking auth status...');
    final prefs = await SharedPreferences.getInstance();
    
    // Check multiple possible token keys
    final token = prefs.getString('access_token') ?? 
                  prefs.getString('access') ?? 
                  prefs.getString('token') ?? 
                  prefs.getString('auth_token');
    
    // Check if onboarding was completed
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    if (token != null) {
      print('✅ Token found, user is authenticated');
      _isAuthenticated = true;
      
      // Try to load user profile
      await loadUserProfile();
      
      // If onboarding not completed in backend but marked locally, update it
      if (_currentUser != null && !_currentUser!['onboarding_completed'] && onboardingCompleted) {
        // Sync onboarding status
        await _syncOnboardingStatus();
      }
    } else {
      print('❌ No token found, user not authenticated');
      _isAuthenticated = false;
    }
    notifyListeners();
  }
  
  Future<void> _syncOnboardingStatus() async {
    try {
      final apiService = ApiService();
      await apiService.post('/users/complete_onboarding/', data: {
        'goal': 'FITNESS',
        'experience_level': 'BEGINNER',
        'training_location': 'HOME',
        'days_per_week': 3,
        'time_available': 30,
      });
      await loadUserProfile();
    } catch (e) {
      print('Error syncing onboarding: $e');
    }
  }
  
  Future<void> loadUserProfile() async {
    print('📱 Loading user profile...');
    try {
      final apiService = ApiService();
      final response = await apiService.get('/users/profile/');
      print('✅ Profile loaded: ${response['username']}');
      _currentUser = response;
      
      // Save onboarding status to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', response['onboarding_completed'] ?? false);
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading profile: $e');
    }
  }
  
  Future<bool> login(String email, String password) async {
    print('🔑 Attempting login with email: $email');
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });
      
      print('📥 Login response received');
      
      if (response.containsKey('access') && response.containsKey('refresh')) {
        final prefs = await SharedPreferences.getInstance();
        
        // Store token with multiple keys for compatibility
        final accessToken = response['access'];
        final refreshToken = response['refresh'];
        
        await prefs.setString('access_token', accessToken);
        await prefs.setString('access', accessToken);
        await prefs.setString('token', accessToken);
        await prefs.setString('auth_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        
        print('✅ Token saved successfully');
        
        _isAuthenticated = true;
        await loadUserProfile();
        
        _isLoading = false;
        notifyListeners();
        print('✅ Login successful!');
        return true;
      } else {
        print('❌ Login response missing tokens');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> register(Map<String, dynamic> userData) async {
    print('📝 Registering new user: ${userData['email']}');
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final requestData = {
        'username': userData['username'],
        'email': userData['email'],
        'password': userData['password'],
        'confirm_password': userData['password'],
      };
      
      final response = await apiService.post('/auth/register/', data: requestData);
      
      print('📥 Registration response received');
      
      if (response.containsKey('access') && response.containsKey('refresh')) {
        final prefs = await SharedPreferences.getInstance();
        
        // Store token with multiple keys for compatibility
        final accessToken = response['access'];
        final refreshToken = response['refresh'];
        
        await prefs.setString('access_token', accessToken);
        await prefs.setString('access', accessToken);
        await prefs.setString('token', accessToken);
        await prefs.setString('auth_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        
        // Mark onboarding as not completed yet
        await prefs.setBool('onboarding_completed', false);
        
        print('✅ Registration successful! Token saved');
        
        _isAuthenticated = true;
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        print('❌ Registration response missing tokens');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Registration error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    print('🚪 Logging out user');
    final prefs = await SharedPreferences.getInstance();
    
    // Clear all token keys
    await prefs.remove('access_token');
    await prefs.remove('access');
    await prefs.remove('token');
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_email');
    await prefs.remove('username');
    await prefs.remove('onboarding_completed');
    
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
    print('✅ Logout complete');
  }
  
  Future<void> completeOnboarding(Map<String, dynamic> onboardingData) async {
    print('📋 Completing onboarding with: $onboardingData');
    try {
      final apiService = ApiService();
      final response = await apiService.post('/users/complete_onboarding/', data: onboardingData);
      print('📥 Onboarding response: $response');
      
      if (response['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await loadUserProfile();
        print('✅ Onboarding completed successfully');
      } else {
        print('❌ Onboarding failed: ${response['errors']}');
      }
    } catch (e) {
      print('❌ Error completing onboarding: $e');
      rethrow;
    }
  }
  
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    print('📋 Onboarding status: $completed');
    return completed;
  }
  
  Future<void> updateProfile(Map<String, dynamic> data) async {
    print('📝 Updating profile: $data');
    try {
      final apiService = ApiService();
      await apiService.patch('/users/update_profile/', data: data);
      await loadUserProfile();
      print('✅ Profile updated successfully');
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    }
  }
  
  // Helper method to check if token exists (for debugging)
  Future<bool> hasValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? 
                  prefs.getString('access') ?? 
                  prefs.getString('token') ?? 
                  prefs.getString('auth_token');
    
    print('🔐 Token check: ${token != null ? 'Token exists' : 'No token found'}');
    if (token != null) {
      print('🔐 Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    }
    return token != null;
  }
}