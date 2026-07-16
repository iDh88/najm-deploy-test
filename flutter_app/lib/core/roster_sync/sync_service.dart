import 'dart:async';

import 'roster_connector.dart';
import 'roster_sync_api.dart';
import 'sync_models.dart';

/// Outcome of one provider sync — safe to log/display (never credentials).
class SyncReport {
  final String providerId;
  final bool ok;
  final ImportResult? importResult;
  final String? serverAction; // for server-orchestrated providers
  final String? error;

  const SyncReport({
    required this.providerId,
    required this.ok,
    this.importResult,
    this.serverAction,
    this.error,
  });
}

String periodOf(DateTime d) {
  const months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
  ];
  return '${months[d.month - 1]}-${d.year}';
}

/// RosterSyncService — device-side orchestration. Pure logic, zero UI:
/// screens observe results, the scheduler calls [syncAll].
///
/// Per spec failure handling: any failure leaves the previously imported
/// roster untouched (the backend never deletes on error; this service never
/// deletes anything) and surfaces a meaningful, credential-free message.
class RosterSyncService {
  final RosterSyncApi _api;
  final ConnectorRegistry _connectors;
  final DateTime Function() _now;

  RosterSyncService({
    required RosterSyncApi api,
    required ConnectorRegistry connectors,
    DateTime Function()? clock,
  })  : _api = api,
        _connectors = connectors,
        _now = clock ?? DateTime.now;

  /// Connect flow: device-validate via the connector (which stores
  /// credentials in secure storage only on success), then register the
  /// connection server-side for status tracking. Order matters: nothing is
  /// registered for credentials that failed validation.
  Future<ConnectOutcome> connect(
      String providerId, Map<String, String> credentials) async {
    final providers = await _api.getProviders();
    final info = providers.firstWhere((p) => p.providerId == providerId,
        orElse: () => throw ConnectorUnavailable('Unknown source.'));
    final connector = _connectors.byId(providerId);
    if (connector == null) {
      throw ConnectorUnavailable(
          'This source has no device connector yet.');
    }
    final outcome = await connector.connect(credentials, info);
    // Register server-side in every case EXCEPT a plain validation error —
    // the awaiting-official state is worth tracking; a wrong URL is not.
    if (outcome.ok || outcome.status == 'awaiting_official_integration') {
      await _api.registerConnection(providerId, clientMeta: {
        'device_flow': outcome.status,
      });
      if (outcome.ok) {
        // First sync immediately after a successful connect (spec).
        await syncProvider(providerId);
      }
    }
    return outcome;
  }

  /// Disconnect: server first (stop tracking), then the guaranteed local
  /// credential wipe. Both run even if one fails.
  Future<void> disconnect(String providerId) async {
    Object? serverErr;
    try {
      await _api.deleteConnection(providerId);
    } catch (e) {
      serverErr = e;
    }
    await _connectors.byId(providerId)?.disconnect();
    if (serverErr != null) throw serverErr; // surfaced after the wipe
  }

  /// One provider, one sync. Routes by orchestration:
  ///   client_orchestrated → device fetch → POST /import
  ///   server_orchestrated → POST /sync-now (server does the pull)
  Future<SyncReport> syncProvider(String providerId) async {
    try {
      final status = await _api.getStatus();
      final info = status.providers.firstWhere(
          (p) => p.providerId == providerId,
          orElse: () => throw ConnectorUnavailable('Unknown source.'));

      if (info.orchestration == 'server_orchestrated' && info.isAvailable) {
        final res = await _api.syncNow(providerId);
        return SyncReport(
            providerId: providerId,
            ok: res['action'] == 'server_synced',
            serverAction: res['action']?.toString(),
            error: res['action'] == 'server_synced'
                ? null
                : res['detail']?.toString());
      }

      final connector = _connectors.byId(providerId);
      if (connector == null) {
        return SyncReport(
            providerId: providerId,
            ok: false,
            error: 'No device connector for this source.');
      }
      final now = _now();
      final payload =
          await connector.fetchRoster(info, periodOf(now), now.year);
      final result = await _api.importRoster(providerId, payload);
      return SyncReport(
          providerId: providerId,
          ok: result.result != 'failed',
          importResult: result);
    } on ConnectorUnavailable catch (e) {
      return SyncReport(providerId: providerId, ok: false, error: e.note);
    } catch (_) {
      return SyncReport(
          providerId: providerId,
          ok: false,
          error: 'Sync failed — your previous roster is untouched. '
              'We\'ll retry automatically.');
    }
  }

  /// All connected, auto-sync-enabled providers (scheduler entry point).
  Future<List<SyncReport>> syncAll() async {
    final List<SyncReport> reports = [];
    try {
      final status = await _api.getStatus();
      for (final conn in status.connections) {
        if (conn.status == 'connected' && conn.autoSync) {
          reports.add(await syncProvider(conn.providerId));
        }
      }
    } catch (_) {
      // Status unreachable (offline). Spec: keep cached roster, retry later.
    }
    return reports;
  }
}

/// SyncScheduler — automatic triggers, no UI, no platform plugins:
///   * a periodic timer (default 6 h),
///   * connectivity regained (spec offline requirement) — feed
///     [onConnectivityChanged] from the app's connectivity provider,
///   * app resumed — call [onAppResumed] from the lifecycle observer.
/// Native background execution (WorkManager / BGTaskScheduler) is a
/// documented activation upgrade (docs/ROSTER_SYNC.md) that plugs in behind
/// [triggerNow] without touching this contract.
class SyncScheduler {
  final RosterSyncService _service;
  final Duration interval;
  Timer? _timer;
  bool _wasOffline = false;
  DateTime? _lastRun;

  SyncScheduler(this._service, {this.interval = const Duration(hours: 6)});

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => triggerNow('periodic'));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void onConnectivityChanged({required bool isOnline}) {
    if (isOnline && _wasOffline) {
      triggerNow('connectivity_regained');
    }
    _wasOffline = !isOnline;
  }

  void onAppResumed() {
    final last = _lastRun;
    if (last == null || DateTime.now().difference(last) > interval) {
      triggerNow('app_resumed');
    }
  }

  Future<List<SyncReport>> triggerNow(String reason) async {
    _lastRun = DateTime.now();
    return _service.syncAll();
  }
}

/// Per-provider health, computed purely from [SyncStatus] — rendered on the
/// Sync Status screen.
enum SyncHealth { healthy, stale, error, pending, disconnected }

class ConnectionHealthMonitor {
  final Duration staleAfter;
  const ConnectionHealthMonitor({this.staleAfter = const Duration(hours: 48)});

  SyncHealth healthOf(RosterConnection? conn, {DateTime? now}) {
    if (conn == null || conn.status == 'disconnected') {
      return SyncHealth.disconnected;
    }
    if (conn.status == 'awaiting_official_integration') {
      return SyncHealth.pending;
    }
    if (conn.lastError != null && conn.lastError!.isNotEmpty) {
      return SyncHealth.error;
    }
    final t = conn.lastSuccessAt;
    if (t == null) return SyncHealth.stale;
    final ref = now ?? DateTime.now();
    return ref.difference(t) > staleAfter
        ? SyncHealth.stale
        : SyncHealth.healthy;
  }
}
