import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'credential_manager.dart';
import 'providers/cae_crew_access_connector.dart';
import 'providers/ics_feed_connector.dart';
import 'roster_connector.dart';
import 'roster_sync_api.dart';
import 'sync_models.dart';
import 'sync_service.dart';

/// Riverpod wiring for the roster-sync layer. Screens depend ONLY on these
/// providers — all synchronization logic lives in core/roster_sync (spec:
/// "Do NOT mix synchronization logic with Flutter UI").

final credentialManagerProvider =
    Provider<CredentialManager>((ref) => CredentialManager());

final connectorRegistryProvider = Provider<ConnectorRegistry>((ref) {
  final creds = ref.watch(credentialManagerProvider);
  return ConnectorRegistry([
    CaeCrewAccessConnector(credentials: creds),
    IcsFeedConnector(credentials: creds),
  ]);
});

final rosterSyncApiProvider = Provider<RosterSyncApi>((ref) => RosterSyncApi());

final rosterSyncServiceProvider = Provider<RosterSyncService>((ref) {
  return RosterSyncService(
    api: ref.watch(rosterSyncApiProvider),
    connectors: ref.watch(connectorRegistryProvider),
  );
});

final syncSchedulerProvider = Provider<SyncScheduler>((ref) {
  final scheduler = SyncScheduler(ref.watch(rosterSyncServiceProvider));
  ref.onDispose(scheduler.stop);
  return scheduler;
});

final healthMonitorProvider = Provider<ConnectionHealthMonitor>(
    (ref) => const ConnectionHealthMonitor());

/// Current status (refresh with `ref.invalidate(syncStatusProvider)`).
final syncStatusProvider = FutureProvider<SyncStatus>(
    (ref) => ref.watch(rosterSyncApiProvider).getStatus());
