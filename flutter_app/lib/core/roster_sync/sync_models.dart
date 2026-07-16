// Roster-sync wire contract — exact mirror of python_services/roster_sync/
// schema.py. Plain Dart (no codegen). Field names follow the server's
// snake_case JSON.

/// One provider from GET /v1/roster-sync/providers.
class ProviderInfo {
  final String providerId;
  final String displayName;
  final bool recommended;
  final String authKind; // prn_password | feed_url | none
  final String orchestration; // client_orchestrated | server_orchestrated
  final String availability; // available | pending_official_integration
  final String availabilityNote;

  const ProviderInfo({
    required this.providerId,
    required this.displayName,
    required this.recommended,
    required this.authKind,
    required this.orchestration,
    required this.availability,
    required this.availabilityNote,
  });

  bool get isAvailable => availability == 'available';

  factory ProviderInfo.fromJson(Map<String, dynamic> j) => ProviderInfo(
        providerId: j['provider_id'] ?? '',
        displayName: j['display_name'] ?? '',
        recommended: j['recommended'] == true,
        authKind: j['auth_kind'] ?? 'none',
        orchestration: j['orchestration'] ?? 'client_orchestrated',
        availability: j['availability'] ?? 'pending_official_integration',
        availabilityNote: j['availability_note'] ?? '',
      );
}

/// A user's connection to one provider (server-tracked status; NEVER
/// credentials — those live only in device secure storage).
class RosterConnection {
  final String providerId;
  final String status; // connected | awaiting_official_integration |
  //                      error | disconnected
  final DateTime? connectedAt;
  final DateTime? lastSyncAt;
  final DateTime? lastSuccessAt;
  final String nextSync; // advisory label, e.g. "automatic"
  final String? lastError;
  final int importedFlightsLast;
  final bool autoSync;

  const RosterConnection({
    required this.providerId,
    required this.status,
    this.connectedAt,
    this.lastSyncAt,
    this.lastSuccessAt,
    this.nextSync = 'automatic',
    this.lastError,
    this.importedFlightsLast = 0,
    this.autoSync = true,
  });

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory RosterConnection.fromJson(Map<String, dynamic> j) =>
      RosterConnection(
        providerId: j['provider_id'] ?? '',
        status: j['status'] ?? 'disconnected',
        connectedAt: _dt(j['connected_at']),
        lastSyncAt: _dt(j['last_sync_at']),
        lastSuccessAt: _dt(j['last_success_at']),
        nextSync: j['next_sync'] ?? 'automatic',
        lastError: j['last_error'],
        importedFlightsLast: (j['imported_flights_last'] ?? 0) as int,
        autoSync: j['auto_sync'] != false,
      );
}

class VersionEntry {
  final int version;
  final String checksum;
  final int importedFlights;
  final DateTime? at;
  final int added;
  final int removed;
  final int changed;

  const VersionEntry({
    required this.version,
    required this.checksum,
    required this.importedFlights,
    this.at,
    this.added = 0,
    this.removed = 0,
    this.changed = 0,
  });

  factory VersionEntry.fromJson(Map<String, dynamic> j) => VersionEntry(
        version: (j['version'] ?? 0) as int,
        checksum: j['checksum'] ?? '',
        importedFlights: (j['imported_flights'] ?? 0) as int,
        at: j['at'] == null ? null : DateTime.tryParse(j['at'].toString()),
        added: (j['added'] ?? 0) as int,
        removed: (j['removed'] ?? 0) as int,
        changed: (j['changed'] ?? 0) as int,
      );
}

/// GET /v1/roster-sync/status.
class SyncStatus {
  final List<RosterConnection> connections;
  final List<ProviderInfo> providers;
  final String preferredSource;
  final Map<String, VersionEntry> versionsLatest;

  const SyncStatus({
    required this.connections,
    required this.providers,
    required this.preferredSource,
    required this.versionsLatest,
  });

  RosterConnection? connection(String providerId) {
    for (final c in connections) {
      if (c.providerId == providerId) return c;
    }
    return null;
  }

  factory SyncStatus.fromJson(Map<String, dynamic> j) => SyncStatus(
        connections: (j['connections'] as List<dynamic>? ?? const [])
            .map((e) => RosterConnection.fromJson(e as Map<String, dynamic>))
            .toList(),
        providers: (j['providers'] as List<dynamic>? ?? const [])
            .map((e) => ProviderInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        preferredSource: j['preferred_source'] ?? 'manual_pdf',
        versionsLatest:
            (j['versions_latest'] as Map<String, dynamic>? ?? const {}).map(
                (k, v) => MapEntry(
                    k, VersionEntry.fromJson(v as Map<String, dynamic>))),
      );
}

/// The ONLY roster shape that may be uploaded to NAJM (Zero-Knowledge
/// directive: "Normalized roster ONLY is uploaded to NAJM backend").
/// Mirrors python_services/roster_sync/schema.py::NormalizedRoster.
class NormalizedRoster {
  final String period; // e.g. JUL-2026
  final int year;
  final List<Map<String, dynamic>> legs;
  final String providerNote;

  const NormalizedRoster({
    required this.period,
    required this.year,
    required this.legs,
    this.providerNote = '',
  });

  Map<String, dynamic> toJson() => {
        'period': period,
        'year': year,
        'legs': legs,
        'provider_note': providerNote,
      };
}

/// What a connector hands to the import API. `kind` matches the server's
/// payload_kind ("ics" | "normalized"). NEVER carries credentials — the
/// server additionally rejects any payload containing credential-shaped
/// keys (assert_no_credentials).
class RosterPayload {
  final String kind;
  final Object payload; // raw ICS text, or normalized roster map
  final String period; // e.g. JUN-2026
  final int year;

  const RosterPayload({
    required this.kind,
    required this.payload,
    required this.period,
    required this.year,
  });
}

class ImportResult {
  final String result; // imported | duplicate | failed
  final String? lineId;
  final int? version;
  final int importedFlights;
  final Map<String, dynamic> diff;
  final List<Map<String, dynamic>> engines;

  const ImportResult({
    required this.result,
    this.lineId,
    this.version,
    this.importedFlights = 0,
    this.diff = const {},
    this.engines = const [],
  });

  bool get isDuplicate => result == 'duplicate';
  bool get isImported => result == 'imported';

  factory ImportResult.fromJson(Map<String, dynamic> j) => ImportResult(
        result: j['result'] ?? 'failed',
        lineId: j['line_id'],
        version: j['version'] as int?,
        importedFlights: (j['imported_flights'] ?? 0) as int,
        diff: Map<String, dynamic>.from(j['diff'] ?? const {}),
        engines: (j['engines'] as List<dynamic>? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

/// Result of a connector-level connect attempt (device side).
class ConnectOutcome {
  final bool ok;

  /// connected | awaiting_official_integration | error
  final String status;
  final String note;

  const ConnectOutcome(
      {required this.ok, required this.status, this.note = ''});
}
