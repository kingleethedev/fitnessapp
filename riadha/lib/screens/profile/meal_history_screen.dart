// lib/screens/profile/meal_history_screen.dart
// lib/screens/profile/meal_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/colors.dart';
import '../../providers/meal_provider.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _recentMeals = [];
  List<Map<String, dynamic>> _favoriteMeals = [];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    await Future.wait([
      mealProvider.loadWeeklySummary(),
      mealProvider.loadFavoriteMeals(),
    ]);
    
    await _loadRecentMeals();
    await _loadFavoriteMeals();
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadRecentMeals() async {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final mealPlan = mealProvider.currentMealPlan;
    
    if (mealPlan != null && mealPlan['meals'] != null) {
      final meals = mealPlan['meals'] as Map<String, dynamic>;
      final List<Map<String, dynamic>> recent = [];
      
      final days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
      final today = DateTime.now().weekday;
      
      for (int i = 0; i < 7; i++) {
        final dayIndex = (today - 1 - i) % 7;
        if (dayIndex >= 0) {
          final day = days[dayIndex];
          if (meals[day] != null) {
            final dayMeals = meals[day] as Map<String, dynamic>;
            dayMeals.forEach((mealType, mealData) {
              recent.add({
                'date': day,
                'meal_type': mealType,
                'name': mealData['name'],
                'calories': mealData['calories'],
                'completed': mealData['completed'] ?? false,
                'log_id': mealData['log_id'],
                'meal_item_id': mealData['id'],
              });
            });
          }
        }
      }
      
      _recentMeals = recent.take(20).toList();
    }
  }

  Future<void> _loadFavoriteMeals() async {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final favorites = mealProvider.favoriteMeals;
    
    _favoriteMeals = favorites.map((fav) {
      final meal = fav['meal_item'];
      return {
        'id': meal['id'],
        'name': meal['name'],
        'calories': meal['calories'],
        'protein': meal['protein'],
        'carbs': meal['carbs'],
        'fats': meal['fats'],
        'meal_type': meal['meal_type'],
        'is_vegetarian': meal['is_vegetarian'],
        'preparation_time': meal['preparation_time'],
      };
    }).toList();
  }

  Future<void> _toggleFavorite(Map<String, dynamic> meal) async {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    
    try {
      final isFavorite = _favoriteMeals.any((fav) => fav['id'] == meal['id']);
      
      if (isFavorite) {
        await mealProvider.removeFavoriteMeal(meal['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        await mealProvider.addFavoriteMeal(meal['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _loadFavoriteMeals();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _logMeal(Map<String, dynamic> meal) async {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mark "${meal['name']}" as completed?'),
            const SizedBox(height: 8),
            Text(
              '${meal['calories']} calories',
              style: const TextStyle(color: AppColors.greyDark),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Log Meal'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      setState(() => _isLoading = true);
      
      try {
        await mealProvider.logMeal(
          meal['meal_type'],
          mealItemId: meal['meal_item_id'],
          customName: meal['name'],
          customCalories: meal['calories'],
        );
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meal logged successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to log meal: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logCustomMeal() async {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    String selectedMealType = 'LUNCH';
    
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Custom Meal'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Meal Name',
                  hintText: 'e.g., Chicken Salad',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  hintText: 'Estimated calories',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMealType,
                decoration: const InputDecoration(labelText: 'Meal Type'),
                items: const [
                  DropdownMenuItem(value: 'BREAKFAST', child: Text('Breakfast')),
                  DropdownMenuItem(value: 'SNACK', child: Text('Snack')),
                  DropdownMenuItem(value: 'LUNCH', child: Text('Lunch')),
                  DropdownMenuItem(value: 'SNACK_2', child: Text('Afternoon Snack')),
                  DropdownMenuItem(value: 'DINNER', child: Text('Dinner')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setStateDialog(() => selectedMealType = value);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final calories = int.tryParse(caloriesController.text);
              if (name.isEmpty || calories == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter meal name and calories'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Log Meal'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
      final name = nameController.text.trim();
      final calories = int.tryParse(caloriesController.text);
      
      setState(() => _isLoading = true);
      
      try {
        final mealProvider = Provider.of<MealProvider>(context, listen: false);
        await mealProvider.logMeal(
          selectedMealType,
          customName: name,
          customCalories: calories,
        );
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Custom meal logged successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to log meal: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = Provider.of<MealProvider>(context);
    final weeklySummary = mealProvider.weeklySummary;
    final mealsByDay = weeklySummary?['meals_by_day'] ?? {};
    final totalMeals = weeklySummary?['total_meals_completed'] ?? 0;
    final completionRate = weeklySummary?['completion_rate'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Meal History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _logCustomMeal,
            tooltip: 'Log Custom Meal',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            '$totalMeals',
                            'Total Meals',
                            Icons.restaurant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '${completionRate.toInt()}%',
                            'Completion Rate',
                            Icons.percent,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Quick Log Button
                    ElevatedButton.icon(
                      onPressed: _logCustomMeal,
                      icon: const Icon(Icons.add),
                      label: const Text('Quick Log Meal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.blue,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Weekly Breakdown Chart
                    const Text(
                      'Weekly Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Container(
                      height: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.greyMedium),
                      ),
                      child: _buildBarChart(mealsByDay),
                    ),
                    
                    const SizedBox(height: 16),
                    _buildLegend(),
                    
                    const SizedBox(height: 24),
                    
                    // Tabs for Recent and Favorites
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.greyLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton('Recent Meals', 0),
                          _buildTabButton('Favorite Meals', 1),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Content based on selected tab
                    if (_selectedTab == 0)
                      _recentMeals.isEmpty
                          ? _buildEmptyState('No meals logged yet', 'Tap the + button to log your first meal')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentMeals.length,
                              itemBuilder: (context, index) {
                                final meal = _recentMeals[index];
                                return _buildMealCard(meal, showFavoriteButton: false);
                              },
                            )
                    else
                      _favoriteMeals.isEmpty
                          ? _buildEmptyState('No favorite meals yet', 'Tap the heart icon on meals to add them to favorites')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _favoriteMeals.length,
                              itemBuilder: (context, index) {
                                final meal = _favoriteMeals[index];
                                return _buildFavoriteMealCard(meal);
                              },
                            ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.greyDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(Map<String, dynamic> mealsByDay) {
    if (mealsByDay.isEmpty) {
      return const Center(
        child: Text(
          'No meal data yet.\nLog your first meal to see the chart!',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.greyDark),
        ),
      );
    }

    final List<BarChartGroupData> barGroups = [];
    final List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      double meals = 0.0;
      
      if (mealsByDay.containsKey(day)) {
        final value = mealsByDay[day];
        if (value is int) {
          meals = value.toDouble();
        } else if (value is double) {
          meals = value;
        } else if (value is num) {
          meals = value.toDouble();
        }
      }
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: meals,
              color: AppColors.blue,
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    double maxMeals = 7.0;
    for (var group in barGroups) {
      final num yValue = group.barRods.first.toY;
      if (yValue > maxMeals) {
        maxMeals = yValue.toDouble();
      }
    }
    final double yMax = maxMeals + 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: yMax,
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString());
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Text(days[value.toInt()].substring(0, 3));
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant, size: 48, color: AppColors.greyDark),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: AppColors.greyDark)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.greyDark), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.blue, size: 28),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.blue)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.greyDark)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.blue,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Meals Logged', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 16),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.greyLight,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Max', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal, {bool showFavoriteButton = true}) {
    final isCompleted = meal['completed'] == true;
    final isFavorite = _favoriteMeals.any((fav) => fav['name'] == meal['name']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isCompleted ? AppColors.success : AppColors.greyMedium),
      ),
      child: ListTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.lightBlue : AppColors.greyLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getMealIcon(meal['meal_type']), color: isCompleted ? AppColors.blue : AppColors.greyDark),
        ),
        title: Text(
          meal['name'],
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? AppColors.greyDark : AppColors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatMealType(meal['meal_type']), style: const TextStyle(fontSize: 12)),
            Text('${meal['calories']} cal • ${meal['date']}', style: const TextStyle(fontSize: 10, color: AppColors.greyDark)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showFavoriteButton)
              IconButton(
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : AppColors.greyDark),
                onPressed: () => _toggleFavorite(meal),
              ),
            if (!isCompleted)
              ElevatedButton(
                onPressed: () => _logMeal(meal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(60, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Log', style: TextStyle(fontSize: 12)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Logged', style: TextStyle(fontSize: 10, color: AppColors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteMealCard(Map<String, dynamic> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: ListTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_getMealIcon(meal['meal_type']), color: AppColors.blue),
        ),
        title: Text(meal['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatMealType(meal['meal_type']), style: const TextStyle(fontSize: 12)),
            Text('${meal['calories']} cal • P:${meal['protein']}g C:${meal['carbs']}g F:${meal['fats']}g',
                style: const TextStyle(fontSize: 10, color: AppColors.greyDark)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _toggleFavorite(meal),
        ),
      ),
    );
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType) {
      case 'BREAKFAST':
        return Icons.free_breakfast;
      case 'LUNCH':
        return Icons.lunch_dining;
      case 'DINNER':
        return Icons.dinner_dining;
      case 'SNACK':
        return Icons.cake;
      default:
        return Icons.restaurant;
    }
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