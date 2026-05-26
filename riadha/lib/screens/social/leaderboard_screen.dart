import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/social_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_widget.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  String _selectedPeriod = 'weekly'; // weekly, monthly, all_time
  List<Map<String, dynamic>> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final socialProvider = Provider.of<SocialProvider>(context, listen: false);
      await socialProvider.loadLeaderboard(period: _selectedPeriod, limit: 100);
      
      setState(() {
        _leaderboard = socialProvider.leaderboard;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading leaderboard: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load leaderboard: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?['id'];

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLeaderboard,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildPeriodSelector(),
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading leaderboard...')
          : _leaderboard.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadLeaderboard,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leaderboard.length,
                    itemBuilder: (context, index) {
                      final item = _leaderboard[index];
                      final isCurrentUser = item['user_id'] == currentUserId;
                      return _buildLeaderboardItem(
                        rank: item['rank'],
                        name: item['username'],
                        workouts: item['workouts'],
                        streak: item['streak_days'] ?? 0,
                        isUser: isCurrentUser,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildPeriodButton('Weekly', 'weekly'),
          const SizedBox(width: 8),
          _buildPeriodButton('Monthly', 'monthly'),
          const SizedBox(width: 8),
          _buildPeriodButton('All Time', 'all_time'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String title, String period) {
    final isSelected = _selectedPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
          _loadLeaderboard();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.blue : AppColors.greyMedium,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? AppColors.white : AppColors.blue,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.emoji_events,
            size: 64,
            color: AppColors.greyDark,
          ),
          const SizedBox(height: 16),
          const Text(
            'No leaderboard data yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.blue,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete workouts to appear on the leaderboard!',
            style: TextStyle(color: AppColors.greyDark),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadLeaderboard,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blue,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardItem({
    required int rank,
    required String name,
    required int workouts,
    required int streak,
    required bool isUser,
  }) {
    // Get medal color for top 3
    Color? medalColor;
    if (rank == 1) medalColor = AppColors.yellow;
    else if (rank == 2) medalColor = Colors.grey;
    else if (rank == 3) medalColor = Colors.brown;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser ? AppColors.lightBlue : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUser ? AppColors.blue : AppColors.greyMedium,
          width: isUser ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Rank indicator
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: medalColor ?? (rank <= 3 ? AppColors.yellow.withOpacity(0.2) : AppColors.greyLight),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Icon(
                      rank == 1 ? Icons.emoji_events :
                      rank == 2 ? Icons.emoji_events :
                      Icons.emoji_events,
                      color: medalColor,
                      size: 28,
                    )
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.greyDark,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isUser ? FontWeight.bold : FontWeight.w500,
                        color: isUser ? AppColors.blue : AppColors.black,
                      ),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department, size: 10, color: AppColors.yellow),
                            const SizedBox(width: 2),
                            Text(
                              '$streak',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkYellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$workouts workout${workouts != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                ),
              ],
            ),
          ),
          
          // "You" badge for current user
          if (isUser)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'You',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}