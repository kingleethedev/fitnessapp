import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/colors.dart';
import '../../providers/progress_provider.dart';
import '../../providers/workout_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/stat_card.dart';

// Modern color palette - Light Blue, Yellow, White only
class ProgressColors {
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
}

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  int _selectedTab = 0;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await Future.wait([
        progressProvider.loadProgressSummary(),
        progressProvider.loadWorkoutStats(),
        progressProvider.loadWeeklySummary(),
        workoutProvider.loadWorkoutHistory(limit: 30),
        mealProvider.loadWeeklySummary(),
        mealProvider.loadMealPlan(),
        mealProvider.loadTodaysMeals(),
        authProvider.loadUserProfile(),
      ]);
      
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: ProgressColors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(ProgressColors.accentYellow),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Loading your progress...',
                style: TextStyle(color: ProgressColors.greyDark),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ProgressColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Progress',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ProgressColors.primaryBlue,
          ),
        ),
        backgroundColor: ProgressColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: ProgressColors.primaryBlue),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: ProgressColors.primaryBlue,
        backgroundColor: ProgressColors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: ProgressColors.greyLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Workouts', 0),
                    _buildTabButton('Meals', 1),
                    _buildTabButton('Body', 2),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            
              // Content based on selected tab
              IndexedStack(
                index: _selectedTab,
                children: [
                  _buildWorkoutTab(),
                  _buildMealTab(),
                  _buildBodyTab(),
                ],
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
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? ProgressColors.accentYellow : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? ProgressColors.darkBlue : ProgressColors.greyDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTab() {
    return Consumer2<ProgressProvider, WorkoutProvider>(
      builder: (context, progressProvider, workoutProvider, child) {
        final workoutHistory = workoutProvider.workoutHistory;
        final workoutStats = progressProvider.workoutStats;
        
        int calculatedTotalWorkouts = 0;
        int calculatedTotalMinutes = 0;
        int calculatedTotalCalories = 0;
        
        for (var workout in workoutHistory) {
          if (workout['is_completed'] == true) {
            calculatedTotalWorkouts++;
            final duration = workout['duration'];
            final calories = workout['calories_burned'];
            if (duration != null) {
              calculatedTotalMinutes += (duration is int ? duration : (duration as num).toInt());
            }
            if (calories != null) {
              calculatedTotalCalories += (calories is int ? calories : (calories as num).toInt());
            }
          }
        }
        
        final totalWorkouts = calculatedTotalWorkouts > 0 
            ? calculatedTotalWorkouts 
            : (workoutStats?['summary']?['total_workouts'] ?? progressProvider.totalWorkouts);
        final totalMinutes = calculatedTotalMinutes > 0 ? calculatedTotalMinutes : 0;
        final totalCalories = calculatedTotalCalories > 0 ? calculatedTotalCalories : 0;
        final streakDays = progressProvider.streakDays;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Workouts',
                    value: '$totalWorkouts',
                    icon: Icons.fitness_center,
                    backgroundColor: ProgressColors.lightBlue,
                    textColor: ProgressColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Total Minutes',
                    value: '$totalMinutes',
                    icon: Icons.timer_outlined,
                    backgroundColor: ProgressColors.lightBlue,
                    textColor: ProgressColors.primaryBlue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Current Streak',
                    value: streakDays == 0 ? '0' : '$streakDays',
                    subtitle: streakDays == 0 ? 'Start today' : 'days',
                    icon: Icons.local_fire_department,
                    iconColor: streakDays >= 3 ? ProgressColors.accentYellow : ProgressColors.greyMedium,
                    backgroundColor: streakDays >= 3 ? ProgressColors.primaryBlue : ProgressColors.greyLight,
                    textColor: streakDays >= 3 ? ProgressColors.white : ProgressColors.greyDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Calories Burned',
                    value: '$totalCalories',
                    icon: Icons.local_fire_department,
                    backgroundColor: ProgressColors.lightBlue,
                    textColor: ProgressColors.primaryBlue,
                  ),
                ),
              ],
            ),
            
            // Weekly Activity Chart
            const SizedBox(height: 24),
            const Text(
              'Weekly Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ProgressColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ProgressColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ProgressColors.greyLight, width: 1),
                ),
                child: _buildWorkoutChart(workoutHistory),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent Workouts
            const Text(
              'Recent Workouts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ProgressColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            
            if (workoutHistory.isNotEmpty)
              ...workoutHistory.take(5).map((workout) => _buildRecentWorkoutItem(workout))
            else
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No workouts yet.\nComplete your first workout to see progress',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ProgressColors.greyDark),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutChart(List<Map<String, dynamic>> workoutHistory) {
    final List<FlSpot> spots = [];
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final workoutsOnDay = workoutHistory.where((w) {
        try {
          final workoutDate = DateTime.parse(w['date']);
          return workoutDate.year == date.year &&
                 workoutDate.month == date.month &&
                 workoutDate.day == date.day &&
                 w['is_completed'] == true;
        } catch (e) {
          return false;
        }
      }).length;
      spots.add(FlSpot(i.toDouble(), workoutsOnDay.toDouble()));
    }

    final double maxY = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final double yMax = maxY > 0 ? maxY + 1 : 5;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: ProgressColors.greyLight, strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11, color: ProgressColors.greyDark),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < 7) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      weekdays[value.toInt()],
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ProgressColors.greyDark),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 35,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: ProgressColors.primaryBlue,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: ProgressColors.primaryBlue,
                  strokeWidth: 2,
                  strokeColor: ProgressColors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: ProgressColors.primaryBlue.withOpacity(0.1),
            ),
          ),
        ],
        maxY: yMax,
        minY: 0,
      ),
    );
  }

  Widget _buildRecentWorkoutItem(Map<String, dynamic> workout) {
    final date = DateTime.parse(workout['date']);
    final exercises = workout['exercises'] as List? ?? [];
    final isCompleted = workout['is_completed'] == true;
    final duration = workout['duration'];
    final calories = workout['calories_burned'];
    final durationInt = duration != null ? (duration is int ? duration : (duration as num).toInt()) : 0;
    final caloriesInt = calories != null ? (calories is int ? calories : (calories as num).toInt()) : 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ProgressColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProgressColors.greyLight, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompleted ? ProgressColors.lightBlue : ProgressColors.greyLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.fitness_center,
              color: isCompleted ? ProgressColors.primaryBlue : ProgressColors.greyDark,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? ProgressColors.primaryBlue : ProgressColors.greyDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercises.length} exercises   $durationInt min   $caloriesInt cal',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? ProgressColors.greyDark : ProgressColors.greyMedium,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: ProgressColors.lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ProgressColors.primaryBlue),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealTab() {
    return Consumer2<MealProvider, ProgressProvider>(
      builder: (context, mealProvider, progressProvider, child) {
        final weeklySummary = mealProvider.weeklySummary;
        final mealsByDay = weeklySummary?['meals_by_day'] ?? {};
        final totalMeals = weeklySummary?['total_meals_completed'] ?? 0;
        final mealPlan = mealProvider.currentMealPlan;
        
        List<Map<String, dynamic>> recentMeals = [];
        if (mealPlan != null && mealPlan['meals'] != null) {
          final meals = mealPlan['meals'] as Map<String, dynamic>;
          final days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY'];
          final today = DateTime.now().weekday;
          final todayName = _getTodayName().toUpperCase();
          
          if (meals[todayName] != null) {
            final dayMeals = meals[todayName] as Map<String, dynamic>;
            dayMeals.forEach((mealType, mealData) {
              recentMeals.add({
                'date': 'Today',
                'dateOrder': 0,
                'meal_type': mealType,
                'name': mealData['name'],
                'calories': mealData['calories'],
                'completed': mealData['completed'] ?? false,
                'log_id': mealData['log_id'],
                'meal_item_id': mealData['id'],
              });
            });
          }
          
          for (int i = 1; i < 7; i++) {
            final dayIndex = (today - 1 - i) % 7;
            if (dayIndex >= 0) {
              final day = days[dayIndex];
              if (meals[day] != null) {
                final dayMeals = meals[day] as Map<String, dynamic>;
                final date = _getDateFromDayIndex(dayIndex);
                dayMeals.forEach((mealType, mealData) {
                  recentMeals.add({
                    'date': date,
                    'dateOrder': i,
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
        }
        
        final todaysMeals = mealProvider.todaysMeals;
        if (todaysMeals.isNotEmpty) {
          for (var entry in todaysMeals.entries) {
            final mealType = entry.key;
            final mealData = entry.value as Map<String, dynamic>;
            final alreadyAdded = recentMeals.any((m) => m['meal_type'] == mealType && m['date'] == 'Today');
            if (!alreadyAdded && mealData['name'] != null) {
              recentMeals.add({
                'date': 'Today',
                'dateOrder': 0,
                'meal_type': mealType,
                'name': mealData['name'],
                'calories': mealData['calories'] ?? 0,
                'completed': mealData['completed'] ?? false,
                'log_id': mealData['log_id'],
                'meal_item_id': mealData['meal_item_id'],
              });
            }
          }
        }
        
        recentMeals.sort((a, b) {
          if (a['dateOrder'] != b['dateOrder']) {
            return a['dateOrder'].compareTo(b['dateOrder']);
          }
          if (a['completed'] != b['completed']) {
            return a['completed'] ? 1 : -1;
          }
          return 0;
        });
        
        final todayName = _getTodayName();
        final todayMealCount = mealsByDay[todayName] ?? 0;
        final totalPossibleMeals = 35;
        final actualCompletionRate = totalPossibleMeals > 0 ? (totalMeals / totalPossibleMeals * 100).toInt() : 0;
        
        final List<BarChartGroupData> barData = [];
        const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        
        double maxMeals = 0;
        for (int i = 0; i < weekdays.length; i++) {
          final day = weekdays[i];
          final count = mealsByDay[day]?.toDouble() ?? 0.0;
          if (count > maxMeals) maxMeals = count;
        }
        maxMeals = maxMeals > 0 ? maxMeals + 1 : 7;
        
        for (int i = 0; i < weekdays.length; i++) {
          final day = weekdays[i];
          final count = mealsByDay[day]?.toDouble() ?? 0.0;
          barData.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: count > 0 ? ProgressColors.primaryBlue : ProgressColors.greyLight,
                  width: 30,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
              barsSpace: 8,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Meals Logged',
                    value: '$totalMeals',
                    subtitle: 'this week',
                    icon: Icons.restaurant,
                    backgroundColor: totalMeals > 0 ? ProgressColors.lightBlue : ProgressColors.greyLight,
                    textColor: totalMeals > 0 ? ProgressColors.primaryBlue : ProgressColors.greyDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Completion Rate',
                    value: '$actualCompletionRate%',
                    subtitle: 'of $totalPossibleMeals meals',
                    icon: Icons.percent,
                    backgroundColor: actualCompletionRate > 50 ? ProgressColors.lightBlue : ProgressColors.greyLight,
                    textColor: actualCompletionRate > 50 ? ProgressColors.primaryBlue : ProgressColors.greyDark,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Today's progress card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ProgressColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ProgressColors.lightBlue, width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ProgressColors.lightBlue,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.today,
                      color: ProgressColors.primaryBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today\'s Progress',
                          style: TextStyle(
                            fontSize: 14,
                            color: ProgressColors.primaryBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$todayMealCount meals logged',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: ProgressColors.primaryBlue,
                          ),
                        ),
                        const Text(
                          'Goal: 5 meals per day',
                          style: TextStyle(
                            fontSize: 11,
                            color: ProgressColors.greyDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (todayMealCount < 5)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ProgressColors.softYellow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${5 - todayMealCount} left',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ProgressColors.darkYellow,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: ProgressColors.lightBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 14, color: ProgressColors.primaryBlue),
                          SizedBox(width: 4),
                          Text(
                            'Complete',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: ProgressColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Weekly Meal Chart
            const Text(
              'Weekly Meal Logging',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ProgressColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Meals logged per day (Target: 5 meals per day)',
              style: TextStyle(fontSize: 12, color: ProgressColors.greyDark),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 280,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ProgressColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ProgressColors.greyLight, width: 1),
                ),
                child: mealsByDay.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant, size: 48, color: ProgressColors.greyMedium),
                            SizedBox(height: 16),
                            Text(
                              'No meals logged yet',
                              style: TextStyle(color: ProgressColors.greyDark),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Log your first meal to see the chart',
                              style: TextStyle(fontSize: 12, color: ProgressColors.greyDark),
                            ),
                          ],
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: maxMeals,
                          barGroups: barData,
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(fontSize: 11, color: ProgressColors.greyDark),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < weekdays.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        weekdays[value.toInt()].substring(0, 3),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ProgressColors.greyDark),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                                reservedSize: 35,
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(
                            show: true,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(color: ProgressColors.greyLight, strokeWidth: 1);
                            },
                          ),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${rod.toY.toInt()} meals',
                                  const TextStyle(color: ProgressColors.white),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: ProgressColors.primaryBlue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Meals Logged', style: TextStyle(fontSize: 11, color: ProgressColors.greyDark)),
                const SizedBox(width: 20),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: ProgressColors.greyLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 6),
                const Text('No Meals', style: TextStyle(fontSize: 11, color: ProgressColors.greyDark)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Recent Meals section
            if (recentMeals.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meals to Log',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ProgressColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recentMeals.take(10).map((meal) => _buildRecentMealItem(meal, mealProvider)),
                ],
              ),
            
            const SizedBox(height: 16),
            
            // Tip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ProgressColors.lightBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline, color: ProgressColors.primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      totalMeals > 0 
                        ? 'Great job logging $totalMeals meals this week Keep tracking to reach your nutrition goals'
                        : 'Logging all your meals helps track nutrition and reach your goals faster',
                      style: const TextStyle(color: ProgressColors.primaryBlue, fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getDateFromDayIndex(int dayIndex) {
    final now = DateTime.now();
    final targetDate = now.subtract(Duration(days: (now.weekday - 1 - dayIndex) % 7));
    final difference = now.difference(targetDate).inDays;
    
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${targetDate.day}/${targetDate.month}';
  }

  Widget _buildRecentMealItem(Map<String, dynamic> meal, MealProvider mealProvider) {
    final isCompleted = meal['completed'] == true;
    final date = meal['date'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ProgressColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCompleted ? ProgressColors.lightBlue : ProgressColors.greyLight, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCompleted ? ProgressColors.lightBlue : ProgressColors.greyLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getMealIcon(meal['meal_type']),
            color: isCompleted ? ProgressColors.primaryBlue : ProgressColors.greyDark,
            size: 22,
          ),
        ),
        title: Text(
          meal['name'] ?? 'Meal',
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? ProgressColors.greyDark : ProgressColors.darkBlue,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              _formatMealType(meal['meal_type']),
              style: const TextStyle(fontSize: 11, color: ProgressColors.greyDark),
            ),
            Text(
              '${meal['calories']} cal   $date',
              style: const TextStyle(fontSize: 10, color: ProgressColors.greyMedium),
            ),
          ],
        ),
        trailing: isCompleted
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ProgressColors.lightBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Logged',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ProgressColors.primaryBlue),
                ),
              )
            : ElevatedButton(
                onPressed: () => _logMealFromProgress(meal, mealProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProgressColors.accentYellow,
                  foregroundColor: ProgressColors.darkBlue,
                  minimumSize: const Size(60, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: const Text('Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
      ),
    );
  }

  Future<void> _logMealFromProgress(Map<String, dynamic> meal, MealProvider mealProvider) async {
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Meal',
          style: TextStyle(color: ProgressColors.primaryBlue),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mark "${meal['name']}" as completed?',
              style: const TextStyle(color: ProgressColors.greyDark),
            ),
            const SizedBox(height: 8),
            Text(
              '${meal['calories']} calories',
              style: const TextStyle(color: ProgressColors.greyMedium),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: ProgressColors.greyMedium)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ProgressColors.accentYellow,
              foregroundColor: ProgressColors.darkBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Log Meal'),
          ),
        ],
      ),
    );
    
    if (result == true && mounted) {
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
              content: Text('Meal logged successfully'),
              backgroundColor: ProgressColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to log meal: $e'),
              backgroundColor: ProgressColors.error,
            ),
          );
        }
      }
    }
  }

  Widget _buildBodyTab() {
    return Consumer2<AuthProvider, ProgressProvider>(
      builder: (context, authProvider, progressProvider, child) {
        final user = authProvider.currentUser;
        final hasMeasurements = (user?['height'] != null && user?['weight'] != null);
        final height = user?['height'] ?? 0.0;
        final weight = user?['weight'] ?? 0.0;
        
        String bmi = '0';
        String bmiCategory = 'Normal';
        Color bmiColor = ProgressColors.primaryBlue;
        
        if (height > 0 && weight > 0) {
          bmi = (weight / ((height / 100) * (height / 100))).toStringAsFixed(1);
          final bmiValue = double.parse(bmi);
          if (bmiValue < 18.5) {
            bmiCategory = 'Underweight';
            bmiColor = ProgressColors.darkYellow;
          } else if (bmiValue >= 25 && bmiValue < 30) {
            bmiCategory = 'Overweight';
            bmiColor = ProgressColors.darkYellow;
          } else if (bmiValue >= 30) {
            bmiCategory = 'Obese';
            bmiColor = ProgressColors.error;
          } else {
            bmiCategory = 'Normal';
            bmiColor = ProgressColors.success;
          }
        }

        if (!hasMeasurements) {
          return _buildAddMeasurementsPrompt(authProvider);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Current Weight',
                    value: '$weight kg',
                    icon: Icons.monitor_weight,
                    backgroundColor: ProgressColors.lightBlue,
                    textColor: ProgressColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Height',
                    value: '$height cm',
                    icon: Icons.height,
                    backgroundColor: ProgressColors.lightBlue,
                    textColor: ProgressColors.primaryBlue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'BMI',
                    value: bmi,
                    subtitle: bmiCategory,
                    icon: Icons.calculate,
                    backgroundColor: bmiColor.withOpacity(0.1),
                    textColor: bmiColor,
                    iconColor: bmiColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Consistency',
                    value: '${(progressProvider.consistencyScore * 100).toInt()}%',
                    subtitle: 'workout consistency',
                    icon: Icons.trending_up,
                    backgroundColor: ProgressColors.softYellow,
                    textColor: ProgressColors.darkYellow,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Update measurements button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ProgressColors.lightBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Track More Measurements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ProgressColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add body fat, muscle mass, and more to track your progress',
                    style: TextStyle(fontSize: 12, color: ProgressColors.primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showAddMeasurementDialog(context, authProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ProgressColors.accentYellow,
                        foregroundColor: ProgressColors.darkBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: const Text('Update Measurements', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddMeasurementsPrompt(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: ProgressColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProgressColors.lightBlue, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: ProgressColors.lightBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.fitness_center, size: 40, color: ProgressColors.primaryBlue),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add Your Body Measurements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: ProgressColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your height and weight to calculate BMI and track your progress',
            style: TextStyle(color: ProgressColors.greyDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showAddMeasurementDialog(context, authProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: ProgressColors.accentYellow,
                foregroundColor: ProgressColors.darkBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: const Text('Add Measurements', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMeasurementDialog(BuildContext context, AuthProvider authProvider) async {
    final heightController = TextEditingController(text: authProvider.currentUser?['height']?.toString() ?? '');
    final weightController = TextEditingController(text: authProvider.currentUser?['weight']?.toString() ?? '');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Body Measurements',
          style: TextStyle(color: ProgressColors.primaryBlue),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                hintText: 'Enter your height in cm',
                prefixIcon: Icon(Icons.height, color: ProgressColors.primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: 'Enter your weight in kg',
                prefixIcon: Icon(Icons.monitor_weight, color: ProgressColors.primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: ProgressColors.greyMedium)),
          ),
          ElevatedButton(
            onPressed: () async {
              final height = double.tryParse(heightController.text);
              final weight = double.tryParse(weightController.text);
              
              if (height != null && weight != null && height > 0 && weight > 0) {
                try {
                  await authProvider.updateProfile({'height': height, 'weight': weight});
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Measurements updated successfully'),
                        backgroundColor: ProgressColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e'), backgroundColor: ProgressColors.error),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid height and weight'),
                    backgroundColor: ProgressColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ProgressColors.accentYellow,
              foregroundColor: ProgressColors.darkBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getTodayName() {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final todayIndex = DateTime.now().weekday - 1;
    return weekdays[todayIndex];
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.toUpperCase()) {
      case 'BREAKFAST':
        return Icons.free_breakfast;
      case 'LUNCH':
        return Icons.lunch_dining;
      case 'DINNER':
        return Icons.dinner_dining;
      case 'SNACK':
      case 'SNACK_2':
        return Icons.cake;
      default:
        return Icons.restaurant;
    }
  }

  String _formatMealType(String mealType) {
    switch (mealType.toUpperCase()) {
      case 'BREAKFAST':
        return 'Breakfast';
      case 'LUNCH':
        return 'Lunch';
      case 'DINNER':
        return 'Dinner';
      case 'SNACK':
        return 'Snack';
      case 'SNACK_2':
        return 'Afternoon Snack';
      default:
        return mealType;
    }
  }
}