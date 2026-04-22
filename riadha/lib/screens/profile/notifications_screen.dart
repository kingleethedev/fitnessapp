
// lib/screens/profile/notifications_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _workoutReminders = true;
  bool _mealReminders = false;
  bool _socialNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive notifications on your device'),
            value: _pushNotifications,
            onChanged: (value) {
              setState(() => _pushNotifications = value);
            },
            activeColor: AppColors.blue,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive updates via email'),
            value: _emailNotifications,
            onChanged: (value) {
              setState(() => _emailNotifications = value);
            },
            activeColor: AppColors.blue,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Workout Reminders'),
            subtitle: const Text('Get reminded to complete your workouts'),
            value: _workoutReminders,
            onChanged: (value) {
              setState(() => _workoutReminders = value);
            },
            activeColor: AppColors.blue,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Meal Reminders'),
            subtitle: const Text('Get reminded to log your meals'),
            value: _mealReminders,
            onChanged: (value) {
              setState(() => _mealReminders = value);
            },
            activeColor: AppColors.blue,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Social Notifications'),
            subtitle: const Text('Friend requests and challenge updates'),
            value: _socialNotifications,
            onChanged: (value) {
              setState(() => _socialNotifications = value);
            },
            activeColor: AppColors.blue,
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Notification preferences are saved automatically',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.greyDark,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}