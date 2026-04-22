import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/services/cache_service.dart';

class WorkoutProvider extends ChangeNotifier {
  Map<String, dynamic>? _todayWorkout;
  Map<String, dynamic>? _currentWorkout;
  List<Map<String, dynamic>> _workoutHistory = [];
  Map<String, dynamic>? _workoutStats;
  bool _isLoading = false;
  bool _historyLoaded = false;
  
  Map<String, dynamic>? get todayWorkout => _todayWorkout;
  Map<String, dynamic>? get currentWorkout => _currentWorkout;
  List<Map<String, dynamic>> get workoutHistory => _workoutHistory;
  Map<String, dynamic>? get workoutStats => _workoutStats;
  bool get isLoading => _isLoading;
  
  Future<void> loadTodayWorkout() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/workouts/today/');
      _todayWorkout = response;
      notifyListeners();
    } catch (e) {
      print('Error loading today workout: $e');
      _todayWorkout = null;
    }
  }
  
  Future<void> loadWorkoutHistory({int limit = 30, bool forceRefresh = false}) async {
    if (_isLoading) return;
    
    // Don't reload if already loaded and not forced
    if (_historyLoaded && !forceRefresh) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.get('/users/workout_history/?limit=$limit');
      _workoutHistory = List<Map<String, dynamic>>.from(response['results']);
      _historyLoaded = true;
      
      // Cache the workouts
      await CacheService.cacheWorkouts(response['results']);
    } catch (e) {
      print('Error loading workout history: $e');
      // Try to load from cache
      final cached = await CacheService.getCachedWorkouts();
      if (cached.isNotEmpty) {
        _workoutHistory = List<Map<String, dynamic>>.from(cached);
      } else {
        _workoutHistory = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> generateWorkout(Map<String, dynamic> params) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.post('/workouts/generate/', data: params);
      print('📋 Generate workout response: $response');
      
      // Ensure we have the workout ID in both formats
      if (response['workout_id'] != null) {
        response['id'] = response['workout_id'];
      }
      if (response['id'] != null) {
        response['workout_id'] = response['id'];
      }
      
      _currentWorkout = response;
      print('✅ Current workout set with ID: ${_currentWorkout?['workout_id']}');
    } catch (e) {
      print('Error generating workout: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void setCurrentWorkout(Map<String, dynamic> workout) {
    // Ensure we have the ID in both formats
    if (workout['workout_id'] != null && workout['id'] == null) {
      workout['id'] = workout['workout_id'];
    }
    if (workout['id'] != null && workout['workout_id'] == null) {
      workout['workout_id'] = workout['id'];
    }
    _currentWorkout = workout;
    print('📋 Set current workout with ID: ${_currentWorkout?['workout_id']}');
    notifyListeners();
  }
  
  Future<Map<String, dynamic>> completeWorkout(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      print('📤 Completing workout with data: $data');
      final response = await apiService.post('/workouts/complete/', data: data);
      print('✅ Workout completed: $response');
      
      // Refresh stats after workout completion
      await loadTodayWorkout();
      await loadWorkoutHistory(forceRefresh: true);
      await loadWorkoutStats();
      
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      print('❌ Error completing workout: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> loadWorkoutStats() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/users/stats/');
      _workoutStats = response;
      print('📋 Workout stats loaded: ${response['summary']}');
      notifyListeners();
    } catch (e) {
      print('Error loading workout stats: $e');
      _workoutStats = null;
    }
  }
  
  void reset() {
    _todayWorkout = null;
    _currentWorkout = null;
    _workoutHistory = [];
    _workoutStats = null;
    _historyLoaded = false;
    notifyListeners();
  }
}