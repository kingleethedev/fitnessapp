import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/meal_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_error_widget.dart';

// Modern color palette - Light Blue, Yellow, White only
class MealColors {
  static const Color lightBlue = Color(0xFFE6F3FF);
  static const Color primaryBlue = Color(0xFF4A90D9);
  static const Color darkBlue = Color(0xFF2C5F8A);
  static const Color softYellow = Color(0xFFFFF4CC);
  static const Color accentYellow = Color(0xFFFFD633);
  static const Color darkYellow = Color(0xFFCCAA00);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8FAFC);
  static const Color greyLight = Color(0xFFE2E8F0);
  static const Color greyMedium = Color(0xFF94A3B8);
  static const Color greyDark = Color(0xFF475569);
  static const Color success = Color(0xFF4A90D9);
  static const Color error = Color(0xFFE57373);
  static const Color warning = Color(0xFFFFD633);
}

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot favorite this meal yet. Please regenerate meal plan.'),
          backgroundColor: MealColors.warning,
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
              backgroundColor: MealColors.success,
            ),
          );
        }
      } else {
        await mealProvider.addFavoriteMeal(mealId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "$mealName" to favorites'),
              backgroundColor: MealColors.success,
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
            backgroundColor: MealColors.error,
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
        backgroundColor: MealColors.offWhite,
        appBar: AppBar(
          title: const Text(
            'Meal Plan',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: MealColors.primaryBlue,
            ),
          ),
          backgroundColor: MealColors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: MealColors.accentYellow,
            indicatorWeight: 3,
            labelColor: MealColors.primaryBlue,
            unselectedLabelColor: MealColors.greyMedium,
            tabs: const [
              Tab(text: 'Weekly Plan'),
              Tab(text: 'Favorites'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: MealColors.primaryBlue),
              onPressed: () {
                _loadMealPlan();
                _loadFavorites();
              },
            ),
          ],
        ),
        body: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
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

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(MealColors.accentYellow),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading meal plan...',
            style: TextStyle(color: MealColors.greyDark),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: MealColors.lightBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 40,
              color: MealColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: MealColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: const TextStyle(color: MealColors.greyDark),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadMealPlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: MealColors.primaryBlue,
              foregroundColor: MealColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: MealColors.lightBlue,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.restaurant,
              size: 50,
              color: MealColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Meal Plan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: MealColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate a meal plan to get started',
            style: TextStyle(color: MealColors.greyDark),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final mealProvider = Provider.of<MealProvider>(context, listen: false);
              await mealProvider.generateMealPlan();
              _loadMealPlan();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MealColors.accentYellow,
              foregroundColor: MealColors.darkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Generate Meal Plan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: MealColors.lightBlue,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.favorite_border,
                size: 50,
                color: MealColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Favorites',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: MealColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the heart icon on meals to add them to favorites',
              style: TextStyle(color: MealColors.greyDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: MealColors.primaryBlue,
      backgroundColor: MealColors.white,
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
        color: MealColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MealColors.greyLight, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: MealColors.lightBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _getMealIcon(meal['name']),
            color: MealColors.primaryBlue,
            size: 28,
          ),
        ),
        title: Text(
          meal['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: MealColors.primaryBlue,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatMealType(meal['meal_type']),
              style: const TextStyle(fontSize: 11, color: MealColors.greyDark),
            ),
            const SizedBox(height: 2),
            Text(
              '${meal['calories']} cal   P:${meal['protein']}g   C:${meal['carbs']}g   F:${meal['fats']}g',
              style: const TextStyle(fontSize: 10, color: MealColors.greyMedium),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: MealColors.accentYellow, size: 24),
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
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: MealColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isToday ? MealColors.accentYellow : MealColors.greyLight,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isToday ? MealColors.accentYellow : MealColors.lightBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? MealColors.darkBlue : MealColors.primaryBlue,
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: MealColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: MealColors.primaryBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...mealOrder.where((mealType) => meals.containsKey(mealType)).map((mealType) {
            final mealData = meals[mealType];
            final isCompleted = mealData['completed'] == true;
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCompleted ? MealColors.offWhite : MealColors.white,
        border: Border(
          bottom: BorderSide(color: MealColors.greyLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Meal icon with log functionality
          GestureDetector(
            onTap: isCompleted ? null : () => _logMeal(mealType, mealItemId),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isCompleted ? MealColors.success : MealColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isCompleted ? Icons.check : _getMealIcon(mealDescription),
                color: isCompleted ? MealColors.white : MealColors.primaryBlue,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MealColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mealDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted ? MealColors.greyDark : MealColors.darkBlue,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Favorite button
          if (isValidUuid)
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? MealColors.accentYellow : MealColors.greyMedium,
                size: 22,
              ),
              onPressed: () => _toggleFavorite(mealId, mealDescription),
            ),
          
          // Calories/Logged status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isCompleted ? MealColors.lightBlue : MealColors.softYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isCompleted ? 'Logged' : '$calories',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isCompleted ? MealColors.primaryBlue : MealColors.darkYellow,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Meal',
          style: TextStyle(color: MealColors.primaryBlue),
        ),
        content: const Text(
          'Mark this meal as completed?',
          style: TextStyle(color: MealColors.greyDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: MealColors.greyMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MealColors.accentYellow,
              foregroundColor: MealColors.darkBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
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
              content: Text('Meal logged successfully'),
              backgroundColor: MealColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to log meal: $e'),
              backgroundColor: MealColors.error,
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
    final name = mealName.toLowerCase();
    if (name.contains('breakfast') || name.contains('oat')) return Icons.free_breakfast;
    if (name.contains('lunch') || name.contains('sandwich')) return Icons.lunch_dining;
    if (name.contains('dinner') || name.contains('pasta')) return Icons.dinner_dining;
    if (name.contains('snack') || name.contains('fruit')) return Icons.cake;
    if (name.contains('protein')) return Icons.fitness_center;
    if (name.contains('salad')) return Icons.emoji_food_beverage;
    return Icons.restaurant;
  }
}