import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/intelligence_models.dart';
import '../providers/intelligence_providers.dart';
import '../widgets/all_widgets.dart';

class LineDashboardScreen extends ConsumerStatefulWidget {
  final String lineId;
  const LineDashboardScreen({super.key, required this.lineId});

  @override
  ConsumerState<LineDashboardScreen> createState() => _LineDashboardState();
}

class _LineDashboardState extends ConsumerState<LineDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lineAsync = ref.watch(lineDetailProvider(widget.lineId));

    return lineAsync.when(
      loading: () => const Scaffold(
        backgroundColor: NajmTheme.navy,
        body: Center(child: CircularProgressIndicator(color: NajmTheme.gold)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: NajmTheme.navy,
        body: Center(child: Text(e.toString(),
            style: const TextStyle(color: NajmTheme.error))),
      ),
      data: (line) {
        if (line == null) {
          return const Scaffold(
            backgroundColor: NajmTheme.navy,
            body: Center(child: Text('Line not found',
                style: TextStyle(color: NajmTheme.textSecondary))),
          );
        }
        return _buildDashboard(line);
      },
    );
  }

  Widget _buildDashboard(MonthlyLine line) {
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: NajmTheme.navyMid,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: NajmTheme.textPrimary),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.compare_arrows, color: NajmTheme.gold),
                onPressed: () => context.push('/intelligence/compare'),
                tooltip: 'Compare',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 56),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Line ${line.lineNumber}',
                      style: const TextStyle(
                          color: NajmTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  Text(line.period,
                      style: const TextStyle(
                          color: NajmTheme.textSecondary, fontSize: 12)),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [NajmTheme.navyMid, NajmTheme.navy],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 50, 20, 0),
                    child: LineClassificationBadge(
                        classification: line.classification, large: true),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: NajmTheme.gold,
              labelColor: NajmTheme.gold,
              unselectedLabelColor: NajmTheme.textMuted,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: '📊  Overview'),
                Tab(text: '✈️  Pairings'),
                Tab(text: '🔋  Fatigue'),
                Tab(text: '📅  Calendar'),
                Tab(text: '💡  Insights'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _OverviewTab(line: line),
            _PairingsTab(lineId: widget.lineId),
            _FatigueTab(line: line, lineId: widget.lineId),
            _CalendarTab(line: line),
            _InsightsTab(insights: line.insights),
          ],
        ),
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final MonthlyLine line;
  const _OverviewTab({required this.line});

  @override
  Widget build(BuildContext context) {
    final s = line.summary;
    final fp = line.fatigueProfile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Metric grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _MetricCard('Block Hours',    '${s.blockHours.toStringAsFixed(1)}h', '✈️', NajmTheme.gold),
            _MetricCard('Est. Credit',    '${s.estimatedCredit.toStringAsFixed(1)}h', '💰', NajmTheme.success),
            _MetricCard('Duty Hours',     '${s.dutyHours.toStringAsFixed(1)}h', '⏱️', NajmTheme.info),
            _MetricCard('Per Diem',       '\$${s.estimatedPerDiem.toStringAsFixed(0)}', '💵', NajmTheme.saudiGreen),
            _MetricCard('Total Pairings', '${s.totalPairings}', '📋', NajmTheme.warning),
            _MetricCard('Off Days',       '${s.offDays}', '🏖️', NajmTheme.textSecondary),
            _MetricCard('Intl Legs',      '${s.internationalCount}', '🌍', NajmTheme.gold),
            _MetricCard('Deadhead Legs',  '${s.deadheadLegs}', '🔄', NajmTheme.error),
          ],
        ),
        const SizedBox(height: 20),

        // Fatigue summary card
        _SectionCard(
          title: 'Fatigue Summary',
          child: Column(
            children: [
              _FatigueRow('Average Fatigue', '${fp.fatiguePercentage}%',
                  fp.averageFatigue, fp.overallLevel),
              const SizedBox(height: 12),
              _FatigueRow('Peak Fatigue',
                  '${(fp.peakFatigue * 100).round()}%',
                  fp.peakFatigue, FatigueLevel.high),
              const SizedBox(height: 12),
              Row(children: [
                _FatigueStat('High Days', '${fp.highFatigueDays}', NajmTheme.error),
                _FatigueStat('WOCL', '${fp.woclTotalMinutes ~/ 60}h', NajmTheme.warning),
                _FatigueStat('Early Sign-ins', '${fp.earlySigninCount}', NajmTheme.info),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Destinations
        _SectionCard(
          title: 'Destinations (${s.uniqueDestinations.length})',
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: s.uniqueDestinations.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: NajmTheme.navyLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NajmTheme.cardBorder),
              ),
              child: Text(d,
                  style: const TextStyle(
                      color: NajmTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            )).toList(),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, icon;
  final Color color;
  const _MetricCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NajmTheme.navyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FatigueRow extends StatelessWidget {
  final String label, value;
  final double progress;
  final FatigueLevel level;
  const _FatigueRow(this.label, this.value, this.progress, this.level);

  Color get _color => level == FatigueLevel.high   ? NajmTheme.error
                    : level == FatigueLevel.medium  ? NajmTheme.warning
                    : NajmTheme.success;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: const TextStyle(
              color: NajmTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(
              color: _color, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: NajmTheme.navyLight,
            valueColor: AlwaysStoppedAnimation(_color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

class _FatigueStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FatigueStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(
            color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(
            color: NajmTheme.textMuted, fontSize: 10), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NajmTheme.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(
              color: NajmTheme.textPrimary,
              fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── Pairings Tab ──────────────────────────────────────────────────────────────

class _PairingsTab extends ConsumerWidget {
  final String lineId;
  const _PairingsTab({required this.lineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairingsAsync = ref.watch(pairingsProvider(lineId));
    return pairingsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: NajmTheme.gold)),
      error: (e, _) => Center(child: Text(e.toString(),
          style: const TextStyle(color: NajmTheme.error))),
      data: (pairings) => pairings.isEmpty
          ? const Center(child: Text('No pairings found',
              style: TextStyle(color: NajmTheme.textSecondary)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                PairingGanttWidget(pairings: pairings),
                const SizedBox(height: 20),
                ...pairings.map((p) => _PairingTile(pairing: p)),
              ],
            ),
    );
  }
}

class _PairingTile extends StatelessWidget {
  final Pairing pairing;
  const _PairingTile({required this.pairing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/intelligence/pairings/${pairing.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NajmTheme.navyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pairing.isLegal
                ? NajmTheme.cardBorder
                : NajmTheme.error.withOpacity(0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(pairing.pairingNumber,
                  style: const TextStyle(
                      color: NajmTheme.gold,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _ClassBadge(pairing.classification),
              const Spacer(),
              if (!pairing.isLegal)
                const Icon(Icons.warning, color: NajmTheme.error, size: 16),
              Text('${pairing.blockHours.toStringAsFixed(1)}h BLK',
                  style: const TextStyle(
                      color: NajmTheme.textSecondary, fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            // Segment ladder preview
            ...pairing.segments.take(4).map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(
                  s.isDeadhead ? Icons.airline_seat_recline_normal : Icons.flight,
                  color: s.isDeadhead ? NajmTheme.info : NajmTheme.gold,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text('${s.flightNumber}  ${s.origin}→${s.destination}',
                    style: TextStyle(
                        color: s.isDeadhead
                            ? NajmTheme.textSecondary
                            : NajmTheme.textPrimary,
                        fontSize: 12)),
                const Spacer(),
                Text('${s.blockHours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                        color: NajmTheme.textMuted, fontSize: 11)),
              ]),
            )),
            if (pairing.segments.length > 4)
              Text('+${pairing.segments.length - 4} more segments',
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 8),
            Row(children: [
              Text('Duty: ${pairing.dutyHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 11)),
              const SizedBox(width: 12),
              Text('FDP: ${pairing.fdpHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 11)),
              const Spacer(),
              if (pairing.isInternational)
                const Text('🌍 Intl',
                    style: TextStyle(
                        color: NajmTheme.info, fontSize: 11)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ClassBadge extends StatelessWidget {
  final String label;
  const _ClassBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: NajmTheme.navyLight,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Text(label.replaceAll('_', ' '),
          style: const TextStyle(
              color: NajmTheme.textSecondary, fontSize: 9,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Fatigue Tab ───────────────────────────────────────────────────────────────

class _FatigueTab extends ConsumerWidget {
  final MonthlyLine line;
  final String lineId;
  const _FatigueTab({required this.line, required this.lineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(fatigueTimelineProvider(lineId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Fatigue level card
        _FatigueHeaderCard(profile: line.fatigueProfile),
        const SizedBox(height: 16),

        // Timeline chart
        timelineAsync.when(
          data:    (pts) => FatigueChartWidget(points: pts),
          loading: () => Container(
            height: 180,
            decoration: BoxDecoration(
              color: NajmTheme.navyCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
                child: CircularProgressIndicator(color: NajmTheme.gold)),
          ),
          error: (e, _) => Container(
            height: 100,
            alignment: Alignment.center,
            child: Text(e.toString(),
                style: const TextStyle(color: NajmTheme.error)),
          ),
        ),
      ],
    );
  }
}

class _FatigueHeaderCard extends StatelessWidget {
  final LineFatigueProfile profile;
  const _FatigueHeaderCard({required this.profile});

  Color get _levelColor => profile.overallLevel == FatigueLevel.high
      ? NajmTheme.error
      : profile.overallLevel == FatigueLevel.medium
          ? NajmTheme.warning
          : NajmTheme.success;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _levelColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _levelColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile.overallLevel.name.toUpperCase()} FATIGUE',
                style: TextStyle(
                    color: _levelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2),
              ),
              Text(
                '${profile.fatiguePercentage}%',
                style: TextStyle(
                    color: _levelColor,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1),
              ),
              Text('average fatigue load',
                  style: const TextStyle(
                      color: NajmTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _FatStat('High days', '${profile.highFatigueDays}', NajmTheme.error),
              const SizedBox(height: 8),
              _FatStat('WOCL hours', '${profile.woclTotalMinutes ~/ 60}h', NajmTheme.warning),
              const SizedBox(height: 8),
              _FatStat('Early sign-ins', '${profile.earlySigninCount}', NajmTheme.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _FatStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FatStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(
          color: NajmTheme.textMuted, fontSize: 11)),
      const SizedBox(width: 8),
      Text(value, style: TextStyle(
          color: color, fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Calendar Tab ──────────────────────────────────────────────────────────────

class _CalendarTab extends StatelessWidget {
  final MonthlyLine line;
  const _CalendarTab({required this.line});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        MonthlyHeatmapWidget(line: line),
      ],
    );
  }
}

// ── Insights Tab ──────────────────────────────────────────────────────────────

class _InsightsTab extends StatelessWidget {
  final List<LineInsight> insights;
  const _InsightsTab({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const Center(
        child: Text('No insights available',
            style: TextStyle(color: NajmTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: insights.length,
      itemBuilder: (_, i) => InsightCardWidget(insight: insights[i], index: i),
    );
  }
}
