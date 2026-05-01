// lib/providers/workout_provider.dart
import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/services/cache_service.dart';

class WorkoutProvider extends ChangeNotifier {
  late ApiService _apiService;
  Map<String, dynamic>? _todayWorkout;
  Map<String, dynamic>? _currentWorkout;
  List<Map<String, dynamic>> _workoutHistory = [];
  Map<String, dynamic>? _workoutStats;
  bool _isLoading = false;
  bool _historyLoaded = false;
  String? _error;
  List<Map<String, dynamic>> _availableTemplates = [];
  bool _hasTemplates = false;
  
  Map<String, dynamic>? get todayWorkout => _todayWorkout;
  Map<String, dynamic>? get currentWorkout => _currentWorkout;
  List<Map<String, dynamic>> get workoutHistory => _workoutHistory;
  Map<String, dynamic>? get workoutStats => _workoutStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasHistory => _workoutHistory.isNotEmpty;
  List<Map<String, dynamic>> get availableTemplates => _availableTemplates;
  bool get hasTemplates => _hasTemplates;
  
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }
  
  Future<void> loadTodayWorkout() async {
    _error = null;
    
    try {
      final response = await _apiService.get('/workouts/today/');
      _todayWorkout = response;
      print('✅ Today\'s workout loaded: ${response != null ? 'Found' : 'None'}');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading today workout: $e');
      _todayWorkout = null;
      notifyListeners();
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> checkAvailableTemplates() async {
    try {
      final response = await _apiService.get('/workouts/available_templates/');
      _availableTemplates = List<Map<String, dynamic>>.from(response['templates'] ?? []);
      _hasTemplates = _availableTemplates.isNotEmpty;
      print('✅ Available templates: ${_availableTemplates.length} found');
      notifyListeners();
    } catch (e) {
      print('Error checking templates: $e');
      _availableTemplates = [];
      _hasTemplates = false;
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> checkTemplatesStatus() async {
    try {
      final response = await _apiService.get('/workouts/check_templates/');
      _hasTemplates = response['has_templates'] ?? false;
      print('✅ Templates status: has_templates=$_hasTemplates, count=${response['template_count']}');
      notifyListeners();
    } catch (e) {
      print('Error checking templates status: $e');
      _hasTemplates = false;
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<Map<String, dynamic>> useTemplate(String templateId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/workouts/use_template/', data: {
        'template_id': templateId,
      });
      print('✅ Used template: $templateId, created workout: ${response['workout_id']}');
      _currentWorkout = response;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      print('Error using template: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> generateWorkoutFromTemplate(String templateId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/workouts/generate/', data: {
        'template_id': templateId,
      });
      print('📋 Generate workout from template response: $response');
      
      if (response['workout_id'] != null) {
        response['id'] = response['workout_id'];
      }
      if (response['id'] != null) {
        response['workout_id'] = response['id'];
      }
      
      _currentWorkout = response;
      print('✅ Generated workout from template with ID: ${_currentWorkout?['workout_id']}');
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      print('Error generating workout from template: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadWorkoutHistory({int limit = 30, bool forceRefresh = false}) async {
    if (_isLoading) return;
    
    // Don't reload if already loaded and not forced
    if (_historyLoaded && !forceRefresh) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/users/workout_history/?limit=$limit');
      _workoutHistory = List<Map<String, dynamic>>.from(response['results'] ?? []);
      _historyLoaded = true;
      print('✅ Loaded ${_workoutHistory.length} workout history items');
      
      // Cache the workouts
      await CacheService.cacheWorkouts(response['results'] ?? []);
    } catch (e) {
      _error = e.toString();
      print('Error loading workout history: $e');
      
      // Rethrow session errors first
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      
      // Try to load from cache for non-session errors
      try {
        final cached = await CacheService.getCachedWorkouts();
        if (cached.isNotEmpty) {
          _workoutHistory = List<Map<String, dynamic>>.from(cached);
          print('✅ Loaded ${_workoutHistory.length} workouts from cache');
        } else {
          _workoutHistory = [];
        }
      } catch (cacheError) {
        print('Error loading from cache: $cacheError');
        _workoutHistory = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> generateWorkout(Map<String, dynamic> params) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/workouts/generate/', data: params);
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
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error generating workout: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
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
    _error = null;
    notifyListeners();
    
    try {
      print('📤 Completing workout with data: $data');
      final response = await _apiService.post('/workouts/complete/', data: data);
      print('✅ Workout completed: $response');
      
      // Refresh stats after workout completion
      await loadTodayWorkout();
      await loadWorkoutHistory(forceRefresh: true);
      await loadWorkoutStats();
      
      return response;
    } catch (e) {
      _error = e.toString();
      print('❌ Error completing workout: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadWorkoutStats() async {
    try {
      final response = await _apiService.get('/users/stats/');
      _workoutStats = response;
      print('📋 Workout stats loaded: ${response['summary']}');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading workout stats: $e');
      _workoutStats = null;
      notifyListeners();
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> saveWorkoutProgress(Map<String, dynamic> progress) async {
    try {
      await _apiService.post('/workouts/save_progress/', data: progress);
      print('✅ Workout progress saved');
    } catch (e) {
      print('Error saving workout progress: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      // Don't rethrow non-session errors to prevent interrupting workout
    }
  }
  
  Future<Map<String, dynamic>> getWorkoutDetails(String workoutId) async {
    try {
      final response = await _apiService.get('/workouts/$workoutId/');
      return response;
    } catch (e) {
      print('Error getting workout details: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<List<Map<String, dynamic>>> getRecommendedWorkouts() async {
    try {
      final response = await _apiService.get('/workouts/recommended/');
      return List<Map<String, dynamic>>.from(response['results'] ?? []);
    } catch (e) {
      print('Error getting recommended workouts: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      return [];
    }
  }
  
  double getCompletionRate() {
    if (_workoutHistory.isEmpty) return 0.0;
    
    int completed = _workoutHistory.where((w) => w['completed'] == true).length;
    return completed / _workoutHistory.length;
  }
  
  int getTotalExercisesCompleted() {
    int total = 0;
    for (var workout in _workoutHistory) {
      final exercises = workout['exercises_completed'];
      if (exercises != null) {
        total += (exercises as num).toInt();
      }
    }
    return total;
  }
  
  int getTotalMinutesWorked() {
    int total = 0;
    for (var workout in _workoutHistory) {
      final duration = workout['duration'];
      if (duration != null) {
        total += (duration as num).toInt();
      }
    }
    return total;
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void reset() {
    _todayWorkout = null;
    _currentWorkout = null;
    _workoutHistory = [];
    _workoutStats = null;
    _historyLoaded = false;
    _isLoading = false;
    _error = null;
    _availableTemplates = [];
    _hasTemplates = false;
    notifyListeners();
  }
}