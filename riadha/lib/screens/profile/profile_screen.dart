// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/primary_button.dart';
import 'edit_profile_screen.dart';
import 'workout_history_screen.dart';
import 'meal_history_screen.dart';

// Modern color palette - Light Blue, Yellow, White only
class ProfileColors {
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
  static const Color black = Color(0xFF1A2B4C);
  static const Color error = Color(0xFFE57373);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
      authProvider.loadUserProfile();
      paymentProvider.loadStatus();
    });
  }

  String _getSubscriptionStatus(Map<String, dynamic>? user, Map<String, dynamic>? paymentStatus) {
    if (paymentStatus == null) return 'Loading...';
    
    final isSubscribed = paymentStatus['is_subscribed'] ?? false;
    final isOnTrial = paymentStatus['is_trial_active'] ?? false;
    final trialDaysRemaining = paymentStatus['trial_days_remaining'] ?? 0;
    
    if (isSubscribed) {
      return 'PREMIUM MEMBER';
    } else if (isOnTrial) {
      return 'TRIAL ACTIVE  $trialDaysRemaining days left';
    } else {
      return 'FREE MEMBER';
    }
  }

  Color _getSubscriptionBadgeColor(Map<String, dynamic>? user, Map<String, dynamic>? paymentStatus) {
    if (paymentStatus == null) return ProfileColors.lightBlue;
    
    final isSubscribed = paymentStatus['is_subscribed'] ?? false;
    final isOnTrial = paymentStatus['is_trial_active'] ?? false;
    
    if (isSubscribed) {
      return ProfileColors.accentYellow;
    } else if (isOnTrial) {
      return ProfileColors.softYellow;
    } else {
      return ProfileColors.lightBlue;
    }
  }

  Color _getSubscriptionTextColor(Map<String, dynamic>? user, Map<String, dynamic>? paymentStatus) {
    if (paymentStatus == null) return ProfileColors.primaryBlue;
    
    final isSubscribed = paymentStatus['is_subscribed'] ?? false;
    final isOnTrial = paymentStatus['is_trial_active'] ?? false;
    
    if (isSubscribed) {
      return ProfileColors.darkBlue;
    } else if (isOnTrial) {
      return ProfileColors.darkYellow;
    } else {
      return ProfileColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final user = authProvider.currentUser;
    final paymentStatus = paymentProvider.status;

    return Scaffold(
      backgroundColor: ProfileColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ProfileColors.primaryBlue,
          ),
        ),
        backgroundColor: ProfileColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: ProfileColors.primaryBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              ).then((_) {
                authProvider.loadUserProfile();
                paymentProvider.loadStatus();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await authProvider.loadUserProfile();
          await paymentProvider.loadStatus();
        },
        color: ProfileColors.primaryBlue,
        backgroundColor: ProfileColors.white,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // User Info Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ProfileColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: ProfileColors.lightBlue, width: 1),
                  ),
                  child: Column(
                    children: [
                      // Avatar placeholder
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: ProfileColors.lightBlue,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.person_outline,
                                size: 40,
                                color: ProfileColors.primaryBlue,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user?['username'] ?? 'Loading...',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ProfileColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?['email'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ProfileColors.greyDark,
                        ),
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getSubscriptionBadgeColor(user, paymentStatus),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _getSubscriptionStatus(user, paymentStatus),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: _getSubscriptionTextColor(user, paymentStatus),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        '${user?['total_workouts'] ?? 0}',
                        'Workouts',
                        Icons.fitness_center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        '${user?['streak_days'] ?? 0}',
                        'Streak',
                        Icons.local_fire_department,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        '${user?['weekly_workouts'] ?? 0}',
                        'This Week',
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Menu Items
                Container(
                  decoration: BoxDecoration(
                    color: ProfileColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ProfileColors.greyLight, width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildMenuItem(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        subtitle: 'Update your personal information',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                          ).then((_) {
                            authProvider.loadUserProfile();
                            paymentProvider.loadStatus();
                          });
                        },
                      ),
                      const Divider(height: 1, color: ProfileColors.greyLight),
                      _buildMenuItem(
                        icon: Icons.fitness_center,
                        title: 'Workout History',
                        subtitle: '${user?['total_workouts'] ?? 0} workouts completed',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WorkoutHistoryScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, color: ProfileColors.greyLight),
                      _buildMenuItem(
                        icon: Icons.restaurant,
                        title: 'Meal History',
                        subtitle: '${user?['total_meals_logged'] ?? 0} meals logged',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MealHistoryScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1, color: ProfileColors.greyLight),
                      _buildMenuItem(
                        icon: Icons.star_outline,
                        title: 'Subscription',
                        subtitle: _getSubscriptionStatus(user, paymentStatus) == 'PREMIUM MEMBER'
                            ? 'Premium Member'
                            : _getSubscriptionStatus(user, paymentStatus).contains('TRIAL')
                                ? 'Active Trial'
                                : 'Upgrade to Premium',
                        onTap: () {
                          Navigator.pushNamed(context, '/subscription');
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      await authProvider.logout();
                      if (mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ProfileColors.error,
                      side: const BorderSide(color: ProfileColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // App version
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: ProfileColors.greyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    final isStreak = label == 'Streak';
    final streakValue = int.tryParse(value) ?? 0;
    final isActiveStreak = isStreak && streakValue >= 3;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isActiveStreak ? ProfileColors.softYellow : ProfileColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActiveStreak ? ProfileColors.accentYellow : ProfileColors.greyLight,
          width: isActiveStreak ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isActiveStreak ? ProfileColors.darkYellow : ProfileColors.primaryBlue,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isActiveStreak ? ProfileColors.darkYellow : ProfileColors.primaryBlue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: ProfileColors.greyDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ProfileColors.lightBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: ProfileColors.primaryBlue, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: ProfileColors.darkBlue,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12, 
          color: ProfileColors.greyDark,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: ProfileColors.greyMedium, size: 20),
      onTap: onTap,
    );
  }
}