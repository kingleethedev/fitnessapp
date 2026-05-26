import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/social_provider.dart';
import '../../widgets/loading_widget.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activeChallenges = [];
  List<Map<String, dynamic>> _myChallenges = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);
    await Future.wait([
      socialProvider.loadChallenges(),
      socialProvider.loadMyChallenges(),
    ]);
    
    setState(() {
      _activeChallenges = socialProvider.challenges;
      _myChallenges = socialProvider.myChallenges;
      _isLoading = false;
    });
  }

  Future<void> _joinChallenge(String challengeId, String challengeName) async {
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Challenge'),
        content: Text('Do you want to join "$challengeName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await socialProvider.joinChallenge(challengeId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully joined the challenge!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to join challenge: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _getChallengeTypeIcon(String type) {
    switch (type) {
      case 'STREAK':
        return '🔥';
      case 'WORKOUT_COUNT':
        return '💪';
      case 'CALORIES':
        return '⚡';
      case 'DURATION':
        return '⏱️';
      case 'CONSISTENCY':
        return '📅';
      default:
        return '🏆';
    }
  }

  String _getChallengeTypeName(String type) {
    switch (type) {
      case 'STREAK':
        return 'Streak Challenge';
      case 'WORKOUT_COUNT':
        return 'Workout Count';
      case 'CALORIES':
        return 'Calories Burned';
      case 'DURATION':
        return 'Total Duration';
      case 'CONSISTENCY':
        return 'Consistency';
      default:
        return type;
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Challenges'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'My Challenges'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading challenges...')
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveChallengesTab(),
                _buildMyChallengesTab(),
              ],
            ),
    );
  }

  Widget _buildActiveChallengesTab() {
    if (_activeChallenges.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: AppColors.greyDark,
            ),
            SizedBox(height: 16),
            Text(
              'No active challenges',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back soon for new challenges!',
              style: TextStyle(color: AppColors.greyDark),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeChallenges.length,
        itemBuilder: (context, index) {
          final challenge = _activeChallenges[index];
          return _buildChallengeCard(
            id: challenge['id'],
            name: challenge['name'],
            description: challenge['description'],
            type: challenge['challenge_type'],
            target: challenge['target_value'],
            startDate: challenge['start_date'],
            endDate: challenge['end_date'],
            participants: challenge['participants_count'] ?? 0,
            isJoined: _myChallenges.any((c) => c['id'] == challenge['id']),
          );
        },
      ),
    );
  }

  Widget _buildMyChallengesTab() {
    if (_myChallenges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppColors.greyDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'No challenges joined',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join a challenge to start competing!',
              style: TextStyle(color: AppColors.greyDark),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(0);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Browse Challenges'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myChallenges.length,
        itemBuilder: (context, index) {
          final challenge = _myChallenges[index];
          final progress = challenge['current_value'] ?? 0.0;
          final target = challenge['target_value'] ?? 0.0;
          final isCompleted = challenge['completed'] ?? false;
          
          return _buildMyChallengeCard(
            name: challenge['name'],
            description: challenge['description'],
            type: challenge['challenge_type'],
            progress: progress,
            target: target,
            isCompleted: isCompleted,
            endDate: challenge['end_date'],
          );
        },
      ),
    );
  }

  Widget _buildChallengeCard({
    required String id,
    required String name,
    required String description,
    required String type,
    required double target,
    required String startDate,
    required String endDate,
    required int participants,
    required bool isJoined,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _getChallengeTypeIcon(type),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getChallengeTypeName(type),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.greyDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.yellow,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$participants joined',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.flag, size: 16, color: AppColors.greyDark), // Fixed: changed from Icons.target
                    const SizedBox(width: 4),
                    Text(
                      'Target: ${target.toInt()}',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.calendar_today, size: 16, color: AppColors.greyDark),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: isJoined
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Joined',
                          style: TextStyle(color: AppColors.white),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => _joinChallenge(id, name),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        foregroundColor: AppColors.white,
                      ),
                      child: const Text('Join Challenge'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyChallengeCard({
    required String name,
    required String description,
    required String type,
    required double progress,
    required double target,
    required bool isCompleted,
    required String endDate,
  }) {
    final percentage = target > 0 ? (progress / target * 100).clamp(0, 100) : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? AppColors.success : AppColors.greyMedium,
          width: isCompleted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? AppColors.success : AppColors.lightBlue,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  _getChallengeTypeIcon(type),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? AppColors.white : AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getChallengeTypeName(type),
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted ? AppColors.white.withOpacity(0.8) : AppColors.greyDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCompleted)
                  const Icon(Icons.check_circle, color: AppColors.white),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.flag, size: 16, color: AppColors.greyDark),
                    const SizedBox(width: 4),
                    Text(
                      'Progress: ${progress.toInt()} / ${target.toInt()}',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: AppColors.greyLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.blue),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${percentage.toInt()}% Complete',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                    Text(
                      'Ends: ${_formatDate(endDate)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}