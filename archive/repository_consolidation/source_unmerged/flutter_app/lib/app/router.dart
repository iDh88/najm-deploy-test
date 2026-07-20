import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_provider.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/bids/bids_screen.dart';
import '../features/home/home_screen.dart';
import '../features/lines/line_detail_screen.dart';
import '../features/lines/lines_screen.dart';
import '../features/onboarding/disclaimer_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/profile_setup_screen.dart';
import '../features/legal/legal_document_screen.dart';
import '../features/profile/preferences_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/roster_sources_screens.dart';
import '../features/profile/salary_calculator_screen.dart';
import '../features/trades/trade_detail_screen.dart';
import '../features/trades/trade_initiate_screen.dart';
import '../features/trades/trade_search_screen.dart';
import '../features/trades/trades_screen.dart' hide TradeDetailScreen, TradeInitiateScreen;
import '../shared/widgets/main_shell.dart';

// Phase 2 — PDF Intelligence
import '../features/intelligence/screens/intelligence_hub_screen.dart';
import '../features/intelligence/screens/line_dashboard_screen.dart';
import '../features/intelligence/screens/pairing_detail_screen.dart';
import '../features/intelligence/screens/upload_search_comparison_screens.dart';

// Phase 3 — Layover Intelligence
import '../features/layover/screens/cities_hub_screen.dart';
import '../features/layover/screens/city_detail_screen.dart';
import '../features/layover/screens/add_recommendation_screen.dart';
import '../features/layover/screens/recommendation_detail_screen.dart';
import '../features/layover/screens/saved_screen.dart';

// Trade Recommendation Engine
import '../features/trades/recommendation/trade_search_screen.dart'
    as trec;
import '../features/trades/recommendation/preference_insights_screen.dart';

// Rest & Legality Engine
import '../features/rest_legality/screens/rest_calculator_screen.dart';
import '../features/rest_legality/screens/trade_legality_screen.dart';

// Knowledge Engine — Operational Knowledge Management
import '../features/admin/knowledge_center/screens/knowledge_center_screen.dart';
import '../features/admin/knowledge_center/screens/upload_document_screen.dart';
import '../features/admin/knowledge_center/screens/document_detail_screen.dart';
import '../features/assistant/ask_operations_screen.dart';

// Subscription System
import '../features/subscription/screens/upgrade_screen.dart';
import '../features/subscription/screens/account_history_screen.dart';
import '../features/subscription/screens/referral_screen.dart';
import '../features/admin/subscription_admin/screens/subscription_control_panel_screen.dart';
import '../features/admin/subscription_admin/screens/plan_editor_screen.dart';
import '../features/admin/subscription_admin/screens/user_subscription_lookup_screen.dart';
import '../features/admin/subscription_admin/screens/promo_campaign_screen.dart';

// Route name constants
class Routes {
  static const splash = '/';
  static const disclaimer = '/disclaimer';
  static const onboarding = '/onboarding';
  static const profileSetup = '/profile-setup';
  static const home = '/home';
  static const lines = '/lines';
  static const lineDetail = '/lines/:lineId';
  static const bids = '/bids';
  static const trades = '/trades';
  static const tradeDetail = '/trades/:tradeId';
  static const tradeInitiate = '/trades/new';
  static const assistant = '/assistant';
  static const profile = '/profile';
  static const settings = '/settings';
  static const rosterSources = '/settings/roster-sources';
  static const rosterSourceConnect =
      '/settings/roster-sources/:providerId/connect';
  static const rosterSourceStatus =
      '/settings/roster-sources/:providerId/status';
  static const salaryCalculator = '/salary-calculator';
  static const subscription = '/subscription';
  static const upgrade = '/subscription/upgrade';
  static const accountHistory = '/subscription/account-history';
  static const referral = '/subscription/referral';

  static const adminSubscription = '/admin/subscription';
  static const adminPlanEditor = '/admin/subscription/plans/:tier';
  static const adminSubscriptionUsers = '/admin/subscription/users';
  static const adminReferralCampaign = '/admin/subscription/referral';

  static const pendingApproval = '/pending-approval';

  // ── Phase 2: PDF Intelligence ─────────────────────────────────────────────
  static const intelligence        = '/intelligence';
  static const intelligenceUpload  = '/intelligence/upload';
  static const intelligenceSearch  = '/intelligence/search';
  static const intelligenceCompare = '/intelligence/compare';
  static const lineAnalysis        = '/intelligence/lines/:lineId';
  static const pairingDetail       = '/intelligence/pairings/:pairingId';

  // ── Phase 3: Layover Intelligence ─────────────────────────────────────────
  static const layover         = '/layover';
  static const layoverSaved    = '/layover/saved';
  static const layoverCity     = '/layover/:cityId';
  static const layoverAdd      = '/layover/:cityId/add';
  static const recommendation  = '/layover/rec/:recId';

  // ── Trade Recommendation ──────────────────────────────────────────────────
  static const tradeRecommend   = '/trades/recommend';
  static const tradePreferences = '/trades/preferences';

