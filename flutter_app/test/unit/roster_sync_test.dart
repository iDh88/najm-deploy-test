// Roster-sync core-layer tests — pure Dart, no platform channels.
// Everything platform-touching is injected: SecureKeyValueStore fake for
// the credential contract, httpGet fake for the ICS connector.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:crew_intelligence_platform/core/roster_sync/credential_manager.dart';
import 'package:crew_intelligence_platform/core/roster_sync/providers/cae_crew_access_connector.dart';
import 'package:crew_intelligence_platform/core/roster_sync/providers/ics_feed_connector.dart';
import 'package:crew_intelligence_platform/core/roster_sync/roster_connector.dart';
import 'package:crew_intelligence_platform/core/roster_sync/sync_models.dart';
import 'package:crew_intelligence_platform/core/roster_sync/sync_service.dart';

class FakeSecureStore implements SecureKeyValueStore {
  final Map<String, String> data = {};
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> delete(String key) async => data.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(data);
}

ProviderInfo _info({
  String id = 'ics_feed',
  String availability = 'available',
  String orchestration = 'client_orchestrated',
  String note = '',
}) =>
    ProviderInfo(
      providerId: id,
      displayName: id,
      recommended: false,
      authKind: 'feed_url',
      orchestration: orchestration,
      availability: availability,
      availabilityNote: note,
    );

const _validIcs = 'BEGIN:VCALENDAR\n'
    'BEGIN:VEVENT\nSUMMARY:SV123 JED-LHR\nEND:VEVENT\nEND:VCALENDAR\n';

