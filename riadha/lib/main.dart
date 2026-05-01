// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/colors.dart';
import 'core/themes/app_theme.dart';
import 'core/services/api_service.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/meal_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/social_provider.dart';
import 'providers/progress_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/workout/workout_execution_screen.dart';
import 'screens/workout/workout_complete_screen.dart';
import 'screens/workout/workout_preview_screen.dart';
import 'screens/meals/meal_plan_screen.dart';
import 'screens/meals/meal_detail_screen.dart';
import 'screens/progress/progress_screen.dart';
import 'screens/social/social_screen.dart';
import 'screens/social/friends_screen.dart';
import 'screens/social/leaderboard_screen.dart';
import 'screens/social/challenges_screen.dart';
import 'screens/payments/subscription_screen.dart';
import 'screens/payments/payment_history_screen.dart';
import 'screens/profile/profile_screen.dart';

late ApiService apiService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SharedPreferences first
  await SharedPreferences.getInstance();
  
  // Initialize ApiService
  apiService = ApiService();
  await apiService.init();
  
  runApp(const FitnessApp());
}

class FitnessApp extends StatelessWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService: apiService)),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()..setApiService(apiService)),
        ChangeNotifierProvider(create: (_) => MealProvider()..setApiService(apiService)),
        ChangeNotifierProvider(create: (_) => PaymentProvider()..setApiService(apiService)),
        ChangeNotifierProvider(create: (_) => SocialProvider()..setApiService(apiService)),
        ChangeNotifierProvider(create: (_) => ProgressProvider()..setApiService(apiService)),
      ],
      child: MaterialApp(
        title: 'Fitness App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/register':
              return MaterialPageRoute(builder: (_) => const RegisterScreen());
            case '/onboarding':
              return MaterialPageRoute(builder: (_) => const OnboardingScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const HomeScreen());
            case '/workout-preview':
              return MaterialPageRoute(builder: (_) => const WorkoutPreviewScreen());
            case '/workout-execution':
              return MaterialPageRoute(builder: (_) => const WorkoutExecutionScreen());
            case '/workout-complete':
              return MaterialPageRoute(builder: (_) => const WorkoutCompleteScreen());
            case '/meal-plan':
              return MaterialPageRoute(builder: (_) => const MealPlanScreen());
            case '/meal-detail':
              return MaterialPageRoute(builder: (_) => const MealDetailScreen());
            case '/progress':
              return MaterialPageRoute(builder: (_) => const ProgressScreen());
            case '/social':
              return MaterialPageRoute(builder: (_) => const SocialScreen());
            case '/friends':
              return MaterialPageRoute(builder: (_) => const FriendsScreen());
            case '/leaderboard':
              return MaterialPageRoute(builder: (_) => const LeaderboardScreen());
            case '/challenges':
              return MaterialPageRoute(builder: (_) => const ChallengesScreen());
            case '/subscription':
              return MaterialPageRoute(builder: (_) => const SubscriptionScreen());
            case '/payment-history':
              return MaterialPageRoute(builder: (_) => const PaymentHistoryScreen());
            case '/profile':
              return MaterialPageRoute(builder: (_) => const ProfileScreen());
            default:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
          }
        },
      ),
    );
  }
}