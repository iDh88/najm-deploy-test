import 'package:firebase_core/firebase_core.dart';
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

  // Firebase
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform);

  // App Check and Crashlytics are disabled on Flutter Web local dev.
  // They can be re-enabled for production once Firebase web settings are finalized.
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
    );

    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;
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

  // Notifications are skipped on Flutter Web local dev.
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
