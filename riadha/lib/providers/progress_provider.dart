// lib/providers/progress_provider.dart
import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class ProgressProvider extends ChangeNotifier {
  late ApiService _apiService;
  int _streakDays = 0;
  int _totalWorkouts = 0;
  int _weeklyWorkouts = 0;
  double _consistencyScore = 0;
  Map<String, dynamic>? _workoutStats;
  Map<String, dynamic>? _weeklySummary;
  bool _isLoading = false;
  String? _error;
  
  int get streakDays => _streakDays;
  int get totalWorkouts => _totalWorkouts;
  int get weeklyWorkouts => _weeklyWorkouts;
  double get consistencyScore => _consistencyScore;
  Map<String, dynamic>? get workoutStats => _workoutStats;
  Map<String, dynamic>? get weeklySummary => _weeklySummary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  String get streakText {
    if (_streakDays >= 30) return 'Legendary Streak 🔥';
    if (_streakDays >= 14) return 'Great Streak 💪';
    if (_streakDays >= 7) return 'Good Streak ⭐';
    if (_streakDays >= 3) return 'Getting Consistent 📈';
    if (_streakDays >= 1) return 'Keep Going 🎯';
    return 'Start Today 🚀';
  }
  
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }
  
  // Helper function to safely convert to int
  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
  
  Future<void> loadProgressSummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/users/profile/');
      
      _streakDays = _toInt(response['streak_days']);
      _totalWorkouts = _toInt(response['total_workouts']);
      _weeklyWorkouts = _toInt(response['weekly_workouts']);
      
      // Calculate consistency score (workouts this week / target)
      const targetWorkouts = 4; // Default target
      _consistencyScore = _weeklyWorkouts / targetWorkouts;
      
      print('✅ Progress summary loaded: Streak=$_streakDays, Total=$_totalWorkouts, Weekly=$_weeklyWorkouts');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading progress summary: $e');
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadWorkoutStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Try to get workout stats from profile since it already has this data
      final profileResponse = await _apiService.get('/users/profile/');
      
      // Try to get additional stats from workout history endpoint if available
      Map<String, dynamic> additionalStats = {};
      try {
        final historyResponse = await _apiService.get('/workouts/history/');
        if (historyResponse is List) {
          int totalMinutes = 0;
          int totalCalories = 0;
          
          for (var workout in historyResponse) {
            final duration = workout['duration'];
            final calories = workout['calories_burned'];
            
            if (duration != null) {
              totalMinutes += _toInt(duration);
            }
            if (calories != null) {
              totalCalories += _toInt(calories);
            }
          }
          
          additionalStats = {
            'total_minutes': totalMinutes,
            'total_calories': totalCalories,
          };
        }
      } catch (e) {
        print('Could not load additional workout stats: $e');
        // Non-critical, continue with basic stats
      }
      
      // Create workout stats from profile data
      _workoutStats = {
        'summary': {
          'total_workouts': _toInt(profileResponse['total_workouts']),
          'total_minutes': additionalStats['total_minutes'] ?? 0,
          'total_calories': additionalStats['total_calories'] ?? 0,
        },
        'streak_days': _toInt(profileResponse['streak_days']),
        'weekly_workouts': _toInt(profileResponse['weekly_workouts']),
        'current_streak': _toInt(profileResponse['current_streak']),
        'longest_streak': _toInt(profileResponse['longest_streak']),
      };
      
      print('✅ Workout stats loaded');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading workout stats: $e');
      
      // Set default empty stats instead of failing
      _workoutStats = {
        'summary': {
          'total_workouts': 0,
          'total_minutes': 0,
          'total_calories': 0,
        },
        'streak_days': 0,
        'weekly_workouts': 0,
        'current_streak': 0,
        'longest_streak': 0,
      };
      notifyListeners();
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadWeeklySummary() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/meals/weekly_summary/');
      _weeklySummary = response;
      print('✅ Weekly summary loaded');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading weekly summary: $e');
      
      // Set default empty summary
      _weeklySummary = {
        'meals_by_day': {},
        'completion_rate': 0,
        'total_meals_completed': 0,
        'calories_consumed': 0,
        'target_calories': 2000,
      };
      notifyListeners();
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadAllProgress() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await Future.wait([
        loadProgressSummary(),
        loadWorkoutStats(),
        loadWeeklySummary(),
      ]);
      print('✅ All progress data loaded successfully');
    } catch (e) {
      _error = e.toString();
      print('Error loading all progress: $e');
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refreshProgress() async {
    await loadAllProgress();
  }
  
  double getConsistencyPercentage() {
    return (_consistencyScore * 100).clamp(0, 100);
  }
  
  String getMotivationalMessage() {
    if (_streakDays >= 30) {
      return "Amazing! You're on fire! 🔥 Keep inspiring others!";
    } else if (_streakDays >= 14) {
      return "Incredible dedication! You're building great habits! 💪";
    } else if (_streakDays >= 7) {
      return "Great work! One week strong! Keep it up! ⭐";
    } else if (_streakDays >= 3) {
      return "Consistency is key! You're doing great! 📈";
    } else if (_streakDays >= 1) {
      return "Every workout counts! Stay motivated! 🎯";
    } else {
      return "Ready to begin your fitness journey? Let's go! 🚀";
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void reset() {
    _streakDays = 0;
    _totalWorkouts = 0;
    _weeklyWorkouts = 0;
    _consistencyScore = 0;
    _workoutStats = null;
    _weeklySummary = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}