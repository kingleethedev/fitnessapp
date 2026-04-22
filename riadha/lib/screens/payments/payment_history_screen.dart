// payment_history_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Payment History'),
      ),
      body: const Center(
        child: Text('Payment History - Coming Soon'),
      ),
    );
  }
}