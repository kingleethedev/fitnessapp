import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hasOnboarding = await authProvider.hasCompletedOnboarding();

    if (authProvider.isAuthenticated) {
      if (hasOnboarding) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // 🔥 LOGO
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.blue.withOpacity(0.1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/images/logo.png', // make sure this exists
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 APP NAME
            const Text(
              'Riadha',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            // 🔥 TAGLINE (optional)
            Text(
              'Your fitness companion',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 30),

            // 🔥 LOADING INDICATOR
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
            ),
          ],
        ),
      ),
    );
  }
}