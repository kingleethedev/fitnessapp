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
  
  // Payment endpoints (PayPal)
  static const String subscriptionPlan = '/payments/plan/';                    // Get subscription plan
  static const String checkTrialEligibility = '/payments/check_trial_eligibility/';  // Check if user can start trial
  static const String startTrial = '/payments/start_trial/';                  // Start 7-day free trial
  static const String subscriptionStatus = '/payments/status/';               // Get current subscription/trial status
  static const String createPayPalPayment = '/payments/create_payment/';      // Create one-time PayPal payment
  static const String createPayPalSubscription = '/payments/create_subscription/'; // Create PayPal subscription
  static const String executePayPalPayment = '/payments/execute_payment/';    // Execute payment after approval
  static const String cancelSubscription = '/payments/cancel_subscription/';  // Cancel active subscription
  static const String paymentHistory = '/payments/payment_history/';          // Get user's payment history
  
  // Legacy/Deprecated endpoints (kept for backward compatibility)
  @Deprecated('Use subscriptionPlan instead')
  static const String subscriptionPlans = '/payments/plans/';
  @Deprecated('Use createPayPalSubscription instead')
  static const String createSubscription = '/payments/create_subscription/';
  
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