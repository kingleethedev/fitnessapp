import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import '../core/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final firebase.FirebaseAuth _firebaseAuth = firebase.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _authError;
  
  final _logoutController = StreamController<void>.broadcast();
  Stream<void> get onLogout => _logoutController.stream;
  
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get authError => _authError;
  
  AuthProvider({required ApiService apiService}) : _apiService = apiService {
    _checkAuthStatus();
  }
  
  // =========================
  // INITIALIZATION
  // =========================
  
  Future<void> _checkAuthStatus() async {
    print('🔐 Checking auth status...');
    final prefs = await SharedPreferences.getInstance();
    
    final token = prefs.getString('access_token');
    
    if (token != null) {
      print('✅ Token found, user is authenticated');
      _isAuthenticated = true;
      await loadUserProfile();
    } else {
      print('❌ No token found');
      _isAuthenticated = false;
      await _checkFirebaseSession();
    }
    notifyListeners();
  }
  
  Future<void> _checkFirebaseSession() async {
    try {
      final firebase.User? firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        print('🔥 Found existing Firebase user, attempting to sync...');
        final idToken = await firebaseUser.getIdToken();
        if (idToken != null) {
          await authenticateWithFirebase(idToken);
        }
      }
    } catch (e) {
      print('❌ Error checking Firebase session: $e');
    }
  }
  
  // =========================
  // USER PROFILE
  // =========================
  
  Future<void> loadUserProfile() async {
    print('📱 Loading user profile...');
    try {
      final response = await _apiService.get('/users/profile/');
      print('✅ Profile loaded: ${response['username']}');
      _currentUser = response;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', response['onboarding_completed'] ?? false);
      
      notifyListeners();
    } catch (e) {
      print('❌ Error loading profile: $e');
      if (e.toString().contains('401')) {
        await logout();
      }
      rethrow;
    }
  }
  
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    print('📝 Updating profile: $updates');
    _setLoading(true);
    
    try {
      await _apiService.patch('/users/update_profile/', data: updates);
      await loadUserProfile();
      print('✅ Profile updated successfully');
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  // =========================
  // EMAIL/PASSWORD AUTH
  // =========================
  
  Future<bool> login(String email, String password) async {
    print('🔑 Attempting login with email: $email');
    _setLoading(true);
    _authError = null;
    
    try {
      final response = await _apiService.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });
      
      if (response.containsKey('access') && response.containsKey('refresh')) {
        await _apiService.saveTokens(response['access'], response['refresh']);
        _isAuthenticated = true;
        await loadUserProfile();
        _setLoading(false);
        print('✅ Login successful!');
        return true;
      } else {
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print('❌ Login error: $e');
      _authError = e.toString();
      _setLoading(false);
      return false;
    }
  }
  
  Future<bool> register(Map<String, dynamic> userData) async {
    print('📝 Registering new user: ${userData['email']}');
    _setLoading(true);
    _authError = null;
    
    try {
      final response = await _apiService.post('/auth/register/', data: {
        'username': userData['username'],
        'email': userData['email'],
        'password': userData['password'],
      });
      
      if (response.containsKey('access') && response.containsKey('refresh')) {
        await _apiService.saveTokens(response['access'], response['refresh']);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', false);
        
        _isAuthenticated = true;
        _setLoading(false);
        print('✅ Registration successful!');
        return true;
      } else {
        _setLoading(false);
        return false;
      }
    } catch (e) {
      print('❌ Registration error: $e');
      _authError = e.toString();
      _setLoading(false);
      return false;
    }
  }
  
  // =========================
  // FIREBASE AUTH
  // =========================
  
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _authError = null;
    
    try {
      await _googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _setLoading(false);
        return false;
      }
      
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      final credential = firebase.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final firebase.UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);
      
      final idToken = await userCredential.user!.getIdToken();
      if (idToken == null) {
        throw Exception('Failed to get ID token');
      }
      
      final success = await authenticateWithFirebase(idToken, provider: 'GOOGLE');
      
      _setLoading(false);
      return success;
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      _authError = e.toString();
      _setLoading(false);
      return false;
    }
  }
  
  Future<bool> authenticateWithFirebase(String idToken, {String provider = 'FIREBASE'}) async {
    _setLoading(true);
    _authError = null;
    
    try {
      final response = await _apiService.firebaseAuth(idToken, provider: provider);
      
      if (response.containsKey('access') && response.containsKey('refresh')) {
        await _apiService.saveTokens(response['access'], response['refresh']);
        _isAuthenticated = true;
        _currentUser = response['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', _currentUser?['onboarding_completed'] ?? false);
        
        _setLoading(false);
        print('✅ Firebase authentication successful');
        return true;
      } else {
        throw Exception('Invalid response from server');
      }
    } catch (e) {
      print('❌ Firebase authentication error: $e');
      _authError = e.toString();
      _setLoading(false);
      return false;
    }
  }
  
  Future<bool> checkFirebaseSession() async {
    try {
      final firebase.User? firebaseUser = _firebaseAuth.currentUser;
      return firebaseUser != null;
    } catch (e) {
      print('❌ Error checking Firebase session: $e');
      return false;
    }
  }
  
  Future<bool> syncFirebaseSession() async {
    try {
      final firebase.User? firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) return false;
      
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) return false;
      
      return await authenticateWithFirebase(idToken);
    } catch (e) {
      print('❌ Error syncing Firebase session: $e');
      return false;
    }
  }
  
  // =========================
  // ONBOARDING
  // =========================
  
  Future<void> completeOnboarding(Map<String, dynamic> onboardingData) async {
    print('📋 Completing onboarding with: $onboardingData');
    _setLoading(true);
    
    try {
      final response = await _apiService.post('/users/complete_onboarding/', data: onboardingData);
      print('📥 Onboarding response: $response');
      
      if (response['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('onboarding_completed', true);
        await loadUserProfile();
        print('✅ Onboarding completed successfully');
      } else {
        print('❌ Onboarding failed: ${response['errors']}');
        throw Exception(response['errors'] ?? 'Onboarding failed');
      }
    } catch (e) {
      print('❌ Error completing onboarding: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    print('📋 Onboarding status: $completed');
    return completed;
  }
  
  // =========================
  // LOGOUT
  // =========================
  
  Future<void> logout() async {
    print('🚪 Logging out user');
    
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      print('⚠️ Error signing out from Firebase: $e');
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('onboarding_completed');
    
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
    
    _logoutController.add(null);
    print('✅ Logout complete');
  }
  
  // =========================
  // HELPERS
  // =========================
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _logoutController.close();
    super.dispose();
  }
}