import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_cache_service.dart';
import '../../core/services/queue_sync_service.dart';

// ─── Offline Banner ───────────────────────────────────────────────────────────
/// Sticky banner shown at the top of every screen when offline.
/// Shows cached data age + pending action count + retry button.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    if (connectivity.isOnline) return const SizedBox.shrink();

    final cache       = ref.read(offlineCacheProvider);
    final queueSync   = ref.read(queueSyncProvider);
    final meta        = cache.getMeta();
    final pending     = queueSync.pendingCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: const Color(0xFF1A1A2E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              color: CIPTheme.warningAmber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You are offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _buildSubtitle(meta, pending),
                  style: const TextStyle(
                    color: CIPTheme.grey500,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (pending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CIPTheme.warningAmber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pending pending',
                style: const TextStyle(
                  color: CIPTheme.warningAmber,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(connectivityProvider.notifier).checkNow(),
            child: const Icon(
              Icons.refresh,
              color: CIPTheme.grey500,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(CacheMeta meta, int pending) {
    final parts = <String>[];
    if (meta.linesCachedAt != null) {
      parts.add(_age(meta.linesCachedAt!));
    }
    if (pending > 0) {
      parts.add('$pending action${pending > 1 ? 's' : ''} will sync when online');
    }
    if (parts.isEmpty) return 'Showing cached data';
    return parts.join(' · ');
  }

  String _age(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60)  return 'Data from ${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return 'Data from ${diff.inHours}h ago';
    return 'Data from ${diff.inDays}d ago';
  }
}

// ─── Sync Success Banner ──────────────────────────────────────────────────────
/// Shown briefly when coming back online and syncing pending actions.
class SyncSuccessBanner extends StatefulWidget {
  final int syncedCount;
  const SyncSuccessBanner({super.key, required this.syncedCount});

  @override
  State<SyncSuccessBanner> createState() => _SyncSuccessBannerState();
}

class _SyncSuccessBannerState extends State<SyncSuccessBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        color: CIPTheme.legalGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Back online · ${widget.syncedCount} action${widget.syncedCount > 1 ? 's' : ''} synced ✓',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Offline Screen Wrapper ───────────────────────────────────────────────────
/// Wraps any screen to show cached data message when offline.
/// Use this on Lines, Bids, and Trades screens.
class OfflineScreenWrapper extends ConsumerWidget {
  final Widget child;
  final bool showBanner;

  const OfflineScreenWrapper({
    super.key,
    required this.child,
    this.showBanner = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (showBanner) const OfflineBanner(),
        Expanded(child: child),
      ],
    );
  }
}

// ─── Offline Action Button ────────────────────────────────────────────────────
/// Button that queues action when offline, executes immediately when online.
class OfflineAwareButton extends ConsumerWidget {
  final String label;
  final String offlineLabel;
  final VoidCallback onOnline;
  final VoidCallback onOffline;
  final Color? color;

  const OfflineAwareButton({
    super.key,
    required this.label,
    required this.offlineLabel,
    required this.onOnline,
    required this.onOffline,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider).isOnline;

    return ElevatedButton(
      onPressed: isOnline ? onOnline : onOffline,
      style: ElevatedButton.styleFrom(
        backgroundColor: isOnline
            ? (color ?? CIPTheme.saudiNavy)
            : CIPTheme.warningAmber,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isOnline) ...[
            const Icon(Icons.cloud_off, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            isOnline ? label : offlineLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI Offline Placeholder ───────────────────────────────────────────────────
/// Shown in the AI assistant when offline.
class AiOfflinePlaceholder extends StatelessWidget {
  const AiOfflinePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: CIPTheme.grey100,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text('⭐', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Najm is offline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CIPTheme.grey900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI features require an internet connection.\nYour conversation history is saved locally.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CIPTheme.grey500,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CIPTheme.grey50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CIPTheme.grey200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'While offline you can still:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  _OfflineCapability('View your cached flight lines'),
                  _OfflineCapability('Browse your submitted bids'),
                  _OfflineCapability('Use the Salary Calculator'),
                  _OfflineCapability('View legality results'),
                  _OfflineCapability('Queue bids and trades to sync later'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineCapability extends StatelessWidget {
  final String text;
  const _OfflineCapability(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: CIPTheme.legalGreen, size: 14),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(
            color: CIPTheme.grey700, fontSize: 12)),
        ],
      ),
    );
  }
}

// ─── Offline Data Card ────────────────────────────────────────────────────────
/// Shows on Lines/Bids screens to indicate data is from cache.
class CachedDataCard extends ConsumerWidget {
  final String dataType;
  const CachedDataCard({super.key, required this.dataType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.read(offlineCacheProvider);
    final meta  = cache.getMeta();

    DateTime? cachedAt;
    switch (dataType) {
      case 'lines':   cachedAt = meta.linesCachedAt;
      case 'bids':    cachedAt = meta.bidsCachedAt;
      case 'trades':  cachedAt = meta.tradesCachedAt;
    }

    if (cachedAt == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CIPTheme.warningAmber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CIPTheme.warningAmber.withOpacity(0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off,
              color: CIPTheme.warningAmber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing cached $dataType · ${cache.cacheAgeString(cachedAt)}',
              style: const TextStyle(
                color: CIPTheme.warningAmber,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
