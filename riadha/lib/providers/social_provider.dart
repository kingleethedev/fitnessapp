// lib/providers/social_provider.dart
import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class SocialProvider extends ChangeNotifier {
  late ApiService _apiService;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _feed = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _myChallenges = [];
  bool _isLoading = false;
  String? _error;
  
  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get friendRequests => _friendRequests;
  List<Map<String, dynamic>> get feed => _feed;
  List<Map<String, dynamic>> get leaderboard => _leaderboard;
  List<Map<String, dynamic>> get challenges => _challenges;
  List<Map<String, dynamic>> get myChallenges => _myChallenges;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }
  
  Future<void> loadFriends() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/social/friends/');
      _friends = List<Map<String, dynamic>>.from(response['friends'] ?? response);
      print('✅ Loaded ${_friends.length} friends');
    } catch (e) {
      _error = e.toString();
      print('Error loading friends: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadFriendRequests() async {
    _error = null;
    
    try {
      final response = await _apiService.get('/social/friend_requests/');
      _friendRequests = List<Map<String, dynamic>>.from(response['requests'] ?? response);
      print('✅ Loaded ${_friendRequests.length} friend requests');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading friend requests: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> sendFriendRequest(String userId) async {
    try {
      await _apiService.post('/social/send_request/', data: {
        'user_id': userId,
      });
      print('✅ Friend request sent to user: $userId');
      await loadFriendRequests();
    } catch (e) {
      print('Error sending friend request: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      await _apiService.post('/social/accept_request/', data: {
        'request_id': requestId,
      });
      print('✅ Friend request accepted: $requestId');
      await loadFriends();
      await loadFriendRequests();
    } catch (e) {
      print('Error accepting friend request: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _apiService.post('/social/reject_request/', data: {
        'request_id': requestId,
      });
      print('✅ Friend request rejected: $requestId');
      await loadFriendRequests();
    } catch (e) {
      print('Error rejecting friend request: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> removeFriend(String friendId) async {
    try {
      await _apiService.delete('/social/remove_friend/', data: {
        'friend_id': friendId,
      });
      print('✅ Friend removed: $friendId');
      await loadFriends();
    } catch (e) {
      print('Error removing friend: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> loadFeed({int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/social/feed/?limit=$limit');
      _feed = List<Map<String, dynamic>>.from(response['results'] ?? response);
      print('✅ Loaded ${_feed.length} feed items');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading feed: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadLeaderboard({String period = 'weekly', int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/social/leaderboard/?period=$period&limit=$limit');
      _leaderboard = List<Map<String, dynamic>>.from(response['results'] ?? response);
      print('✅ Loaded ${_leaderboard.length} leaderboard entries');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading leaderboard: $e');
      _leaderboard = [];
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadChallenges() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/social/challenges/');
      _challenges = List<Map<String, dynamic>>.from(response['results'] ?? response);
      print('✅ Loaded ${_challenges.length} challenges');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading challenges: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadMyChallenges() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/social/my_challenges/');
      _myChallenges = List<Map<String, dynamic>>.from(response['results'] ?? response);
      print('✅ Loaded ${_myChallenges.length} my challenges');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading my challenges: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> joinChallenge(String challengeId) async {
    try {
      await _apiService.post('/social/join_challenge/', data: {
        'challenge_id': challengeId,
      });
      print('✅ Joined challenge: $challengeId');
      await loadMyChallenges();
      await loadChallenges();
    } catch (e) {
      print('Error joining challenge: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> leaveChallenge(String challengeId) async {
    try {
      await _apiService.post('/social/leave_challenge/', data: {
        'challenge_id': challengeId,
      });
      print('✅ Left challenge: $challengeId');
      await loadMyChallenges();
      await loadChallenges();
    } catch (e) {
      print('Error leaving challenge: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getChallengeDetails(String challengeId) async {
    try {
      final response = await _apiService.get('/social/challenges/$challengeId/');
      print('✅ Loaded challenge details for: $challengeId');
      return response;
    } catch (e) {
      print('Error getting challenge details: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final response = await _apiService.get('/social/search/?q=$query');
      final results = List<Map<String, dynamic>>.from(response['results'] ?? response);
      print('✅ Found ${results.length} users matching "$query"');
      return results;
    } catch (e) {
      print('Error searching users: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      return [];
    }
  }
  
  Future<void> shareWorkout(String workoutId, {String? comment}) async {
    try {
      await _apiService.post('/social/share_workout/', data: {
        'workout_id': workoutId,
        'comment': comment,
      });
      print('✅ Workout shared successfully');
      await loadFeed();
    } catch (e) {
      print('Error sharing workout: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  Future<void> likePost(String postId) async {
    try {
      await _apiService.post('/social/like_post/', data: {
        'post_id': postId,
      });
      print('✅ Post liked: $postId');
      await loadFeed();
    } catch (e) {
      print('Error liking post: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> unlikePost(String postId) async {
    try {
      await _apiService.delete('/social/unlike_post/', data: {
        'post_id': postId,
      });
      print('✅ Post unliked: $postId');
      await loadFeed();
    } catch (e) {
      print('Error unliking post: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  Future<void> addComment(String postId, String comment) async {
    try {
      await _apiService.post('/social/add_comment/', data: {
        'post_id': postId,
        'comment': comment,
      });
      print('✅ Comment added to post: $postId');
      await loadFeed();
    } catch (e) {
      print('Error adding comment: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void reset() {
    _friends = [];
    _friendRequests = [];
    _feed = [];
    _leaderboard = [];
    _challenges = [];
    _myChallenges = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
  
  int getPendingRequestCount() {
    return _friendRequests.length;
  }
  
  int getActiveChallengesCount() {
    return _myChallenges.where((c) => c['status'] == 'active').length;
  }
  
  double getFriendsWorkoutAverage() {
    if (_friends.isEmpty) return 0.0;
    
    int totalWorkouts = 0;
    for (var friend in _friends) {
      final weeklyWorkouts = friend['weekly_workouts'];
      if (weeklyWorkouts != null) {
        totalWorkouts += (weeklyWorkouts as num).toInt();
      }
    }
    return totalWorkouts / _friends.length;
  }
}  // Make sure this closing brace is present