import 'package:flutter/material.dart';
import '../core/services/api_service.dart';

class PaymentProvider extends ChangeNotifier {
  late ApiService _apiService;
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = false;
  String? _error;
  
  Map<String, dynamic>? get plan => _plan;
  Map<String, dynamic>? get status => _status;
  List<Map<String, dynamic>> get paymentHistory => _paymentHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }
  
  Future<void> loadPlan() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.get('/payments/plan/');
      _plan = response;
      print('✅ Loaded subscription plan');
    } catch (e) {
      _error = e.toString();
      print('Error loading plan: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadStatus() async {
    try {
      final response = await _apiService.get('/payments/status/');
      _status = response;
      print('✅ Subscription status: hasAccess=${response['has_access']}');
      notifyListeners();
    } catch (e) {
      print('Error loading status: $e');
      _error = e.toString();
    }
  }
  
  Future<Map<String, dynamic>> startTrial() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/payments/start_trial/');
      await loadStatus();
      print('✅ Trial started successfully');
      return response;
    } catch (e) {
      _error = e.toString();
      print('Error starting trial: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // CREATE PAYPAL PAYMENT (One-time payment)
  Future<Map<String, dynamic>> createPayPalPayment() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('💰 Creating PayPal payment...');
      final response = await _apiService.post('/payments/create_payment/');
      print('✅ PayPal payment created: ${response['payment_id']}');
      print('🔗 Approval URL: ${response['approval_url']}');
      return response;
    } catch (e) {
      _error = e.toString();
      print('❌ Error creating PayPal payment: $e');
      return {'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // CREATE PAYPAL SUBSCRIPTION (Recurring)
  Future<Map<String, dynamic>> createPayPalSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('💰 Creating PayPal subscription...');
      final response = await _apiService.post('/payments/create_subscription/');
      print('✅ PayPal subscription created: ${response['subscription_id']}');
      print('🔗 Approval URL: ${response['approval_url']}');
      return response;
    } catch (e) {
      _error = e.toString();
      print('❌ Error creating PayPal subscription: $e');
      return {'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // EXECUTE PAYPAL PAYMENT AFTER APPROVAL
  Future<Map<String, dynamic>> executePayPalPayment({
    required String paymentId,
    required String payerId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('💰 Executing PayPal payment: $paymentId');
      final response = await _apiService.post(
        '/payments/execute_payment/',
        data: {
          'payment_id': paymentId,
          'payer_id': payerId,
        },
      );
      
      if (response['success'] == true) {
        print('✅ Payment executed successfully');
        await loadStatus();
        await loadPaymentHistory();
      } else {
        print('⚠️ Payment execution returned: ${response['success']}');
      }
      
      return response;
    } catch (e) {
      _error = e.toString();
      print('❌ Error executing payment: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // CANCEL SUBSCRIPTION
  Future<Map<String, dynamic>> cancelSubscription() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _apiService.post('/payments/cancel_subscription/');
      await loadStatus();
      print('✅ Subscription cancelled');
      return response;
    } catch (e) {
      _error = e.toString();
      print('Error cancelling subscription: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // LOAD PAYMENT HISTORY
  Future<void> loadPaymentHistory() async {
    try {
      final response = await _apiService.get('/payments/payment_history/');
      _paymentHistory = List<Map<String, dynamic>>.from(response['transactions'] ?? []);
      print('✅ Loaded ${_paymentHistory.length} payment transactions');
      notifyListeners();
    } catch (e) {
      print('Error loading payment history: $e');
      _error = e.toString();
    }
  }
  
  // LEGACY METHODS (kept for backward compatibility - DEPRECATED)
  @Deprecated('Use createPayPalPayment() or createPayPalSubscription() instead')
  Future<Map<String, dynamic>> createPaymentIntent() async {
    print('⚠️ createPaymentIntent() is deprecated. Use createPayPalPayment() or createPayPalSubscription()');
    return await createPayPalPayment();
  }
  
  @Deprecated('Use executePayPalPayment() instead')
  Future<Map<String, dynamic>> confirmPayment(String paymentId) async {
    print('⚠️ confirmPayment() is deprecated. Use executePayPalPayment() instead');
    return await executePayPalPayment(paymentId: paymentId, payerId: '');
  }
  
  @Deprecated('Use createPayPalSubscription() instead')
  Future<Map<String, dynamic>> subscribe() async {
    print('⚠️ subscribe() is deprecated. Use createPayPalSubscription()');
    return await createPayPalSubscription();
  }
  
  // =========================
  // HELPER GETTERS
  // =========================
  bool get hasAccess => _status?['has_access'] ?? false;
  bool get isOnTrial => _status?['is_trial_active'] ?? false;
  int get trialDaysRemaining => _status?['trial_days_remaining'] ?? 0;
  bool get isSubscribed => _status?['is_subscribed'] ?? false;
  bool get hasPaymentHistory => _paymentHistory.isNotEmpty;
  bool get hasPendingPayment => _paymentHistory.any((t) => t['status'] == 'PENDING');
  
  Map<String, dynamic>? get pendingPayment {
    try {
      return _paymentHistory.firstWhere((t) => t['status'] == 'PENDING');
    } catch (e) {
      return null;
    }
  }
  
  Map<String, dynamic>? get latestPayment {
    if (_paymentHistory.isEmpty) return null;
    return _paymentHistory.first;
  }
  
  double get totalSpent {
    double total = 0;
    for (var transaction in _paymentHistory) {
      if (transaction['status'] == 'SUCCEEDED' || transaction['status'] == 'COMPLETED') {
        total += double.parse(transaction['amount'].toString());
      }
    }
    return total;
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void reset() {
    _plan = null;
    _status = null;
    _paymentHistory = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}