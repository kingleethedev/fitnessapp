// lib/screens/profile/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/colors.dart';
import '../../providers/progress_provider.dart';
import '../../providers/workout_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    
    await Future.wait([
      progressProvider.loadWorkoutStats(),
      workoutProvider.loadWorkoutHistory(limit: 100),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workoutStats = progressProvider.workoutStats;
    final workoutHistory = workoutProvider.workoutHistory;
    
    // Calculate statistics
    final totalWorkouts = workoutStats?['summary']?['total_workouts'] ?? 0;
    final totalMinutes = workoutStats?['summary']?['total_minutes'] ?? 0;
    final totalCalories = workoutStats?['summary']?['total_calories'] ?? 0;
    final avgDuration = totalWorkouts > 0 ? totalMinutes / totalWorkouts : 0;
    final avgCaloriesPerWorkout = totalWorkouts > 0 ? totalCalories / totalWorkouts : 0;
    
    // Favorite exercise
    Map<String, int> exerciseCount = {};
    for (var workout in workoutHistory) {
      final exercises = workout['exercises'] as List;
      for (var exercise in exercises) {
        final name = exercise['name'];
        exerciseCount[name] = (exerciseCount[name] ?? 0) + 1;
      }
    }
    final favoriteExercise = exerciseCount.entries.isEmpty
        ? 'None'
        : exerciseCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    // Workout times (morning, afternoon, evening) - mock data for now
    final workoutTimes = {'Morning': 35, 'Afternoon': 45, 'Evening': 20};

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Stats
              const Text(
                'Overall Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildStatRow('Total Workouts', totalWorkouts.toString()),
                    const Divider(),
                    _buildStatRow('Total Minutes', totalMinutes.toString()),
                    const Divider(),
                    _buildStatRow('Total Calories', totalCalories.toString()),
                    const Divider(),
                    _buildStatRow('Avg Duration', '${avgDuration.toInt()} min'),
                    const Divider(),
                    _buildStatRow('Avg Calories/Workout', avgCaloriesPerWorkout.toInt().toString()),
                    const Divider(),
                    _buildStatRow('Favorite Exercise', favoriteExercise),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Workout Time Distribution
              const Text(
                'Workout Time Distribution',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.greyMedium),
                ),
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(
                        value: workoutTimes['Morning']?.toDouble() ?? 0,
                        title: 'Morning',
                        color: AppColors.blue,
                        radius: 60,
                        titleStyle: const TextStyle(color: AppColors.white),
                      ),
                      PieChartSectionData(
                        value: workoutTimes['Afternoon']?.toDouble() ?? 0,
                        title: 'Afternoon',
                        color: AppColors.yellow,
                        radius: 60,
                        titleStyle: const TextStyle(color: AppColors.white),
                      ),
                      PieChartSectionData(
                        value: workoutTimes['Evening']?.toDouble() ?? 0,
                        title: 'Evening',
                        color: AppColors.success,
                        radius: 60,
                        titleStyle: const TextStyle(color: AppColors.white),
                      ),
                    ],
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Achievements
              const Text(
                'Achievements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildAchievementCard(
                    'First Workout',
                    totalWorkouts >= 1,
                    Icons.fitness_center,
                  ),
                  _buildAchievementCard(
                    '10 Workouts',
                    totalWorkouts >= 10,
                    Icons.star,
                  ),
                  _buildAchievementCard(
                    '50 Workouts',
                    totalWorkouts >= 50,
                    Icons.workspace_premium,
                  ),
                  _buildAchievementCard(
                    '100 Workouts',
                    totalWorkouts >= 100,
                    Icons.emoji_events,
                  ),
                  _buildAchievementCard(
                    '7 Day Streak',
                    progressProvider.streakDays >= 7,
                    Icons.local_fire_department,
                  ),
                  _buildAchievementCard(
                    '30 Day Streak',
                    progressProvider.streakDays >= 30,
                    Icons.whatshot,
                  ),
                  _buildAchievementCard(
                    'Perfect Week',
                    progressProvider.weeklyWorkouts >= 5,
                    Icons.weekend,
                  ),
                  _buildAchievementCard(
                    'Early Bird',
                    false, // Can be implemented with workout time tracking
                    Icons.wb_sunny,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
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

  Widget _buildAchievementCard(String title, bool achieved, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: achieved ? AppColors.lightBlue : AppColors.greyLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achieved ? AppColors.blue : AppColors.greyMedium,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: achieved ? AppColors.blue : AppColors.greyDark,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: achieved ? AppColors.blue : AppColors.greyDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Icon(
            achieved ? Icons.check_circle : Icons.lock_outline,
            size: 16,
            color: achieved ? AppColors.success : AppColors.greyDark,
          ),
        ],
      ),
    );
  }
}