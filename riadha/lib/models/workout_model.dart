// workout_model.dart
import 'exercise_model.dart';

class Workout {
  final String id;
  final DateTime date;
  final int duration;
  final List<Exercise> exercises;
  final double difficultyScore;
  final int intensityLevel;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? caloriesBurned;
  
  Workout({
    required this.id,
    required this.date,
    required this.duration,
    required this.exercises,
    required this.difficultyScore,
    required this.intensityLevel,
    required this.isCompleted,
    this.completedAt,
    this.caloriesBurned,
  });
  
  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['workout_id'] ?? json['id'],
      date: DateTime.parse(json['date']),
      duration: json['duration'],
      exercises: (json['exercises'] as List)
          .map((e) => Exercise.fromJson(e))
          .toList(),
      difficultyScore: json['difficulty_score']?.toDouble() ?? 0.5,
      intensityLevel: json['intensity_level'] ?? 1,
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      caloriesBurned: json['calories_burned'],
    );
  }
  
  int get totalExercises => exercises.length;
  
  int get completedExercises => exercises.where((e) => e.completed).length;
  
  double get completionPercentage => totalExercises > 0 
      ? completedExercises / totalExercises 
      : 0;
}