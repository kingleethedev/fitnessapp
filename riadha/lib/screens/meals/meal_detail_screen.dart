import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/meal_provider.dart';
import '../../widgets/loading_widget.dart';

class MealDetailScreen extends StatefulWidget {
  final String? mealId;
  final Map<String, dynamic>? mealData;
  final String? mealType;
  
  const MealDetailScreen({
    super.key,
    this.mealId,
    this.mealData,
    this.mealType,
  });

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _mealDetails;
  bool _isLogged = false;

  @override
  void initState() {
    super.initState();
    _loadMealDetails();
  }

  Future<void> _loadMealDetails() async {
    if (widget.mealData != null) {
      setState(() {
        _mealDetails = widget.mealData;
        _isLogged = widget.mealData?['completed'] == true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // If mealId is provided, fetch from API
      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      // You would need to add a method to fetch single meal by ID
      // For now, we'll use the passed data or show mock data
      
      setState(() {
        _mealDetails = {
          'name': 'Grilled Chicken Salad',
          'calories': 450,
          'protein': 35,
          'carbs': 15,
          'fats': 28,
          'ingredients': [
            'Grilled chicken breast',
            'Mixed greens',
            'Cherry tomatoes',
            'Cucumber',
            'Olive oil and lemon dressing',
          ],
          'instructions': '1. Grill chicken breast until cooked through\n2. Wash and prepare vegetables\n3. Combine all ingredients\n4. Drizzle with dressing',
          'preparation_time': 15,
          'meal_type': widget.mealType ?? 'LUNCH',
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading meal details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logMeal() async {
    if (_isLogged) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal already logged!'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      
      await mealProvider.logMeal(
        widget.mealType ?? 'LUNCH',
        mealItemId: widget.mealId,
        customName: _mealDetails?['name'],
        customCalories: _mealDetails?['calories'],
      );
      
      setState(() {
        _isLogged = true;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meal logged successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Go back after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log meal: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: LoadingWidget(message: 'Loading meal details...'),
      );
    }

    if (_mealDetails == null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          title: const Text('Meal Details'),
        ),
        body: const Center(
          child: Text('Meal not found'),
        ),
      );
    }

    final meal = _mealDetails!;
    
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Meal Details'),
        actions: [
          if (_isLogged)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  'LOGGED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal name
            Text(
              meal['name'] ?? 'Meal',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Meal type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatMealType(meal['meal_type'] ?? 'LUNCH'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.blue,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Nutrition info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildNutritionRow('Calories', '${meal['calories'] ?? 0} kcal'),
                  const Divider(),
                  _buildNutritionRow('Protein', '${meal['protein'] ?? 0}g'),
                  const Divider(),
                  _buildNutritionRow('Carbs', '${meal['carbs'] ?? 0}g'),
                  const Divider(),
                  _buildNutritionRow('Fats', '${meal['fats'] ?? 0}g'),
                  if (meal['fiber'] != null) ...[
                    const Divider(),
                    _buildNutritionRow('Fiber', '${meal['fiber']}g'),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Preparation time
            if (meal['preparation_time'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightYellow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: AppColors.darkYellow),
                    const SizedBox(width: 12),
                    Text(
                      'Preparation time: ${meal['preparation_time']} minutes',
                      style: const TextStyle(color: AppColors.darkYellow),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Ingredients
            const Text(
              'Ingredients',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 12),
            ...(meal['ingredients'] as List? ?? []).map((ingredient) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(ingredient)),
                ],
              ),
            )),
            
            const SizedBox(height: 24),
            
            // Instructions
            if (meal['instructions'] != null) ...[
              const Text(
                'Instructions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                meal['instructions'],
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 24),
            ],
            
            // Log meal button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLogged ? null : _logMeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLogged ? AppColors.success : AppColors.blue,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_isLogged ? 'Meal Logged' : 'Log Meal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMealType(String mealType) {
    switch (mealType) {
      case 'BREAKFAST':
        return 'Breakfast';
      case 'LUNCH':
        return 'Lunch';
      case 'DINNER':
        return 'Dinner';
      case 'SNACK':
        return 'Snack';
      default:
        return mealType;
    }
  }
}