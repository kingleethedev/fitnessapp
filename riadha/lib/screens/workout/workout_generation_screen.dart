import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class WorkoutGenerationScreen extends StatelessWidget {
  const WorkoutGenerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Generate Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate New Workout',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Customize your workout based on your preferences',
              style: TextStyle(color: AppColors.greyDark),
            ),
            const SizedBox(height: 32),
            _buildOptionCard('Goal', 'Fat Loss'),
            const SizedBox(height: 12),
            _buildOptionCard('Experience', 'Intermediate'),
            const SizedBox(height: 12),
            _buildOptionCard('Location', 'Home'),
            const SizedBox(height: 12),
            _buildOptionCard('Duration', '30 minutes'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Workout generated!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Generate Workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.greyMedium),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(color: AppColors.greyDark),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.greyDark),
            ],
          ),
        ],
      ),
    );
  }
}