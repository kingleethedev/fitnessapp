// social_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Social'),
      ),
      body: const Center(
        child: Text(
          'Social Screen - Coming Soon',
          style: TextStyle(color: AppColors.blue),
        ),
      ),
    );
  }
}