import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/auth/auth_provider.dart';
import '../core/roster_sync/roster_sync_bootstrap.dart';
// app_localizations.dart is auto-generated. Run: flutter gen-l10n
// ignore: depend_on_referenced_packages
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'router.dart';
import 'theme.dart';

class CIPApp extends ConsumerWidget {
  const CIPApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'Crew Intelligence Platform',
      debugShowCheckedModeBanner: false,

      // Routing
      routerConfig: router,

      // Theming
      theme: CIPTheme.lightTheme,
      darkTheme: CIPTheme.darkTheme,
      themeMode: ThemeMode.light,

      // Localization
      // F29: Arabic was authored (app_ar.arb, settings toggle, RTL-aware
      // screens) but supportedLocales hard-locked to English and the
      // resolution callback force-returned 'en', making the toggle a silent
      // no-op. Honor the selected locale; fall back to English for anything
      // unsupported.
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (requested, supported) {
        if (requested != null &&
            supported.any((l) => l.languageCode == requested.languageCode)) {
          return Locale(requested.languageCode);
        }
        return const Locale('en');
      },

      builder: (context, child) {
        // Enforce text scale factor limits for accessibility without breaking layout
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.85, 1.3),
            ),
          ),
          // Zero-Knowledge session behaviour (owner directive): mounting the
          // bootstrap ABOVE every route is what makes "Application Restart →
          // credentials restored from Keychain/Keystore → automatic
          // background synchronization → no additional login required"
          // actually true at runtime. Without this mount the SyncScheduler
          // exists but nothing ever starts it.
          child: RosterSyncBootstrap(child: child!),
        );
      },
    );
  }
}

// Locale provider — persisted in the Hive 'settings' box (opened in main()
// before runApp, so synchronous access here is safe).
// F29: loads the saved language on startup and writes back on every change,
// so the settings-screen toggle survives app restarts. Unknown/legacy values
// fall back to English.
final localeProvider = StateProvider<Locale>((ref) {
  ref.listenSelf((_, next) {
    Hive.box('settings').put('locale', next.languageCode);
  });
  final saved = Hive.box('settings').get('locale', defaultValue: 'en');
  return Locale(saved == 'ar' ? 'ar' : 'en');
});
