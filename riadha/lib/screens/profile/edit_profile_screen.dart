// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _goalController;
  late TextEditingController _experienceController;
  late TextEditingController _locationController;
  late TextEditingController _daysPerWeekController;
  late TextEditingController _timeAvailableController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    _usernameController = TextEditingController(text: user?['username'] ?? '');
    _emailController = TextEditingController(text: user?['email'] ?? '');
    _heightController = TextEditingController(text: user?['height']?.toString() ?? '');
    _weightController = TextEditingController(text: user?['weight']?.toString() ?? '');
    _goalController = TextEditingController(text: user?['goal'] ?? 'FITNESS');
    _experienceController = TextEditingController(text: user?['experience_level'] ?? 'BEGINNER');
    _locationController = TextEditingController(text: user?['training_location'] ?? 'HOME');
    _daysPerWeekController = TextEditingController(text: (user?['days_per_week'] ?? 3).toString());
    _timeAvailableController = TextEditingController(text: (user?['time_available'] ?? 30).toString());
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalController.dispose();
    _experienceController.dispose();
    _locationController.dispose();
    _daysPerWeekController.dispose();
    _timeAvailableController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        final updates = {
          'height': double.tryParse(_heightController.text),
          'weight': double.tryParse(_weightController.text),
          'goal': _goalController.text,
          'experience_level': _experienceController.text,
          'training_location': _locationController.text,
          'days_per_week': int.tryParse(_daysPerWeekController.text),
          'time_available': int.tryParse(_timeAvailableController.text),
        };
        
        await authProvider.updateProfile(updates);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value?.isEmpty == true ? 'Enter username' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                enabled: false, // Email cannot be changed
              ),
              
              const SizedBox(height: 24),
              const Text(
                'Body Measurements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Height (cm)',
                        prefixIcon: Icon(Icons.height),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Weight (kg)',
                        prefixIcon: Icon(Icons.monitor_weight),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              const Text(
                'Fitness Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _goalController.text,
                decoration: const InputDecoration(
                  labelText: 'Goal',
                  prefixIcon: Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(value: 'FAT_LOSS', child: Text('Fat Loss')),
                  DropdownMenuItem(value: 'MUSCLE_GAIN', child: Text('Muscle Gain')),
                  DropdownMenuItem(value: 'FITNESS', child: Text('General Fitness')),
                ],
                onChanged: (value) => _goalController.text = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _experienceController.text,
                decoration: const InputDecoration(
                  labelText: 'Experience Level',
                  prefixIcon: Icon(Icons.trending_up),
                ),
                items: const [
                  DropdownMenuItem(value: 'BEGINNER', child: Text('Beginner')),
                  DropdownMenuItem(value: 'INTERMEDIATE', child: Text('Intermediate')),
                  DropdownMenuItem(value: 'ADVANCED', child: Text('Advanced')),
                ],
                onChanged: (value) => _experienceController.text = value!,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _locationController.text,
                decoration: const InputDecoration(
                  labelText: 'Training Location',
                  prefixIcon: Icon(Icons.location_on),
                ),
                items: const [
                  DropdownMenuItem(value: 'HOME', child: Text('Home')),
                  DropdownMenuItem(value: 'GYM', child: Text('Gym')),
                  DropdownMenuItem(value: 'OUTDOOR', child: Text('Outdoor')),
                ],
                onChanged: (value) => _locationController.text = value!,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _daysPerWeekController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Days per week',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _timeAvailableController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minutes per workout',
                        prefixIcon: Icon(Icons.timer),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              PrimaryButton(
                text: _isLoading ? 'Saving...' : 'Save Changes',
                onPressed: _saveChanges,
              ),
            ],
          ),
        ),
      ),
    );
  }
}