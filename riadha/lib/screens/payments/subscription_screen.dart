import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../widgets/primary_button.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Premium'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upgrade to Premium',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Get access to all features',
              style: TextStyle(color: AppColors.greyDark),
            ),
            const SizedBox(height: 32),
            _buildFeatureItem('Unlimited Workouts'),
            _buildFeatureItem('Advanced Analytics'),
            _buildFeatureItem('Custom Meal Plans'),
            _buildFeatureItem('Priority Support'),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blue),
              ),
              child: Column(
                children: [
                  const Text(
                    'Premium Monthly',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '\$9.99',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  const Text(
                    'per month',
                    style: TextStyle(color: AppColors.greyDark),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Subscribe Now',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 16, color: AppColors.white),
          ),
          const SizedBox(width: 12),
          Text(feature, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}