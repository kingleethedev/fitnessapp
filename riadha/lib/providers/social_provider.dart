// lib/providers/social_provider.dart
import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class SocialProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> _feed = [];
  List<Map<String, dynamic>> _leaderboard = [];  // Add this line
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _myChallenges = [];
  bool _isLoading = false;
  
  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get friendRequests => _friendRequests;
  List<Map<String, dynamic>> get feed => _feed;
  List<Map<String, dynamic>> get leaderboard => _leaderboard;  // Add this getter
  List<Map<String, dynamic>> get challenges => _challenges;
  List<Map<String, dynamic>> get myChallenges => _myChallenges;
  bool get isLoading => _isLoading;
  
  Future<void> loadFriends() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.get('/social/friends/');
      _friends = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading friends: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadFriendRequests() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/social/friend_requests/');
      _friendRequests = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading friend requests: $e');
    }
  }
  
  Future<void> sendFriendRequest(String userId) async {
    try {
      final apiService = ApiService();
      await apiService.post('/social/send_request/', data: {
        'user_id': userId,
      });
      await loadFriendRequests();
    } catch (e) {
      print('Error sending friend request: $e');
      rethrow;
    }
  }
  
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final apiService = ApiService();
      await apiService.post('/social/accept_request/', data: {
        'request_id': requestId,
      });
      await loadFriends();
      await loadFriendRequests();
    } catch (e) {
      print('Error accepting friend request: $e');
      rethrow;
    }
  }
  
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      final apiService = ApiService();
      await apiService.post('/social/reject_request/', data: {
        'request_id': requestId,
      });
      await loadFriendRequests();
    } catch (e) {
      print('Error rejecting friend request: $e');
      rethrow;
    }
  }
  
  Future<void> removeFriend(String friendId) async {
    try {
      final apiService = ApiService();
      await apiService.delete('/social/remove_friend/', data: {
        'friend_id': friendId,
      });
      await loadFriends();
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }
  
  Future<void> loadFeed({int limit = 50}) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/social/feed/?limit=$limit');
      _feed = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading feed: $e');
    }
  }
  
  Future<void> loadLeaderboard({String period = 'weekly', int limit = 50}) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/social/leaderboard/?period=$period&limit=$limit');
      _leaderboard = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading leaderboard: $e');
      _leaderboard = [];
    }
  }
  
  Future<void> loadChallenges() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/social/challenges/');
      _challenges = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading challenges: $e');
    }
  }
  
  Future<void> loadMyChallenges() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/social/my_challenges/');
      _myChallenges = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      print('Error loading my challenges: $e');
    }
  }
  
  Future<void> joinChallenge(String challengeId) async {
    try {
      final apiService = ApiService();
      await apiService.post('/social/join_challenge/', data: {
        'challenge_id': challengeId,
      });
      await loadMyChallenges();
    } catch (e) {
      print('Error joining challenge: $e');
      rethrow;
    }
  }
  
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/social/search/?q=$query');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }
}