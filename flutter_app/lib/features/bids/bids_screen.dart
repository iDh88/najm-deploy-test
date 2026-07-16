import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_cache_service.dart';
import '../../core/services/queue_sync_service.dart';
import '../../shared/widgets/offline_widgets.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../features/lines/lines_screen.dart';
import '../../shared/widgets/shared_widgets.dart';

class BidsScreen extends ConsumerStatefulWidget {
  const BidsScreen({super.key});

  @override
  ConsumerState<BidsScreen> createState() => _BidsScreenState();
}

class _BidsScreenState extends ConsumerState<BidsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _month = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bidsAsync = ref.watch(userBidsProvider(_month));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: const Text('My Bids'),
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: CIPTheme.saudiNavy,
          unselectedLabelColor: CIPTheme.grey500,
          indicatorColor: CIPTheme.saudiNavy,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Suggested'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Active Bids Tab ──
          bidsAsync.when(
            data: (bids) => bids.isEmpty
                ? _EmptyBidsState(onBrowse: () => context.go('/lines'))
                : _BidPriorityStack(bids: bids, month: _month),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          // ── AI Suggestions Tab ──
          _AutoBidSuggestionsTab(user: user, month: _month),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/lines'),
        backgroundColor: CIPTheme.saudiNavy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Browse Lines', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ─── Draggable Priority Stack ─────────────────────────────────────────────────
class _BidPriorityStack extends ConsumerStatefulWidget {
  final List<Bid> bids;
  final String month;
  const _BidPriorityStack({required this.bids, required this.month});

  @override
  ConsumerState<_BidPriorityStack> createState() => _BidPriorityStackState();
}

class _BidPriorityStackState extends ConsumerState<_BidPriorityStack> {
  late List<Bid> _orderedBids;

  @override
  void initState() {
    super.initState();
    _orderedBids = List.from(widget.bids)..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  void didUpdateWidget(_BidPriorityStack old) {
    super.didUpdateWidget(old);
    _orderedBids = List.from(widget.bids)..sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<void> _savePriorities() async {
    final repo = ref.read(bidsRepositoryProvider);
    await repo.updateBidPriorities(_orderedBids);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Priority order saved'), backgroundColor: CIPTheme.legalGreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.drag_indicator, color: CIPTheme.grey500, size: 18),
              const SizedBox(width: 8),
              const Text('Drag to reorder priority', style: TextStyle(fontSize: 13, color: CIPTheme.grey700)),
              const Spacer(),
              TextButton(
                onPressed: _savePriorities,
                child: const Text('Save Order'),
              ),
            ],
          ),
        ),
        // Reorderable list
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _orderedBids.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _orderedBids.removeAt(oldIndex);
                _orderedBids.insert(newIndex, item);
                HapticFeedback.mediumImpact();
              });
            },
            itemBuilder: (context, index) {
              final bid = _orderedBids[index];
              return _BidCard(
                key: ValueKey(bid.id),
                bid: bid,
                rank: index + 1,
                onWithdraw: () => _withdrawBid(bid),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _withdrawBid(Bid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw Bid'),
        content: Text('Withdraw bid for Line ${bid.lineNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw', style: TextStyle(color: CIPTheme.violationRed)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final repo = ref.read(bidsRepositoryProvider);
      await repo.withdrawBid(bid.id);
      HapticFeedback.heavyImpact();
    }
  }
}

class _BidCard extends StatelessWidget {
  final Bid bid;
  final int rank;
  final VoidCallback onWithdraw;

  const _BidCard({super.key, required this.bid, required this.rank, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel) = switch (bid.status) {
      BidStatus.submitted  => (CIPTheme.saudiNavy, 'Submitted'),
      BidStatus.awarded    => (CIPTheme.legalGreen, 'Awarded ✓'),
      BidStatus.rejected   => (CIPTheme.violationRed, 'Not Awarded'),
      BidStatus.withdrawn  => (CIPTheme.grey500, 'Withdrawn'),
      _                    => (CIPTheme.grey500, 'Draft'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: rank == 1 ? CIPTheme.saudiGold.withOpacity(0.15)
                     : rank == 2 ? CIPTheme.grey200
                     : CIPTheme.grey100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('#$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13,
                    color: rank <= 2 ? CIPTheme.saudiGold : CIPTheme.grey700,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text('Line ${bid.lineNumber}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bid.month, style: const TextStyle(fontSize: 12, color: CIPTheme.grey500)),
            if (bid.isAutoBid)
              const Text('⭐ Najm suggested',
                style: TextStyle(fontSize: 11, color: CIPTheme.saudiGold)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
            ),
            if (bid.status == BidStatus.submitted) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: CIPTheme.grey500),
                onPressed: onWithdraw,
                tooltip: 'Withdraw bid',
              ),
            ],
            const Icon(Icons.drag_handle, color: CIPTheme.grey300),
          ],
        ),
      ),
    );
  }
}

// ─── Auto Bid Suggestions Tab ─────────────────────────────────────────────────
class _AutoBidSuggestionsTab extends ConsumerWidget {
  final CIPUser? user;
  final String month;
  const _AutoBidSuggestionsTab({this.user, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (user?.subscriptionTier == SubscriptionTier.free) {
      return _ProUpgradePrompt();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [CIPTheme.saudiNavy, Color(0xFF0D3266)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⭐ Najm AI Suggestions', style: TextStyle(
                color: CIPTheme.saudiGold, fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('Based on your bidding history and preferences',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Column(
            children: [
              SizedBox(height: 32),
              Icon(Icons.auto_awesome, size: 48, color: CIPTheme.grey300),
              SizedBox(height: 16),
              Text('Upload your roster to get\npersonalized bid suggestions',
                textAlign: TextAlign.center,
                style: TextStyle(color: CIPTheme.grey500)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProUpgradePrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Upgrade to PRO', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Get AI-powered bid suggestions based on your schedule preferences and history.',
              textAlign: TextAlign.center, style: TextStyle(color: CIPTheme.grey500)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/profile'),
              child: const Text('View Plans — from SAR 39/mo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyBidsState extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyBidsState({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🗳️', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('No bids yet', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            const SizedBox(height: 8),
            const Text('Browse available lines and submit your first bid',
              textAlign: TextAlign.center, style: TextStyle(color: CIPTheme.grey500)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.flight),
              label: const Text('Browse Lines'),
            ),
          ],
        ),
      ),
    );
  }
}
