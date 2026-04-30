import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Exercise Image
                      _buildExerciseImage(currentExercise),
                      
                      const SizedBox(height: 24),
                      
                      // Exercise name
                      Text(
                        currentExercise['name'],
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
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
                      
                      const SizedBox(height: 32),
                      
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
                      
                      const SizedBox(height: 32),
                      
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
                      
                      const SizedBox(height: 24),
                      
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseImage(Map<String, dynamic> exercise) {
    final String exerciseName = exercise['name'].toLowerCase();
    final String? imageUrl = exercise['image_url'];
    
    // If there's a custom image URL provided, use it
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.greyLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => _buildDefaultExerciseImage(exerciseName),
        ),
      );
    }
    
    // Otherwise use default image based on exercise type
    return _buildDefaultExerciseImage(exerciseName);
  }

  Widget _buildDefaultExerciseImage(String exerciseName) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.blue.withOpacity(0.1),
            AppColors.lightBlue.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blue.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getExerciseIcon(exerciseName),
            size: 80,
            color: AppColors.blue.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            _getExerciseCategory(exerciseName),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.blue.withOpacity(0.6),
            ),
          ),
        ],
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
    if (name.contains('push') || name.contains('press')) return Icons.fitness_center;
    if (name.contains('squat')) return Icons.accessibility_new;
    if (name.contains('plank')) return Icons.table_rows;
    if (name.contains('lunge')) return Icons.directions_walk;
    if (name.contains('jump') || name.contains('box')) return Icons.flash_on;
    if (name.contains('pull') || name.contains('row')) return Icons.fitness_center;
    if (name.contains('curl')) return Icons.fitness_center;
    if (name.contains('crunch') || name.contains('sit')) return Icons.fitness_center;
    if (name.contains('run') || name.contains('cardio')) return Icons.directions_run;
    if (name.contains('stretch') || name.contains('yoga')) return Icons.self_improvement;
    return Icons.fitness_center;
  }

  String _getExerciseCategory(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('push') || name.contains('press')) return 'Chest & Shoulders';
    if (name.contains('pull') || name.contains('row')) return 'Back & Biceps';
    if (name.contains('squat') || name.contains('leg')) return 'Legs & Glutes';
    if (name.contains('core') || name.contains('plank') || name.contains('crunch')) return 'Core Workout';
    if (name.contains('cardio') || name.contains('run') || name.contains('jump')) return 'Cardio Exercise';
    if (name.contains('stretch') || name.contains('yoga')) return 'Flexibility';
    return 'Strength Training';
  }

  String _getExerciseTip(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('push')) return 'Keep your back straight and lower your chest to the ground. Inhale down, exhale up.';
    if (name.contains('press')) return 'Keep your core tight and press through your palms. Maintain a straight line from head to knees.';
    if (name.contains('squat')) return 'Keep your chest up, knees behind toes, and weight in your heels. Go as low as comfortable.';
    if (name.contains('plank')) return 'Keep your body in a straight line from head to toes. Engage your core and glutes.';
    if (name.contains('lunge')) return 'Keep your front knee at a 90-degree angle and back knee hovering above ground.';
    if (name.contains('jump')) return 'Land softly on the balls of your feet. Keep your knees slightly bent on landing.';
    if (name.contains('pull')) return 'Keep your shoulders down and back. Pull your chest towards the bar.';
    if (name.contains('curl')) return 'Keep your elbows tucked at your sides. Squeeze your biceps at the top.';
    if (name.contains('crunch')) return 'Keep your lower back pressed into the floor. Exhale as you curl up.';
    if (name.contains('run')) return 'Maintain good posture. Land softly and keep your stride comfortable.';
    if (name.contains('stretch')) return 'Breathe deeply and don\'t bounce. Hold each stretch for 15-30 seconds.';
    return 'Focus on proper form and controlled movements. Breathe steadily throughout the exercise.';
  }
}