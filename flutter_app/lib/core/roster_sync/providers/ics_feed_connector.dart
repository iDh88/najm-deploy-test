import 'package:http/http.dart' as http;

import '../credential_manager.dart';
import '../roster_connector.dart';
import '../sync_models.dart';
import 'ics_normalizer.dart';

/// Calendar-feed connector (RFC 5545) — a REAL, standards-based source
/// available today. The user pastes the calendar-subscription URL from
/// their crew portal; the device fetches the raw ICS text and hands it to
/// the backend (payload_kind "ics"), which owns parsing, dedup, versioning
/// and engine fan-out.
///
/// Security notes:
///   * Feed URLs frequently embed a personal token → the URL is a
///     CREDENTIAL: stored only via [CredentialManager] (Keychain/Keystore),
///     never logged, and never echoed in error messages.
///   * https is REQUIRED — an http feed would leak the token in transit.
class IcsFeedConnector implements RosterConnector {
  static const fieldUrl = 'feed_url';

  final CredentialManager _credentials;
  final Future<http.Response> Function(Uri) _get;

  IcsFeedConnector({
    required CredentialManager credentials,
    Future<http.Response> Function(Uri)? httpGet, // injectable for tests
  })  : _credentials = credentials,
        _get = httpGet ?? ((uri) => http.get(uri));

  @override
  String get providerId => 'ics_feed';

  @override
  List<AuthField> get authFields =>
      const [AuthField(fieldUrl, 'Calendar URL (https)')];

  @override
  Future<ConnectOutcome> connect(
      Map<String, String> credentials, ProviderInfo info) async {
    final raw = (credentials[fieldUrl] ?? '').trim();
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return const ConnectOutcome(
          ok: false,
          status: 'error',
          note: 'Enter the full https:// calendar link from your crew '
              'portal. Plain http links are not accepted — the link can '
              'contain your personal token.');
    }
    final String body;
    try {
      final res = await _get(uri);
      if (res.statusCode != 200) {
        return ConnectOutcome(
            ok: false,
            status: 'error',
            note: 'The calendar feed answered with status '
                '${res.statusCode}. Check the link and try again.');
      }
      body = res.body;
    } catch (_) {
      // Never include the URL or exception text (may echo the token).
      return const ConnectOutcome(
          ok: false,
          status: 'error',
          note: 'Could not reach the calendar feed. Check your connection '
              'and the link, then try again.');
    }
    if (!body.contains('BEGIN:VCALENDAR') || !body.contains('BEGIN:VEVENT')) {
      return const ConnectOutcome(
          ok: false,
          status: 'error',
          note: 'That link is reachable but is not a calendar feed '
              '(no events found).');
    }
    // Validated — store the URL as a credential ONLY now.
    await _credentials.store(providerId, fieldUrl, raw);
    return const ConnectOutcome(
        ok: true,
        status: 'connected',
        note: 'Calendar feed verified.');
  }

  @override
  Future<RosterPayload> fetchRoster(
      ProviderInfo info, String period, int year) async {
    final url = await _credentials.readField(providerId, fieldUrl);
    if (url == null || url.isEmpty) {
      throw ConnectorUnavailable(
          'Calendar feed is not connected on this device.');
    }
    final http.Response res;
    try {
      res = await _get(Uri.parse(url));
    } catch (_) {
      throw ConnectorUnavailable('Calendar feed unreachable — kept your '
          'previous roster.');
    }
    if (res.statusCode != 200) {
      throw ConnectorUnavailable('Calendar feed answered '
          '${res.statusCode} — kept your previous roster.');
    }

    // Zero-Knowledge: normalize HERE. The raw calendar — which also holds
    // personal, non-flight events — never leaves the device; only flight
    // legs are uploaded.
    final NormalizedRoster roster;
    try {
      roster = IcsNormalizer.normalize(res.body, period, year);
    } on IcsNormalizeException catch (e) {
      throw ConnectorUnavailable('${e.message} Your previous roster is '
          'unchanged.');
    }
    return RosterPayload(
        kind: 'normalized',
        payload: roster.toJson(),
        period: period,
        year: year);
  }

  @override
  Future<void> disconnect() async {
    await _credentials.wipeProvider(providerId);
  }
}