  // ── Rest & Legality Engine ────────────────────────────────────────────────
  static const restCalculator = '/rest/calculator';
  static const tradeLegality  = '/rest/trade';

  // ── Knowledge Engine ──────────────────────────────────────────────────────
  static const knowledgeCenter = '/admin/knowledge';
  static const knowledgeUpload = '/admin/knowledge/upload';
  static const knowledgeDetail = '/admin/knowledge/:documentId';
  static const askOperations   = '/assistant/ask-ops';

  // ── Profile: preferences, legal, release notes ────────────────────────────
  // The legal tiles used to point at https://cip.app/privacy and /terms — a
  // domain that does not exist. The real documents ship in assets/legal/ and
  // now render offline, in-app.
  static const linePreferences = '/profile/preferences';
  static const legalTerms      = '/legal/terms';
  static const legalPrivacy    = '/legal/privacy';
  static const releaseNotes    = '/about/release-notes';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // Read the latest auth state without rebuilding (and therefore resetting)
      // the entire router whenever Firebase emits. Screen-level auth actions
      // already navigate explicitly, while SplashScreen handles initial auth.
      final isAuthenticated = ref.read(authStateProvider).valueOrNull != null;
      final isOnboarding = state.matchedLocation == Routes.disclaimer ||
          state.matchedLocation == Routes.onboarding ||
          state.matchedLocation == Routes.profileSetup;

