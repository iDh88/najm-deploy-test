// firebase_options.dart
// ─────────────────────────────────────────────────────────────────────────────
// AUTO-GENERATED — DO NOT EDIT MANUALLY
//
// Run the following to regenerate for your Firebase project:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
//
// This file is committed as a TEMPLATE only.
// Replace all placeholder values with your actual Firebase project config.
// NEVER commit real API keys to public repositories.
// Store sensitive values in a CI/CD secret and inject at build time.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBisDxUrNuMwc-zyYuX4wlelbIIt3C_K7M',
    appId: '1:266574565630:web:7d850bc0885bfa7939d5af',
    messagingSenderId: '266574565630',
    projectId: 'najm-dev-9159c',
    authDomain: 'najm-dev-9159c.firebaseapp.com',
    storageBucket: 'najm-dev-9159c.firebasestorage.app',
  );

  // ── Web (Firebase Hosting companion) ──────────────────────────────────────

  // ── Android ───────────────────────────────────────────────────────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_PROJECT_ID.appspot.com',
  );

  // ── iOS ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_WITH_IOS_API_KEY',
    appId: 'REPLACE_WITH_IOS_APP_ID',
    messagingSenderId: 'REPLACE_WITH_SENDER_ID',
    projectId: 'REPLACE_WITH_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_PROJECT_ID.appspot.com',
    iosBundleId: 'app.cip.najm',
  );
}