import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/ai_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class LineDetailScreen extends ConsumerStatefulWidget {
  final String lineId;
  const LineDetailScreen({super.key, required this.lineId});

  @override
  ConsumerState<LineDetailScreen> createState() => _LineDetailScreenState();
}

class _LineDetailScreenState extends ConsumerState<LineDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _submittingBid = false;

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
    final lineAsync = ref.watch(singleLineProvider(widget.lineId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return lineAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (line) {
        if (line == null) return const Scaffold(body: Center(child: Text('Line not found')));
        return _buildScaffold(line, user);
      },
    );
  }

  Widget _buildScaffold(FlightLine line, CIPUser? user) {
    final hasViolations = line.legs.any((l) => l.legalityStatus == LegalityStatus.violation);
    final hasWarnings = line.legs.any((l) => l.legalityStatus == LegalityStatus.warning);

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: CIPTheme.saudiNavy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () => _shareLineDetails(line),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _LineDetailHeader(line: line, hasViolations: hasViolations, hasWarnings: hasWarnings),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: CIPTheme.saudiGold,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Timeline'),
                Tab(text: 'Legs'),
                Tab(text: 'Salary'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _TimelineTab(line: line),
            _LegsTab(line: line),
            _SalaryTab(line: line),
          ],
        ),
      ),
      bottomNavigationBar: _BidBottomBar(
        line: line,
        user: user,
        hasViolations: hasViolations,
        isSubmitting: _submittingBid,
        onBid: () => _submitBid(line, user),
        onGhostBid: () => _showGhostBid(line),
      ),
    );
  }

  Future<void> _submitBid(FlightLine line, CIPUser? user) async {
    if (user == null || _submittingBid) return;

    // Check for existing bid
    final repo = ref.read(bidsRepositoryProvider);
    final exists = await repo.hasExistingBid(user.id, line.id, line.month);
    if (exists) {
      _showSnack('You already have a bid on this line', isError: true);
      return;
    }

    setState(() => _submittingBid = true);
    HapticFeedback.mediumImpact();

    try {
      final bid = Bid(
        id: const Uuid().v4(),
        userId: user.id,
        lineId: line.id,
        lineNumber: line.lineNumber,
        month: line.month,
        priority: 1,
        status: BidStatus.submitted,
        userMode: user.userMode,
        isAutoBid: false,
        scoreAtBid: BidScoreSnapshot(
          salaryScore: line.summary.salaryScore,
          restScore: line.summary.restQualityScore,
          composite: line.summary.compositeScore,
        ),
        estimatedSalary: line.summary.estimatedSalaryMax,
        submittedAt: DateTime.now(),
      );

      await repo.submitBid(bid);
      HapticFeedback.heavyImpact();
      _showSnack('Bid submitted for Line ${line.lineNumber} ✓');

      // Log behavior event
      ref.read(aiServiceProvider).logBehaviorEvent(
        userId: user.id,
        eventType: 'bid_submitted',
        metadata: {
          'lineId': line.id,
          'lineNumber': line.lineNumber,
          'destinations': line.destinations,
          'estimatedSalary': line.summary.estimatedSalaryMax,
          'userMode': user.userMode.name,
        },
      );
    } catch (e) {
      _showSnack('Failed to submit bid: $e', isError: true);
    } finally {
      setState(() => _submittingBid = false);
    }
  }

  void _showGhostBid(FlightLine line) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GhostBidSheet(line: line),
    );
  }

  void _shareLineDetails(FlightLine line) {
    // Share.share('Line ${line.lineNumber} — ${line.destinations.join(', ')}');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? CIPTheme.violationRed : CIPTheme.legalGreen,
    ));
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _LineDetailHeader extends StatelessWidget {
  final FlightLine line;
  final bool hasViolations, hasWarnings;
  const _LineDetailHeader({required this.line, required this.hasViolations, required this.hasWarnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CIPTheme.saudiNavy, Color(0xFF0D3266)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Line ${line.lineNumber}',
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              LegalityBadge(hasViolations: hasViolations, hasWarnings: hasWarnings),
            ],
          ),
          const SizedBox(height: 6),
          Text(line.destinations.take(5).join(' · '),
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _HeaderStat('${line.summary.totalLegs}', 'Legs'),
              _HeaderStat('${line.summary.totalBlockHours.toStringAsFixed(0)}h', 'Block'),
              _HeaderStat('${line.summary.layoverCount}', 'Layovers'),
              _HeaderStat('SAR ${line.summary.estimatedSalaryMin.toStringAsFixed(0)}', 'Est. Pay'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String value, label;
  const _HeaderStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─── Timeline Tab ─────────────────────────────────────────────────────────────
class _TimelineTab extends StatelessWidget {
  final FlightLine line;
  const _TimelineTab({required this.line});

  @override
  Widget build(BuildContext context) {
    final cipColors = Theme.of(context).extension<CIPColors>()!;
    if (line.legs.isEmpty) return const Center(child: Text('No legs found'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Horizontal scrollable Gantt strip
        const Text('Duty Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        SizedBox(
          height: 80,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: line.legs.map((leg) => _TimelineBlock(leg: leg, cipColors: cipColors)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Legality summary
        LegalityPanel(result: LegalityResult(
          passed: !line.legs.any((l) => l.legalityStatus == LegalityStatus.violation),
          violations: line.legs
              .where((l) => l.legalityStatus == LegalityStatus.violation)
              .expand((l) => l.legalityFlags.map((f) => LegalityViolation(
                ruleId: f,
                ruleDescription: _ruleDescription(f),
                ruleDescriptionAr: _ruleDescriptionAr(f),
                actualValue: l.restBeforeHours,
                requiredValue: l.legType == LegType.international ? 15.0 : 14.0,
                unit: 'hours',
                affectedLegIds: [l.id],
              ))).toList(),
          warnings: line.legs
              .where((l) => l.legalityStatus == LegalityStatus.warning)
              .expand((l) => l.legalityFlags.map((f) => LegalityViolation(
                ruleId: f,
                ruleDescription: _ruleDescription(f),
                ruleDescriptionAr: _ruleDescriptionAr(f),
                actualValue: l.restBeforeHours,
                requiredValue: l.legType == LegType.international ? 15.0 : 14.0,
                unit: 'hours',
                severity: LegalitySeverity.warning,
                affectedLegIds: [l.id],
              ))).toList(),
        )),
      ],
    );
  }

  String _ruleDescription(String ruleId) {
    if (ruleId.contains('DOM')) return 'Minimum 14h rest required after domestic duty (from release time)';
    if (ruleId.contains('INT')) return 'Minimum 15h rest required after international duty (from release time)';
    if (ruleId.contains('FDP')) return 'Maximum Flight Duty Period exceeded';
    return 'Legality rule violation: $ruleId';
  }

  String _ruleDescriptionAr(String ruleId) {
    if (ruleId.contains('DOM')) return 'Minimum 14h rest required after domestic duty (from release time)';
    if (ruleId.contains('INT')) return 'Minimum 15h rest required after international duty (from release time)';
    if (ruleId.contains('FDP')) return 'Maximum Flight Duty Period exceeded';
    return 'Legal violation: $ruleId';
  }
}

class _TimelineBlock extends StatelessWidget {
  final FlightLeg leg;
  final CIPColors cipColors;
  const _TimelineBlock({required this.leg, required this.cipColors});

  @override
  Widget build(BuildContext context) {
    final color = leg.legalityStatus == LegalityStatus.violation
        ? CIPTheme.violationRed
        : leg.legType == LegType.international
            ? cipColors.internationalLeg
            : cipColors.domesticLeg;

    final width = (leg.blockHours * 30).clamp(60.0, 200.0);

    return Row(
      children: [
        // Rest gap
        if (leg.restBeforeHours > 0)
          Container(
            width: (leg.restBeforeHours * 8).clamp(20.0, 80.0),
            height: 40,
            alignment: Alignment.center,
            child: Text('${leg.restBeforeHours.toStringAsFixed(0)}h',
              style: const TextStyle(fontSize: 9, color: CIPTheme.grey500)),
          ),
        // Leg block
        Container(
          width: width,
          height: 60,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: leg.legalityStatus == LegalityStatus.violation
                ? Border.all(color: CIPTheme.violationRed, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(leg.flightNumber,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('${leg.origin}→${leg.destination}',
                style: const TextStyle(color: Colors.white70, fontSize: 9)),
              Text('${leg.blockHours.toStringAsFixed(1)}h',
                style: const TextStyle(color: Colors.white60, fontSize: 9)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Legs Tab ─────────────────────────────────────────────────────────────────
class _LegsTab extends StatelessWidget {
  final FlightLine line;
  const _LegsTab({required this.line});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: line.legs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _LegRow(leg: line.legs[i], index: i),
    );
  }
}

class _LegRow extends StatelessWidget {
  final FlightLeg leg;
  final int index;
  const _LegRow({required this.leg, required this.index});

  @override
  Widget build(BuildContext context) {
    final depTime = DateFormat('HH:mm').format(leg.departureLT);
    final arrTime = DateFormat('HH:mm').format(leg.arrivalLT);
    final depDate = DateFormat('dd MMM').format(leg.departureLT);

    final badgeColor = leg.legalityStatus == LegalityStatus.violation
        ? CIPTheme.violationRed
        : leg.legType == LegType.international
            ? CIPTheme.legalGreen
            : CIPTheme.restBlue;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: leg.legalityStatus == LegalityStatus.violation
            ? Border.all(color: CIPTheme.violationRed.withOpacity(0.5))
            : Border.all(color: CIPTheme.grey200),
      ),
      child: Row(
        children: [
          // Leg number
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Center(child: Text('${index + 1}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(leg.flightNumber,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('${leg.origin} → ${leg.destination}',
                      style: const TextStyle(color: CIPTheme.grey700, fontSize: 13)),
                    const Spacer(),
                    Text(depDate, style: const TextStyle(color: CIPTheme.grey500, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('$depTime → $arrTime',
                      style: const TextStyle(color: CIPTheme.grey700, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${leg.blockHours.toStringAsFixed(1)}h',
                      style: const TextStyle(color: CIPTheme.grey500, fontSize: 12)),
                    if (leg.layover) ...[
                      const SizedBox(width: 8),
                      const Text('🏨 Layover', style: TextStyle(fontSize: 11, color: CIPTheme.warningAmber)),
                    ],
                  ],
                ),
                if (leg.restAfterHours > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Rest after: ${leg.restAfterHours.toStringAsFixed(1)}h'
                      ' ${leg.restAfterHours < (leg.legType == LegType.international ? 15 : 14) ? "⚠️" : "✓"}',
                      style: TextStyle(
                        fontSize: 11,
                        color: leg.restAfterHours < 14 ? CIPTheme.violationRed : CIPTheme.legalGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Salary Tab ───────────────────────────────────────────────────────────────
class _SalaryTab extends StatelessWidget {
  final FlightLine line;
  const _SalaryTab({required this.line});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: 'SAR ', decimalDigits: 0);
    final summary = line.summary;
    final totalBlock = summary.totalBlockHours;
    final avgRate = totalBlock > 0 ? (summary.estimatedSalaryMin / totalBlock) : 0.0;
    final totalPerDiem = line.legs
        .fold<double>(0, (sum, l) => sum + l.perDiem);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SalaryCard(
          title: 'Estimated Gross Pay',
          titleAr: 'Estimated Gross Pay',
          value: '${fmt.format(summary.estimatedSalaryMin)} – ${fmt.format(summary.estimatedSalaryMax)}',
          color: CIPTheme.moneyGreen,
          icon: Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 10),
        _SalaryBreakdownRow('Block Hours', '${totalBlock.toStringAsFixed(1)}h × SAR ${avgRate.toStringAsFixed(0)}/h',
            fmt.format(summary.estimatedSalaryMin - totalPerDiem)),
        _SalaryBreakdownRow('Per Diem Allowances', '${line.legs.length} duties',
            fmt.format(totalPerDiem)),
        _SalaryBreakdownRow('International Premium',
            '${summary.internationalLegs} int\'l legs', 'Included'),
        const Divider(height: 24),
        _SalaryBreakdownRow('Total Estimated', '', fmt.format(summary.estimatedSalaryMax),
            isBold: true),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CIPTheme.warningAmberBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CIPTheme.warningAmber.withOpacity(0.3)),
          ),
          child: const Text(
            '⚠️ Salary estimates are based on standard rates and may differ from your actual pay. Variable components such as overtime and allowances may apply.',
            style: TextStyle(fontSize: 12, color: CIPTheme.grey700),
          ),
        ),
      ],
    );
  }
}

class _SalaryCard extends StatelessWidget {
  final String title, titleAr, value;
  final Color color;
  final IconData icon;
  const _SalaryCard({required this.title, required this.titleAr,
    required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titleAr, style: TextStyle(fontSize: 12, color: color, fontFamily: 'Inter')),
              Text(title, style: const TextStyle(fontSize: 11, color: CIPTheme.grey500)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalaryBreakdownRow extends StatelessWidget {
  final String label, sublabel, amount;
  final bool isBold;
  const _SalaryBreakdownRow(this.label, this.sublabel, this.amount, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                if (sublabel.isNotEmpty)
                  Text(sublabel, style: const TextStyle(color: CIPTheme.grey500, fontSize: 12)),
              ],
            ),
          ),
          Text(amount, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 16 : 14,
            color: isBold ? CIPTheme.moneyGreen : CIPTheme.grey900,
          )),
        ],
      ),
    );
  }
}

// ─── Bid Bottom Bar ───────────────────────────────────────────────────────────
class _BidBottomBar extends StatelessWidget {
  final FlightLine line;
  final CIPUser? user;
  final bool hasViolations, isSubmitting;
  final VoidCallback onBid, onGhostBid;

  const _BidBottomBar({
    required this.line, required this.user, required this.hasViolations,
    required this.isSubmitting, required this.onBid, required this.onGhostBid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CIPTheme.grey200)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: onGhostBid,
            icon: const Icon(Icons.preview_outlined, size: 18),
            label: const Text('Preview'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(100, 48),
              foregroundColor: CIPTheme.saudiNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: hasViolations || isSubmitting ? null : onBid,
              icon: isSubmitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.how_to_vote_outlined, size: 18),
              label: Text(hasViolations
                  ? 'Cannot Bid — Violations'
                  : isSubmitting ? 'Submitting...' : 'Bid on Line ${line.lineNumber}'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Ghost Bid Sheet ──────────────────────────────────────────────────────────
class _GhostBidSheet extends StatelessWidget {
  final FlightLine line;
  const _GhostBidSheet({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: CIPTheme.grey300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ghost Bid Preview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('How your month would look if you win Line ${line.lineNumber}',
                  style: const TextStyle(color: CIPTheme.grey500, fontSize: 13)),
                const SizedBox(height: 20),
                const Text('📅 Schedule simulation coming in Phase 2',
                  style: TextStyle(color: CIPTheme.grey700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
