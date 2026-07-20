import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import 'connectivity_service.dart';
import 'offline_cache_service.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final queueSyncProvider = Provider<QueueSyncService>((ref) {
  final service = QueueSyncService(
    cache:        ref.read(offlineCacheProvider),
    connectivity: ref.read(connectivityProvider.notifier),
  );
  // Auto-sync when connectivity returns
  ref.listen(connectivityProvider, (prev, next) {
    if (next.isOnline && (prev == null || !prev.isOnline)) {
      service.syncAll(ref);
    }
  });
  return service;
});

class QueueSyncService {
  final OfflineCacheService cache;
  final ConnectivityNotifier connectivity;
  bool _syncing = false;

  QueueSyncService({required this.cache, required this.connectivity});

  // ── Enqueue actions while offline ────────────────────────────────────────
  Future<void> enqueueBidSubmit({
    required String lineId,
    required String lineNumber,
    required String month,
    required String rank,
    required int priority,
  }) async {
    await cache.enqueueAction(QueuedAction(
      id:        const Uuid().v4(),
      type:      QueuedActionType.submitBid,
      payload:   {
        'lineId':     lineId,
        'lineNumber': lineNumber,
        'month':      month,
        'rank':       rank,
        'priority':   priority,
      },
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueBidWithdraw(String bidId) async {
    await cache.enqueueAction(QueuedAction(
      id:        const Uuid().v4(),
      type:      QueuedActionType.withdrawBid,
      payload:   {'bidId': bidId},
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueReorderBids(List<String> bidIds) async {
    await cache.enqueueAction(QueuedAction(
      id:        const Uuid().v4(),
      type:      QueuedActionType.reorderBids,
      payload:   {'bidIds': bidIds},
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueCreateTrade(Map<String, dynamic> tradeData) async {
    await cache.enqueueAction(QueuedAction(
      id:        const Uuid().v4(),
      type:      QueuedActionType.createTrade,
      payload:   tradeData,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueAcceptTrade(String tradeId, String receiverId) async {
    await cache.enqueueAction(QueuedAction(
      id:        const Uuid().v4(),
      type:      QueuedActionType.acceptTrade,
      payload:   {'tradeId': tradeId, 'receiverId': receiverId},
      createdAt: DateTime.now(),
    ));
  }

  Future<void> enqueueUpdatePreferences(Map<String, dynamic> prefs) async {
    await cache.enqueueAction(QueuedAction(
      id:        const Uuid().v4(),
      type:      QueuedActionType.updatePreferences,
      payload:   prefs,
      createdAt: DateTime.now(),
    ));
  }

  // ── Sync all pending actions ──────────────────────────────────────────────
  Future<SyncResult> syncAll(Ref ref) async {
    if (_syncing) return SyncResult(synced: 0, failed: 0);
    _syncing = true;

    final pending = cache.getPendingActions();
    if (pending.isEmpty) {
      _syncing = false;
      return SyncResult(synced: 0, failed: 0);
    }

    int synced = 0;
    int failed = 0;

    for (final action in pending) {
      try {
        await _processAction(action, ref);
        await cache.removeAction(action.id);
        synced++;
      } catch (e) {
        action.retryCount++;
        if (action.retryCount >= 3) {
          // Give up after 3 retries
          await cache.removeAction(action.id);
          failed++;
        }
      }
    }

    _syncing = false;
    return SyncResult(synced: synced, failed: failed);
  }

  Future<void> _processAction(QueuedAction action, Ref ref) async {
    final bidsRepo   = ref.read(bidsRepositoryProvider);
    final tradesRepo = ref.read(tradesRepositoryProvider);

    switch (action.type) {
      case QueuedActionType.submitBid:
        final bid = Bid(
          id:         const Uuid().v4(),
          userId:     action.payload['userId'] as String? ?? '',
          lineId:     action.payload['lineId'] as String,
          lineNumber: action.payload['lineNumber'] as String,
          month:      action.payload['month'] as String,
          rank:       action.payload['rank'] as String,
          priority:   action.payload['priority'] as int,
          status:     BidStatus.submitted,
          submittedAt:action.createdAt,
          isAutoBid:  false,
        );
        await bidsRepo.submitBid(bid);

      case QueuedActionType.withdrawBid:
        await bidsRepo.withdrawBid(action.payload['bidId'] as String);

      case QueuedActionType.reorderBids:
        // BidsRepository exposes updateBidPriorities(List<Bid>), not
        // reorderBids(List<String>); reconstructing the Bid list here is logic
        // the offline queue never captured. Unwired scaffolding (F13).
        throw UnsupportedError('Offline bid-reorder replay not supported (F13 — not yet wired)');

      case QueuedActionType.createTrade:
        final trade = Trade.fromJson(action.payload);
        await tradesRepo.createTrade(trade);

      case QueuedActionType.acceptTrade:
        // acceptTrade now requires a fresh receiver-side legality verdict
        // (see TradesRepository.acceptTrade), which this offline queue never
        // captured. This path is unwired scaffolding (audit F13: enqueueAcceptTrade
        // has no callers). Fail explicitly rather than write a fabricated
        // legality result; wire a real offline legality check before enabling it.
        throw UnsupportedError(
          'Offline trade-accept requires a live legality check (F13 — not yet wired)',
        );

      case QueuedActionType.updatePreferences:
        // Preferences live on AuthService.updatePreferences(userId, UserPreferences),
        // not a userRepository; the queued Map can't be safely reconstructed here.
        // Unwired scaffolding (F13).
        throw UnsupportedError('Offline preferences replay not supported (F13 — not yet wired)');

      case QueuedActionType.cancelTrade:
        // No cancel path was wired into the offline queue (F13).
        throw UnsupportedError('Offline trade-cancel replay not supported (F13 — not yet wired)');
    }
  }

  int get pendingCount => cache.getPendingActions().length;
}

class SyncResult {
  final int synced;
  final int failed;
  const SyncResult({required this.synced, required this.failed});
}
