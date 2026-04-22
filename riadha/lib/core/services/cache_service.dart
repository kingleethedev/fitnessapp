import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  static const String _workoutCacheKey = 'cached_workouts';
  static const String _mealCacheKey = 'cached_meals';
  static const String _profileCacheKey = 'cached_profile';
  
  static Future<void> cacheWorkouts(List<dynamic> workouts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workoutCacheKey, jsonEncode(workouts));
  }
  
  static Future<List<dynamic>> getCachedWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_workoutCacheKey);
    if (cached != null) {
      return jsonDecode(cached);
    }
    return [];
  }
  
  static Future<void> cacheProfile(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileCacheKey, jsonEncode(profile));
  }
  
  static Future<Map<String, dynamic>?> getCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_profileCacheKey);
    if (cached != null) {
      return jsonDecode(cached);
    }
    return null;
  }
}