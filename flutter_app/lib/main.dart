import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/services/offline_cache_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useFirebaseEmulators =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: false);

  // Firebase
  await Firebase.initializeApp(
    options: useFirebaseEmulators
        ? const FirebaseOptions(
            apiKey: 'demo-api-key',
            appId: '1:1234567890:web:najm-e2e',
            messagingSenderId: '1234567890',
            projectId: 'demo-najm',
            authDomain: '127.0.0.1',
            storageBucket: 'demo-najm.appspot.com',
          )
        : DefaultFirebaseOptions.currentPlatform,
  );

  // E2E/local development can run entirely against credential-free Firebase
  // emulators. Production builds keep using the configured Firebase project.
  if (kIsWeb && useFirebaseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    FirebaseStorage.instance.useStorageEmulator('127.0.0.1', 9199);
  }

  // App Check and Crashlytics are native-only here: App Check has no web
  // provider configured (throws ArgumentError on web) and Crashlytics has no
  // web implementation. Guard them so the web build boots; mobile behaviour is
  // unchanged because kIsWeb is false there.
  if (!kIsWeb) {
    // App Check (anti-abuse)
    await FirebaseAppCheck.instance.activate(
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );

    // Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Hive local storage
  await Hive.initFlutter();
  await _registerHiveAdapters();
  await _openHiveBoxes();

  // Offline cache
  final offlineCache = OfflineCacheService();
  await offlineCache.init();

  // Notifications (native-only: flutter_local_notifications / FirebaseMessaging)
  if (!kIsWeb) {
    await NotificationService.initialize();
  }

  // Portrait on phones
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: CIPApp()));
}

Future<void> _registerHiveAdapters() async {
  // Adapters registered here after build_runner generation
  // Hive.registerAdapter(FlightLineCacheAdapter());
  // Hive.registerAdapter(LegCacheAdapter());
  // Hive.registerAdapter(BidCacheAdapter());
}

Future<void> _openHiveBoxes() async {
  await Hive.openBox('settings');
  await Hive.openBox('flightLines');
  await Hive.openBox('bids');
  await Hive.openBox('userPreferences');
  await Hive.openBox('aiSessions');
  // Phase 2 — Intelligence cache
  await Hive.openBox('intelligenceCache');
  // Phase 3 — Layover cache
  await Hive.openBox('layoverCache');
}
