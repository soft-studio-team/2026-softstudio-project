// Generated from ios/Runner/GoogleService-Info.plist
// Re-run generation after re-downloading Firebase config.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// True when real Firebase keys were pasted (not the YOUR_* placeholders).
bool get isFirebaseConfigured {
  final key = DefaultFirebaseOptions.currentPlatform.apiKey;
  return key.isNotEmpty && !key.startsWith('YOUR_');
}

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  // iOS values from GoogleService-Info.plist. Android uses the same project
  // until a separate Android app is registered (then replace android block).
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBM_zNVNXHMh7su-IsTK7QQfBffI2Cgr4Q',
    appId: '1:828519649900:ios:408f78b84de74194313e49',
    messagingSenderId: '828519649900',
    projectId: 'softstudio-wishlist-app',
    storageBucket: 'softstudio-wishlist-app.firebasestorage.app',
    iosBundleId: 'com.softstudio.wishlist',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBUilvVOTPnvnl4Be9QNOiqZyvjYPG0qv0',
    appId: '1:828519649900:android:26b03443c184ebb9313e49',
    messagingSenderId: '828519649900',
    projectId: 'softstudio-wishlist-app',
    storageBucket: 'softstudio-wishlist-app.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBM_zNVNXHMh7su-IsTK7QQfBffI2Cgr4Q',
    appId: '1:828519649900:ios:408f78b84de74194313e49',
    messagingSenderId: '828519649900',
    projectId: 'softstudio-wishlist-app',
    storageBucket: 'softstudio-wishlist-app.firebasestorage.app',
  );
}
