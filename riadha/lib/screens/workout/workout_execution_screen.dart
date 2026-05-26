import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/exercise_video_player.dart';

// Modern color palette - Light Blue, Yellow, White only
class ExecutionColors {
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
  bool _showVideo = true;

  @override
  void initState() {
    super.initState();
    _debugWorkoutData();
    _startCurrentExercise();
  }

  void _debugWorkoutData() {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final workout = workoutProvider.currentWorkout;
    print('Workout data: $workout');
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
      
      setState(() {
        _showVideo = true;
      });
      
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
    
    if (workout == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Workout data not found'),
          backgroundColor: ExecutionColors.error,
        ),
      );
      return;
    }
    
    final workoutId = workout['workout_id'] ?? workout['id'];
    
    if (workoutId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Workout ID not found'),
          backgroundColor: ExecutionColors.error,
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
    
    try {
      final response = await workoutProvider.completeWorkout(completeData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Workout completed  + ${response['calories_burned'] ?? 0} calories burned'),
            backgroundColor: ExecutionColors.success,
          ),
        );
        Navigator.pushReplacementNamed(context, '/workout-complete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: ExecutionColors.error,
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

  void _toggleVideo() {
    setState(() {
      _showVideo = !_showVideo;
    });
  }

  void _skipExercise() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Skip Exercise',
          style: TextStyle(color: ExecutionColors.primaryBlue),
        ),
        content: const Text(
          'Are you sure you want to skip this exercise?',
          style: TextStyle(color: ExecutionColors.greyDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: ExecutionColors.greyMedium),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _nextExercise();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ExecutionColors.error,
              foregroundColor: ExecutionColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
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
    final hasVideo = currentExercise['video_url'] != null && currentExercise['video_url'].toString().isNotEmpty;
    
    return Scaffold(
      backgroundColor: ExecutionColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: ExecutionColors.greyLight,
              valueColor: const AlwaysStoppedAnimation<Color>(ExecutionColors.accentYellow),
              minHeight: 4,
            ),
            
            // Header with controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ExecutionColors.lightBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentExerciseIndex + 1} / ${exercises.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ExecutionColors.primaryBlue,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      if (hasVideo)
                        IconButton(
                          icon: Icon(
                            _showVideo ? Icons.videocam : Icons.videocam_off,
                            color: ExecutionColors.primaryBlue,
                            size: 22,
                          ),
                          onPressed: _toggleVideo,
                        ),
                      if (currentExercise.containsKey('duration') && currentExercise['duration'] != null)
                        IconButton(
                          icon: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            color: ExecutionColors.primaryBlue,
                            size: 28,
                          ),
                          onPressed: _togglePause,
                        ),
                      IconButton(
                        icon: const Icon(Icons.skip_next, color: ExecutionColors.error, size: 28),
                        onPressed: _skipExercise,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: ExecutionColors.greyDark, size: 24),
                        onPressed: () => Navigator.pop(context),
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
                      // Video Player
                      if (hasVideo && _showVideo)
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: ExerciseVideoPlayer(
                                  videoUrl: currentExercise['video_url'],
                                  exerciseName: currentExercise['name'],
                                  height: 220,
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _toggleVideo,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: ExecutionColors.greyLight,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Text(
                                    'Hide Video',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ExecutionColors.greyDark,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Exercise Image
                      if (!hasVideo || !_showVideo)
                        _buildExerciseImage(currentExercise),
                      
                      const SizedBox(height: 24),
                      
                      // Exercise name
                      Text(
                        currentExercise['name'],
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: ExecutionColors.primaryBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Rest indicator
                      if (_isResting)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: ExecutionColors.accentYellow,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'REST',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: ExecutionColors.darkBlue,
                              letterSpacing: 1,
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
                                fontSize: 14,
                                color: ExecutionColors.greyDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${currentExercise['reps']}',
                              style: const TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: ExecutionColors.primaryBlue,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (isExerciseCompleted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ExecutionColors.lightBlue,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: const Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: ExecutionColors.primaryBlue,
                                    letterSpacing: 0.5,
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
                                fontSize: 14,
                                color: ExecutionColors.greyDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatTime(_remainingTime),
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: _isResting ? ExecutionColors.darkYellow : ExecutionColors.primaryBlue,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // Exercise tip
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ExecutionColors.lightBlue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getExerciseIcon(currentExercise['name']),
                              size: 24,
                              color: ExecutionColors.primaryBlue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                currentExercise['tip'] ?? _getExerciseTip(currentExercise['name']),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: ExecutionColors.primaryBlue,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Complete button
                      if (!_isResting && 
                          currentExercise.containsKey('reps') && 
                          currentExercise['reps'] != null && 
                          !isExerciseCompleted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _completeExercise,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ExecutionColors.accentYellow,
                              foregroundColor: ExecutionColors.darkBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Complete Exercise',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      
                      // Next button
                      if (!_isResting && isExerciseCompleted)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _nextExercise,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ExecutionColors.primaryBlue,
                              foregroundColor: ExecutionColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _currentExerciseIndex + 1 == exercises.length ? 'Finish Workout' : 'Next Exercise',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
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
    final String? videoUrl = exercise['video_url'];
    
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 220,
                decoration: BoxDecoration(
                  color: ExecutionColors.greyLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(ExecutionColors.accentYellow),
                    ),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => _buildDefaultExerciseImage(exerciseName),
            ),
            if (videoUrl != null && videoUrl.isNotEmpty)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ExecutionColors.darkBlue.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_filled, color: ExecutionColors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Video Available',
                        style: TextStyle(color: ExecutionColors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }
    
    return _buildDefaultExerciseImage(exerciseName);
  }

  Widget _buildDefaultExerciseImage(String exerciseName) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExecutionColors.lightBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ExecutionColors.lightBlue, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getExerciseIcon(exerciseName),
            size: 80,
            color: ExecutionColors.primaryBlue.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _getExerciseCategory(exerciseName),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ExecutionColors.primaryBlue.withOpacity(0.6),
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
    if (name.contains('jump')) return Icons.flash_on;
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
    if (name.contains('cardio') || name.contains('run') || name.contains('jump')) return 'Cardio';
    if (name.contains('stretch') || name.contains('yoga')) return 'Flexibility';
    return 'Strength Training';
  }

  String _getExerciseTip(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('push')) return 'Keep your back straight and lower your chest to the ground';
    if (name.contains('press')) return 'Keep your core tight and press through your palms';
    if (name.contains('squat')) return 'Keep your chest up and weight in your heels';
    if (name.contains('plank')) return 'Keep your body in a straight line from head to toes';
    if (name.contains('lunge')) return 'Keep your front knee at a 90-degree angle';
    if (name.contains('jump')) return 'Land softly on the balls of your feet';
    if (name.contains('pull')) return 'Keep your shoulders down and back';
    if (name.contains('curl')) return 'Keep your elbows tucked at your sides';
    if (name.contains('crunch')) return 'Keep your lower back pressed into the floor';
    if (name.contains('run')) return 'Maintain good posture and land softly';
    if (name.contains('stretch')) return 'Breathe deeply and do not bounce';
    return 'Focus on proper form and controlled movements';
  }
}