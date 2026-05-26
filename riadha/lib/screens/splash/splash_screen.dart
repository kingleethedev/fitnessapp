import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  bool _isNavigating = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Use addPostFrameCallback to ensure navigation happens after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndNavigate();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateToScreen(String routeName) async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    if (mounted) {
      // Use pushNamedAndRemoveUntil to clear the entire navigation stack
      await Navigator.pushNamedAndRemoveUntil(
        context,
        routeName,
        (route) => false,
      );
    }
  }

  Future<void> _initializeAndNavigate() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      if (mounted) {
        setState(() {
          _statusMessage = 'Checking authentication...';
          _hasError = false;
        });
      }
      
      final isAuthenticated = authProvider.isAuthenticated;
      
      if (isAuthenticated && mounted) {
        setState(() {
          _statusMessage = 'Loading profile...';
        });
        
        final hasOnboarding = await authProvider.hasCompletedOnboarding();
        
        if (mounted) {
          await _navigateToScreen(hasOnboarding ? '/home' : '/onboarding');
        }
      } else if (mounted) {
        // Check for Firebase session
        setState(() {
          _statusMessage = 'Checking saved session...';
        });
        
        final hasFirebaseSession = await authProvider.checkFirebaseSession();
        
        if (hasFirebaseSession && mounted) {
          setState(() {
            _statusMessage = 'Syncing with server...';
          });
          
          final synced = await authProvider.syncFirebaseSession();
          
          if (synced && mounted) {
            final hasOnboarding = await authProvider.hasCompletedOnboarding();
            await _navigateToScreen(hasOnboarding ? '/home' : '/onboarding');
          } else if (mounted) {
            await _navigateToScreen('/login');
          }
        } else if (mounted) {
          await _navigateToScreen('/login');
        }
      }
    } catch (e) {
      print('❌ Splash screen error: $e');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _statusMessage = 'Something went wrong';
        });
        
        await Future.delayed(const Duration(seconds: 2));
        
        if (mounted) {
          await _navigateToScreen('/login');
        }
      }
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
            // Animated Logo
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.blue,
                          AppColors.blue.withOpacity(0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.blue.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(70),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.fitness_center,
                            size: 60,
                            color: Colors.white,
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            const Text(
              'Riadha',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your fitness companion',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.greyDark,
              ),
            ),
            const SizedBox(height: 50),
            if (!_hasError) ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
              ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.greyDark,
                ),
              ),
            ] else ...[
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _statusMessage = 'Retrying...';
                    _isNavigating = false;
                  });
                  _initializeAndNavigate();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}