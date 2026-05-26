// lib/screens/profile/workout_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';

// Modern color palette - Light Blue, Yellow, White only
class WorkoutHistoryColors {
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
  static const Color warning = Color(0xFFFFD633);
}

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
      await workoutProvider.loadWorkoutHistory(limit: 100);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load history: $e'),
            backgroundColor: WorkoutHistoryColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final history = workoutProvider.workoutHistory;

    return Scaffold(
      backgroundColor: WorkoutHistoryColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Workout History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: WorkoutHistoryColors.primaryBlue,
          ),
        ),
        backgroundColor: WorkoutHistoryColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: WorkoutHistoryColors.primaryBlue),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: WorkoutHistoryColors.primaryBlue,
        backgroundColor: WorkoutHistoryColors.white,
        child: _isLoading && history.isEmpty
            ? const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(WorkoutHistoryColors.accentYellow),
                  ),
                ),
              )
            : history.isEmpty
                ? _buildEmptyState()
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: WorkoutHistoryColors.lightBlue,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.fitness_center,
              size: 50,
              color: WorkoutHistoryColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Workouts Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: WorkoutHistoryColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete your first workout to see it here',
            style: TextStyle(
              fontSize: 14,
              color: WorkoutHistoryColors.greyDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final date = DateTime.parse(workout['date']);
    final exercises = workout['exercises'] as List;
    final isCompleted = workout['is_completed'] == true;
    final duration = workout['duration'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: WorkoutHistoryColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkoutHistoryColors.greyLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? WorkoutHistoryColors.lightBlue : WorkoutHistoryColors.softYellow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: WorkoutHistoryColors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isCompleted ? WorkoutHistoryColors.primaryBlue : WorkoutHistoryColors.darkYellow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatDate(date),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCompleted ? WorkoutHistoryColors.primaryBlue : WorkoutHistoryColors.darkYellow,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCompleted ? WorkoutHistoryColors.primaryBlue : WorkoutHistoryColors.accentYellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'In Progress',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? WorkoutHistoryColors.white : WorkoutHistoryColors.darkBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                Row(
                  children: [
                    _buildInfoChip(
                      icon: Icons.timer_outlined,
                      label: '$duration min',
                      color: WorkoutHistoryColors.greyDark,
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      icon: Icons.fitness_center,
                      label: '${exercises.length} exercises',
                      color: WorkoutHistoryColors.greyDark,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Exercise list
                const Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WorkoutHistoryColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 8),
                
                ...exercises.take(3).map((exercise) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: WorkoutHistoryColors.primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          exercise['name'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: WorkoutHistoryColors.darkBlue,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: WorkoutHistoryColors.lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          exercise.containsKey('reps')
                              ? '${exercise['reps']} reps'
                              : '${exercise['duration']} sec',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: WorkoutHistoryColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                
                if (exercises.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${exercises.length - 3} more exercises',
                      style: const TextStyle(
                        fontSize: 11,
                        color: WorkoutHistoryColors.greyMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WorkoutHistoryColors.greyLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDate = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(workoutDate).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }
}