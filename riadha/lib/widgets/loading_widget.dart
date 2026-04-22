// loading_widget.dart
import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  
  const LoadingWidget({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.blue),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.greyDark,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}