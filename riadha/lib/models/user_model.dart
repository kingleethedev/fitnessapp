// user_model.dart
class User {
  final String id;
  final String username;
  final String email;
  final double? height;
  final double? weight;
  final String goal;
  final String experienceLevel;
  final String trainingLocation;
  final int daysPerWeek;
  final int timeAvailable;
  final int streakDays;
  final int totalWorkouts;
  final String subscriptionTier;
  final bool onboardingCompleted;
  final DateTime createdAt;
  
  User({
    required this.id,
    required this.username,
    required this.email,
    this.height,
    this.weight,
    required this.goal,
    required this.experienceLevel,
    required this.trainingLocation,
    required this.daysPerWeek,
    required this.timeAvailable,
    required this.streakDays,
    required this.totalWorkouts,
    required this.subscriptionTier,
    required this.onboardingCompleted,
    required this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      height: json['height']?.toDouble(),
      weight: json['weight']?.toDouble(),
      goal: json['goal'],
      experienceLevel: json['experience_level'],
      trainingLocation: json['training_location'],
      daysPerWeek: json['days_per_week'],
      timeAvailable: json['time_available'],
      streakDays: json['streak_days'],
      totalWorkouts: json['total_workouts'],
      subscriptionTier: json['subscription_tier'],
      onboardingCompleted: json['onboarding_completed'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  bool get isPremium => subscriptionTier != 'FREE';
  
  String getStreakText() {
    if (streakDays >= 30) return 'Legendary Streak';
    if (streakDays >= 14) return 'Great Streak';
    if (streakDays >= 7) return 'Good Streak';
    return 'Keep Going';
  }
}