void main() {
  group('CredentialManager', () {
    test('stores, reads, and namespaces per provider', () async {
      final store = FakeSecureStore();
      final cm = CredentialManager(store: store);
      await cm.store('ics_feed', 'feed_url', 'https://x/cal.ics');
      await cm.store('cae_crew_access', 'prn', '12345');

      expect(await cm.readField('ics_feed', 'feed_url'),
          'https://x/cal.ics');
      expect(await cm.readProvider('cae_crew_access'), {'prn': '12345'});
      expect(await cm.hasCredentials('ics_feed'), isTrue);
      // Keys live under the namespace — nothing stored bare.
      expect(store.data.keys.every((k) => k.startsWith('najm.roster_sync.')),
          isTrue);
    });

    test('wipeProvider erases every field for that provider only', () async {
      final store = FakeSecureStore();
      final cm = CredentialManager(store: store);
      await cm.store('cae_crew_access', 'prn', 'p');
      await cm.store('cae_crew_access', 'password', 's');
      await cm.store('ics_feed', 'feed_url', 'https://x');

      final wiped = await cm.wipeProvider('cae_crew_access');
      expect(wiped, 2);
      expect(await cm.hasCredentials('cae_crew_access'), isFalse);
      expect(await cm.hasCredentials('ics_feed'), isTrue);
    });

    test('wipeAll clears only the roster_sync namespace', () async {
      final store = FakeSecureStore();
      store.data['unrelated.key'] = 'keep-me';
      final cm = CredentialManager(store: store);
      await cm.store('ics_feed', 'feed_url', 'https://x');
      final wiped = await cm.wipeAll();
      expect(wiped, 1);
      expect(store.data['unrelated.key'], 'keep-me');
    });
  });

  group('IcsFeedConnector', () {
    IcsFeedConnector make(FakeSecureStore store,
        Future<http.Response> Function(Uri) get) {
      return IcsFeedConnector(
          credentials: CredentialManager(store: store), httpGet: get);
    }

    test('rejects non-https and stores nothing', () async {
      final store = FakeSecureStore();
      final c = make(store, (_) async => http.Response(_validIcs, 200));
      final out = await c
          .connect({'feed_url': 'http://portal/cal.ics'}, _info());
      expect(out.ok, isFalse);
      expect(store.data, isEmpty);
    });

    test('rejects a reachable non-calendar and stores nothing', () async {
      final store = FakeSecureStore();
      final c = make(store, (_) async => http.Response('<html>', 200));
      final out = await c
          .connect({'feed_url': 'https://portal/cal.ics'}, _info());
      expect(out.ok, isFalse);
      expect(out.note.contains('not a calendar'), isTrue);
      expect(store.data, isEmpty);
    });

    test('error notes never echo the URL (token-bearing)', () async {
      final store = FakeSecureStore();
      const secretUrl = 'https://portal/cal.ics?token=SECRET123';
      final c = make(store, (_) async => http.Response('nope', 500));
      final out = await c.connect({'feed_url': secretUrl}, _info());
      expect(out.ok, isFalse);
      expect(out.note.contains('SECRET123'), isFalse);
      expect(out.note.contains(secretUrl), isFalse);
    });

    test('stores the URL only after successful validation, then fetches',
        () async {
      final store = FakeSecureStore();
      var calls = 0;
      final c = make(store, (_) async {
        calls++;
        return http.Response(_validIcs, 200);
      });
      final out = await c
          .connect({'feed_url': 'https://portal/cal.ics'}, _info());
      expect(out.ok, isTrue);
      expect(store.data.values, contains('https://portal/cal.ics'));

      final payload = await c.fetchRoster(_info(), 'JUL-2026', 2026);
      expect(payload.kind, 'ics');
      expect(payload.payload, _validIcs);
      expect(payload.period, 'JUL-2026');
      expect(calls, 2);
    });

    test('fetch failure keeps a meaningful, credential-free message',
        () async {
      final store = FakeSecureStore();
      final cm = CredentialManager(store: store);
      await cm.store('ics_feed', 'feed_url', 'https://x/cal.ics?token=SEC');
      final c = IcsFeedConnector(
          credentials: cm, httpGet: (_) async => throw Exception('SEC'));
      expect(
        () => c.fetchRoster(_info(), 'JUL-2026', 2026),
        throwsA(isA<ConnectorUnavailable>().having(
            (e) => e.note.contains('SEC'), 'leaks secret', isFalse)),
      );
    });
  });

  group('CaeCrewAccessConnector — honest states', () {
    test('pending official integration: no connect, NO credential stored',
        () async {
      final store = FakeSecureStore();
      final c = CaeCrewAccessConnector(
          credentials: CredentialManager(store: store));
      final out = await c.connect(
        {'prn': '12345', 'password': 'secret'},
        _info(
            id: 'cae_crew_access',
            availability: 'pending_official_integration',
            note: 'official integration only'),
      );
      expect(out.ok, isFalse);
      expect(out.status, 'awaiting_official_integration');
      expect(out.note, 'official integration only');
      expect(store.data, isEmpty); // unusable secrets are never retained
    });

    test('enterprise (server_orchestrated): connects without device creds',
        () async {
      final store = FakeSecureStore();
      final c = CaeCrewAccessConnector(
          credentials: CredentialManager(store: store));
      final out = await c.connect(
        const {},
        _info(
            id: 'cae_crew_access',
            availability: 'available',
            orchestration: 'server_orchestrated'),
      );
      expect(out.ok, isTrue);
      expect(store.data, isEmpty);
    });

    test('device fetch is refused with the honest note', () async {
      final c = CaeCrewAccessConnector(
          credentials: CredentialManager(store: FakeSecureStore()));
      expect(
        () => c.fetchRoster(
            _info(
                id: 'cae_crew_access',
                availability: 'pending_official_integration',
                note: 'awaiting CAE'),
            'JUL-2026',
            2026),
        throwsA(isA<ConnectorUnavailable>()
            .having((e) => e.note, 'note', 'awaiting CAE')),
      );
    });
  });

  group('Health + registry + period', () {
    test('health classification', () {
      const monitor = ConnectionHealthMonitor();
      final now = DateTime(2026, 7, 12, 12);
      RosterConnection conn({
        String status = 'connected',
        String? error,
        DateTime? success,
      }) =>
          RosterConnection(
              providerId: 'p',
              status: status,
              lastError: error,
              lastSuccessAt: success);

      expect(monitor.healthOf(null), SyncHealth.disconnected);
      expect(
          monitor.healthOf(conn(status: 'awaiting_official_integration'),
              now: now),
          SyncHealth.pending);
      expect(monitor.healthOf(conn(error: 'boom'), now: now),
          SyncHealth.error);
      expect(
          monitor.healthOf(
              conn(success: now.subtract(const Duration(hours: 2))),
              now: now),
          SyncHealth.healthy);
      expect(
          monitor.healthOf(
              conn(success: now.subtract(const Duration(hours: 72))),
              now: now),
          SyncHealth.stale);
    });

    test('registry lookup and periodOf format', () {
      final registry = ConnectorRegistry([
        CaeCrewAccessConnector(
            credentials: CredentialManager(store: FakeSecureStore())),
      ]);
      expect(registry.supports('cae_crew_access'), isTrue);
      expect(registry.supports('sabre'), isFalse);
      expect(periodOf(DateTime(2026, 7, 12)), 'JUL-2026');
      expect(periodOf(DateTime(2026, 1, 1)), 'JAN-2026');
    });
  });
}
