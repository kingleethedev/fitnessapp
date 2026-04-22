import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  const WorkoutExecutionScreen({super.key});

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  int _currentExerciseIndex = 0;
  int _remainingTime = 0;
  Timer? _timer;
  bool _isResting = false;
  bool _isPaused = false;
  final List<Map<String, dynamic>> _exerciseLogs = [];
  int _completedExercises = 0;

  @override
  void initState() {
    super.initState();
    _debugWorkoutData();
    _startCurrentExercise();
  }

  void _debugWorkoutData() {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final workout = workoutProvider.currentWorkout;
    print('📋 Workout data: $workout');
    print('📋 Workout keys: ${workout?.keys}');
    print('📋 Workout ID: ${workout?['workout_id']}');
    print('📋 Workout ID alt: ${workout?['id']}');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCurrentExercise() {
    final workout = Provider.of<WorkoutProvider>(context, listen: false).currentWorkout;
    if (workout != null && _currentExerciseIndex < (workout['exercises'] as List).length) {
      final exercise = workout['exercises'][_currentExerciseIndex];
      
      if (exercise.containsKey('duration') && exercise['duration'] != null) {
        setState(() {
          _remainingTime = exercise['duration'];
          _isResting = false;
          _isPaused = false;
        });
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else if (!_isPaused && _remainingTime == 0) {
        if (!_isResting) {
          _completeExercise();
        } else {
          _nextExercise();
        }
        timer.cancel();
      }
    });
  }

  void _completeExercise() {
    final workout = Provider.of<WorkoutProvider>(context, listen: false).currentWorkout;
    final exercise = workout!['exercises'][_currentExerciseIndex];
    
    _exerciseLogs.add({
      'exercise_name': exercise['name'],
      'target_reps': exercise['reps'],
      'actual_reps': exercise['reps'],
      'target_duration': exercise['duration'],
      'actual_duration': exercise['duration'],
      'completed': true,
      'difficulty_rating': 3,
    });
    
    setState(() {
      _completedExercises++;
    });
    
    // Check if rest period is needed
    if (exercise.containsKey('rest') && exercise['rest'] != null && exercise['rest'] > 0) {
      setState(() {
        _isResting = true;
        _remainingTime = exercise['rest'];
      });
      _startTimer();
    } else {
      _nextExercise();
    }
  }

  void _nextExercise() {
    final workout = Provider.of<WorkoutProvider>(context, listen: false).currentWorkout;
    final exercises = workout!['exercises'] as List;
    
    if (_currentExerciseIndex + 1 < exercises.length) {
      setState(() {
        _currentExerciseIndex++;
        _isResting = false;
        _isPaused = false;
      });
      _startCurrentExercise();
    } else {
      _finishWorkout();
    }
  }

  Future<void> _finishWorkout() async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final workout = workoutProvider.currentWorkout;
    
    print('📋 Finishing workout: $workout');
    
    if (workout == null) {
      print('❌ Workout is null');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Workout data not found'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    // Try multiple possible ID fields
    final workoutId = workout['workout_id'] ?? workout['id'];
    
    print('📋 Extracted workout ID: $workoutId');
    
    if (workoutId == null) {
      print('❌ No workout ID found. Available keys: ${workout.keys}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Workout ID not found'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    final duration = workout['duration'] ?? 30;
    final timeSpent = duration - (_remainingTime ~/ 60);
    
    final completeData = {
      'workout_id': workoutId.toString(),
      'completed': true,
      'time_taken': timeSpent > 0 ? timeSpent : duration,
      'satisfaction_rating': 4,
      'logs': _exerciseLogs,
    };
    
    print('📤 Sending completion data: $completeData');
    
    try {
      final response = await workoutProvider.completeWorkout(completeData);
      print('✅ Workout completed successfully: $response');
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Workout completed! +${response['calories_burned'] ?? 0} calories burned'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Navigate to completion screen
        Navigator.pushReplacementNamed(context, '/workout-complete');
      }
    } catch (e) {
      print('❌ Error completing workout: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (!_isPaused && _remainingTime > 0) {
      _startTimer();
    }
  }

  void _skipExercise() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip Exercise'),
        content: const Text('Are you sure you want to skip this exercise?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _nextExercise();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workout = workoutProvider.currentWorkout;
    
    if (workout == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final exercises = workout['exercises'] as List;
    final currentExercise = exercises[_currentExerciseIndex];
    final progress = (_currentExerciseIndex + 1) / exercises.length;
    final isExerciseCompleted = _exerciseLogs.any((log) => log['exercise_name'] == currentExercise['name']);
    
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.greyLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.yellow),
              minHeight: 4,
            ),
            
            // Header with controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exercise ${_currentExerciseIndex + 1} of ${exercises.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.greyDark,
                    ),
                  ),
                  Row(
                    children: [
                      // Timer-based exercises show pause button
                      if (currentExercise.containsKey('duration') && currentExercise['duration'] != null)
                        IconButton(
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          onPressed: _togglePause,
                          color: AppColors.blue,
                        ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: _skipExercise,
                        color: AppColors.error,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: AppColors.greyDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Exercise name
                    Text(
                      currentExercise['name'],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Rest indicator
                    if (_isResting)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'REST',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 48),
                    
                    // Exercise details
                    if (currentExercise.containsKey('reps') && currentExercise['reps'] != null)
                      Column(
                        children: [
                          const Text(
                            'Target Reps',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.greyDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${currentExercise['reps']}',
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: AppColors.blue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isExerciseCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    
                    if (currentExercise.containsKey('duration') && currentExercise['duration'] != null)
                      Column(
                        children: [
                          Text(
                            _isResting ? 'Rest Time' : 'Time Remaining',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.greyDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTime(_remainingTime),
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: _isResting ? AppColors.yellow : AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 48),
                    
                    // Exercise tip/instruction
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _getExerciseIcon(currentExercise['name']),
                            size: 32,
                            color: AppColors.blue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getExerciseTip(currentExercise['name']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.blue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Complete button (for rep-based exercises not yet completed)
                    if (!_isResting && 
                        currentExercise.containsKey('reps') && 
                        currentExercise['reps'] != null && 
                        !isExerciseCompleted)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _completeExercise,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Complete Exercise'),
                        ),
                      ),
                    
                    // Next button (for completed exercises)
                    if (!_isResting && isExerciseCompleted)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _nextExercise,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentExerciseIndex + 1 == exercises.length ? 'Finish Workout' : 'Next Exercise',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  IconData _getExerciseIcon(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('push')) return Icons.fitness_center;
    if (name.contains('squat')) return Icons.accessibility_new;
    if (name.contains('plank')) return Icons.table_rows;
    if (name.contains('lunge')) return Icons.directions_walk;
    if (name.contains('jump')) return Icons.flash_on;
    return Icons.fitness_center;
  }

  String _getExerciseTip(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('push')) return 'Keep your back straight and lower your chest to the ground';
    if (name.contains('squat')) return 'Keep your chest up and knees behind your toes';
    if (name.contains('plank')) return 'Keep your body in a straight line from head to toes';
    if (name.contains('lunge')) return 'Keep your front knee at a 90-degree angle';
    if (name.contains('jump')) return 'Land softly on the balls of your feet';
    return 'Focus on proper form and controlled movements';
  }
}