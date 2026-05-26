import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/workout_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/payment_provider.dart';
import '../workout/workout_preview_screen.dart';
import '../meals/meal_plan_screen.dart';
import '../progress/progress_screen.dart';
import '../payments/subscription_screen.dart';

// Modern color palette - Light Blue, Yellow, White only
class RiadhaColors {
  static const Color lightBlue = Color(0xFFE6F3FF);
  static const Color lightBlueAccent = Color(0xFFB8D9F5);
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _hasAccess = false;
  bool _isTrialExpired = false;
  late AnimationController _loadingController;
  late Animation<double> _pulseAnimation;
  int _messageIndex = 0;

  final List<String> _loadingMessages = [
    'Preparing your workout plan',
    'Counting your calories',
    'Measuring your progress',
    'Getting you in shape',
    'Loading your fitness journey',
    'Synchronizing with your goals',
    'Almost ready',
    'You will crush it today',
    'Setting up your experience',
  ];

  final List<Widget> _screens = [
    const HomeContent(),
    const WorkoutPreviewScreen(),
    const MealPlanScreen(),
    const ProgressScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startMessageRotation();
    _checkAuthAndLoadData();
  }

  void _setupAnimations() {
    _loadingController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _loadingController, curve: Curves.easeInOut),
    );
  }

  void _startMessageRotation() {
    Future.delayed(const Duration(seconds: 2), _rotateMessage);
  }

  void _rotateMessage() {
    if (mounted && _isLoading) {
      setState(() {
        _messageIndex = (_messageIndex + 1) % _loadingMessages.length;
      });
      Future.delayed(const Duration(seconds: 2), _rotateMessage);
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadData() async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    
    if (!authProvider.isAuthenticated) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    
    await paymentProvider.loadStatus();
    
    _hasAccess = paymentProvider.hasAccess;
    
    final hasUsedTrial = paymentProvider.status?['has_used_trial'] ?? false;
    final isTrialActive = paymentProvider.isOnTrial;
    final isSubscribed = paymentProvider.isSubscribed;
    
    _isTrialExpired = hasUsedTrial && !isTrialActive && !isSubscribed;
    
    if (!_hasAccess) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      }
      return;
    }
    
    await _loadData();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    await Future.wait([
      workoutProvider.loadTodayWorkout(),
      progressProvider.loadProgressSummary(),
      mealProvider.loadTodaysMeals(),
      authProvider.loadUserProfile(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    
    if (_isLoading || paymentProvider.isLoading) {
      return _buildLoadingScreen();
    }
    
    if (!authProvider.isAuthenticated) {
      return const SizedBox.shrink();
    }
    
    if (_isTrialExpired) {
      return _buildExpiredAccessScreen();
    }
    
    return Scaffold(
      backgroundColor: RiadhaColors.offWhite,
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: RiadhaColors.white,
          boxShadow: [
            BoxShadow(
              color: RiadhaColors.greyLight,
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: RiadhaColors.white,
          selectedItemColor: RiadhaColors.primaryBlue,
          unselectedItemColor: RiadhaColors.greyMedium,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
          elevation: 0,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'Workouts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined),
              activeIcon: Icon(Icons.restaurant),
              label: 'Meals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: RiadhaColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo with animation
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: RiadhaColors.lightBlue,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.fitness_center,
                            size: 60,
                            color: RiadhaColors.primaryBlue,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            // Simple loading indicator
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(RiadhaColors.accentYellow),
                backgroundColor: RiadhaColors.lightBlue,
              ),
            ),
            const SizedBox(height: 32),
            // Loading message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _loadingMessages[_messageIndex],
                key: ValueKey(_messageIndex),
                style: TextStyle(
                  fontSize: 16,
                  color: RiadhaColors.greyDark,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: RiadhaColors.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiredAccessScreen() {
    return Scaffold(
      backgroundColor: RiadhaColors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: RiadhaColors.lightBlue,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  height: 80,
                  width: 80,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.timer_outlined,
                      size: 64,
                      color: RiadhaColors.primaryBlue,
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Trial Expired',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: RiadhaColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your free trial has ended.\nUpgrade to continue your fitness journey.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: RiadhaColors.greyDark,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RiadhaColors.primaryBlue,
                    foregroundColor: RiadhaColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  authProvider.logout();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: RiadhaColors.greyMedium),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Modern HomeContent Widget
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutProvider>(context);
    final progressProvider = Provider.of<ProgressProvider>(context);
    final mealProvider = Provider.of<MealProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    
    final streakDays = progressProvider.streakDays;
    final streakText = progressProvider.streakText;
    final user = authProvider.currentUser;
    final username = user?['username'] ?? '';
    final isOnTrial = paymentProvider.isOnTrial;
    final trialDaysRemaining = paymentProvider.trialDaysRemaining;
    
    return Scaffold(
      backgroundColor: RiadhaColors.offWhite,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          color: RiadhaColors.white,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: RiadhaColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.fitness_center,
                            color: RiadhaColors.primaryBlue,
                            size: 22,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // App name
                  const Text(
                    'RIADHA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: RiadhaColors.primaryBlue,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  // Trial badge
                  if (isOnTrial)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: RiadhaColors.accentYellow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$trialDaysRemaining days left',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: RiadhaColors.darkBlue,
                        ),
                      ),
                    ),
                  // Profile button
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/profile'),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: RiadhaColors.lightBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: RiadhaColors.primaryBlue,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: RiadhaColors.primaryBlue,
        backgroundColor: RiadhaColors.white,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome message
              if (username.isNotEmpty) ...[
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: 14,
                    color: RiadhaColors.greyDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: RiadhaColors.primaryBlue,
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // IMPROVED STREAK CARD - Shows 0 state with CTA
              _buildStreakCard(streakDays, streakText),
              
              const SizedBox(height: 28),
              
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: RiadhaColors.primaryBlue,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      title: 'Workout',
                      icon: Icons.fitness_center,
                      color: RiadhaColors.primaryBlue,
                      bgColor: RiadhaColors.lightBlue,
                      onTap: () {
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        homeState?.setState(() {
                          homeState._selectedIndex = 1;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildQuickActionCard(
                      title: 'Meal Plan',
                      icon: Icons.restaurant,
                      color: RiadhaColors.darkYellow,
                      bgColor: RiadhaColors.softYellow,
                      onTap: () {
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        homeState?.setState(() {
                          homeState._selectedIndex = 2;
                        });
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 28),
              
              // Today's Workout
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: RiadhaColors.lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fitness_center, color: RiadhaColors.primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Today\'s Workout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: RiadhaColors.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: workoutProvider.todayWorkout != null 
                          ? RiadhaColors.lightBlue
                          : RiadhaColors.greyLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      workoutProvider.todayWorkout != null ? 'Ready' : 'Not set',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: workoutProvider.todayWorkout != null 
                            ? RiadhaColors.primaryBlue
                            : RiadhaColors.greyDark,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              if (workoutProvider.todayWorkout != null)
                _buildWorkoutCard(workoutProvider.todayWorkout!)
              else
                _buildPlaceholderCard(
                  title: 'Start Your Journey',
                  subtitle: 'Generate your first workout',
                  icon: Icons.fitness_center,
                  onTap: () {
                    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                    homeState?.setState(() {
                      homeState._selectedIndex = 1;
                    });
                  },
                ),
              
              const SizedBox(height: 28),
              
              // Today's Meals
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: RiadhaColors.softYellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant, color: RiadhaColors.darkYellow, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Today\'s Meals',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: RiadhaColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              if (mealProvider.todaysMeals.isNotEmpty)
                _buildMealPreview(mealProvider.todaysMeals)
              else
                _buildPlaceholderCard(
                  title: 'Plan Your Meals',
                  subtitle: 'Create a meal plan',
                  icon: Icons.restaurant,
                  onTap: () => Navigator.pushNamed(context, '/meal-plan'),
                ),
              
              const SizedBox(height: 28),
              
              // Stats Section
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: RiadhaColors.lightBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bar_chart, color: RiadhaColors.primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Stats',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: RiadhaColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Workouts',
                      value: '${progressProvider.totalWorkouts}',
                      icon: Icons.fitness_center,
                      color: RiadhaColors.primaryBlue,
                      bgColor: RiadhaColors.lightBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'This Week',
                      value: '${progressProvider.weeklyWorkouts}',
                      icon: Icons.calendar_today,
                      color: RiadhaColors.primaryBlue,
                      bgColor: RiadhaColors.lightBlue,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Consistency',
                      value: '${(progressProvider.consistencyScore * 100).toInt()}%',
                      icon: Icons.trending_up,
                      color: RiadhaColors.darkYellow,
                      bgColor: RiadhaColors.softYellow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Active Days',
                      value: '$streakDays',
                      icon: Icons.local_fire_department,
                      color: RiadhaColors.primaryBlue,
                      bgColor: RiadhaColors.lightBlue,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // IMPROVED STREAK CARD with zero-state CTA
  Widget _buildStreakCard(int streakDays, String streakText) {
    final hasStarted = streakDays > 0;
    final isActive = streakDays >= 3;
    final nextMilestone = _getNextMilestone(streakDays);
    final progressToNext = hasStarted ? (streakDays / nextMilestone).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: RiadhaColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasStarted 
              ? (isActive ? RiadhaColors.accentYellow : RiadhaColors.greyLight)
              : RiadhaColors.primaryBlue,
          width: hasStarted ? 1.5 : 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with icon and label
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasStarted 
                        ? (isActive ? RiadhaColors.softYellow : RiadhaColors.lightBlue)
                        : RiadhaColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.local_fire_department,
                    color: hasStarted 
                        ? (isActive ? RiadhaColors.darkYellow : RiadhaColors.primaryBlue)
                        : RiadhaColors.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  hasStarted ? 'Current Streak' : 'Get Started',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasStarted ? RiadhaColors.greyDark : RiadhaColors.primaryBlue,
                  ),
                ),
                const Spacer(),
                // Streak badge (only if started)
                if (hasStarted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? RiadhaColors.accentYellow : RiadhaColors.lightBlue,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      streakDays == 1 ? 'DAY 1' : 'DAY $streakDays',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isActive ? RiadhaColors.darkBlue : RiadhaColors.primaryBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (hasStarted) ...[
              // Main streak number - large and bold
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$streakDays',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: isActive ? RiadhaColors.darkYellow : RiadhaColors.primaryBlue,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      streakDays == 1 ? 'day' : 'days',
                      style: TextStyle(
                        fontSize: 18,
                        color: isActive ? RiadhaColors.darkYellow : RiadhaColors.greyDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Motivational message
              Text(
                _getStreakMessage(streakDays),
                style: TextStyle(
                  fontSize: 13,
                  color: RiadhaColors.greyDark,
                  height: 1.4,
                ),
              ),
              
              // Progress bar to next milestone (only for active streaks under 30 days)
              if (streakDays < 30 && nextMilestone > streakDays)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next: $nextMilestone days',
                            style: TextStyle(
                              fontSize: 11,
                              color: RiadhaColors.greyMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${(progressToNext * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: isActive ? RiadhaColors.darkYellow : RiadhaColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progressToNext,
                          backgroundColor: RiadhaColors.greyLight,
                          color: isActive ? RiadhaColors.accentYellow : RiadhaColors.primaryBlue,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              // ZERO STATE - User hasn't started yet
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '0',
                    style: TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: RiadhaColors.primaryBlue,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete your first workout\nto start your streak',
                    style: TextStyle(
                      fontSize: 13,
                      color: RiadhaColors.greyDark,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to workouts tab
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        homeState?.setState(() {
                          homeState._selectedIndex = 1;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RiadhaColors.primaryBlue,
                        foregroundColor: RiadhaColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Start Your First Workout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStreakMessage(int streakDays) {
    if (streakDays == 1) {
      return 'Great start Keep it going tomorrow';
    } else if (streakDays < 3) {
      return 'You are building momentum Stay consistent';
    } else if (streakDays < 7) {
      return 'Excellent consistency You are on fire';
    } else if (streakDays < 14) {
      return 'Amazing discipline This is impressive';
    } else if (streakDays < 30) {
      return 'Unstoppable You are building a powerful habit';
    } else {
      return 'Legendary streak You are an inspiration';
    }
  }

  int _getNextMilestone(int currentDays) {
    if (currentDays < 3) return 3;
    if (currentDays < 7) return 7;
    if (currentDays < 14) return 14;
    if (currentDays < 30) return 30;
    return 30;
  }

  Future<void> _loadData() async {
    setState(() => _isRefreshing = true);
    
    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
    final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
    final mealProvider = Provider.of<MealProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    
    await Future.wait([
      workoutProvider.loadTodayWorkout(),
      progressProvider.loadProgressSummary(),
      mealProvider.loadTodaysMeals(),
      authProvider.loadUserProfile(),
      paymentProvider.loadStatus(),
    ]);
    
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return GestureDetector(
      onTap: () {
        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
        homeState?.setState(() {
          homeState._selectedIndex = 3;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard(Map<String, dynamic> workout) {
    final exercises = workout['exercises'] as List;
    final isCompleted = workout['is_completed'] ?? false;
    
    return Container(
      decoration: BoxDecoration(
        color: RiadhaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RiadhaColors.greyLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RiadhaColors.lightBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: RiadhaColors.primaryBlue, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${workout['duration']} min',
                      style: const TextStyle(
                        color: RiadhaColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted ? RiadhaColors.primaryBlue : RiadhaColors.accentYellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted ? 'Completed' : 'Ready',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: RiadhaColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: exercises.take(3).map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: RiadhaColors.lightBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: RiadhaColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: RiadhaColors.primaryBlue,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              exercise.containsKey('reps') 
                                  ? '${exercise['reps']} reps' 
                                  : '${exercise['duration']} sec',
                              style: TextStyle(
                                fontSize: 12,
                                color: RiadhaColors.greyDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
                    workoutProvider.setCurrentWorkout(workout);
                    Navigator.pushNamed(context, '/workout-execution');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RiadhaColors.primaryBlue,
                    foregroundColor: RiadhaColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Start Workout',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealPreview(Map<String, dynamic> meals) {
    final mealEntries = meals.entries.take(3).toList();
    final completedCount = meals.entries.where((entry) => entry.value['completed'] == true).length;
    final totalMeals = meals.length;
    
    return Container(
      decoration: BoxDecoration(
        color: RiadhaColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RiadhaColors.greyLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RiadhaColors.softYellow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.restaurant, color: RiadhaColors.darkYellow, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '$completedCount/$totalMeals logged',
                      style: const TextStyle(
                        color: RiadhaColors.darkYellow,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: completedCount == totalMeals ? RiadhaColors.primaryBlue : RiadhaColors.accentYellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    completedCount == totalMeals ? 'Complete' : 'In Progress',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: RiadhaColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: mealEntries.map((entry) {
                final mealType = entry.key;
                final mealData = entry.value as Map<String, dynamic>;
                final isCompleted = mealData['completed'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted ? RiadhaColors.primaryBlue : RiadhaColors.softYellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : _getMealIcon(mealType),
                          color: RiadhaColors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatMealType(mealType),
                              style: const TextStyle(
                                fontSize: 11,
                                color: RiadhaColors.greyDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mealData['name'] ?? 'Meal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isCompleted ? RiadhaColors.greyDark : RiadhaColors.primaryBlue,
                                fontSize: 13,
                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted ? RiadhaColors.lightBlue : RiadhaColors.softYellow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isCompleted ? 'Done' : '${mealData['calories'] ?? 0} cal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCompleted ? RiadhaColors.primaryBlue : RiadhaColors.darkYellow,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/meal-plan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: RiadhaColors.primaryBlue,
                  side: const BorderSide(color: RiadhaColors.primaryBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'View Full Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: RiadhaColors.white,
          border: Border.all(color: RiadhaColors.lightBlue, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: RiadhaColors.primaryBlue.withOpacity(0.5), size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: RiadhaColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: RiadhaColors.greyDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: RiadhaColors.lightBlue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Create',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: RiadhaColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMealIcon(String mealType) {
    switch (mealType.toUpperCase()) {
      case 'BREAKFAST':
        return Icons.free_breakfast;
      case 'LUNCH':
        return Icons.lunch_dining;
      case 'DINNER':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }

  String _formatMealType(String mealType) {
    switch (mealType.toUpperCase()) {
      case 'BREAKFAST':
        return 'Breakfast';
      case 'LUNCH':
        return 'Lunch';
      case 'DINNER':
        return 'Dinner';
      default:
        return mealType;
    }
  }
}