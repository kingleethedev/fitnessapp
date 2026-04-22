import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class ProgressProvider extends ChangeNotifier {
  int _streakDays = 0;
  int _totalWorkouts = 0;
  int _weeklyWorkouts = 0;
  double _consistencyScore = 0;
  Map<String, dynamic>? _workoutStats;
  Map<String, dynamic>? _weeklySummary;
  bool _isLoading = false;
  
  int get streakDays => _streakDays;
  int get totalWorkouts => _totalWorkouts;
  int get weeklyWorkouts => _weeklyWorkouts;
  double get consistencyScore => _consistencyScore;
  Map<String, dynamic>? get workoutStats => _workoutStats;
  Map<String, dynamic>? get weeklySummary => _weeklySummary;
  bool get isLoading => _isLoading;
  
  String get streakText {
    if (_streakDays >= 30) return 'Legendary Streak';
    if (_streakDays >= 14) return 'Great Streak';
    if (_streakDays >= 7) return 'Good Streak';
    if (_streakDays >= 3) return 'Getting Consistent';
    if (_streakDays >= 1) return 'Keep Going';
    return 'Start Today';
  }
  
  Future<void> loadProgressSummary() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.get('/users/profile/');
      _streakDays = response['streak_days'] ?? 0;
      _totalWorkouts = response['total_workouts'] ?? 0;
      _weeklyWorkouts = response['weekly_workouts'] ?? 0;
      
      // Calculate consistency score (workouts this week / target)
      final targetWorkouts = 4; // Default target
      _consistencyScore = _weeklyWorkouts / targetWorkouts;
      
      notifyListeners();
    } catch (e) {
      print('Error loading progress summary: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadWorkoutStats() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/users/stats/');
      _workoutStats = response;
      notifyListeners();
    } catch (e) {
      print('Error loading workout stats: $e');
    }
  }
  
  Future<void> loadWeeklySummary() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/meals/weekly_summary/');
      _weeklySummary = response;
      notifyListeners();
    } catch (e) {
      print('Error loading weekly summary: $e');
    }
  }
}