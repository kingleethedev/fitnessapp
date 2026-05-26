// exercise_model.dart
class Exercise {
  final String name;
  final int? reps;
  final int? duration;
  final int? restSeconds;
  bool completed;
  int? actualReps;
  int? actualDuration;
  
  Exercise({
    required this.name,
    this.reps,
    this.duration,
    this.restSeconds,
    this.completed = false,
    this.actualReps,
    this.actualDuration,
  });
  
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'],
      reps: json['reps'],
      duration: json['duration'],
      restSeconds: json['rest'],
      completed: json['completed'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'reps': reps,
      'duration': duration,
      'rest': restSeconds,
      'completed': completed,
      'actual_reps': actualReps,
      'actual_duration': actualDuration,
    };
  }
  
  String getDisplayText() {
    if (reps != null) return '$reps reps';
    if (duration != null) return '$duration seconds';
    return '';
  }
}