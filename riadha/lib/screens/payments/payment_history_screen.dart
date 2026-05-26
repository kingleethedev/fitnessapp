import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/payment_provider.dart';

// Modern color palette - Light Blue, Yellow, White only
class PaymentHistoryColors {
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
}

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    await paymentProvider.loadPaymentHistory();
    if (mounted) setState(() {});
  }

  String _getMonthYear(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return '';
    }
  }

  double _calculateTotalPaid(List<Map<String, dynamic>> transactions) {
    double total = 0;
    for (var transaction in transactions) {
      final status = transaction['status'];
      // Updated to include PayPal success statuses
      if (status == 'SUCCEEDED' || status == 'COMPLETED' || status == 'APPROVED') {
        total += double.parse(transaction['amount'].toString());
      }
    }
    return total;
  }

  int _calculateMonthsPaid(List<Map<String, dynamic>> transactions) {
    Set<String> uniqueMonths = {};
    for (var transaction in transactions) {
      final status = transaction['status'];
      // Updated to include PayPal success statuses
      if (status == 'SUCCEEDED' || status == 'COMPLETED' || status == 'APPROVED') {
        final monthYear = _getMonthYear(transaction['created_at']);
        if (monthYear.isNotEmpty) uniqueMonths.add(monthYear);
      }
    }
    return uniqueMonths.length;
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'SUCCEEDED':
      case 'COMPLETED':
      case 'APPROVED':
        return 'Success';
      case 'PENDING':
        return 'Pending';
      case 'FAILED':
        return 'Failed';
      case 'REFUNDED':
        return 'Refunded';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SUCCEEDED':
      case 'COMPLETED':
      case 'APPROVED':
        return PaymentHistoryColors.success;
      case 'PENDING':
        return PaymentHistoryColors.warning;
      case 'FAILED':
        return PaymentHistoryColors.error;
      case 'REFUNDED':
        return PaymentHistoryColors.greyMedium;
      default:
        return PaymentHistoryColors.greyMedium;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);
    final successfulTransactions = paymentProvider.paymentHistory
        .where((t) => t['status'] == 'SUCCEEDED' || t['status'] == 'COMPLETED' || t['status'] == 'APPROVED')
        .toList();
    
    final totalPaid = _calculateTotalPaid(paymentProvider.paymentHistory);
    final monthsPaid = _calculateMonthsPaid(paymentProvider.paymentHistory);
    
    return Scaffold(
      backgroundColor: PaymentHistoryColors.offWhite,
      appBar: AppBar(
        title: const Text(
          'Payment History',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: PaymentHistoryColors.primaryBlue,
          ),
        ),
        backgroundColor: PaymentHistoryColors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: PaymentHistoryColors.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: PaymentHistoryColors.primaryBlue),
            onPressed: _loadPaymentHistory,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPaymentHistory,
        color: PaymentHistoryColors.primaryBlue,
        backgroundColor: PaymentHistoryColors.white,
        child: paymentProvider.isLoading && paymentProvider.paymentHistory.isEmpty
            ? const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(PaymentHistoryColors.accentYellow),
                  ),
                ),
              )
            : paymentProvider.paymentHistory.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      // Summary Cards
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: PaymentHistoryColors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: PaymentHistoryColors.greyLight, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: PaymentHistoryColors.lightBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.attach_money,
                                        size: 18,
                                        color: PaymentHistoryColors.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Total Spent',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: PaymentHistoryColors.greyDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${totalPaid.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: PaymentHistoryColors.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${successfulTransactions.length} payments',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: PaymentHistoryColors.greyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: PaymentHistoryColors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: PaymentHistoryColors.greyLight, width: 1),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: PaymentHistoryColors.lightBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.calendar_today,
                                        size: 18,
                                        color: PaymentHistoryColors.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Months Paid',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: PaymentHistoryColors.greyDark,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$monthsPaid',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: PaymentHistoryColors.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      monthsPaid == 1 ? 'month' : 'months',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: PaymentHistoryColors.greyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Transactions List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: paymentProvider.paymentHistory.length,
                          itemBuilder: (context, index) {
                            final transaction = paymentProvider.paymentHistory[index];
                            final status = transaction['status'];
                            final isSuccessful = status == 'SUCCEEDED' || status == 'COMPLETED' || status == 'APPROVED';
                            final isPending = status == 'PENDING';
                            final monthYear = _getMonthYear(transaction['created_at']);
                            final statusDisplay = _getStatusDisplay(status);
                            final statusColor = _getStatusColor(status);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: PaymentHistoryColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSuccessful ? PaymentHistoryColors.lightBlue : PaymentHistoryColors.greyLight,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isSuccessful ? PaymentHistoryColors.lightBlue : (isPending ? PaymentHistoryColors.softYellow : PaymentHistoryColors.error.withOpacity(0.1)),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              isSuccessful ? Icons.check : (isPending ? Icons.pending : Icons.error_outline),
                                              color: isSuccessful ? PaymentHistoryColors.primaryBlue : (isPending ? PaymentHistoryColors.darkYellow : PaymentHistoryColors.error),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '\$${transaction['amount']}',
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: PaymentHistoryColors.primaryBlue,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                monthYear,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: PaymentHistoryColors.primaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSuccessful ? PaymentHistoryColors.lightBlue : (isPending ? PaymentHistoryColors.softYellow : PaymentHistoryColors.error.withOpacity(0.1)),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          statusDisplay,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1, color: PaymentHistoryColors.greyLight),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 12,
                                        color: PaymentHistoryColors.greyMedium,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatDate(transaction['created_at']),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: PaymentHistoryColors.greyMedium,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      if (transaction['payment_type'] != null)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.payment,
                                              size: 12,
                                              color: PaymentHistoryColors.greyMedium,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              transaction['payment_type'] == 'SUBSCRIPTION' ? 'PayPal' : 'One-time',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: PaymentHistoryColors.greyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: PaymentHistoryColors.lightBlue,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.history,
              size: 50,
              color: PaymentHistoryColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Payment History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: PaymentHistoryColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your PayPal transactions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: PaymentHistoryColors.greyDark,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PaymentHistoryColors.accentYellow,
              foregroundColor: PaymentHistoryColors.darkBlue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text(
              'Start Membership',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}