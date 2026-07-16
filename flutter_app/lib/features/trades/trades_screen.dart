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
import '../../core/services/ai_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class TradesScreen extends ConsumerStatefulWidget {
  const TradesScreen({super.key});

  @override
  ConsumerState<TradesScreen> createState() => _TradesScreenState();
}

class _TradesScreenState extends ConsumerState<TradesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isPro = user?.subscriptionTier != SubscriptionTier.free;

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: const Text('Trade Board'),
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: CIPTheme.saudiNavy,
          unselectedLabelColor: CIPTheme.grey500,
          indicatorColor: CIPTheme.saudiNavy,
          tabs: const [
            Tab(text: 'Open Board'),
            Tab(text: 'My Trades'),
            Tab(text: 'Incoming'),
          ],
        ),
      ),
      body: !isPro
          ? _ProGate()
          : TabBarView(
              controller: _tabController,
              children: [
                _OpenTradeBoard(),
                _MyTradesTab(),
                _IncomingTradesTab(),
              ],
            ),
      floatingActionButton: isPro
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/trades/new'),
              backgroundColor: CIPTheme.saudiNavy,
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              label: const Text('Post Trade', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

// ─── Open Trade Board ─────────────────────────────────────────────────────────
class _OpenTradeBoard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(openTradesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;

    return tradesAsync.when(
      data: (trades) {
        final myTrades = trades.where((t) => t.initiatorId == user?.id).toList();
        final otherTrades = trades.where((t) => t.initiatorId != user?.id).toList();

        if (trades.isEmpty) {
          return _EmptyTradeBoard();
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (otherTrades.isNotEmpty) ...[
              _SectionHeader(title: 'Available Trades', count: otherTrades.length),
              const SizedBox(height: 8),
              ...otherTrades.map((t) => _TradeCard(trade: t, isOwn: false)),
            ],
            if (myTrades.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionHeader(title: 'My Open Posts', count: myTrades.length),
              const SizedBox(height: 8),
              ...myTrades.map((t) => _TradeCard(trade: t, isOwn: true)),
            ],
          ],
        );
      },
      loading: () => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const SkeletonLoader(height: 120),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ─── Trade Card ───────────────────────────────────────────────────────────────
class _TradeCard extends ConsumerWidget {
  final Trade trade;
  final bool isOwn;
  const _TradeCard({required this.trade, required this.isOwn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeLeft = trade.expiresAt.difference(DateTime.now());
    final timeLeftStr = timeLeft.inHours > 0
        ? '${timeLeft.inHours}h left'
        : '${timeLeft.inMinutes}m left';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOwn
            ? CIPTheme.saudiNavy.withOpacity(0.3)
            : CIPTheme.grey200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _tradeTypeColor(trade.type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_tradeTypeLabel(trade.type),
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: _tradeTypeColor(trade.type),
                    )),
                ),
                const Spacer(),
                Text(timeLeftStr,
                  style: const TextStyle(fontSize: 11, color: CIPTheme.grey500)),
              ],
            ),
            const SizedBox(height: 12),

            // Offered vs Requested legs
            Row(
              children: [
                Expanded(child: _LegMiniCard(
                  label: 'Offering',
                  leg: trade.offeredLeg,
                  color: CIPTheme.violationRed.withOpacity(0.05),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.swap_horiz,
                    color: CIPTheme.grey500, size: 20),
                ),
                Expanded(child: trade.requestedLeg != null
                  ? _LegMiniCard(
                      label: 'Wants',
                      leg: trade.requestedLeg!,
                      color: CIPTheme.legalGreen.withOpacity(0.05),
                    )
                  : _OpenWantCard()),
              ],
            ),

            if (trade.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(trade.note, style: const TextStyle(
                fontSize: 12, color: CIPTheme.grey700, fontStyle: FontStyle.italic)),
            ],

            const SizedBox(height: 12),

            // Action buttons
            if (!isOwn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _acceptTrade(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CIPTheme.saudiNavy,
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Accept Trade', style: TextStyle(color: Colors.white)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _cancelTrade(context, ref),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CIPTheme.violationRed),
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel Post',
                    style: TextStyle(color: CIPTheme.violationRed)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _tradeTypeColor(TradeType type) => switch (type) {
    TradeType.direct  => CIPTheme.saudiNavy,
    TradeType.openDrop => CIPTheme.warningAmber,
    TradeType.pickUp  => CIPTheme.legalGreen,
    TradeType.swap    => CIPTheme.balancedPurple,
  };

  String _tradeTypeLabel(TradeType type) => switch (type) {
    TradeType.direct   => 'Direct Trade',
    TradeType.openDrop => 'Open Drop',
    TradeType.pickUp   => 'Pick Up',
    TradeType.swap     => 'Full Swap',
  };

  Future<void> _acceptTrade(BuildContext context, WidgetRef ref) async {
    // Show legality check loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking legality...'),
            ],
          ),
        ),
      )),
    );

    // Simulate legality check (real implementation calls checkLegality Cloud Function)
    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted) Navigator.pop(context);

    // Show result
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade accepted — pending confirmation'),
          backgroundColor: CIPTheme.legalGreen,
        ),
      );
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _cancelTrade(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Trade Post'),
        content: const Text('This will remove your trade from the board.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Post', style: TextStyle(color: CIPTheme.violationRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final repo = ref.read(tradesRepositoryProvider);
      await repo.cancelTrade(trade.id);
    }
  }
}

