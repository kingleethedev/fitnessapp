// lib/screens/workout/workout_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';

class WorkoutPreviewScreen extends StatefulWidget {
  const WorkoutPreviewScreen({super.key});

  @override
  State<WorkoutPreviewScreen> createState() => _WorkoutPreviewScreenState();
}

class _WorkoutPreviewScreenState extends State<WorkoutPreviewScreen> {
  bool _isLoadingTemplates = false;
  List<Map<String, dynamic>> _availableTemplates = [];
  bool _showTemplateSelector = false;

  @override
  void initState() {
    super.initState();
    // Load today's workout when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayWorkout();
    });
  }

  Future<void> _loadTodayWorkout() async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    
    // Check if templates exist
    await workoutProvider.checkAvailableTemplates();
    
    // Load today's workout (will use template if available)
    await workoutProvider.loadTodayWorkout();
    
    // If no workout and no templates, show template selector
    if (workoutProvider.todayWorkout == null && 
        workoutProvider.availableTemplates.isNotEmpty &&
        !workoutProvider.isLoading) {
      setState(() {
        _availableTemplates = workoutProvider.availableTemplates;
        _showTemplateSelector = true;
      });
    }
    
    setState(() {});
  }

  Future<void> _useTemplate(String templateId) async {
    setState(() {
      _isLoadingTemplates = true;
      _showTemplateSelector = false;
    });
    
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    await workoutProvider.useTemplate(templateId);
    
    setState(() {
      _isLoadingTemplates = false;
    });
    
    // Refresh the display
    await workoutProvider.loadTodayWorkout();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workout = workoutProvider.todayWorkout ?? workoutProvider.currentWorkout;
    
    // Show loading state
    if (workoutProvider.isLoading || _isLoadingTemplates) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          title: const Text('Today\'s Workout'),
          backgroundColor: AppColors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
              ),
              SizedBox(height: 16),
              Text(
                'Loading your workout...',
                style: TextStyle(color: AppColors.greyDark),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show template selector if no workout and templates available
    if (_showTemplateSelector && _availableTemplates.isNotEmpty) {
      return _buildTemplateSelector();
    }
    
    // Show empty state if no workout
    if (workout == null) {
      return Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          title: const Text('Today\'s Workout'),
          backgroundColor: AppColors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center, size: 64, color: AppColors.greyMedium),
              const SizedBox(height: 16),
              const Text(
                'No workout scheduled for today',
                style: TextStyle(fontSize: 18, color: AppColors.greyDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate a workout from your profile settings',
                style: TextStyle(color: AppColors.greyDark),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigate to profile to generate workout
                  Navigator.pushNamed(context, '/profile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Go to Profile'),
              ),
            ],
          ),
        ),
      );
    }
    
    final exercises = workout['exercises'] as List? ?? [];
    final totalDuration = workout['duration'] ?? 0;
    final isCompleted = workout['is_completed'] ?? false;
    final templateName = workout['template_name'];
    
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Today\'s Workout'),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await workoutProvider.loadTodayWorkout();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Template info if from template
          if (templateName != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, size: 16, color: AppColors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'From: $templateName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Workout summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isCompleted ? AppColors.success.withOpacity(0.1) : AppColors.blue.withOpacity(0.1),
                  isCompleted ? AppColors.success.withOpacity(0.3) : AppColors.lightBlue.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted ? AppColors.success.withOpacity(0.3) : AppColors.blue.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  Icons.fitness_center,
                  '${exercises.length}',
                  'Exercises',
                  isCompleted ? AppColors.success : AppColors.blue,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: (isCompleted ? AppColors.success : AppColors.blue).withOpacity(0.3),
                ),
                _buildSummaryItem(
                  Icons.timer,
                  '$totalDuration',
                  'Minutes',
                  isCompleted ? AppColors.success : AppColors.blue,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: (isCompleted ? AppColors.success : AppColors.blue).withOpacity(0.3),
                ),
                _buildSummaryItem(
                  Icons.local_fire_department,
                  '${totalDuration * 8}',
                  'Calories',
                  isCompleted ? AppColors.success : AppColors.blue,
                ),
              ],
            ),
          ),
          
          // Status banner if completed
          if (isCompleted)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Workout completed on ${_formatDate(workout['completed_at'])}',
                      style: const TextStyle(color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          
          // Exercise list header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                  ),
                ),
                const Spacer(),
                Text(
                  '${exercises.length} total',
                  style: const TextStyle(color: AppColors.greyDark),
                ),
              ],
            ),
          ),
          
          // Exercise list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _buildExerciseCard(exercise, index + 1);
              },
            ),
          ),
          
          // Start workout button (only if not completed)
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    workoutProvider.setCurrentWorkout(workout);
                    Navigator.pushNamed(context, '/workout-execution');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Workout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTemplateSelector() {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Choose Your Workout'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.fitness_center, size: 40, color: AppColors.blue),
                SizedBox(height: 8),
                Text(
                  'Select a workout template',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.blue,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose from our curated workouts',
                  style: TextStyle(color: AppColors.greyDark),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _availableTemplates.length,
              itemBuilder: (context, index) {
                final template = _availableTemplates[index];
                return _buildTemplateCard(template);
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTemplateCard(Map<String, dynamic> template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _useTemplate(template['id']),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppColors.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template['name'] ?? 'Workout',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template['description'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildInfoChip(Icons.timer, '${template['default_duration']} min'),
                    _buildInfoChip(Icons.flag, template['goal'] ?? 'Fitness'),
                    _buildInfoChip(Icons.people, template['experience_level'] ?? 'Beginner'),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'SELECT',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.blue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(String? dateTime) {
    if (dateTime == null) return '';
    final date = DateTime.parse(dateTime);
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Widget _buildSummaryItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
        ),
      ],
    );
  }
  
  Widget _buildExerciseCard(Map<String, dynamic> exercise, int number) {
    final exerciseName = exercise['name'] ?? 'Exercise';
    final reps = exercise['reps'];
    final duration = exercise['duration'];
    final rest = exercise['rest'] ?? 30;
    final imageUrl = exercise['image_url'];
    final tip = exercise['tip'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Exercise image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      color: AppColors.greyLight,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildDefaultExerciseImage(exerciseName),
                  )
                : _buildDefaultExerciseImage(exerciseName),
          ),
          
          // Exercise details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        exerciseName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Exercise metrics
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (reps != null)
                      _buildMetricChip(
                        Icons.repeat,
                        '$reps reps',
                        AppColors.blue,
                      ),
                    if (duration != null)
                      _buildMetricChip(
                        Icons.timer,
                        '$duration sec',
                        AppColors.blue,
                      ),
                    _buildMetricChip(
                      Icons.restore,
                      'Rest: $rest sec',
                      AppColors.warning,
                    ),
                  ],
                ),
                
                if (tip != null && tip.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb,
                          size: 20,
                          color: AppColors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDefaultExerciseImage(String exerciseName) {
    return Container(
      height: 180,
      width: double.infinity,
      color: AppColors.greyLight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getExerciseIcon(exerciseName),
            size: 48,
            color: AppColors.blue.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            exerciseName,
            style: const TextStyle(color: AppColors.greyDark),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
  
  IconData _getExerciseIcon(String exerciseName) {
    final name = exerciseName.toLowerCase();
    if (name.contains('push')) return Icons.fitness_center;
    if (name.contains('squat')) return Icons.accessibility_new;
    if (name.contains('plank')) return Icons.table_rows;
    if (name.contains('lunge')) return Icons.directions_walk;
    if (name.contains('jump')) return Icons.flash_on;
    if (name.contains('pull')) return Icons.fitness_center;
    if (name.contains('run')) return Icons.directions_run;
    if (name.contains('burpee')) return Icons.flash_on;
    if (name.contains('crunches')) return Icons.fitness_center;
    return Icons.fitness_center;
  }
}