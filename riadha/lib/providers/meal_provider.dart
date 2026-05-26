import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class MealProvider extends ChangeNotifier {
  late ApiService _apiService;
  Map<String, dynamic>? _currentMealPlan;
  Map<String, dynamic> _todaysMeals = {};
  List<Map<String, dynamic>> _favoriteMeals = [];
  Map<String, dynamic>? _weeklySummary;
  bool _isLoading = false;
  String? _error;
  
  Map<String, dynamic>? get currentMealPlan => _currentMealPlan;
  Map<String, dynamic> get todaysMeals => _todaysMeals;
  List<Map<String, dynamic>> get favoriteMeals => _favoriteMeals;
  Map<String, dynamic>? get weeklySummary => _weeklySummary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }
  
  Future<void> loadMealPlan() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/meals/current_plan/');
      _currentMealPlan = response;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading meal plan: $e');
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadTodaysMeals() async {
    try {
      final response = await _apiService.get('/meals/todays_meals/');
      _todaysMeals = response['meals'] ?? {};
      notifyListeners();
    } catch (e) {
      print('Error loading today\'s meals: $e');
      _error = e.toString();
      _todaysMeals = {};
      notifyListeners();
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> generateMealPlan({String goal = 'HEALTHY_EATING'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/meals/generate_plan/', data: {
        'goal': goal,
      });
      _currentMealPlan = response;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error generating meal plan: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> logMeal(String mealType, {String? mealItemId, String? customName, int? customCalories}) async {
    try {
      // Prepare data - ensure custom_name is never null
      final data = {
        'meal_type': mealType,
        'meal_item_id': mealItemId,
        'custom_name': customName ?? '',  // Use empty string instead of null
        'custom_calories': customCalories,
      };
      
      print('📤 Logging meal with data: $data');
      
      final response = await _apiService.post('/meals/log_meal/', data: data);
      print('📥 Log meal response: $response');
      
      await loadTodaysMeals();
      await loadWeeklySummary();
      
      notifyListeners();
    } catch (e) {
      print('Error logging meal: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> rateMeal(String logId, int rating, {String? notes}) async {
    try {
      await _apiService.post('/meals/rate_meal/', data: {
        'log_id': logId,
        'rating': rating,
        'notes': notes,
      });
    } catch (e) {
      print('Error rating meal: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> loadFavoriteMeals() async {
    try {
      final response = await _apiService.get('/meals/favorites/');
      _favoriteMeals = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading favorites: $e');
      _error = e.toString();
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> addFavoriteMeal(String mealItemId) async {
    try {
      await _apiService.post('/meals/favorite_meal/', data: {
        'meal_item_id': mealItemId,
      });
      await loadFavoriteMeals();
    } catch (e) {
      print('Error adding favorite: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> removeFavoriteMeal(String mealItemId) async {
    try {
      await _apiService.delete('/meals/unfavorite_meal/', data: {
        'meal_item_id': mealItemId,
      });
      await loadFavoriteMeals();
    } catch (e) {
      print('Error removing favorite: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> loadWeeklySummary() async {
    try {
      final response = await _apiService.get('/meals/weekly_summary/');
      _weeklySummary = response;
      notifyListeners();
    } catch (e) {
      print('Error loading weekly summary: $e');
      _error = e.toString();
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void reset() {
    _currentMealPlan = null;
    _todaysMeals = {};
    _favoriteMeals = [];
    _weeklySummary = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}