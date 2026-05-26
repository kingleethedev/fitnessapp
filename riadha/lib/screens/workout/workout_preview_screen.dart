// lib/screens/workout/workout_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';
import '../../widgets/exercise_video_player.dart';

// Modern color palette - Light Blue, Yellow, White only
class WorkoutColors {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTodayWorkout();
    });
  }

  Future<void> _loadTodayWorkout() async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    
    await workoutProvider.checkAvailableTemplates();
    await workoutProvider.loadTodayWorkout();
    
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
    
    await workoutProvider.loadTodayWorkout();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final workout = workoutProvider.todayWorkout ?? workoutProvider.currentWorkout;
    
    if (workoutProvider.isLoading || _isLoadingTemplates) {
      return _buildLoadingScreen();
    }
    
    if (_showTemplateSelector && _availableTemplates.isNotEmpty) {
      return _buildTemplateSelector();
    }
    
    if (workout == null) {
      return _buildEmptyState();
    }
    
    final exercises = workout['exercises'] as List? ?? [];
    final totalDuration = workout['duration'] ?? 0;
    final isCompleted = workout['is_completed'] ?? false;
    final templateName = workout['template_name'];
    
    return Scaffold(
      backgroundColor: WorkoutColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Today\'s Workout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: WorkoutColors.primaryBlue,
          ),
        ),
        backgroundColor: WorkoutColors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: WorkoutColors.primaryBlue),
            onPressed: () async {
              await workoutProvider.loadTodayWorkout();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (templateName != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: WorkoutColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, size: 16, color: WorkoutColors.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'From: $templateName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: WorkoutColors.primaryBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Stats summary - flat design
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WorkoutColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCompleted ? WorkoutColors.primaryBlue : WorkoutColors.lightBlue,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  Icons.fitness_center,
                  '${exercises.length}',
                  'Exercises',
                  isCompleted ? WorkoutColors.success : WorkoutColors.primaryBlue,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: (isCompleted ? WorkoutColors.success : WorkoutColors.primaryBlue).withOpacity(0.2),
                ),
                _buildSummaryItem(
                  Icons.timer_outlined,
                  '$totalDuration',
                  'Minutes',
                  isCompleted ? WorkoutColors.success : WorkoutColors.primaryBlue,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: (isCompleted ? WorkoutColors.success : WorkoutColors.primaryBlue).withOpacity(0.2),
                ),
                _buildSummaryItem(
                  Icons.local_fire_department,
                  '${totalDuration * 8}',
                  'Calories',
                  isCompleted ? WorkoutColors.success : WorkoutColors.primaryBlue,
                ),
              ],
            ),
          ),
          
          // Completion status
          if (isCompleted)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: WorkoutColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: WorkoutColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Workout completed on ${_formatDate(workout['completed_at'])}',
                      style: const TextStyle(
                        color: WorkoutColors.primaryBlue,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Exercises header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: WorkoutColors.primaryBlue,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: WorkoutColors.lightBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${exercises.length} total',
                    style: const TextStyle(
                      fontSize: 11,
                      color: WorkoutColors.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
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
                    backgroundColor: WorkoutColors.accentYellow,
                    foregroundColor: WorkoutColors.darkBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Start Workout',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: WorkoutColors.white,
      appBar: AppBar(
        title: const Text(
          'Today\'s Workout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: WorkoutColors.primaryBlue,
          ),
        ),
        backgroundColor: WorkoutColors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(WorkoutColors.accentYellow),
                backgroundColor: WorkoutColors.lightBlue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading your workout...',
              style: TextStyle(
                fontSize: 14,
                color: WorkoutColors.greyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: WorkoutColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Today\'s Workout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: WorkoutColors.primaryBlue,
          ),
        ),
        backgroundColor: WorkoutColors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: WorkoutColors.lightBlue,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 50,
                  color: WorkoutColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No workout scheduled',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: WorkoutColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Generate a workout from your profile settings to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: WorkoutColors.greyDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/profile');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: WorkoutColors.primaryBlue,
                  foregroundColor: WorkoutColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Go to Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTemplateSelector() {
    return Scaffold(
      backgroundColor: WorkoutColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Choose Your Workout',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: WorkoutColors.primaryBlue,
          ),
        ),
        backgroundColor: WorkoutColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: WorkoutColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WorkoutColors.lightBlue, width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: WorkoutColors.lightBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 40,
                    color: WorkoutColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select a Workout Template',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: WorkoutColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose from our curated workouts to get started',
                  style: TextStyle(
                    fontSize: 13,
                    color: WorkoutColors.greyDark,
                  ),
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
        color: WorkoutColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkoutColors.greyLight, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _useTemplate(template['id']),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: WorkoutColors.lightBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: WorkoutColors.primaryBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template['name'] ?? 'Workout',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: WorkoutColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template['description'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WorkoutColors.greyDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.timer_outlined, '${template['default_duration']} min'),
                    _buildInfoChip(Icons.flag_outlined, template['goal'] ?? 'Fitness'),
                    _buildInfoChip(Icons.people_outline, template['experience_level'] ?? 'Beginner'),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: WorkoutColors.accentYellow,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'SELECT',
                      style: TextStyle(
                        color: WorkoutColors.darkBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: WorkoutColors.lightBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: WorkoutColors.primaryBlue),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: WorkoutColors.primaryBlue,
              fontWeight: FontWeight.w500,
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
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: WorkoutColors.greyDark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildExerciseCard(Map<String, dynamic> exercise, int number) {
    final exerciseName = exercise['name'] ?? 'Exercise';
    final reps = exercise['reps'];
    final duration = exercise['duration'];
    final rest = exercise['rest'] ?? 30;
    final tip = exercise['tip'];
    final videoUrl = exercise['video_url'];
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: WorkoutColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: WorkoutColors.greyLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Player - shown at top if exists
          if (hasVideo)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: ExerciseVideoPlayer(
                videoUrl: videoUrl,
                exerciseName: exerciseName,
                height: 220,
              ),
            ),
          
          // Exercise Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: WorkoutColors.lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '$number',
                          style: const TextStyle(
                            color: WorkoutColors.primaryBlue,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: WorkoutColors.primaryBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (reps != null)
                      _buildMetricChip(
                        Icons.repeat,
                        '$reps reps',
                        WorkoutColors.primaryBlue,
                      ),
                    if (duration != null)
                      _buildMetricChip(
                        Icons.timer_outlined,
                        '$duration sec',
                        WorkoutColors.primaryBlue,
                      ),
                    _buildMetricChip(
                      Icons.restore,
                      'Rest: $rest sec',
                      WorkoutColors.accentYellow,
                    ),
                    if (hasVideo)
                      _buildMetricChip(
                        Icons.videocam,
                        'With Video',
                        WorkoutColors.success,
                      ),
                  ],
                ),
                
                if (tip != null && tip.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: WorkoutColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          size: 18,
                          color: WorkoutColors.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WorkoutColors.primaryBlue,
                              height: 1.4,
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
  
  Widget _buildMetricChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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
}