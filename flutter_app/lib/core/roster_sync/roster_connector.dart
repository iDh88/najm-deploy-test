import 'credential_manager.dart';
import 'sync_models.dart';

/// RosterConnector — the common interface every roster source implements
/// (feature spec "Future Expansion": Sabre, Jeppesen, AIMS, NetLine, PDF,
/// Excel, ICS, Email all plug in here without rewriting existing code).
///
/// Responsibilities are deliberately narrow:
///   * capture + validate credentials for its auth kind,
///   * fetch the user's roster FROM THE DEVICE (client_orchestrated — the
///     backend never sees credentials),
///   * hand a [RosterPayload] to the sync service, which owns import,
///     dedup, versioning and engine fan-out via the backend.
///
/// Connectors contain NO UI and NO scheduling — the spec's separation of
/// responsibilities.
abstract class RosterConnector {
  String get providerId;

  /// Ordered credential fields this connector needs from the connect screen
  /// (label → obscure?). Empty for providers with no device auth.
  List<AuthField> get authFields;

  /// Validate credentials against the provider and persist them via
  /// [CredentialManager] ONLY on success (or on explicit awaiting-official
  /// opt-in — see CAE connector). Never throws credentials in messages.
  Future<ConnectOutcome> connect(
      Map<String, String> credentials, ProviderInfo info);

  /// Fetch the roster for [period]/[year] from the source using stored
  /// credentials. Throws [ConnectorUnavailable] when the provider cannot
  /// serve (e.g. official integration pending) — the sync service keeps the
  /// cached roster untouched, per spec failure handling.
  Future<RosterPayload> fetchRoster(
      ProviderInfo info, String period, int year);

  /// Securely erase all locally stored credentials for this provider.
  Future<void> disconnect();
}

class AuthField {
  final String key; // storage field name, e.g. "prn"
  final String label; // UI label, e.g. "PRN"
  final bool obscure;
  const AuthField(this.key, this.label, {this.obscure = false});
}

class ConnectorUnavailable implements Exception {
  final String note;
  ConnectorUnavailable(this.note);
  @override
  String toString() => note;
}

/// Registry — mirrors the server catalog's priority order (CAE Sync first,
/// manual upload last). The Settings UI renders from the SERVER catalog and
/// looks connectors up here by id, so a provider that exists server-side but
/// has no device connector yet simply renders without a Connect action.
class ConnectorRegistry {
  final Map<String, RosterConnector> _byId;
  ConnectorRegistry(List<RosterConnector> connectors)
      : _byId = {for (final c in connectors) c.providerId: c};

  RosterConnector? byId(String providerId) => _byId[providerId];
  bool supports(String providerId) => _byId.containsKey(providerId);
}
