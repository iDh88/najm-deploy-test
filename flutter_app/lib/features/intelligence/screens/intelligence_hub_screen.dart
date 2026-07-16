import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/intelligence_models.dart';
import '../providers/intelligence_providers.dart';
import '../widgets/all_widgets.dart';
import 'upload_screen.dart';

class IntelligenceHubScreen extends ConsumerWidget {
  const IntelligenceHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Replace with real userId from auth
    const userId = 'demo_user';
    final linesAsync = ref.watch(userLinesProvider(userId));

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _HubHeader(),
          ),

          // ── Quick stats ──────────────────────────────────────────────────
          linesAsync.when(
            data: (lines) => SliverToBoxAdapter(
              child: lines.isNotEmpty
                  ? _QuickStats(lines: lines)
                  : const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error:   (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ── Action row ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      icon: '📄',
                      label: 'Upload PDF',
                      subtitle: 'Analyze new schedule',
                      color: NajmTheme.gold,
                      onTap: () => context.push('/intelligence/upload'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: '🔍',
                      label: 'Smart Search',
                      subtitle: 'Filter & find lines',
                      color: NajmTheme.info,
                      onTap: () => context.push('/intelligence/search'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionCard(
                      icon: '⚖️',
                      label: 'Compare',
                      subtitle: 'Line vs line',
                      color: NajmTheme.saudiGreen,
                      onTap: () => context.push('/intelligence/compare'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Lines list ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Analyzed Lines',
                    style: TextStyle(
                      color: NajmTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  linesAsync.when(
                    data: (l) => Text(
                      '${l.length} lines',
                      style: const TextStyle(
                          color: NajmTheme.textMuted, fontSize: 12),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error:   (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),

          linesAsync.when(
            data: (lines) => lines.isEmpty
                ? SliverToBoxAdapter(child: _EmptyState())
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _LineCard(line: lines[i], index: i),
                        childCount: lines.length,
                      ),
                    ),
                  ),
            loading: () => SliverToBoxAdapter(child: _LoadingList()),
            error:   (e, _) => SliverToBoxAdapter(
              child: Center(
                child: Text(e.toString(),
                    style: const TextStyle(color: NajmTheme.error)),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/intelligence/upload'),
        backgroundColor: NajmTheme.gold,
        foregroundColor: NajmTheme.navy,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload PDF',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HubHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [NajmTheme.navyMid, NajmTheme.navy],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: NajmTheme.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: NajmTheme.gold.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'PHASE 2',
                      style: TextStyle(
                        color: NajmTheme.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'PDF Intelligence\nEngine',
                style: TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aviation-grade schedule analysis · Fatigue scoring · Smart insights',
                style: TextStyle(
                    color: NajmTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Quick stats ───────────────────────────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  final List<MonthlyLine> lines;
  const _QuickStats({required this.lines});

  @override
  Widget build(BuildContext context) {
    final avgFatigue = lines.isEmpty
        ? 0.0
        : lines.map((l) => l.fatigueProfile.averageFatigue).reduce((a, b) => a + b) /
            lines.length;
    final totalBlock = lines.fold(0.0,
        (sum, l) => sum + l.summary.blockHours);
    final lowFatigue = lines
        .where((l) => l.fatigueProfile.overallLevel == FatigueLevel.low)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          _StatChip(label: 'Avg Fatigue',
              value: '${(avgFatigue * 100).round()}%',
              color: avgFatigue > 0.6 ? NajmTheme.error
                   : avgFatigue > 0.35 ? NajmTheme.warning
                   : NajmTheme.success),
          const SizedBox(width: 8),
          _StatChip(label: 'Total Block',
              value: '${totalBlock.toStringAsFixed(0)}h',
              color: NajmTheme.gold),
          const SizedBox(width: 8),
          _StatChip(label: 'Low Fatigue Lines',
              value: '$lowFatigue/${lines.length}',
              color: NajmTheme.success),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: NajmTheme.textMuted, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Action card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String icon, label, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: NajmTheme.navyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: const TextStyle(
                    color: NajmTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ── Line card ─────────────────────────────────────────────────────────────────

class _LineCard extends StatelessWidget {
  final MonthlyLine line;
  final int index;
  const _LineCard({required this.line, required this.index});

  @override
  Widget build(BuildContext context) {
    final clf = line.classification;
    final fp  = line.fatigueProfile;
    final color = Color(int.parse(clf.color.replaceAll('#', 'FF'), radix: 16));

    return GestureDetector(
      onTap: () => context.push('/intelligence/lines/${line.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NajmTheme.navyCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Classification badge
                LineClassificationBadge(classification: clf),
                const Spacer(),
                Text(
                  line.period,
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Key metrics row
            Row(
              children: [
                _Metric(label: 'Block', value: '${line.summary.blockHours.toStringAsFixed(0)}h', icon: '✈️'),
                _Metric(label: 'Credit', value: '${line.summary.estimatedCredit.toStringAsFixed(0)}h', icon: '💰'),
                _Metric(label: 'Pairings', value: '${line.summary.totalPairings}', icon: '📋'),
                _Metric(label: 'Off Days', value: '${line.summary.offDays}', icon: '🏖️'),
              ],
            ),
            const SizedBox(height: 14),

            // Fatigue bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Fatigue Load',
                      style: const TextStyle(
                          color: NajmTheme.textMuted, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '${fp.fatiguePercentage}% · ${fp.overallLevel.name.toUpperCase()}',
                      style: TextStyle(
                          color: _fatigueLevelColor(fp.overallLevel),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fp.averageFatigue.clamp(0.0, 1.0),
                    backgroundColor: NajmTheme.navyLight,
                    valueColor: AlwaysStoppedAnimation(
                        _fatigueLevelColor(fp.overallLevel)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),

            if (line.insights.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: NajmTheme.navyLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(line.insights.first.icon,
                        style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line.insights.first.titleEn,
                        style: const TextStyle(
                            color: NajmTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: index * 60))
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.06, end: 0),
    );
  }

  Color _fatigueLevelColor(FatigueLevel l) {
    switch (l) {
      case FatigueLevel.high:   return NajmTheme.error;
      case FatigueLevel.medium: return NajmTheme.warning;
      case FatigueLevel.low:    return NajmTheme.success;
    }
  }
}

class _Metric extends StatelessWidget {
  final String label, value, icon;
  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(
                  color: NajmTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Text('📄', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            const Text('No Analyzed Lines',
                style: TextStyle(
                    color: NajmTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Upload your monthly schedule PDF\nto start the intelligence analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: NajmTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (i) => Container(
          height: 140,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: NajmTheme.navyLight,
            borderRadius: BorderRadius.circular(18),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1200.ms, color: NajmTheme.navyCard)),
      ),
    );
  }
}
