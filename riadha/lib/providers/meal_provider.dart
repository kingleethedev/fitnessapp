import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class MealProvider extends ChangeNotifier {
  Map<String, dynamic>? _currentMealPlan;
  Map<String, dynamic> _todaysMeals = {};
  List<Map<String, dynamic>> _favoriteMeals = [];
  Map<String, dynamic>? _weeklySummary;
  bool _isLoading = false;
  
  Map<String, dynamic>? get currentMealPlan => _currentMealPlan;
  Map<String, dynamic> get todaysMeals => _todaysMeals;
  List<Map<String, dynamic>> get favoriteMeals => _favoriteMeals;
  Map<String, dynamic>? get weeklySummary => _weeklySummary;
  bool get isLoading => _isLoading;
  
  Future<void> loadMealPlan() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.get('/meals/current_plan/');
      _currentMealPlan = response;
      notifyListeners();
    } catch (e) {
      print('Error loading meal plan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadTodaysMeals() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/meals/todays_meals/');
      _todaysMeals = response['meals'] ?? {};
      notifyListeners();
    } catch (e) {
      print('Error loading today\'s meals: $e');
      _todaysMeals = {};
      notifyListeners();
    }
  }
  
  Future<void> generateMealPlan({String goal = 'HEALTHY_EATING'}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.post('/meals/generate_plan/', data: {
        'goal': goal,
      });
      _currentMealPlan = response;
      notifyListeners();
    } catch (e) {
      print('Error generating meal plan: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
 // lib/providers/meal_provider.dart

Future<void> logMeal(String mealType, {String? mealItemId, String? customName, int? customCalories}) async {
  try {
    final apiService = ApiService();
    
    // Prepare data - ensure custom_name is never null
    final data = {
      'meal_type': mealType,
      'meal_item_id': mealItemId,
      'custom_name': customName ?? '',  // Use empty string instead of null
      'custom_calories': customCalories,
    };
    
    print('📤 Logging meal with data: $data');
    
    final response = await apiService.post('/meals/log_meal/', data: data);
    print('📥 Log meal response: $response');
    
    await loadTodaysMeals();
    await loadWeeklySummary();
    
    notifyListeners();
  } catch (e) {
    print('Error logging meal: $e');
    rethrow;
  }
}
  
  Future<void> rateMeal(String logId, int rating, {String? notes}) async {
    try {
      final apiService = ApiService();
      await apiService.post('/meals/rate_meal/', data: {
        'log_id': logId,
        'rating': rating,
        'notes': notes,
      });
    } catch (e) {
      print('Error rating meal: $e');
      rethrow;
    }
  }
  
  Future<void> loadFavoriteMeals() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/meals/favorites/');
      _favoriteMeals = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }
  
  Future<void> addFavoriteMeal(String mealItemId) async {
    try {
      final apiService = ApiService();
      await apiService.post('/meals/favorite_meal/', data: {
        'meal_item_id': mealItemId,
      });
      await loadFavoriteMeals();
    } catch (e) {
      print('Error adding favorite: $e');
      rethrow;
    }
  }
  
  Future<void> removeFavoriteMeal(String mealItemId) async {
    try {
      final apiService = ApiService();
      await apiService.delete('/meals/unfavorite_meal/', data: {
        'meal_item_id': mealItemId,
      });
      await loadFavoriteMeals();
    } catch (e) {
      print('Error removing favorite: $e');
      rethrow;
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