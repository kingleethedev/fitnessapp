import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class PaymentProvider extends ChangeNotifier {
  bool _isSubscribed = false;
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = false;
  
  bool get isSubscribed => _isSubscribed;
  List<Map<String, dynamic>> get plans => _plans;
  List<Map<String, dynamic>> get paymentHistory => _paymentHistory;
  bool get isLoading => _isLoading;
  
  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final apiService = ApiService();
      final response = await apiService.get('/payments/plans/');
      _plans = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error loading plans: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadPaymentHistory() async {
    try {
      final apiService = ApiService();
      final response = await apiService.get('/payments/payment_history/');
      _paymentHistory = List<Map<String, dynamic>>.from(response['transactions']);
      notifyListeners();
    } catch (e) {
      print('Error loading payment history: $e');
    }
  }
  
  Future<Map<String, dynamic>> createSubscription(String priceId) async {
    try {
      final apiService = ApiService();
      final response = await apiService.post('/payments/create_subscription/', data: {
        'price_id': priceId,
      });
      _isSubscribed = true;
      notifyListeners();
      return response;
    } catch (e) {
      print('Error creating subscription: $e');
      rethrow;
    }
  }
  
  Future<void> cancelSubscription() async {
    try {
      final apiService = ApiService();
      await apiService.post('/payments/cancel_subscription/');
      _isSubscribed = false;
      notifyListeners();
    } catch (e) {
      print('Error cancelling subscription: $e');
      rethrow;
    }
  }
}