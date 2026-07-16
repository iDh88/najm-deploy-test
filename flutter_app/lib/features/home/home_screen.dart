import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../shared/widgets/legality_badge.dart';
import '../../shared/widgets/skeleton_loader.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      body: CustomScrollView(
        slivers: [
          _HomeAppBar(user: user),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (user != null) _AutoBidSuggestionBanner(user: user),
                const SizedBox(height: 16),
                _QuickStatsRow(month: currentMonth),
                const SizedBox(height: 16),
                _ActiveLineCard(month: currentMonth),
                const SizedBox(height: 16),
                _UpcomingDutyCard(month: currentMonth),
                const SizedBox(height: 16),
                _TradeAlertCard(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Home App Bar ─────────────────────────────────────────────────────────────
class _HomeAppBar extends ConsumerWidget {
  final CIPUser? user;
  const _HomeAppBar({this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final greeting = _getGreeting();

    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: CIPTheme.saudiNavy,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [CIPTheme.saudiNavy, Color(0xFF0D3266)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                greeting,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                user?.name ?? 'Welcome',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _ModeChip(mode: user?.userMode ?? UserMode.balanced),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      user?.baseStation ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

class _ModeChip extends StatelessWidget {
  final UserMode mode;
  const _ModeChip({required this.mode});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (mode) {
      UserMode.money => ('💰', 'Money', CIPTheme.moneyGreen),
      UserMode.rest => ('😴', 'Rest', CIPTheme.restBlue),
      UserMode.balanced => ('⚖️', 'Balanced', CIPTheme.balancedPurple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '$icon $label',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Auto Bid Suggestion Banner ───────────────────────────────────────────────
class _AutoBidSuggestionBanner extends StatelessWidget {
  final CIPUser user;
  const _AutoBidSuggestionBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    // Only show for PRO+ users
    if (user.subscriptionTier == SubscriptionTier.free) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFC8A84B), Color(0xFFE8C86B)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Najm Has Bids Ready',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Najm has 3 bid suggestions ready',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(Routes.bids),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white24,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Review', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Stats Row ──────────────────────────────────────────────────────────
class _QuickStatsRow extends ConsumerWidget {
  final String month;
  const _QuickStatsRow({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bidsAsync = ref.watch(userBidsProvider(month));

    return Row(
      children: [
        Expanded(child: _StatCard(
          label: 'Duty Hours', sublabel: 'Duty Hours',
          value: '0', unit: 'h', color: CIPTheme.saudiNavy,
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(
          label: 'Days Off', sublabel: 'Days Off',
          value: '0', unit: 'd', color: CIPTheme.legalGreen,
        )),
        const SizedBox(width: 8),
        Expanded(child: bidsAsync.when(
          data: (bids) => _StatCard(
            label: 'My Bids', sublabel: 'My Bids',
            value: bids.length.toString(), unit: '', color: CIPTheme.saudiGold,
          ),
          loading: () => const SkeletonLoader(height: 80),
          error: (_, __) => const _StatCard(
            label: 'My Bids', sublabel: 'My Bids',
            value: '-', unit: '', color: CIPTheme.saudiGold,
          ),
        )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final String unit;
  final Color color;

  const _StatCard({
    required this.label, required this.sublabel,
    required this.value, required this.unit, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: CIPTheme.grey700, fontFamily: 'Inter')),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              if (unit.isNotEmpty) Text(unit, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
          Text(sublabel, style: const TextStyle(fontSize: 10, color: CIPTheme.grey500)),
        ],
      ),
    );
  }
}

// ─── Active Line Card ─────────────────────────────────────────────────────────
class _ActiveLineCard extends ConsumerWidget {
  final String month;
  const _ActiveLineCard({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('My Current Line', style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter'
              )),
              TextButton(
                onPressed: () => context.push(Routes.lines),
                child: const Text('Browse Lines'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CIPTheme.grey50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No line awarded for this month',
                textAlign: TextAlign.center,
                style: TextStyle(color: CIPTheme.grey500, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Upcoming Duty Card ───────────────────────────────────────────────────────
class _UpcomingDutyCard extends ConsumerWidget {
  final String month;
  const _UpcomingDutyCard({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: CIPTheme.saudiNavy.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.flight_takeoff, color: CIPTheme.saudiNavy),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upcoming Duty', style: TextStyle(
                  fontWeight: FontWeight.w600, fontFamily: 'Inter'
                )),
                Text('No upcoming duties', style: TextStyle(
                  color: CIPTheme.grey500, fontSize: 13
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Trade Alert Card ─────────────────────────────────────────────────────────
class _TradeAlertCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(openTradesProvider);

    return tradesAsync.when(
      data: (trades) {
        if (trades.isEmpty) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => context.push(Routes.trades),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CIPTheme.warningAmberBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CIPTheme.warningAmber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Text('🔄', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${trades.length} trade opportunities available',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const Icon(Icons.chevron_right, color: CIPTheme.grey700),
              ],
            ),
          ),
        );
      },
      loading: () => const SkeletonLoader(height: 60),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
// Pay Computer route: context.go('/salary-calculator')
