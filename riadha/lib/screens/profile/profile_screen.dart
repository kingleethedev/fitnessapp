// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';
import 'edit_profile_screen.dart';
import 'workout_history_screen.dart';
import 'meal_history_screen.dart';

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
      authProvider.loadUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: AppColors.blue),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.blue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              ).then((_) => authProvider.loadUserProfile());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => authProvider.loadUserProfile(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // User Info Section
                Column(
                  children: [
                    Text(
                      user?['username'] ?? 'Loading...',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user?['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.greyDark,
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: user['subscription_tier'] == 'PREMIUM' 
                              ? AppColors.yellow 
                              : AppColors.lightBlue,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user['subscription_tier'] == 'PREMIUM' ? 'PREMIUM MEMBER' : 'FREE MEMBER',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: user['subscription_tier'] == 'PREMIUM' 
                                ? AppColors.white 
                                : AppColors.blue,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 32),
                
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
                        'Day Streak',
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
                
                const SizedBox(height: 32),
                const Divider(),
                
                // Menu Items
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                    ).then((_) => authProvider.loadUserProfile());
                  },
                ),
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
                _buildMenuItem(
                  icon: Icons.star,
                  title: 'Subscription',
                  subtitle: user?['subscription_tier'] == 'PREMIUM' 
                      ? 'Premium Member' 
                      : 'Upgrade to Premium',
                  onTap: () {
                    Navigator.pushNamed(context, '/subscription');
                  },
                ),
                
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                
                // Sign Out Button
                PrimaryButton(
                  text: 'Sign Out',
                  onPressed: () async {
                    await authProvider.logout();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.blue, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.greyDark,
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
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.blue, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: AppColors.black,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12, 
          color: AppColors.greyDark,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.greyDark),
      onTap: onTap,
    );
  }
}