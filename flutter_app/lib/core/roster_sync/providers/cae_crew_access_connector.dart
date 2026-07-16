import '../credential_manager.dart';
import '../roster_connector.dart';
import '../sync_models.dart';

/// CAE Crew Access — the spec's primary source, shipped in the only honest
/// shape possible today.
///
/// There is no published consumer API for CAE Crew Access, and the feature
/// spec explicitly forbids reverse-engineered or ToS-violating integrations.
/// This connector therefore mirrors the backend's config-activated design:
///
///   * While the server catalog reports `pending_official_integration`,
///     [connect] registers NOTHING usable and — deliberately — stores NO
///     credentials: retaining a password the app cannot use anywhere would
///     be pure liability. The user gets the server's plain-language note
///     (official-integration-only policy + the working alternatives).
///   * When ops configures the official integration server-side
///     (CAE_INTEGRATION_MODE):
///       - `enterprise_service` (expected production route): roster pulls
///         are SERVER-orchestrated with NAJM's enterprise service
///         credentials from the secret manager. The device never holds user
///         credentials at all — [connect] just registers, and the sync
///         service routes syncs through POST /sync-now.
///       - `device_oauth`: the device authenticates against CAE's official
///         OAuth endpoints. Wiring that flow requires CAE's published
///         client parameters; until they exist this path reports itself as
///         an activation task (see docs/ROSTER_SYNC.md → Activation
///         checklist) instead of pretending.
///
/// Every downstream stage — import, dedup, versioning, enrichment, engine
/// fan-out, status UI — is live and exercised today via the ICS provider,
/// so CAE activation is configuration, not a rewrite.
class CaeCrewAccessConnector implements RosterConnector {
  static const fieldPrn = 'prn';
  static const fieldPassword = 'password';

  final CredentialManager _credentials;

  CaeCrewAccessConnector({required CredentialManager credentials})
      : _credentials = credentials;

  @override
  String get providerId => 'cae_crew_access';

  @override
  List<AuthField> get authFields => const [
        AuthField(fieldPrn, 'PRN'),
        AuthField(fieldPassword, 'Password', obscure: true),
      ];

  @override
  Future<ConnectOutcome> connect(
      Map<String, String> credentials, ProviderInfo info) async {
    if (!info.isAvailable) {
      // Honest pending state. No credential is stored: nothing can use it.
      return ConnectOutcome(
        ok: false,
        status: 'awaiting_official_integration',
        note: info.availabilityNote,
      );
    }
    if (info.orchestration == 'server_orchestrated') {
      // Enterprise integration — the server syncs with NAJM's service
      // account. User credentials are not part of this flow at all.
      return const ConnectOutcome(
        ok: true,
        status: 'connected',
        note: 'Connected through the enterprise integration — rosters sync '
            'automatically; no credentials are kept on this device.',
      );
    }
    // device_oauth — official device flow: activation task until CAE's
    // client parameters are published. We refuse rather than simulate.
    return const ConnectOutcome(
      ok: false,
      status: 'awaiting_official_integration',
      note: 'The official device sign-in flow needs CAE\'s published OAuth '
          'client parameters. Until then rosters can sync through the '
          'enterprise integration, the calendar feed, or manual upload.',
    );
  }

  @override
  Future<RosterPayload> fetchRoster(
      ProviderInfo info, String period, int year) async {
    if (info.isAvailable && info.orchestration == 'server_orchestrated') {
      throw ConnectorUnavailable(
          'CAE syncs are server-orchestrated — use Sync Now.');
    }
    throw ConnectorUnavailable(info.availabilityNote.isNotEmpty
        ? info.availabilityNote
        : 'CAE Crew Access is awaiting the official integration.');
  }

  @override
  Future<void> disconnect() async {
    // Defensive wipe — the pending flow stores nothing, but disconnect must
    // guarantee zero residue regardless of history.
    await _credentials.wipeProvider(providerId);
  }
}
