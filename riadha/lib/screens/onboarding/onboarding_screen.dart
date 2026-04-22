// onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<String, dynamic> _answers = {};

  final List<Map<String, dynamic>> _questions = [
    {
      'title': 'What is your primary goal?',
      'options': ['Fat Loss', 'Muscle Gain', 'General Fitness'],
      'values': ['FAT_LOSS', 'MUSCLE_GAIN', 'FITNESS'],  // Add actual values for API
      'key': 'goal',
    },
    {
      'title': 'What is your experience level?',
      'options': ['Beginner', 'Intermediate', 'Advanced'],
      'values': ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
      'key': 'experience_level',
    },
    {
      'title': 'Where will you train?',
      'options': ['Home', 'Gym', 'Outdoor'],
      'values': ['HOME', 'GYM', 'OUTDOOR'],
      'key': 'training_location',
    },
    {
      'title': 'How many days per week?',
      'options': ['2 days', '3 days', '4 days', '5 days'],
      'values': [2, 3, 4, 5],  // Integer values
      'key': 'days_per_week',
    },
    {
      'title': 'How much time per workout?',
      'options': ['15 min', '30 min', '45 min', '60 min'],
      'values': [15, 30, 45, 60],  // Integer values
      'key': 'time_available',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_currentPage + 1} of ${_questions.length}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.greyDark,
                    ),
                  ),
                  Text(
                    '${((_currentPage + 1) / _questions.length * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (_currentPage + 1) / _questions.length,
              backgroundColor: AppColors.greyLight,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.yellow),
              minHeight: 4,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final question = _questions[index];
                  final selectedDisplayValue = _answers[question['key']];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          question['title'],
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.blue,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ...List.generate(question['options'].length, (optIndex) {
                          final option = question['options'][optIndex];
                          final actualValue = question['values'][optIndex];
                          final isSelected = selectedDisplayValue == option;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  // Store both display value and actual value
                                  _answers[question['key']] = option;
                                  _answers['${question['key']}_value'] = actualValue;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? AppColors.yellow : AppColors.blue,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected
                                      ? AppColors.yellow.withOpacity(0.1)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: AppColors.blue,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: AppColors.yellow),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                text: _currentPage == _questions.length - 1 ? 'Complete' : 'Next',
                onPressed: () {
                  if (_currentPage == _questions.length - 1) {
                    _completeOnboarding();
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeOnboarding() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Format data correctly for API
    final onboardingData = {
      'goal': _answers['goal_value'] ?? _answers['goal']?.toUpperCase().replaceAll(' ', '_'),
      'experience_level': _answers['experience_level_value'] ?? _answers['experience_level']?.toUpperCase().replaceAll(' ', '_'),
      'training_location': _answers['training_location_value'] ?? _answers['training_location']?.toUpperCase(),
      'days_per_week': _answers['days_per_week_value'] ?? int.tryParse(_answers['days_per_week']?.split(' ')[0] ?? '3'),
      'time_available': _answers['time_available_value'] ?? int.tryParse(_answers['time_available']?.split(' ')[0] ?? '30'),
    };
    
    print('Sending onboarding data: $onboardingData'); // Debug
    
    await authProvider.completeOnboarding(onboardingData);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
}