      if (!isAuthenticated && !isOnboarding && state.matchedLocation != Routes.splash) {
        return Routes.disclaimer;
      }
      if (isAuthenticated && isOnboarding) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.linePreferences,
        builder: (context, state) => const PreferencesScreen(),
      ),
      GoRoute(
        path: Routes.legalTerms,
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Terms of Service',
          assetPath: 'assets/legal/terms-of-service.md',
        ),
      ),
      GoRoute(
        path: Routes.legalPrivacy,
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Privacy Policy',
          assetPath: 'assets/legal/privacy-policy.md',
        ),
      ),
      GoRoute(
        path: Routes.releaseNotes,
        builder: (context, state) => const LegalDocumentScreen(
          title: 'Release Notes',
          assetPath: 'assets/legal/release-notes.md',
        ),
      ),
      GoRoute(
        path: Routes.disclaimer,
        builder: (context, state) => const DisclaimerScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/pending-approval',
        builder: (context, state) => const PendingApprovalScreen(),
      ),

      // Main shell with bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: Routes.lines,
            pageBuilder: (context, state) => const NoTransitionPage(child: LinesScreen()),
            routes: [
              GoRoute(
                path: ':lineId',
                builder: (context, state) => LineDetailScreen(
                  lineId: state.pathParameters['lineId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.bids,
            pageBuilder: (context, state) => const NoTransitionPage(child: BidsScreen()),
          ),
          GoRoute(
            path: Routes.trades,
            pageBuilder: (context, state) => const NoTransitionPage(child: TradesScreen()),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const TradeInitiateScreen(),
              ),
              GoRoute(
                path: ':tradeId',
                builder: (context, state) => TradeDetailScreen(
                  tradeId: state.pathParameters['tradeId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.assistant,
            pageBuilder: (context, state) => const NoTransitionPage(child: AssistantScreen()),
          ),
          GoRoute(
            path: Routes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: Routes.rosterSources,
            builder: (context, state) => const RosterSourcesScreen(),
          ),
          GoRoute(
            path: Routes.rosterSourceConnect,
            builder: (context, state) => RosterSourceConnectScreen(
                providerId: state.pathParameters['providerId']!),
          ),
          GoRoute(
            path: Routes.rosterSourceStatus,
            builder: (context, state) => SyncStatusScreen(
                providerId: state.pathParameters['providerId']!),
          ),

          // ── Phase 2: PDF Intelligence ─────────────────────────────────
          GoRoute(
            path: Routes.intelligence,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: IntelligenceHubScreen()),
          ),
          GoRoute(
            path: Routes.intelligenceUpload,
            builder: (_, __) => const UploadScreen(),
          ),
          GoRoute(
            path: Routes.intelligenceSearch,
            builder: (_, __) => const SearchScreen(),
          ),
          GoRoute(
            path: Routes.intelligenceCompare,
            builder: (_, __) => const ComparisonScreen(),
          ),
          GoRoute(
            path: Routes.lineAnalysis,
            builder: (_, s) => LineDashboardScreen(
                lineId: s.pathParameters['lineId']!),
          ),
          GoRoute(
            path: Routes.pairingDetail,
            builder: (_, s) => PairingDetailScreen(
              pairingId: s.pathParameters['pairingId']!,
              lineId:    s.uri.queryParameters['lineId'] ?? '',
            ),
          ),

          // ── Phase 3: Layover Intelligence ─────────────────────────────
          GoRoute(
            path: Routes.layover,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: CitiesHubScreen()),
          ),
          // F30: declared BEFORE Routes.layoverCity so '/layover/saved' is
          // not swallowed by the ':cityId' path parameter.
          GoRoute(
            path: Routes.layoverSaved,
            builder: (_, __) => const SavedScreen(),
          ),
          GoRoute(
            path: Routes.layoverCity,
            builder: (_, s) => CityDetailScreen(
              cityId:     s.pathParameters['cityId']!,
              initialTab: s.uri.queryParameters['tab'],
            ),
          ),
          GoRoute(
            path: Routes.layoverAdd,
            builder: (_, s) => AddRecommendationScreen(
              cityId:          s.pathParameters['cityId']!,
              initialCategory: s.uri.queryParameters['category'],
            ),
          ),
          GoRoute(
            path: Routes.recommendation,
            builder: (_, s) => RecommendationDetailScreen(
                recId: s.pathParameters['recId']!),
          ),

          // ── Trade Recommendation Engine ────────────────────────────────
          GoRoute(
            path: Routes.tradeRecommend,
            builder: (_, s) => trec.TradeSearchScreen(
              prefillRoute:          s.uri.queryParameters['route'],
              prefillBlockHours:     double.tryParse(
                  s.uri.queryParameters['block']   ?? ''),
              prefillDutyHours:      double.tryParse(
                  s.uri.queryParameters['duty']    ?? ''),
              prefillFdpMinutes:     int.tryParse(
                  s.uri.queryParameters['fdp']     ?? ''),
              prefillSigninHour:     int.tryParse(
                  s.uri.queryParameters['signin']  ?? ''),
              prefillIsInternational:
                  s.uri.queryParameters['intl'] == 'true',
              prefillFatigueScore:   double.tryParse(
                  s.uri.queryParameters['fatigue'] ?? ''),
              month: s.uri.queryParameters['month'],
            ),
          ),
          // ── Rest & Legality Engine ──────────────────────────────────────
          GoRoute(
            path: Routes.restCalculator,
            builder: (_, s) => RestCalculatorScreen(
              prefillLegs:      int.tryParse(s.uri.queryParameters['legs']   ?? ''),
              prefillIsIntl:    s.uri.queryParameters['intl']    == 'true',
              prefillCarryOver: double.tryParse(
                  s.uri.queryParameters['carryOver'] ?? ''),
            ),
          ),
          GoRoute(
            path: Routes.tradeLegality,
            builder: (_, s) => TradeLegalityScreen(
              offeredRouteLabel:   s.uri.queryParameters['offered'],
              requestedRouteLabel: s.uri.queryParameters['requested'],
            ),
          ),

          GoRoute(
            path: Routes.tradePreferences,
            builder: (_, s) => PreferenceInsightsScreen(
                userId: s.uri.queryParameters['userId'] ?? ''),
          ),

          // ── Knowledge Engine ────────────────────────────────────────────
          GoRoute(
            path: Routes.knowledgeCenter,
            builder: (_, __) => const KnowledgeCenterScreen(),
          ),
          GoRoute(
            path: Routes.knowledgeUpload,
            builder: (_, s) => UploadDocumentScreen(
              replacingDocumentId:   s.uri.queryParameters['replace'],
              replacingDocumentName: s.uri.queryParameters['name'],
            ),
          ),
          GoRoute(
            path: Routes.knowledgeDetail,
            builder: (_, s) => DocumentDetailScreen(
                documentId: s.pathParameters['documentId']!),
          ),
          GoRoute(
            path: Routes.askOperations,
            pageBuilder: (_, __) =>
                const NoTransitionPage(child: AskOperationsScreen()),
          ),

          // ── Subscription System (user-facing) ─────────────────────────
          GoRoute(
            path: Routes.upgrade,
            builder: (_, __) => const UpgradeScreen(),
          ),
          GoRoute(
            path: Routes.accountHistory,
            builder: (_, __) => const AccountHistoryScreen(),
          ),
          GoRoute(
            path: Routes.referral,
            builder: (_, __) => const ReferralScreen(),
          ),

          // ── Subscription System (admin) ────────────────────────────────
          GoRoute(
            path: Routes.adminSubscription,
            builder: (_, __) => const SubscriptionControlPanelScreen(),
          ),
          GoRoute(
            path: Routes.adminPlanEditor,
            builder: (_, s) => PlanEditorScreen(
                tier: s.pathParameters['tier']!),
          ),
          GoRoute(
            path: Routes.adminSubscriptionUsers,
            builder: (_, __) => const UserSubscriptionLookupScreen(),
          ),
          GoRoute(
            path: Routes.adminReferralCampaign,
            builder: (_, __) => const PromoCampaignScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.error}'),
      ),
    ),
  );
});

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (_, next) {
      next.whenData((user) {
        if (user != null) {
          context.go(Routes.home);
        } else {
          context.go(Routes.disclaimer);
        }
      });
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1B4F8A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/najm_logo.png', width: 120, height: 120),
            const SizedBox(height: 24),
            const Text(
              'Najm',
              style: TextStyle(
                color: Color(0xFFC8A84B),
                fontSize: 48,
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crew Intelligence Platform',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC8A84B)),
            ),
          ],
        ),
      ),
    );
  }
}
