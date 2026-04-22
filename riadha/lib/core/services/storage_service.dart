// storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;
  
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // Auth tokens
  static Future<void> saveAuthToken(String token) async {
    await _prefs.setString('auth_token', token);
  }
  
  static String? getAuthToken() {
    return _prefs.getString('auth_token');
  }
  
  static Future<void> saveRefreshToken(String token) async {
    await _prefs.setString('refresh_token', token);
  }
  
  static String? getRefreshToken() {
    return _prefs.getString('refresh_token');
  }
  
  // User data
  static Future<void> saveUserId(String userId) async {
    await _prefs.setString('user_id', userId);
  }
  
  static String? getUserId() {
    return _prefs.getString('user_id');
  }
  
  static Future<void> saveUserEmail(String email) async {
    await _prefs.setString('user_email', email);
  }
  
  static String? getUserEmail() {
    return _prefs.getString('user_email');
  }
  
  static Future<void> saveUsername(String username) async {
    await _prefs.setString('username', username);
  }
  
  static String? getUsername() {
    return _prefs.getString('username');
  }
  
  // Onboarding
  static Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool('onboarding_completed', completed);
  }
  
  static bool isOnboardingCompleted() {
    return _prefs.getBool('onboarding_completed') ?? false;
  }
  
  // Settings
  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool('notifications_enabled', enabled);
  }
  
  static bool areNotificationsEnabled() {
    return _prefs.getBool('notifications_enabled') ?? true;
  }
  
  // Clear all data
  static Future<void> clearAll() async {
    await _prefs.clear();
  }
}