class _LegMiniCard extends StatelessWidget {
  final String label;
  final TradeLeg leg;
  final Color color;
  const _LegMiniCard({required this.label, required this.leg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: CIPTheme.grey500)),
          const SizedBox(height: 4),
          Text(leg.flightNumber,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('${leg.origin} → ${leg.destination}',
            style: const TextStyle(fontSize: 12)),
          Text(DateFormat('dd MMM').format(leg.departureUTC),
            style: const TextStyle(fontSize: 11, color: CIPTheme.grey500)),
        ],
      ),
    );
  }
}

class _OpenWantCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CIPTheme.grey50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CIPTheme.grey200, style: BorderStyle.solid),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Open', style: TextStyle(fontSize: 10, color: CIPTheme.grey500)),
          SizedBox(height: 4),
          Text('Any leg', style: TextStyle(fontSize: 13, color: CIPTheme.grey700)),
          Text('accepted', style: TextStyle(fontSize: 11, color: CIPTheme.grey500)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: CIPTheme.saudiNavy.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: CIPTheme.saudiNavy)),
        ),
      ],
    );
  }
}

class _MyTradesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(userTradesProvider);
    return tradesAsync.when(
      data: (trades) => trades.isEmpty
          ? _EmptyTradeBoard()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: trades.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _TradeCard(trade: trades[i], isOwn: true),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _IncomingTradesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Text('No incoming trade requests', style: TextStyle(color: CIPTheme.grey500)),
    );
  }
}

class _EmptyTradeBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔄', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('Trade board is empty', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
          const SizedBox(height: 8),
          const Text('No open trades right now.\nPost one to get started.',
            textAlign: TextAlign.center, style: TextStyle(color: CIPTheme.grey500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/trades/new'),
            icon: const Icon(Icons.add),
            label: const Text('Post a Trade'),
          ),
        ],
      ),
    );
  }
}

class _ProGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔄', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Trade Board', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Access the trade board to swap individual flight legs with other crew members.',
              textAlign: TextAlign.center, style: TextStyle(color: CIPTheme.grey500)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/profile'),
              child: const Text('Upgrade to PRO — SAR 39/mo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trade Detail and Initiate screens (stubs for routing) ───────────────────
class TradeDetailScreen extends StatelessWidget {
  final String tradeId;
  const TradeDetailScreen({super.key, required this.tradeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Trade $tradeId')),
      body: const Center(child: Text('Trade detail — full implementation in Phase 2')),
    );
  }
}

class TradeInitiateScreen extends StatelessWidget {
  const TradeInitiateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Trade')),
      body: const Center(child: Text('Trade initiation flow — full implementation in Phase 2')),
    );
  }
}
