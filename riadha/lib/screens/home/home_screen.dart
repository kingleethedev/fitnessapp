import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../workout/workout_preview_screen.dart';
import '../meals/meal_plan_screen.dart';
import '../progress/progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const WorkoutPreviewScreen(),
    const MealPlanScreen(),
    const ProgressScreen(),
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.blue,
          unselectedItemColor: AppColors.greyDark,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          elevation: 0,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'Workouts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined),
              activeIcon: Icon(Icons.restaurant),
              label: 'Meals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }
}

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
    final authProvider = Provider.of<AuthProvider>(context);
    
    final streakDays = progressProvider.streakDays;
    final streakText = progressProvider.streakText;
    final user = authProvider.currentUser;
    
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          color: AppColors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 30,
                      width: 30,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.fitness_center,
                        color: AppColors.blue,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Riadha',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.blue,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Ready to transform? 🔥',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.greyDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: AppColors.yellow, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${(progressProvider.consistencyScore * 100).toInt()}%',
                          style: const TextStyle(
                            color: AppColors.darkYellow,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: AppColors.blue,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.blue,
        backgroundColor: AppColors.white,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Message
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.greyDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?['username'] ?? 'Athlete',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Streak Card
              Container(
                decoration: BoxDecoration(
                  color: streakDays >= 3 ? AppColors.lightBlue : AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: streakDays >= 3 ? AppColors.blue : AppColors.greyMedium,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: streakDays >= 3 ? AppColors.blue : AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.local_fire_department,
                          color: streakDays >= 3 ? AppColors.yellow : AppColors.blue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Streak',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.greyDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              streakDays == 0 ? 'Start today!' : '$streakDays day${streakDays != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.blue,
                              ),
                            ),
                            Text(
                              streakDays == 0 ? 'Complete a workout to start your streak' : streakText,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.greyDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (streakDays > 0)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.lightYellow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '🔥 x$streakDays',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkYellow,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Quick Actions Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  Text(
                    'TAP TO START',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.greyMedium,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Quick Actions Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildQuickActionCard(
                    title: 'WORKOUT',
                    icon: Icons.fitness_center,
                    color: AppColors.blue,
                    bgColor: AppColors.lightBlue,
                    onTap: () {
                      // Navigate to workout preview tab
                      final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                      homeState?.setState(() {
                        homeState._selectedIndex = 1;
                      });
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'MEAL PLAN',
                    icon: Icons.restaurant,
                    color: AppColors.yellow,
                    bgColor: AppColors.lightYellow,
                    onTap: () {
                      final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                      homeState?.setState(() {
                        homeState._selectedIndex = 2;
                      });
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'FRIENDS',
                    icon: Icons.people,
                    color: AppColors.blue,
                    bgColor: AppColors.lightBlue,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'LEADERBOARD',
                    icon: Icons.emoji_events,
                    color: AppColors.yellow,
                    bgColor: AppColors.lightYellow,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'CHALLENGES',
                    icon: Icons.flag,
                    color: AppColors.blue,
                    bgColor: AppColors.lightBlue,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                  ),
                  _buildQuickActionCard(
                    title: 'PREMIUM',
                    icon: Icons.star,
                    color: AppColors.yellow,
                    bgColor: AppColors.lightYellow,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Today's Workout Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fitness_center, color: AppColors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Today\'s Workout',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    workoutProvider.todayWorkout != null ? 'Ready' : 'Not set',
                    style: TextStyle(
                      fontSize: 12,
                      color: workoutProvider.todayWorkout != null ? AppColors.blue : AppColors.greyMedium,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              if (workoutProvider.todayWorkout != null)
                _buildWorkoutCard(workoutProvider.todayWorkout!)
              else
                _buildPlaceholderCard(
                  title: 'Generate New Workout',
                  subtitle: 'Create your personalized plan',
                  icon: Icons.fitness_center,
                  onTap: () {
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    homeState?.setState(() {
                      homeState._selectedIndex = 1;
                    });
                  },
                ),
              
              const SizedBox(height: 30),
              
              // Today's Meals Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant, color: AppColors.yellow, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Today\'s Meals',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              if (mealProvider.todaysMeals.isNotEmpty)
                _buildMealPreview(mealProvider.todaysMeals)
              else
                _buildPlaceholderCard(
                  title: 'Generate Meal Plan',
                  subtitle: 'Create your weekly meal plan',
                  icon: Icons.restaurant,
                  onTap: () => Navigator.pushNamed(context, '/meal-plan'),
                ),
              
              const SizedBox(height: 30),
              
              // Stats Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart, color: AppColors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Stats',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    title: 'Total Workouts',
                    value: '${progressProvider.totalWorkouts}',
                    icon: Icons.fitness_center,
                    color: AppColors.blue,
                    bgColor: AppColors.lightBlue,
                  ),
                  _buildStatCard(
                    title: 'This Week',
                    value: '${progressProvider.weeklyWorkouts}',
                    icon: Icons.calendar_today,
                    color: AppColors.blue,
                    bgColor: AppColors.lightBlue,
                  ),
                  _buildStatCard(
                    title: 'Consistency',
                    value: '${(progressProvider.consistencyScore * 100).toInt()}%',
                    icon: Icons.trending_up,
                    color: AppColors.darkYellow,
                    bgColor: AppColors.lightYellow,
                  ),
                  _buildStatCard(
                    title: 'Active Days',
                    value: '$streakDays',
                    icon: Icons.calendar_today,
                    color: AppColors.blue,
                    bgColor: AppColors.lightBlue,
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
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
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: () {
        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
        homeState?.setState(() {
          homeState._selectedIndex = 3;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyMedium, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: AppColors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${workout['duration']} min',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.success : AppColors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'COMPLETED ✓' : 'READY',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      letterSpacing: 0.5,
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
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: AppColors.blue,
                          size: 22,
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
                                fontWeight: FontWeight.w600,
                                color: AppColors.blue,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              exercise.containsKey('reps') 
                                  ? '${exercise['reps']} reps' 
                                  : '${exercise['duration']} sec',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.greyDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chevron_right, color: AppColors.blue, size: 20),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'START WORKOUT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greyMedium, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightYellow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant, color: AppColors.yellow, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$completedCount/$totalMeals logged',
                      style: const TextStyle(
                        color: AppColors.darkYellow,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: completedCount == totalMeals ? AppColors.success : AppColors.yellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    completedCount == totalMeals ? 'COMPLETE ✓' : 'IN PROGRESS',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      letterSpacing: 0.5,
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
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.success : AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : _getMealIcon(mealType),
                          color: isCompleted ? AppColors.white : AppColors.yellow,
                          size: 22,
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
                                fontSize: 11,
                                color: AppColors.greyDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mealData['name'] ?? 'Meal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isCompleted ? AppColors.greyDark : AppColors.blue,
                                fontSize: 13,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted ? AppColors.success.withOpacity(0.1) : AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCompleted ? 'DONE' : '${mealData['calories'] ?? 0} cal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCompleted ? AppColors.success : AppColors.darkYellow,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'VIEW FULL PLAN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
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
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.blue, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.blue, size: 50),
            const SizedBox(height: 16),
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
              style: TextStyle(
                fontSize: 13,
                color: AppColors.greyDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'TAP TO CREATE →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
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
        return 'BREAKFAST';
      case 'LUNCH':
        return 'LUNCH';
      case 'DINNER':
        return 'DINNER';
      case 'SNACK':
        return 'SNACK';
      default:
        return mealType;
    }
  }
}