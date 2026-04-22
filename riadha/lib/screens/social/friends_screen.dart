import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/social_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/loading_widget.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);
    await Future.wait([
      socialProvider.loadFriends(),
      socialProvider.loadFriendRequests(),
    ]);
    
    setState(() => _isLoading = false);
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);
    final results = await socialProvider.searchUsers(query);
    setState(() => _searchResults = results);
  }

  Future<void> _sendFriendRequest(String userId, String userName) async {
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);
    
    try {
      await socialProvider.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $userName'),
            backgroundColor: AppColors.success,
          ),
        );
        _searchController.clear();
        setState(() => _searchResults = []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _acceptRequest(String requestId, String userName) async {
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);
    
    try {
      await socialProvider.acceptFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $userName as a friend'),
            backgroundColor: AppColors.success,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept request: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId, String userName) async {
    final socialProvider = Provider.of<SocialProvider>(context, listen: false);
    
    try {
      await socialProvider.rejectFriendRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejected request from $userName'),
            backgroundColor: AppColors.warning,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject request: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeFriend(String friendId, String friendName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Are you sure you want to remove $friendName from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final socialProvider = Provider.of<SocialProvider>(context, listen: false);
      try {
        await socialProvider.removeFriend(friendId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed $friendName from friends'),
              backgroundColor: AppColors.success,
            ),
          );
          await _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove friend: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialProvider = Provider.of<SocialProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.currentUser?['id'];
    
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Friends'),
            Tab(text: 'Requests'),
            Tab(text: 'Add Friends'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Loading friends...')
          : TabBarView(
              controller: _tabController,
              children: [
                // Friends tab
                _buildFriendsTab(socialProvider.friends),
                
                // Friend Requests tab
                _buildRequestsTab(socialProvider.friendRequests),
                
                // Add Friends tab
                _buildAddFriendsTab(),
              ],
            ),
    );
  }

  Widget _buildFriendsTab(List<Map<String, dynamic>> friends) {
    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.greyDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'No friends yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add friends to see their activity!',
              style: TextStyle(color: AppColors.greyDark),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _tabController.animateTo(2);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Find Friends'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: friends.length,
        itemBuilder: (context, index) {
          final friend = friends[index];
          return _buildFriendCard(
            id: friend['id'],
            name: friend['username'],
            email: friend['email'],
            streak: friend['streak_days'] ?? 0,
            workouts: friend['total_workouts'] ?? 0,
          );
        },
      ),
    );
  }

  Widget _buildRequestsTab(List<Map<String, dynamic>> requests) {
    if (requests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_disabled,
              size: 64,
              color: AppColors.greyDark,
            ),
            SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.blue,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Friend requests will appear here',
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
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildRequestCard(
            id: request['id'],
            fromUserId: request['from_user'],
            name: request['from_user_name'],
          );
        },
      ),
    );
  }

  Widget _buildAddFriendsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: InputDecoration(
              hintText: 'Search by username or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppColors.greyLight,
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search,
                        size: 64,
                        color: AppColors.greyDark,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Search for friends',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Enter a username or email to find friends'
                            : 'No users found',
                        style: const TextStyle(color: AppColors.greyDark),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return _buildSearchResultCard(
                      id: user['id'],
                      name: user['username'],
                      email: user['email'],
                      isFriend: user['is_friend'] == true,
                      requestSent: user['request_sent'] == true,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFriendCard({
    required String id,
    required String name,
    required String email,
    required int streak,
    required int workouts,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.greyMedium),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.lightBlue,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                if (streak > 0) ...[
                  const Icon(Icons.local_fire_department, size: 12, color: AppColors.yellow),
                  const SizedBox(width: 4),
                  Text(
                    '$streak day streak',
                    style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.fitness_center, size: 12, color: AppColors.greyDark),
                const SizedBox(width: 4),
                Text(
                  '$workouts workouts',
                  style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'message',
              child: Text('Send Message'),
            ),
            PopupMenuItem(
              value: 'remove',
              child: const Text('Remove Friend'),
            ),
          ],
          onSelected: (value) {
            if (value == 'remove') {
              _removeFriend(id, name);
            }
          },
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required String id,
    required String fromUserId,
    required String name,
  }) {
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
          CircleAvatar(
            backgroundColor: AppColors.lightBlue,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Wants to be your friend',
                  style: TextStyle(fontSize: 12, color: AppColors.greyDark),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: AppColors.success),
                onPressed: () => _acceptRequest(id, name),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.error),
                onPressed: () => _rejectRequest(id, name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultCard({
    required String id,
    required String name,
    required String email,
    required bool isFriend,
    required bool requestSent,
  }) {
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
          CircleAvatar(
            backgroundColor: AppColors.lightBlue,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  email,
                  style: const TextStyle(fontSize: 12, color: AppColors.greyDark),
                ),
              ],
            ),
          ),
          if (isFriend)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Friends',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.white,
                ),
              ),
            )
          else if (requestSent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Request Sent',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.white,
                ),
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _sendFriendRequest(id, name),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
                minimumSize: const Size(80, 35),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Add'),
            ),
        ],
      ),
    );
  }
}