// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not configured yet');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBx1JqlDXt8ZsWBpmhmknnWIJdWKtC4xlo',
    appId: '1:748564464578:android:86c2e47a617a3ccadf0c5b',
    messagingSenderId: '748564464578',
    projectId: 'fitness-app-4ea15',
    storageBucket: 'fitness-app-4ea15.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBx1JqlDXt8ZsWBpmhmknnWIJdWKtC4xlo',
    appId: '1:748564464578:ios:YOUR_IOS_APP_ID',
    messagingSenderId: '748564464578',
    projectId: 'fitness-app-4ea15',
    storageBucket: 'fitness-app-4ea15.firebasestorage.app',
    iosBundleId: 'com.example.riadha', // Update to your bundle ID
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBx1JqlDXt8ZsWBpmhmknnWIJdWKtC4xlo',
    appId: '1:748564464578:macos:YOUR_MACOS_APP_ID',
    messagingSenderId: '748564464578',
    projectId: 'fitness-app-4ea15',
    storageBucket: 'fitness-app-4ea15.firebasestorage.app',
  );
}