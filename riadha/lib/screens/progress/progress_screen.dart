import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/colors.dart';
import '../../providers/progress_provider.dart';
import '../../providers/workout_provider.dart';
import '../../providers/meal_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/stat_card.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  int _selectedTab = 0;
  
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
      final workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
      final mealProvider = Provider.of<MealProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Load each method individually instead of loadAllData
      await Future.wait([
        progressProvider.loadProgressSummary(),
        progressProvider.loadWorkoutStats(),
        progressProvider.loadWeeklySummary(),
        workoutProvider.loadWorkoutHistory(limit: 30),
        mealProvider.loadWeeklySummary(),
        authProvider.loadUserProfile(),
      ]);
      
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
              ),
              SizedBox(height: 16),
              Text(
                'Loading your progress...',
                style: TextStyle(color: AppColors.greyDark),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.greyLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Workouts', 0),
                    _buildTabButton('Meals', 1),
                    _buildTabButton('Body', 2),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            
              // Content based on selected tab
              IndexedStack(
                index: _selectedTab,
                children: [
                  _buildWorkoutTab(),
                  _buildMealTab(),
                  _buildBodyTab(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.greyDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTab() {
    return Consumer2<ProgressProvider, WorkoutProvider>(
      builder: (context, progressProvider, workoutProvider, child) {
        final workoutHistory = workoutProvider.workoutHistory;
        final workoutStats = progressProvider.workoutStats;
        
        final totalWorkouts = workoutStats?['summary']?['total_workouts'] ?? progressProvider.totalWorkouts;
        final totalMinutes = workoutStats?['summary']?['total_minutes'] ?? 0;
        final totalCalories = workoutStats?['summary']?['total_calories'] ?? 0;
        final streakDays = progressProvider.streakDays;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total Workouts',
                    value: '$totalWorkouts',
                    icon: Icons.fitness_center,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Total Minutes',
                    value: '$totalMinutes',
                    icon: Icons.timer,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Current Streak',
                    value: streakDays == 0 ? 'Start today!' : '$streakDays day${streakDays != 1 ? 's' : ''}',
                    subtitle: streakDays == 0 ? 'Complete a workout to start' : 'Keep going!',
                    icon: Icons.local_fire_department,
                    iconColor: streakDays >= 3 ? AppColors.yellow : AppColors.greyMedium,
                    backgroundColor: streakDays >= 3 ? AppColors.blue : AppColors.greyLight,
                    textColor: streakDays >= 3 ? AppColors.white : AppColors.greyDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Calories Burned',
                    value: '$totalCalories',
                    icon: Icons.local_fire_department,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
              ],
            ),
            
            // Weekly Activity Chart
            if (workoutHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Weekly Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.blue,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.greyMedium),
                  ),
                  child: _buildWorkoutChart(workoutHistory),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Recent Workouts
            const Text(
              'Recent Workouts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 12),
            
            if (workoutHistory.isNotEmpty)
              ...workoutHistory.take(5).map((workout) => _buildRecentWorkoutItem(workout))
            else
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No workouts yet.\nComplete your first workout to see progress!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.greyDark),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutChart(List<Map<String, dynamic>> workoutHistory) {
    final List<FlSpot> spots = [];
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final workoutsOnDay = workoutHistory.where((w) {
        final workoutDate = DateTime.parse(w['date']);
        return workoutDate.year == date.year &&
               workoutDate.month == date.month &&
               workoutDate.day == date.day &&
               w['is_completed'] == true;
      }).length;
      spots.add(FlSpot((6 - i).toDouble(), workoutsOnDay.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < 7) {
                  return Text(weekdays[value.toInt()]);
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.blue,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.blue.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentWorkoutItem(Map<String, dynamic> workout) {
    final date = DateTime.parse(workout['date']);
    final exercises = workout['exercises'] as List;
    final isCompleted = workout['is_completed'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.lightBlue : AppColors.greyLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fitness_center,
              color: isCompleted ? AppColors.blue : AppColors.greyDark,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? AppColors.blue : AppColors.greyDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercises.length} exercises • ${workout['duration']} min',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted ? AppColors.greyDark : AppColors.greyMedium,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 10, color: AppColors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealTab() {
    return Consumer<MealProvider>(
      builder: (context, mealProvider, child) {
        final weeklySummary = mealProvider.weeklySummary;
        final mealsByDay = weeklySummary?['meals_by_day'] ?? {};
        final completionRate = weeklySummary?['completion_rate'] ?? 0;
        final totalMeals = weeklySummary?['total_meals_completed'] ?? 0;
        
        final List<BarChartGroupData> barData = [];
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        
        for (int i = 0; i < weekdays.length; i++) {
          final day = weekdays[i];
          final count = mealsByDay[day]?.toDouble() ?? 0.0;
          barData.add(
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: count,
                  color: AppColors.blue,
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Meals Logged',
                    value: '$totalMeals',
                    icon: Icons.restaurant,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Completion Rate',
                    value: '${completionRate.toInt()}%',
                    icon: Icons.percent,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Weekly Meal Chart
            const Text(
              'Weekly Meal Logging',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.greyMedium),
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 7.0,
                    barGroups: barData,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) => Text(value.toInt().toString()),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) => Text(weekdays[value.toInt()]),
                          reservedSize: 30,
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Tip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb, color: AppColors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Logging all your meals helps track nutrition and reach your goals faster!',
                      style: TextStyle(color: AppColors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBodyTab() {
    return Consumer2<AuthProvider, ProgressProvider>(
      builder: (context, authProvider, progressProvider, child) {
        final user = authProvider.currentUser;
        final hasMeasurements = (user?['height'] != null && user?['weight'] != null);
        final height = user?['height'] ?? 0.0;
        final weight = user?['weight'] ?? 0.0;
        
        String bmi = '0';
        String bmiCategory = 'Normal';
        
        if (height > 0 && weight > 0) {
          bmi = (weight / ((height / 100) * (height / 100))).toStringAsFixed(1);
          final bmiValue = double.parse(bmi);
          if (bmiValue < 18.5) bmiCategory = 'Underweight';
          else if (bmiValue >= 25 && bmiValue < 30) bmiCategory = 'Overweight';
          else if (bmiValue >= 30) bmiCategory = 'Obese';
        }

        if (!hasMeasurements) {
          return _buildAddMeasurementsPrompt(authProvider);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats cards
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Current Weight',
                    value: '$weight kg',
                    icon: Icons.monitor_weight,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Height',
                    value: '$height cm',
                    icon: Icons.height,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'BMI',
                    value: bmi,
                    subtitle: bmiCategory,
                    icon: Icons.calculate,
                    backgroundColor: AppColors.lightBlue,
                    textColor: AppColors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Consistency',
                    value: '${(progressProvider.consistencyScore * 100).toInt()}%',
                    icon: Icons.trending_up,
                    backgroundColor: AppColors.lightYellow,
                    textColor: AppColors.darkYellow,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Update measurements button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Track More Measurements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add body fat, muscle mass, and more to track your progress',
                    style: TextStyle(fontSize: 12, color: AppColors.blue),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showAddMeasurementDialog(context, authProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Update Measurements'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddMeasurementsPrompt(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.greyLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.fitness_center, size: 64, color: AppColors.blue),
          const SizedBox(height: 16),
          const Text(
            'Add Your Body Measurements',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your height and weight to calculate BMI and track your progress',
            style: TextStyle(color: AppColors.greyDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showAddMeasurementDialog(context, authProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Add Measurements'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMeasurementDialog(BuildContext context, AuthProvider authProvider) async {
    final heightController = TextEditingController(text: authProvider.currentUser?['height']?.toString() ?? '');
    final weightController = TextEditingController(text: authProvider.currentUser?['weight']?.toString() ?? '');
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Body Measurements'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                hintText: 'Enter your height in cm',
                prefixIcon: Icon(Icons.height),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                hintText: 'Enter your weight in kg',
                prefixIcon: Icon(Icons.monitor_weight),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final height = double.tryParse(heightController.text);
              final weight = double.tryParse(weightController.text);
              
              if (height != null && weight != null && height > 0 && weight > 0) {
                try {
                  await authProvider.updateProfile({'height': height, 'weight': weight});
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Measurements updated successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter valid height and weight'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}