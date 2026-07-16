// Profile — view-model logic and a widget smoke test.
//
// The logic that decides what a crew member SEES (is my sync healthy? how many
// days left? which provider fed my roster?) lives in pure functions in
// profile_providers.dart precisely so it can be tested without a backend, a
// device, or a Firebase project. This file tests those decisions.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crew_intelligence_platform/core/roster_sync/sync_models.dart';
import 'package:crew_intelligence_platform/features/profile/providers/profile_providers.dart';
import 'package:crew_intelligence_platform/features/profile/widgets/profile_widgets.dart';

RosterConnection _conn({
  String providerId = 'ics_feed',
  String status = 'connected',
  DateTime? lastSuccessAt,
  String? lastError,
  int importedFlightsLast = 0,
}) =>
    RosterConnection(
      providerId: providerId,
      status: status,
      connectedAt: DateTime(2026, 7, 1),
      lastSyncAt: lastSuccessAt,
      lastSuccessAt: lastSuccessAt,
      nextSync: 'automatic',
      lastError: lastError,
      importedFlightsLast: importedFlightsLast,
      autoSync: true,
    );

SyncStatus _status(List<RosterConnection> connections,
        {String preferred = 'ics_feed'}) =>
    SyncStatus(
      connections: connections,
      providers: const [
        ProviderInfo(
          providerId: 'ics_feed',
          displayName: 'ICS Calendar',
          recommended: true,
          authKind: 'feed_url',
          orchestration: 'client_orchestrated',
          availability: 'available',
          availabilityNote: '',
        ),
      ],
      preferredSource: preferred,
      versionsLatest: const {},
    );

void main() {
  group('syncBadgeFor — the badge crew actually read', () {
    test('no connections → none (not a failure)', () {
      expect(syncBadgeFor(_status([])), ProfileSyncBadge.none);
      expect(syncBadgeFor(null), ProfileSyncBadge.none);
    });

    test('disconnected sources are ignored, not counted as waiting', () {
      expect(
        syncBadgeFor(_status([_conn(status: 'disconnected')])),
        ProfileSyncBadge.none,
      );
    });

    test('connected but never synced → waiting', () {
      expect(syncBadgeFor(_status([_conn()])), ProfileSyncBadge.waiting);
    });

    test('connected and synced → healthy', () {
      expect(
        syncBadgeFor(_status([_conn(lastSuccessAt: DateTime(2026, 7, 13))])),
        ProfileSyncBadge.healthy,
      );
    });

    test('an error wins over a past success — never a green light on a '
        'broken sync', () {
      expect(
        syncBadgeFor(_status([
          _conn(lastSuccessAt: DateTime(2026, 7, 13), lastError: 'HTTP 401'),
        ])),
        ProfileSyncBadge.failed,
      );
    });
  });

  group('activeSourceOf', () {
    test('returns the preferred source when it is actually connected', () {
      expect(activeSourceOf(_status([_conn()])), 'ics_feed');
    });

    test('returns null when the preferred source has no connection', () {
      expect(activeSourceOf(_status([], preferred: 'cae_crew_access')), isNull);
    });
  });

  group('SubscriptionCardView.daysRemaining', () {
    final now = DateTime(2026, 7, 14);

    test('counts whole days to renewal', () {
      expect(
        SubscriptionCardView.daysRemaining(DateTime(2026, 7, 22), now),
        8,
      );
    });

    test('an expired plan shows 0, never a negative number', () {
      expect(
        SubscriptionCardView.daysRemaining(DateTime(2026, 7, 1), now),
        0,
      );
    });

    test('no renewal date → null, so the card renders "—" not a guess', () {
      expect(SubscriptionCardView.daysRemaining(null, now), isNull);
    });
  });

  group('supportMailto', () {
    test('builds a mailto: URI for the real support address', () {
      final uri = supportMailto(supportEmail, subject: 'NAJM — Support');
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'NajmAssistance@gmail.com');
      expect(uri.queryParameters['subject'], 'NAJM — Support');
    });

    test('administrator address is the separate business inbox', () {
      expect(administratorEmail, 'NajmPlatform@gmail.com');
      expect(administratorEmail, isNot(supportEmail));
    });
  });

  group('SecurityCard', () {
    testWidgets('states the zero-knowledge guarantee and shows no credential',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: SecurityCard())),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Keychain'), findsOneWidget);
      expect(find.textContaining('Keystore'), findsOneWidget);

      // The card must never render a secret. It cannot — it reads no
      // credential source at all — and this asserts that stays true.
      for (final leak in ['password', 'PRN', 'token', 'secret']) {
        expect(find.textContaining(RegExp(leak, caseSensitive: false)),
            findsNothing,
            reason: '"$leak" must never appear on the Security card');
      }
    });
  });
}
