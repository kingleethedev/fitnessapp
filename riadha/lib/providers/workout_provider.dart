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
  
  /// Helper method to ensure exercises have video URLs properly formatted
  Map<String, dynamic> _normalizeWorkoutData(Map<String, dynamic> workout) {
    if (workout == null) return {};
    
    final normalized = Map<String, dynamic>.from(workout);
    
    // Ensure ID is available in both formats
    if (normalized['workout_id'] != null && normalized['id'] == null) {
      normalized['id'] = normalized['workout_id'];
    }
    if (normalized['id'] != null && normalized['workout_id'] == null) {
      normalized['workout_id'] = normalized['id'];
    }
    
    // Process exercises to ensure video URLs are accessible
    if (normalized['exercises'] != null) {
      final exercises = List.from(normalized['exercises']);
      final processedExercises = exercises.map((exercise) {
        final processed = Map<String, dynamic>.from(exercise);
        
        // Extract video URL from various possible locations
        if (processed['video_url'] == null && processed['videoUrl'] != null) {
          processed['video_url'] = processed['videoUrl'];
        }
        
        // Check if exercise has video (from has_video flag or video_url presence)
        if (processed['has_video'] == null) {
          processed['has_video'] = processed['video_url'] != null && 
                                    processed['video_url'].toString().isNotEmpty;
        }
        
        // Log for debugging
        if (processed['has_video'] == true) {
          print('🎥 Exercise "${processed['name']}" has video: ${processed['video_url']}');
        } else {
          print('📝 Exercise "${processed['name']}" has no video');
        }
        
        return processed;
      }).toList();
      
      normalized['exercises'] = processedExercises;
    }
    
    return normalized;
  }
  
  Future<void> loadTodayWorkout() async {
    _error = null;
    
    try {
      final response = await _apiService.get('/workouts/today/');
      _todayWorkout = response != null ? _normalizeWorkoutData(response) : null;
      print('✅ Today\'s workout loaded: ${response != null ? 'Found' : 'None'}');
      
      if (_todayWorkout != null && _todayWorkout!['exercises'] != null) {
        final exercises = _todayWorkout!['exercises'] as List;
        final videosCount = exercises.where((e) => e['has_video'] == true).length;
        print('📹 Exercises with videos: $videosCount/${exercises.length}');
      }
      
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
      _currentWorkout = _normalizeWorkoutData(response);
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
      
      // Ensure we have the workout ID in both formats
      if (response['workout_id'] != null) {
        response['id'] = response['workout_id'];
      }
      if (response['id'] != null) {
        response['workout_id'] = response['id'];
      }
      
      _currentWorkout = _normalizeWorkoutData(response);
      print('✅ Generated workout from template with ID: ${_currentWorkout?['workout_id']}');
      
      // Log video availability
      if (_currentWorkout != null && _currentWorkout!['exercises'] != null) {
        final exercises = _currentWorkout!['exercises'] as List;
        final videosCount = exercises.where((e) => e['has_video'] == true).length;
        print('📹 Exercises with videos: $videosCount/${exercises.length}');
      }
      
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
      final workouts = List<Map<String, dynamic>>.from(response['results'] ?? []);
      _workoutHistory = workouts.map((w) => _normalizeWorkoutData(w)).toList();
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
      
      _currentWorkout = _normalizeWorkoutData(response);
      print('✅ Current workout set with ID: ${_currentWorkout?['workout_id']}');
      
      // Log video availability
      if (_currentWorkout != null && _currentWorkout!['exercises'] != null) {
        final exercises = _currentWorkout!['exercises'] as List;
        final videosCount = exercises.where((e) => e['has_video'] == true).length;
        print('📹 Exercises with videos: $videosCount/${exercises.length}');
      }
      
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
    _currentWorkout = _normalizeWorkoutData(workout);
    print('📋 Set current workout with ID: ${_currentWorkout?['workout_id']}');
    
    // Log video availability
    if (_currentWorkout != null && _currentWorkout!['exercises'] != null) {
      final exercises = _currentWorkout!['exercises'] as List;
      final videosCount = exercises.where((e) => e['has_video'] == true).length;
      print('📹 Exercises with videos: $videosCount/${exercises.length}');
    }
    
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
      return _normalizeWorkoutData(response);
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
      final workouts = List<Map<String, dynamic>>.from(response['results'] ?? []);
      return workouts.map((w) => _normalizeWorkoutData(w)).toList();
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
  
  /// Helper method to check if a workout has any videos
  bool hasVideosInWorkout(Map<String, dynamic>? workout) {
    if (workout == null || workout['exercises'] == null) return false;
    final exercises = workout['exercises'] as List;
    return exercises.any((e) => e['has_video'] == true);
  }
  
  /// Get count of exercises with videos in current workout
  int getVideoCountInCurrentWorkout() {
    if (_currentWorkout == null || _currentWorkout!['exercises'] == null) return 0;
    final exercises = _currentWorkout!['exercises'] as List;
    return exercises.where((e) => e['has_video'] == true).length;
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