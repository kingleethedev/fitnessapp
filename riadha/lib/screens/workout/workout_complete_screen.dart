// workout_complete_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/colors.dart';
import '../../providers/progress_provider.dart';

// Modern color palette - Light Blue, Yellow, White only
class CompleteColors {
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
}

class WorkoutCompleteScreen extends StatelessWidget {
  const WorkoutCompleteScreen({super.key});

  String _getStreakMessage(int streakDays) {
    if (streakDays == 1) {
      return 'Great start Keep it going tomorrow';
    } else if (streakDays < 3) {
      return 'You are building momentum Stay consistent';
    } else if (streakDays < 7) {
      return 'Excellent consistency You are on fire';
    } else if (streakDays < 14) {
      return 'Amazing discipline This is impressive';
    } else if (streakDays < 30) {
      return 'Unstoppable You are building a powerful habit';
    } else {
      return 'Legendary streak You are an inspiration';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressProvider = Provider.of<ProgressProvider>(context);
    final workoutStats = progressProvider.workoutStats;
    
    // Get the actual workout stats from the completed workout
    final Map<String, dynamic> workoutStatsData = {
      'time': workoutStats?['summary']?['last_workout_duration'] ?? '28',
      'exercises': workoutStats?['summary']?['last_workout_exercises'] ?? '8',
      'calories': workoutStats?['summary']?['last_workout_calories'] ?? '240',
    };
    
    // Get the updated streak from the progress provider
    final streakDays = progressProvider.streakDays;
    final isNewStreak = streakDays == 1;
    
    return Scaffold(
      backgroundColor: CompleteColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              // Success icon - flat design
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: CompleteColors.lightBlue,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.check,
                  size: 44,
                  color: CompleteColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              const Text(
                'Workout Complete',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: CompleteColors.primaryBlue,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                isNewStreak ? 'You started your streak' : 'Keep pushing forward',
                style: const TextStyle(
                  fontSize: 13,
                  color: CompleteColors.greyDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Stats card - flat design
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CompleteColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CompleteColors.lightBlue, width: 1.5),
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                      icon: Icons.timer_outlined,
                      label: 'Time',
                      value: '${workoutStatsData['time']} minutes',
                    ),
                    const SizedBox(height: 12),
                    _buildDivider(),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      icon: Icons.fitness_center,
                      label: 'Exercises',
                      value: '${workoutStatsData['exercises']} completed',
                    ),
                    const SizedBox(height: 12),
                    _buildDivider(),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      icon: Icons.local_fire_department,
                      label: 'Streak',
                      value: '$streakDays day${streakDays != 1 ? 's' : ''}',
                      highlight: streakDays >= 3,
                    ),
                    const SizedBox(height: 12),
                    _buildDivider(),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      icon: Icons.bolt,
                      label: 'Calories',
                      value: '${workoutStatsData['calories']} burned',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Streak message
              if (streakDays > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: streakDays >= 3 ? CompleteColors.softYellow : CompleteColors.lightBlue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: streakDays >= 3 ? CompleteColors.darkYellow : CompleteColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getStreakMessage(streakDays),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: streakDays >= 3 ? CompleteColors.darkYellow : CompleteColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Done button - yellow accent
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CompleteColors.accentYellow,
                    foregroundColor: CompleteColors.darkBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Share button - outline
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Share.share(
                      'I just completed my workout with Riadha\n'
                      '${workoutStatsData['time']} minutes  ${workoutStatsData['exercises']} exercises  ${workoutStatsData['calories']} calories burned\n'
                      'Current streak: $streakDays day${streakDays != 1 ? 's' : ''}'
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CompleteColors.primaryBlue,
                    side: const BorderSide(color: CompleteColors.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Share Progress',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Motivational message
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: CompleteColors.lightBlue,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  streakDays >= 3 
                      ? 'Amazing consistency  You are on fire'
                      : 'One step closer to your goal',
                  style: const TextStyle(
                    fontSize: 11,
                    color: CompleteColors.primaryBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: highlight ? CompleteColors.softYellow : CompleteColors.lightBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: highlight ? CompleteColors.darkYellow : CompleteColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: CompleteColors.greyDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: highlight ? CompleteColors.darkYellow : CompleteColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: CompleteColors.greyLight,
    );
  }
}