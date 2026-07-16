import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import 'models.dart';
import 'recommendation_provider.dart';
import 'widgets/match_card.dart';
import 'widgets/search_header.dart';
import 'widgets/cold_start_banner.dart';
import 'widgets/score_breakdown_sheet.dart';
import 'widgets/prn_workflow_sheet.dart';

class TradeSearchScreen extends ConsumerStatefulWidget {
  /// Pre-filled from the line detail screen when crew taps a trip
  final String? prefillRoute;
  final double? prefillBlockHours;
  final double? prefillDutyHours;
  final int?    prefillFdpMinutes;
  final int?    prefillSigninHour;
  final bool?   prefillIsInternational;
  final double? prefillFatigueScore;
  final String? month;

  const TradeSearchScreen({
    super.key,
    this.prefillRoute,
    this.prefillBlockHours,
    this.prefillDutyHours,
    this.prefillFdpMinutes,
    this.prefillSigninHour,
    this.prefillIsInternational,
    this.prefillFatigueScore,
    this.month,
  });

  @override
  ConsumerState<TradeSearchScreen> createState() => _TradeSearchScreenState();
}

class _TradeSearchScreenState extends ConsumerState<TradeSearchScreen> {
  final _routeCtrl = TextEditingController();
  String? _selectedMonth;
  bool _searched = false;

  // Demo user — replace with real auth provider
  static const _userId = 'demo_crew_001';
  static const _rank   = 'CA';

  @override
  void initState() {
    super.initState();
    if (widget.prefillRoute != null) {
      _routeCtrl.text = widget.prefillRoute!;
    }
    _selectedMonth = widget.month ?? _currentMonth();
  }

  @override
  void dispose() {
    _routeCtrl.dispose();
    super.dispose();
  }

  String _currentMonth() {
    final now = DateTime.now();
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN',
      'JUL','AUG','SEP','OCT','NOV','DEC',
    ];
    return '${months[now.month - 1]}-${now.year}';
  }

  Future<void> _runSearch() async {
    final route = _routeCtrl.text.trim().toUpperCase();
    if (route.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _searched = true);

    await ref.read(tradeSearchProvider.notifier).search(
      userId:          _userId,
      rank:            _rank,
      month:           _selectedMonth!,
      routeKey:        route,
      blockHours:      widget.prefillBlockHours  ?? 4.5,
      dutyHours:       widget.prefillDutyHours   ?? 7.0,
      fdpMinutes:      widget.prefillFdpMinutes  ?? 420,
      signinHour:      widget.prefillSigninHour  ?? 8,
      layoverHours:    0.0,
      isInternational: widget.prefillIsInternational ?? true,
      hasDeadhead:     false,
      fatigueScore:    widget.prefillFatigueScore ?? 0.4,
      tripDates:       [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(tradeSearchProvider);

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Find Trade Match',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (searchState.hasResults)
            TextButton(
              onPressed: () {
                ref.read(tradeSearchProvider.notifier).reset();
                setState(() => _searched = false);
              },
              child: const Text('Reset',
                  style: TextStyle(color: CIPTheme.primary)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search header ────────────────────────────────────────────────
          SearchHeader(
            routeController: _routeCtrl,
            selectedMonth:   _selectedMonth!,
            onMonthChanged:  (m) => setState(() => _selectedMonth = m),
            onSearch:        _runSearch,
            isLoading:       searchState.isLoading,
            isPrefilled:     widget.prefillRoute != null,
          ),

          // ── Results ──────────────────────────────────────────────────────
          Expanded(
            child: _buildResults(searchState),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(TradeSearchState state) {
    if (!_searched && !state.hasResults) {
      return _IdleState(hasPrefill: widget.prefillRoute != null);
    }

    if (state.isLoading) {
      return _LoadingState();
    }

    if (state.status == SearchStatus.error) {
      return _ErrorState(error: state.error ?? 'Search failed');
    }

    if (!state.hasResults) {
      return _EmptyState(route: _routeCtrl.text);
    }

    final result = state.result!;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: result.matches.length + 2, // header + cold-start banner
      itemBuilder: (ctx, i) {
        // Stats header
        if (i == 0) {
          return _ResultsHeader(result: result);
        }
        // Cold-start notice
        if (i == 1 && result.isColdStart) {
          return const ColdStartBanner();
        }
        final matchIndex = i - (result.isColdStart ? 2 : 1);
        if (matchIndex >= result.matches.length) return const SizedBox.shrink();

        final match = result.matches[matchIndex];
        return MatchCard(
          match:   match,
          index:   matchIndex,
          tradeId: state.activeTradeId,
          userId:  _userId,
          onViewBreakdown: () => _showBreakdown(ctx, match),
          onOpenPRN:       () => _showPRNWorkflow(ctx, match, state.activeTradeId),
          onAccepted:      () => ref.read(tradeSearchProvider.notifier)
              .recordAccepted(
                userId:          _userId,
                prn:             match.prn,
                blockHours:      widget.prefillBlockHours  ?? 4.5,
                dutyHours:       widget.prefillDutyHours   ?? 7.0,
                fatigueScore:    widget.prefillFatigueScore ?? 0.4,
                isInternational: widget.prefillIsInternational ?? true,
                hasDeadhead:     false,
                signinHour:      widget.prefillSigninHour  ?? 8,
                layoverHours:    0.0,
              ),
        )
            .animate(delay: Duration(milliseconds: matchIndex * 55))
            .fadeIn(duration: 280.ms)
            .slideY(begin: 0.06, end: 0);
      },
    );
  }

  void _showBreakdown(BuildContext ctx, TradeMatch match) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: CIPTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ScoreBreakdownSheet(match: match),
    );
  }

  void _showPRNWorkflow(
      BuildContext ctx, TradeMatch match, String tradeId) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: CIPTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => PRNWorkflowSheet(
        match:   match,
        tradeId: tradeId,
        userId:  _userId,
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ResultsHeader extends StatelessWidget {
  final TradeSearchResult result;
  const _ResultsHeader({required this.result});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        children: [
          _Chip('${result.matchCount} Matches', CIPTheme.primary),
          const SizedBox(width: 8),
          _Chip('${result.legalCount} Legal', CIPTheme.success),
          const SizedBox(width: 8),
          _Chip('${result.totalScanned} Scanned', CIPTheme.textSecondary),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _IdleState extends StatelessWidget {
  final bool hasPrefill;
  const _IdleState({required this.hasPrefill});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              hasPrefill ? 'Tap Search to find matches' : 'Enter a route to find trade partners',
              style: const TextStyle(
                  color: CIPTheme.textPrimary,
                  fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'The system scans all active lines for crew\nwith compatible schedules and route familiarity.',
              style: TextStyle(color: CIPTheme.textSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: CIPTheme.primary, strokeWidth: 2.5),
          const SizedBox(height: 20),
          const Text('Scanning monthly lines…',
              style: TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 6),
          const Text('Checking legality · Fatigue · Route compatibility',
              style: TextStyle(color: CIPTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String route;
  const _EmptyState({required this.route});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text('No Matches Found',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'No crew with compatible schedules found for\n$route this month.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: CIPTheme.error, size: 40),
            const SizedBox(height: 12),
            Text(error,
                style: const TextStyle(
                    color: CIPTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
