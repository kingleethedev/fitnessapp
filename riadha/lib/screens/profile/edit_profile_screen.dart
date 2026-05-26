// lib/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/primary_button.dart';

// Modern color palette - Light Blue, Yellow, White only
class EditProfileColors {
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
  static const Color success = Color(0xFF4A90D9);
  static const Color error = Color(0xFFE57373);
}

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
              content: Text('Profile updated successfully'),
              backgroundColor: EditProfileColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: EditProfileColors.error,
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
      backgroundColor: EditProfileColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: EditProfileColors.primaryBlue,
          ),
        ),
        backgroundColor: EditProfileColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Personal Information Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: EditProfileColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EditProfileColors.greyLight, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EditProfileColors.lightBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            size: 18,
                            color: EditProfileColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: EditProfileColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.greyLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                        ),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Enter username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Your email address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.greyLight),
                        ),
                      ),
                      enabled: false,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Body Measurements Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: EditProfileColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EditProfileColors.greyLight, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EditProfileColors.lightBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.monitor_weight,
                            size: 18,
                            color: EditProfileColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Body Measurements',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: EditProfileColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Height (cm)',
                              hintText: 'Enter height',
                              prefixIcon: Icon(Icons.height),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.greyLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                              ),
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
                              hintText: 'Enter weight',
                              prefixIcon: Icon(Icons.monitor_weight),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.greyLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Fitness Preferences Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: EditProfileColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: EditProfileColors.greyLight, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: EditProfileColors.lightBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            size: 18,
                            color: EditProfileColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Fitness Preferences',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: EditProfileColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _goalController.text,
                      decoration: const InputDecoration(
                        labelText: 'Goal',
                        prefixIcon: Icon(Icons.flag_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.greyLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                        ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.greyLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                        ),
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
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.greyLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                        ),
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
                              hintText: 'Days',
                              prefixIcon: Icon(Icons.calendar_today),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.greyLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                              ),
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
                              hintText: 'Minutes',
                              prefixIcon: Icon(Icons.timer_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.greyLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(color: EditProfileColors.primaryBlue, width: 2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EditProfileColors.accentYellow,
                    foregroundColor: EditProfileColors.darkBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: EditProfileColors.greyLight,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(EditProfileColors.darkBlue),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}