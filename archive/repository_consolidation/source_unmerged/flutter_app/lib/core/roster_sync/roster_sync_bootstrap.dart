import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../services/connectivity_service.dart';
import 'roster_sync_providers.dart';

/// RosterSyncBootstrap — the piece that makes "log in once" true.
///
/// Zero-Knowledge directive, Session Behaviour:
///   Application Restart → credentials restored from Keychain/Keystore →
///   automatic background synchronization → NO additional login required.
///
/// Without this, the SyncScheduler exists but nobody starts it: credentials
/// would survive a restart and still nothing would sync until the user went
/// looking for a Sync button. This widget wraps the app and drives the three
/// spec triggers:
///   * app start (credentials are already in the secure enclave — no prompt),
///   * app resumed from background,
///   * connectivity regained (the offline requirement: sync when back online).
///
/// It holds NO credentials itself — it only tells the service to run; the
/// connectors read secrets from secure storage at the moment of use.
class RosterSyncBootstrap extends ConsumerStatefulWidget {
  final Widget child;
  const RosterSyncBootstrap({super.key, required this.child});

  @override
  ConsumerState<RosterSyncBootstrap> createState() =>
      _RosterSyncBootstrapState();
}

class _RosterSyncBootstrapState extends ConsumerState<RosterSyncBootstrap>
    with WidgetsBindingObserver {
  bool _syncStarted = false;

  Future<void> _startSyncIfApproved(String reason) async {
    if (_syncStarted) return;
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    final claims = (await user.getIdTokenResult()).claims ?? const {};
    final canSync = claims['accountStatus'] == 'approved' ||
        claims['admin'] == true ||
        claims['superAdmin'] == true;
    if (!canSync || !mounted) return;
    _syncStarted = true;
    final scheduler = ref.read(syncSchedulerProvider);
    scheduler.start();
    unawaited(scheduler.triggerNow(reason));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer past the first frame so startup isn't blocked by a network call.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(authStateProvider).valueOrNull != null) {
        // Restored-from-Keychain path: sync straight away, no login prompt.
        unawaited(_startSyncIfApproved('app_start'));
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_syncStarted) ref.read(syncSchedulerProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (next.valueOrNull != null) {
        unawaited(_startSyncIfApproved('auth_ready'));
      } else if (_syncStarted && !next.isLoading) {
        ref.read(syncSchedulerProvider).stop();
        _syncStarted = false;
      }
    });

    // Offline → online transitions drive an automatic resync.
    ref.listen<ConnectivityState>(connectivityProvider, (prev, next) {
      if (!_syncStarted) return;
      if (prev?.isOnline == next.isOnline) return;
      ref
          .read(syncSchedulerProvider)
          .onConnectivityChanged(isOnline: next.isOnline);
    });
    return widget.child;
  }
}
