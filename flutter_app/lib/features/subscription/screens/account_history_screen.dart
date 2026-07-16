import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';

class AccountHistoryScreen extends ConsumerWidget {
  const AccountHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(accountHistoryProvider);
    final entitlement = watchEntitlement(ref);

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Account History', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _StatusSummaryCard(entitlement: entitlement),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: CIPTheme.primary)),
              error: (e, _) => Center(child: Text(e.toString(),
                  style: const TextStyle(color: CIPTheme.error))),
              data: (events) {
                if (events.isEmpty) {
                  return const _EmptyHistory();
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: events.length,
                  itemBuilder: (_, i) => _HistoryRow(
                    event: events[i],
                    isFirst: i == 0,
                    isLast: i == events.length - 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/subscription/referral'),
                icon: const Icon(Icons.card_giftcard, size: 16),
                label: const Text('Refer Friends'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => context.push('/subscription/upgrade'),
                icon: const Icon(Icons.workspace_premium_outlined, size: 16),
                label: const Text('Upgrade'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CIPTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StatusSummaryCard extends StatelessWidget {
  final Entitlement entitlement;
  const _StatusSummaryCard({required this.entitlement});

  String get _statusLabel {
    if (!entitlement.subscriptionsEnabled) return 'Free Access (Launch Period)';
    switch (entitlement.status) {
      case SubscriptionStatus.trial:     return 'Free Trial';
      case SubscriptionStatus.active:    return 'Pro — Active';
      case SubscriptionStatus.granted:   return 'Pro — Granted';
      case SubscriptionStatus.cancelled: return 'Pro — Cancelled (active until period end)';
      case SubscriptionStatus.expired:   return 'Free Plan';
      case SubscriptionStatus.none:      return 'Free Plan';
    }
  }

  Color get _statusColor =>
      entitlement.isProActive ? CIPTheme.success : CIPTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(entitlement.isProActive ? Icons.verified : Icons.person_outline,
            color: _statusColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_statusLabel,
                  style: TextStyle(
                      color: _statusColor, fontSize: 14, fontWeight: FontWeight.w700)),
              if (entitlement.expirationDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Renews/expires ${_fmt(entitlement.expirationDate!)}',
                    style: const TextStyle(color: CIPTheme.textMuted, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _HistoryRow extends StatelessWidget {
  final AccountHistoryEvent event;
  final bool isFirst, isLast;

  const _HistoryRow({required this.event, required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: CIPTheme.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(event.eventType.icon, style: const TextStyle(fontSize: 16)),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  color: CIPTheme.divider,
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.description,
                      style: const TextStyle(
                          color: CIPTheme.textPrimary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 3),
                  Text(_relativeTime(event.createdAt),
                      style: const TextStyle(color: CIPTheme.textMuted, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text('No activity yet',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Trial activations, subscription changes, and bonus\ndays will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CIPTheme.textSecondary, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
