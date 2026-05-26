import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';
import '../../providers/payment_provider.dart';
import '../../widgets/primary_button.dart';
import 'paypal_webview_screen.dart'; // We'll create this for PayPal checkout

// Modern color palette - Light Blue, Yellow, White only
class SubscriptionColors {
  static const Color lightBlue = Color(0xFFE6F3FF);
  static const Color primaryBlue = Color(0xFF4A90D9);
  static const Color darkBlue = Color(0xFF2C5F8A);
  static const Color softYellow = Color(0xFFFFF4CC);
  static const Color accentYellow = Color(0xFFFFD633);
  static const Color darkYellow = Color(0xFFCCAA00);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8FAFC);
  static const Color greyLight = Color(0xFFE2E8F0);
  static const Color greyMedium = Color(0xFF94A3B8);
  static const Color greyDark = Color(0xFF475569);
  static const Color success = Color(0xFF4A90D9);
  static const Color error = Color(0xFFE57373);
  static const Color warning = Color(0xFFFFD633);
  static const Color white70 = Color(0xB3FFFFFF);
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isProcessing = false;
  String? _pendingPaymentStatus;
  Map<String, dynamic>? _pendingTransaction;
  
  Timer? _pendingPaymentTimer;
  DateTime? _pendingPaymentStartTime;
  int _pendingElapsedSeconds = 0;
  
  static const int _timeoutMinutes = 5;
  static const int _timeoutSeconds = _timeoutMinutes * 60;
  static const int _warningThresholdSeconds = 3 * 60;
  
  static const String _pendingPaymentKey = 'pending_payment_start_time';
  static const String _pendingTransactionIdKey = 'pending_transaction_id';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadPendingPaymentFromStorage();
  }

  @override
  void dispose() {
    _pendingPaymentTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPendingPaymentFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStartTime = prefs.getString(_pendingPaymentKey);
    final savedTransactionId = prefs.getString(_pendingTransactionIdKey);
    
    if (savedStartTime != null && savedTransactionId != null) {
      final startTime = DateTime.parse(savedStartTime);
      final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
      
      if (elapsedSeconds < _timeoutSeconds) {
        final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
        await paymentProvider.loadPaymentHistory();
        
        Map<String, dynamic>? pendingTransaction;
        for (var transaction in paymentProvider.paymentHistory) {
          if (transaction['id'] == savedTransactionId && transaction['status'] == 'PENDING') {
            pendingTransaction = transaction;
            break;
          }
        }
        
        if (pendingTransaction != null && mounted) {
          setState(() {
            _pendingPaymentStatus = 'PENDING';
            _pendingTransaction = pendingTransaction;
            _pendingPaymentStartTime = startTime;
            _pendingElapsedSeconds = elapsedSeconds;
          });
          _startPendingPaymentTimer();
          return;
        }
      }
      await prefs.remove(_pendingPaymentKey);
      await prefs.remove(_pendingTransactionIdKey);
    }
    
    await _checkForPendingPayments();
  }

  Future<void> _savePendingPaymentToStorage() async {
    if (_pendingTransaction != null && _pendingPaymentStartTime != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPaymentKey, _pendingPaymentStartTime!.toIso8601String());
      await prefs.setString(_pendingTransactionIdKey, _pendingTransaction!['id']);
    }
  }

  Future<void> _clearPendingPaymentFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingPaymentKey);
    await prefs.remove(_pendingTransactionIdKey);
  }

  Future<void> _loadData() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    await paymentProvider.loadPlan();
    await paymentProvider.loadStatus();
    await paymentProvider.loadPaymentHistory();
    if (mounted) setState(() {});
  }

  void _startPendingPaymentTimer() {
    if (_pendingPaymentStartTime == null) return;
    
    _pendingPaymentTimer?.cancel();
    
    _pendingPaymentTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_pendingPaymentStatus == 'PENDING' && _pendingPaymentStartTime != null && mounted) {
        final elapsedSeconds = DateTime.now().difference(_pendingPaymentStartTime!).inSeconds;
        _pendingElapsedSeconds = elapsedSeconds;
        
        if (mounted) setState(() {});
        
        if (elapsedSeconds >= _timeoutSeconds) {
          _markPendingPaymentAsFailed();
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _markPendingPaymentAsFailed() async {
    if (_pendingTransaction == null) return;
    
    if (mounted) {
      setState(() {
        _pendingPaymentStatus = 'FAILED';
        if (_pendingTransaction != null) {
          _pendingTransaction!['status'] = 'FAILED';
        }
      });
    }
    
    _pendingPaymentTimer?.cancel();
    await _clearPendingPaymentFromStorage();
  }

  Future<void> _checkForPendingPayments() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    await paymentProvider.loadPaymentHistory();
    
    final transactions = paymentProvider.paymentHistory;
    if (transactions.isNotEmpty && mounted) {
      Map<String, dynamic>? pendingTransaction;
      Map<String, dynamic>? failedTransaction;
      
      for (var transaction in transactions) {
        final status = transaction['status'];
        if (status == 'PENDING') {
          pendingTransaction = transaction;
          break;
        } else if (status == 'FAILED') {
          failedTransaction = transaction;
          break;
        }
      }
      
      setState(() {
        if (pendingTransaction != null) {
          _pendingPaymentStatus = 'PENDING';
          _pendingTransaction = pendingTransaction;
          _pendingPaymentStartTime = DateTime.now();
          _savePendingPaymentToStorage();
          _startPendingPaymentTimer();
        } else if (failedTransaction != null) {
          _pendingPaymentStatus = 'FAILED';
          _pendingTransaction = failedTransaction;
          _clearPendingPaymentFromStorage();
        } else {
          _pendingPaymentStatus = null;
          _pendingTransaction = null;
          _clearPendingPaymentFromStorage();
        }
      });
    }
  }

  String _formatExpiryDate(DateTime? date) {
    if (date == null) return 'No active subscription';
    final now = DateTime.now();
    if (date.isBefore(now)) return 'Expired';
    
    final daysLeft = date.difference(now).inDays;
    if (daysLeft <= 0) return 'Expires today';
    if (daysLeft == 1) return 'Expires tomorrow';
    return 'Expires in $daysLeft days';
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SubscriptionColors.lightBlue,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: SubscriptionColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SubscriptionColors.darkBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartTrial() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final status = paymentProvider.status;
    
    if (status?['has_access'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active subscription'),
          backgroundColor: SubscriptionColors.error,
        ),
      );
      return;
    }
    
    setState(() => _isProcessing = true);

    try {
      final result = await paymentProvider.startTrial();
      
      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('7-day free trial started'),
            backgroundColor: SubscriptionColors.success,
          ),
        );
        await paymentProvider.loadStatus();
        if (mounted) setState(() {});
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to start trial'),
            backgroundColor: SubscriptionColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${paymentProvider.error ?? e.toString()}'),
            backgroundColor: SubscriptionColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSubscribe() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    final status = paymentProvider.status;
    
    if (status?['has_access'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active subscription'),
          backgroundColor: SubscriptionColors.error,
        ),
      );
      return;
    }
    
    if (_pendingPaymentStatus == 'PENDING') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have a pending payment'),
          backgroundColor: SubscriptionColors.warning,
        ),
      );
      return;
    }
    
    setState(() => _isProcessing = true);

    try {
      // Create PayPal payment
      final result = await paymentProvider.createPayPalPayment();
      
      if (result['approval_url'] != null && mounted) {
        // Navigate to PayPal WebView for approval
        final approvalResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PayPalWebViewScreen(
              approvalUrl: result['approval_url'],
              paymentId: result['payment_id'],
            ),
          ),
        );
        
        if (approvalResult == true && mounted) {
          // Payment was approved, execute it
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Activating subscription...'),
              backgroundColor: SubscriptionColors.success,
            ),
          );
          
          await paymentProvider.loadPaymentHistory();
          await paymentProvider.loadStatus();
          await _checkForPendingPayments();
          
          if (mounted) setState(() {});
        } else if (approvalResult == false && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled or failed'),
              backgroundColor: SubscriptionColors.error,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Subscription failed'),
            backgroundColor: SubscriptionColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${paymentProvider.error ?? e.toString()}'),
            backgroundColor: SubscriptionColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final status = paymentProvider.status;
    
    if (paymentProvider.isLoading && status == null) {
      return const Scaffold(
        backgroundColor: SubscriptionColors.white,
        body: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(SubscriptionColors.accentYellow),
            ),
          ),
        ),
      );
    }
    
    final hasAccess = status?['has_access'] ?? false;
    final isSubscribed = status?['is_subscribed'] ?? false;
    final isOnTrial = status?['is_trial_active'] ?? false;
    final trialDaysRemaining = status?['trial_days_remaining'] ?? 0;
    final hasUsedTrial = status?['has_used_trial'] ?? false;
    final subscriptionEndDate = status?['subscription_end_date'] != null 
        ? DateTime.tryParse(status?['subscription_end_date']) 
        : null;
    
    final hasActiveSubscription = hasAccess || isSubscribed;
    
    return Scaffold(
      backgroundColor: SubscriptionColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Membership',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: SubscriptionColors.primaryBlue,
          ),
        ),
        backgroundColor: SubscriptionColors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: SubscriptionColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: SubscriptionColors.primaryBlue),
            onPressed: () => Navigator.pushNamed(context, '/payment-history'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: SubscriptionColors.primaryBlue),
            onPressed: () async {
              await paymentProvider.loadStatus();
              await paymentProvider.loadPaymentHistory();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section with Logo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: SubscriptionColors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // App Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: SubscriptionColors.lightBlue,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.fitness_center,
                            size: 50,
                            color: SubscriptionColors.primaryBlue,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    hasActiveSubscription ? 'Premium Member' : 'Join Riadha',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: SubscriptionColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasActiveSubscription 
                        ? (subscriptionEndDate != null ? _formatExpiryDate(subscriptionEndDate) : 'Unlock all premium features')
                        : 'Transform your fitness journey today',
                    style: const TextStyle(
                      fontSize: 13,
                      color: SubscriptionColors.greyDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Main Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pending Status
                  if (_pendingPaymentStatus == 'PENDING' && !hasActiveSubscription)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SubscriptionColors.softYellow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SubscriptionColors.accentYellow, width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SubscriptionColors.accentYellow.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.pending, color: SubscriptionColors.darkYellow),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Processing',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: SubscriptionColors.darkYellow,
                                  ),
                                ),
                                Text(
                                  'Your payment is being processed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SubscriptionColors.darkYellow.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_pendingPaymentStatus == 'PENDING' && !hasActiveSubscription)
                    const SizedBox(height: 20),
                  
                  if (_pendingPaymentStatus == 'FAILED' && !hasActiveSubscription)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: SubscriptionColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SubscriptionColors.error.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: SubscriptionColors.error.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.error_outline, color: SubscriptionColors.error),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Failed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: SubscriptionColors.error,
                                  ),
                                ),
                                Text(
                                  _pendingTransaction?['error_message'] ?? 'Please try again',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SubscriptionColors.error.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _handleSubscribe,
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: SubscriptionColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_pendingPaymentStatus == 'FAILED' && !hasActiveSubscription)
                    const SizedBox(height: 20),
                  
                  // Benefits Section
                  const Text(
                    'Premium Benefits',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: SubscriptionColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureItem(Icons.fitness_center, 'Personalized workout plans'),
                  _buildFeatureItem(Icons.bar_chart, 'Track your progress'),
                  _buildFeatureItem(Icons.restaurant, 'Custom meal plans'),
                  _buildFeatureItem(Icons.people, 'Community challenges'),
                  _buildFeatureItem(Icons.emoji_events, 'Achievement badges'),
                  
                  const SizedBox(height: 28),
                  
                  // Action Section - Only show subscription options
                  if (hasActiveSubscription)
                    Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: SubscriptionColors.lightBlue,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 48,
                                color: SubscriptionColors.primaryBlue,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'You are a Premium Member',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: SubscriptionColors.primaryBlue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subscriptionEndDate != null 
                                    ? _formatExpiryDate(subscriptionEndDate)
                                    : 'Enjoy all premium features',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SubscriptionColors.greyDark,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: SubscriptionColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: InkWell(
                                  onTap: () => Navigator.pushNamed(context, '/payment-history'),
                                  borderRadius: BorderRadius.circular(14),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.history, color: SubscriptionColors.primaryBlue, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'View Payment History',
                                        style: TextStyle(
                                          color: SubscriptionColors.primaryBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else if (isOnTrial && !hasActiveSubscription)
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isProcessing ? null : _handleSubscribe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SubscriptionColors.accentYellow,
                              foregroundColor: SubscriptionColors.darkBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _isProcessing ? 'Processing...' : 'Subscribe Now (\$${paymentProvider.plan?['amount'] ?? '9.99'}/month)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: SubscriptionColors.lightBlue,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(context, '/payment-history'),
                            borderRadius: BorderRadius.circular(14),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, color: SubscriptionColors.primaryBlue, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Payment History',
                                  style: TextStyle(
                                    color: SubscriptionColors.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Your trial ends in $trialDaysRemaining day${trialDaysRemaining != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: SubscriptionColors.greyDark,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  else if (!hasUsedTrial && !hasActiveSubscription)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: SubscriptionColors.primaryBlue,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Start Free Trial',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: SubscriptionColors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '7 days free',
                                    style: TextStyle(
                                      color: SubscriptionColors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: SubscriptionColors.accentYellow,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Then \$${paymentProvider.plan?['amount'] ?? '9.99'}/month',
                                      style: const TextStyle(
                                        color: SubscriptionColors.darkBlue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isProcessing ? null : _handleStartTrial,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SubscriptionColors.accentYellow,
                                    foregroundColor: SubscriptionColors.darkBlue,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    _isProcessing ? 'Processing...' : 'Start Free Trial',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No payment required • Cancel anytime',
                                style: TextStyle(
                                  color: SubscriptionColors.white.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Terms
                  Center(
                    child: Text(
                      'PayPal is our payment processor. By continuing, you agree to our Terms of Service',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: SubscriptionColors.greyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}