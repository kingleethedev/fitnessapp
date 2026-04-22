// lib/screens/profile/workout_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    await workoutProvider.loadWorkoutHistory(limit: 100);
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final history = workoutProvider.workoutHistory;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: history.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fitness_center, size: 64, color: AppColors.greyDark),
                    SizedBox(height: 16),
                    Text(
                      'No workouts yet',
                      style: TextStyle(color: AppColors.greyDark),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Complete your first workout to see it here',
                      style: TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final workout = history[index];
                  return _buildWorkoutCard(workout);
                },
              ),
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final date = DateTime.parse(workout['date']);
    final exercises = workout['exercises'] as List;
    final isCompleted = workout['is_completed'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.lightBlue : AppColors.greyLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? AppColors.blue : AppColors.greyDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted ? AppColors.success : AppColors.warning,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'In Progress',
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
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, size: 16, color: AppColors.greyDark),
                    const SizedBox(width: 4),
                    Text(
                      '${workout['duration']} minutes',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.fitness_center, size: 16, color: AppColors.greyDark),
                    const SizedBox(width: 4),
                    Text(
                      '${exercises.length} exercises',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...exercises.take(3).map((exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercise['name'],
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        exercise.containsKey('reps')
                            ? '${exercise['reps']} reps'
                            : '${exercise['duration']} sec',
                        style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                      ),
                    ],
                  ),
                )),
                if (exercises.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+ ${exercises.length - 3} more exercises',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}