// lib/providers/payment_provider.dart
import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class PaymentProvider extends ChangeNotifier {
  late ApiService _apiService;
  bool _isSubscribed = false;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = false;
  String? _error;
  
  bool get isSubscribed => _isSubscribed;
  List<Map<String, dynamic>> get plans => _plans;
  List<Map<String, dynamic>> get paymentHistory => _paymentHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }
  
  Future<void> loadPlans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/payments/plans/');
      _plans = List<Map<String, dynamic>>.from(response);
      print('✅ Loaded ${_plans.length} payment plans');
    } catch (e) {
      _error = e.toString();
      print('Error loading plans: $e');
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadPaymentHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/payments/payment_history/');
      _paymentHistory = List<Map<String, dynamic>>.from(response['transactions'] ?? []);
      print('✅ Loaded ${_paymentHistory.length} payment transactions');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading payment history: $e');
      
      // Rethrow session errors for UI handling
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<Map<String, dynamic>> createSubscription(String priceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/payments/create_subscription/', data: {
        'price_id': priceId,
      });
      _isSubscribed = true;
      print('✅ Subscription created successfully');
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      print('Error creating subscription: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> cancelSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _apiService.post('/payments/cancel_subscription/');
      _isSubscribed = false;
      print('✅ Subscription cancelled successfully');
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error cancelling subscription: $e');
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> checkSubscriptionStatus() async {
    try {
      final response = await _apiService.get('/payments/subscription_status/');
      _isSubscribed = response['is_subscribed'] ?? false;
      print('✅ Subscription status: ${_isSubscribed ? 'Active' : 'Inactive'}');
      notifyListeners();
    } catch (e) {
      print('Error checking subscription status: $e');
      _error = e.toString();
      
      if (e.toString().contains('Session expired')) {
        rethrow;
      }
    }
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void reset() {
    _isSubscribed = false;
    _plans = [];
    _paymentHistory = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}