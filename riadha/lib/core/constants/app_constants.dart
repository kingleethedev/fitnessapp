// app_constants.dart
class ApiEndpoints {
  static const String baseUrl = 'https://hardly-urgency-length.ngrok-free.dev/api';
  // For production: static const String baseUrl = 'https://api.fitnessapp.com/api';
  
  // Auth endpoints
  static const String login = '/auth/login/';
  static const String register = '/auth/register/';
  static const String refreshToken = '/token/refresh/';
  static const String logout = '/auth/logout/';
  
  // User endpoints
  static const String userProfile = '/users/me/';
  static const String updateProfile = '/users/update_profile/';
  static const String completeOnboarding = '/users/complete_onboarding/';
  
  // Workout endpoints
  static const String generateWorkout = '/workouts/generate/';
  static const String completeWorkout = '/workouts/complete/';
  static const String todayWorkout = '/workouts/today/';
  static const String workoutHistory = '/workouts/history/';
  static const String workoutStats = '/workouts/stats/';
  
  // Meal endpoints
  static const String meals = '/meals/meals/';
  static const String generateMealPlan = '/meals/generate_plan/';
  static const String currentMealPlan = '/meals/current_plan/';
  static const String todaysMeals = '/meals/todays_meals/';
  static const String logMeal = '/meals/log_meal/';
  static const String rateMeal = '/meals/rate_meal/';
  static const String favoriteMeal = '/meals/favorite_meal/';
  static const String favorites = '/meals/favorites/';
  static const String weeklyMealSummary = '/meals/weekly_summary/';
  
  // Payment endpoints
  static const String subscriptionPlans = '/payments/plans/';
  static const String createSubscription = '/payments/create_subscription/';
  static const String cancelSubscription = '/payments/cancel_subscription/';
  static const String paymentHistory = '/payments/payment_history/';
  
  // Social endpoints
  static const String friends = '/social/friends/';
  static const String friendRequests = '/social/friend_requests/';
  static const String sendFriendRequest = '/social/send_request/';
  static const String acceptFriendRequest = '/social/accept_request/';
  static const String rejectFriendRequest = '/social/reject_request/';
  static const String removeFriend = '/social/remove_friend/';
  static const String feed = '/social/feed/';
  static const String leaderboard = '/social/leaderboard/';
  static const String friendLeaderboard = '/social/friend_leaderboard/';
  static const String challenges = '/social/challenges/';
  static const String joinChallenge = '/social/join_challenge/';
  static const String createChallenge = '/social/create_challenge/';
  static const String searchUsers = '/social/search/';
  
  // Analytics endpoints
  static const String dashboard = '/analytics/dashboard/';
}