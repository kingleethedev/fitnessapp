import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/meal_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_error_widget.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _mealPlan;
  String? _error;
  List<Map<String, dynamic>> _favoriteMeals = [];
  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _loadMealPlan();
    _loadFavorites();
  }

  Future<void> _loadMealPlan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      await mealProvider.loadMealPlan();
      
      setState(() {
        _mealPlan = mealProvider.currentMealPlan;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      await mealProvider.loadFavoriteMeals();
      setState(() {
        _favoriteMeals = mealProvider.favoriteMeals;
        _favoriteIds = _favoriteMeals.map((fav) => fav['meal_item']['id'].toString()).toSet();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String mealId, String mealName) async {
    if (mealId.isEmpty || mealId.contains('_')) {
      // This is a generated ID, not a real UUID
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot favorite this meal yet. Please regenerate meal plan.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final isFavorite = _favoriteIds.contains(mealId);
    
    try {
      if (isFavorite) {
        await mealProvider.removeFavoriteMeal(mealId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "$mealName" from favorites'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await mealProvider.addFavoriteMeal(mealId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "$mealName" to favorites'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
      await _loadFavorites();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorites: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    final weekdays = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
    return weekdays[now.weekday % 7];
  }

  bool _isToday(String day) {
    return day.toUpperCase() == _getTodayKey();
  }

  @override
  Widget build(BuildContext context) {
    final mealProvider = Provider.of<MealProvider>(context);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          title: const Text('Meal Plan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Weekly Plan'),
              Tab(text: 'Favorites'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadMealPlan();
                _loadFavorites();
              },
            ),
          ],
        ),
        body: _isLoading
            ? const LoadingWidget(message: 'Loading meal plan...')
            : _error != null
                ? CustomErrorWidget(
                    message: _error!,
                    onRetry: _loadMealPlan,
                  )
                : TabBarView(
                    children: [
                      // Weekly Plan Tab
                      mealProvider.currentMealPlan != null
                          ? _buildMealPlan(mealProvider.currentMealPlan!)
                          : _buildEmptyState(),
                      // Favorites Tab
                      _buildFavoritesTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.restaurant,
            size: 64,
            color: AppColors.greyDark,
          ),
          const SizedBox(height: 16),
          const Text(
            'No meal plan found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate a meal plan to get started',
            style: TextStyle(color: AppColors.greyDark),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              final mealProvider = Provider.of<MealProvider>(context, listen: false);
              await mealProvider.generateMealPlan();
              _loadMealPlan();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Generate Meal Plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesTab() {
    if (_favoriteMeals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.favorite_border,
              size: 64,
              color: AppColors.greyDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'No favorite meals yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart icon on meals to add them to favorites',
              style: TextStyle(color: AppColors.greyDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favoriteMeals.length,
        itemBuilder: (context, index) {
          final favorite = _favoriteMeals[index];
          final meal = favorite['meal_item'];
          return _buildFavoriteCard(meal);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getMealIcon(meal['name']),
            color: AppColors.blue,
            size: 28,
          ),
        ),
        title: Text(
          meal['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatMealType(meal['meal_type']),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${meal['calories']} cal • P:${meal['protein']}g C:${meal['carbs']}g F:${meal['fats']}g',
              style: const TextStyle(fontSize: 10, color: AppColors.greyDark),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: Colors.red),
          onPressed: () => _toggleFavorite(meal['id'].toString(), meal['name']),
        ),
      ),
    );
  }

  Widget _buildMealPlan(Map<String, dynamic> mealPlan) {
    final days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
    
    Map<String, dynamic> mealsData = {};
    if (mealPlan.containsKey('meals')) {
      mealsData = mealPlan['meals'] as Map<String, dynamic>;
    } else {
      mealsData = mealPlan;
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final dayMeals = mealsData[day];
        
        if (dayMeals == null) return const SizedBox.shrink();
        
        final isToday = _isToday(day);
        
        return _buildDaySection(
          day: day,
          meals: dayMeals,
          isToday: isToday,
        );
      },
    );
  }

  Widget _buildDaySection({
    required String day,
    required Map<String, dynamic> meals,
    required bool isToday,
  }) {
    final mealOrder = ['BREAKFAST', 'SNACK', 'LUNCH', 'SNACK_2', 'DINNER'];
    final mealDisplayNames = {
      'BREAKFAST': 'Breakfast',
      'SNACK': 'Morning Snack',
      'LUNCH': 'Lunch',
      'SNACK_2': 'Afternoon Snack',
      'DINNER': 'Dinner',
    };
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isToday ? AppColors.yellow : AppColors.greyMedium,
          width: isToday ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isToday ? AppColors.yellow : AppColors.lightBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isToday ? AppColors.white : AppColors.blue,
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...mealOrder.where((mealType) => meals.containsKey(mealType)).map((mealType) {
            final mealData = meals[mealType];
            final isCompleted = mealData['completed'] == true;
            // Check if this is a real UUID (contains hyphens)
            final mealId = mealData['id']?.toString() ?? '';
            final isValidUuid = mealId.contains('-') && mealId.length > 30;
            final isFavorite = isValidUuid && _favoriteIds.contains(mealId);
            
            return _buildMealItem(
              mealType: mealType,
              mealName: mealDisplayNames[mealType]!,
              mealDescription: mealData['name'] ?? 'Meal',
              calories: mealData['calories'] ?? 0,
              isCompleted: isCompleted,
              isFavorite: isFavorite,
              mealId: mealId,
              isValidUuid: isValidUuid,
              mealItemId: mealData['id'],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMealItem({
    required String mealType,
    required String mealName,
    required String mealDescription,
    required int calories,
    required bool isCompleted,
    required bool isFavorite,
    required String mealId,
    required bool isValidUuid,
    String? mealItemId,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompleted ? AppColors.greyLight : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.greyMedium.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // Meal icon with log functionality
          GestureDetector(
            onTap: isCompleted ? null : () => _logMeal(mealType, mealItemId),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.success : AppColors.lightBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCompleted ? Icons.check : _getMealIcon(mealDescription),
                color: isCompleted ? AppColors.white : AppColors.blue,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Meal info
          Expanded(
            child: GestureDetector(
              onTap: isCompleted ? null : () => _logMeal(mealType, mealItemId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mealDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: isCompleted ? AppColors.greyDark : AppColors.black,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Favorite button - only show if we have a valid UUID
          if (isValidUuid)
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : AppColors.greyDark,
                size: 22,
              ),
              onPressed: () => _toggleFavorite(mealId, mealDescription),
            ),
          
          // Calories/Logged status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : AppColors.lightYellow,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isCompleted ? 'Logged' : '$calories cal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCompleted ? AppColors.white : AppColors.darkYellow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logMeal(String mealType, String? mealItemId) async {
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Meal'),
        content: const Text('Mark this meal as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Log Meal'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await mealProvider.logMeal(mealType, mealItemId: mealItemId);
        _loadMealPlan();
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
      }
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

  IconData _getMealIcon(String mealName) {
    switch (mealName.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }
}