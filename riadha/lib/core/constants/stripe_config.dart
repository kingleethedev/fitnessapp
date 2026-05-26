// lib/core/constants/stripe_config.dart
class StripeConfig {
  // This will be replaced at build time or from environment
  static const String publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );
  
  static bool get isConfigured => publishableKey.isNotEmpty;
}