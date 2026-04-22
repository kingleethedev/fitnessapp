import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../widgets/stat_card.dart';
import '../workout/workout_generation_screen.dart';
import '../meals/meal_plan_screen.dart';
import '../progress/progress_screen.dart';
import '../social/social_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of screens - NO CONST for non-const widgets
  final List<Widget> _screens = [
    const HomeContent(),
    WorkoutGenerationScreen(),
    const MealPlanScreen(),
    const ProgressScreen(),
    const SocialScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await Future.wait([
      workoutProvider.loadTodayWorkout(),
      progressProvider.loadProgressSummary(),
      mealProvider.loadTodaysMeals(),
      authProvider.loadUserProfile(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Riadha',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.blue,
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final user = authProvider.currentUser;
              if (user != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      'Hi, ${user['username'] ?? 'User'}',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.blue,
        unselectedItemColor: AppColors.greyDark,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Meals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Social',
          ),
        ],
      ),
    );
  }
}

// HomeContent widget - MUST be StatefulWidget to have context in methods
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final progressProvider = Provider.of<ProgressProvider>(context);
    final mealProvider = Provider.of<MealProvider>(context);
    
    final streakDays = progressProvider.streakDays;
    final streakText = progressProvider.streakText;
    
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak card
            StatCard(
              title: 'Current Streak',
              value: streakDays == 0 ? 'Start today!' : '$streakDays day${streakDays != 1 ? 's' : ''}',
              subtitle: streakDays == 0 ? 'Complete a workout to start your streak' : streakText,
              icon: Icons.local_fire_department,
              iconColor: streakDays >= 3 ? AppColors.yellow : AppColors.greyMedium,
              backgroundColor: streakDays >= 3 ? AppColors.blue : AppColors.greyLight,
              textColor: streakDays >= 3 ? AppColors.white : AppColors.greyDark,
            ),
            
            const SizedBox(height: 24),
            
            // Quick Actions Section
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Workout',
                    icon: Icons.fitness_center,
                    color: AppColors.blue,
                    onTap: () => Navigator.pushNamed(context, '/workout-generation'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Meal Plan',
                    icon: Icons.restaurant,
                    color: AppColors.yellow,
                    onTap: () => Navigator.pushNamed(context, '/meal-plan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Friends',
                    icon: Icons.people,
                    color: AppColors.blue,
                    onTap: () => Navigator.pushNamed(context, '/friends'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Leaderboard',
                    icon: Icons.emoji_events,
                    color: AppColors.yellow,
                    onTap: () => Navigator.pushNamed(context, '/leaderboard'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Challenges',
                    icon: Icons.flag,
                    color: AppColors.blue,
                    onTap: () => Navigator.pushNamed(context, '/challenges'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    title: 'Premium',
                    icon: Icons.star,
                    color: AppColors.yellow,
                    onTap: () => Navigator.pushNamed(context, '/subscription'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Today's workout section
            const Text(
              'Today\'s Workout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            
            const SizedBox(height: 12),
            
            if (workoutProvider.todayWorkout != null)
              _buildWorkoutCard(workoutProvider.todayWorkout!)
            else
              _buildPlaceholderCard(
                title: 'Generate New Workout',
                subtitle: 'Tap to create your personalized plan',
                onTap: () => Navigator.pushNamed(context, '/workout-generation'),
              ),
            
            const SizedBox(height: 24),
            
            // Today's Meal Plan preview
            const Text(
              'Today\'s Meals',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            
            const SizedBox(height: 12),
            
            if (mealProvider.todaysMeals.isNotEmpty)
              _buildMealPreview(mealProvider.todaysMeals)
            else
              _buildPlaceholderCard(
                title: 'Generate Meal Plan',
                subtitle: 'Tap to create your weekly meal plan',
                onTap: () => Navigator.pushNamed(context, '/meal-plan'),
              ),
            
            const SizedBox(height: 24),
            
            // Quick Stats
            const Text(
              'Your Stats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/progress'),
                    child: StatCard(
                      title: 'Total Workouts',
                      value: '${progressProvider.totalWorkouts}',
                      icon: Icons.fitness_center,
                      backgroundColor: AppColors.lightBlue,
                      textColor: AppColors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/progress'),
                    child: StatCard(
                      title: 'This Week',
                      value: '${progressProvider.weeklyWorkouts}',
                      icon: Icons.calendar_today,
                      backgroundColor: AppColors.lightBlue,
                      textColor: AppColors.blue,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/progress'),
                    child: StatCard(
                      title: 'Consistency',
                      value: '${(progressProvider.consistencyScore * 100).toInt()}%',
                      icon: Icons.trending_up,
                      backgroundColor: AppColors.lightYellow,
                      textColor: AppColors.darkYellow,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/social'),
                    child: StatCard(
                      title: 'Social',
                      value: 'Connect',
                      icon: Icons.people,
                      backgroundColor: AppColors.lightBlue,
                      textColor: AppColors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await Future.wait([
      workoutProvider.loadTodayWorkout(),
      progressProvider.loadProgressSummary(),
      mealProvider.loadTodaysMeals(),
      authProvider.loadUserProfile(),
    ]);
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.greyMedium),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final exercises = workout['exercises'] as List;
    final isCompleted = workout['is_completed'] ?? false;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ready to Move',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.success : AppColors.yellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : '${workout['duration']} min',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: exercises.take(3).map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: AppColors.yellow,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exercise.containsKey('reps') 
                                  ? '${exercise['reps']} reps' 
                                  : '${exercise['duration']} sec',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.greyDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
                    workoutProvider.setCurrentWorkout(workout);
                    Navigator.pushNamed(context, '/workout-execution');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Start Workout'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealPreview(Map<String, dynamic> meals) {
    final mealEntries = meals.entries.take(3).toList();
    final completedCount = meals.entries.where((entry) => entry.value['completed'] == true).length;
    final totalMeals = meals.length;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Meals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: completedCount == totalMeals ? AppColors.success : AppColors.yellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$completedCount/$totalMeals logged',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: mealEntries.map((entry) {
                final mealType = entry.key;
                final mealData = entry.value as Map<String, dynamic>;
                final isCompleted = mealData['completed'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.success : AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : _getMealIcon(mealType),
                          color: isCompleted ? AppColors.white : AppColors.blue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatMealType(mealType),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.greyDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mealData['name'] ?? 'Meal',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isCompleted ? AppColors.greyDark : AppColors.black,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.success : AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isCompleted ? 'Done' : '${mealData['calories'] ?? 0} cal',
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
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/meal-plan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.blue,
                  side: const BorderSide(color: AppColors.blue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Full Meal Plan'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.blue, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.blue),
            ),
          ],
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