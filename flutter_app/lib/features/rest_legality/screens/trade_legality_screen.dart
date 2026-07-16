import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../models/rest_models.dart';
import '../providers/rest_providers.dart';
import '../widgets/legality_card.dart';

/// Shown when crew want to check legality of a specific trade.
/// Pre-filled from the trade search screen; also usable standalone.
class TradeLegalityScreen extends ConsumerStatefulWidget {
  final String? offeredRouteLabel;
  final String? requestedRouteLabel;

  const TradeLegalityScreen({
    super.key,
    this.offeredRouteLabel,
    this.requestedRouteLabel,
  });

  @override
  ConsumerState<TradeLegalityScreen> createState() =>
      _TradeLegalityScreenState();
}

class _TradeLegalityScreenState
    extends ConsumerState<TradeLegalityScreen> {

  // Offered duty
  DateTime? _offStart, _offEnd, _offNext;
  int  _offLegs = 2, _offDHLegs = 0, _offBlock = 0, _offRptHour = 8;
  bool _offIntl = true;

  // Requested duty
  DateTime? _reqStart, _reqEnd, _reqNext;
  int  _reqLegs = 2, _reqDHLegs = 0, _reqBlock = 0, _reqRptHour = 8;
  bool _reqIntl = true;

  String   _crewType = 'cabin_standard';
  bool     _loading  = false;
  TradeSafetyResult? _result;
  String?  _error;

  Future<void> _check() async {
    if (_offStart == null || _offEnd == null ||
        _reqStart == null || _reqEnd == null) {
      setState(() => _error = 'Fill in both duty start and end times.');
      return;
    }
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final offered = _buildPayload(
        start: _offStart!, end: _offEnd!, next: _offNext,
        legs: _offLegs, dh: _offDHLegs, block: _offBlock,
        rptHour: _offRptHour, intl: _offIntl,
      );
      final requested = _buildPayload(
        start: _reqStart!, end: _reqEnd!, next: _reqNext,
        legs: _reqLegs, dh: _reqDHLegs, block: _reqBlock,
        rptHour: _reqRptHour, intl: _reqIntl,
      );
      final result = await ref
          .read(restLegalityServiceProvider)
          .validateTrade(
            offered:   offered,
            requested: requested,
            crewType:  _crewType,
          );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildPayload({
    required DateTime start, required DateTime end, DateTime? next,
    required int legs, required int dh, required int block,
    required int rptHour, required bool intl,
  }) =>
      {
        'duty_start_utc':     start.toUtc().toIso8601String(),
        'duty_end_utc':       end.toUtc().toIso8601String(),
        if (next != null)
          'next_duty_start_utc': next.toUtc().toIso8601String(),
        'report_local_hour':  rptHour,
        'num_operating_legs': legs,
        'num_deadhead_legs':  dh,
        'block_minutes':      block,
        'is_international':   intl,
        'crew_type':          _crewType,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Trade Legality Check',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Crew type ───────────────────────────────────────────────────
          _SectionLabel('Crew Type'),
          const SizedBox(height: 6),
          _CrewTypeSelector(
            value:     _crewType,
            onChanged: (v) => setState(() => _crewType = v),
          ),
          const SizedBox(height: 20),

          // ── Offered duty ────────────────────────────────────────────────
          _DutySection(
            title:      '📤 Offered Duty',
            subtitle:   widget.offeredRouteLabel ?? 'Your duty being offered',
            color:      CIPTheme.primary,
            start:      _offStart,
            end:        _offEnd,
            next:       _offNext,
            legs:       _offLegs,
            dhLegs:     _offDHLegs,
            blockMins:  _offBlock,
            rptHour:    _offRptHour,
            isIntl:     _offIntl,
            onStartChanged: (v) => setState(() => _offStart   = v),
            onEndChanged:   (v) => setState(() => _offEnd     = v),
            onNextChanged:  (v) => setState(() => _offNext    = v),
            onLegsChanged:  (v) => setState(() => _offLegs    = v),
            onDhChanged:    (v) => setState(() => _offDHLegs  = v),
            onBlockChanged: (v) => setState(() => _offBlock   = v),
            onRptChanged:   (v) => setState(() => _offRptHour = v),
            onIntlChanged:  (v) => setState(() => _offIntl    = v),
          ),
          const SizedBox(height: 16),

          // VS divider
          const Center(
            child: Text('VS',
                style: TextStyle(
                    color: CIPTheme.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2)),
          ),
          const SizedBox(height: 16),

          // ── Requested duty ──────────────────────────────────────────────
          _DutySection(
            title:      '📥 Requested Duty',
            subtitle:   widget.requestedRouteLabel ?? 'Duty you want to receive',
            color:      CIPTheme.warning,
            start:      _reqStart,
            end:        _reqEnd,
            next:       _reqNext,
            legs:       _reqLegs,
            dhLegs:     _reqDHLegs,
            blockMins:  _reqBlock,
            rptHour:    _reqRptHour,
            isIntl:     _reqIntl,
            onStartChanged: (v) => setState(() => _reqStart   = v),
            onEndChanged:   (v) => setState(() => _reqEnd     = v),
            onNextChanged:  (v) => setState(() => _reqNext    = v),
            onLegsChanged:  (v) => setState(() => _reqLegs    = v),
            onDhChanged:    (v) => setState(() => _reqDHLegs  = v),
            onBlockChanged: (v) => setState(() => _reqBlock   = v),
            onRptChanged:   (v) => setState(() => _reqRptHour = v),
            onIntlChanged:  (v) => setState(() => _reqIntl    = v),
          ),
          const SizedBox(height: 20),

          // ── Check button ────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _check,
              style: ElevatedButton.styleFrom(
                backgroundColor: CIPTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.balance_outlined, size: 18),
              label: Text(
                _loading ? 'Checking…' : 'Check Trade Legality',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),

          // Error
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    color: CIPTheme.error, fontSize: 12)),
          ],

          // ── Results ─────────────────────────────────────────────────────
          if (_result != null) ...[
            const SizedBox(height: 24),
            _TradeSafetyResultCard(result: _result!),
          ],

          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ── Trade result card ─────────────────────────────────────────────────────────

class _TradeSafetyResultCard extends StatelessWidget {
  final TradeSafetyResult result;
  const _TradeSafetyResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isSafe = result.tradeIsSafe;
    final color  = isSafe ? CIPTheme.success : CIPTheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall verdict
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Column(children: [
            Text(
              isSafe ? '✅ TRADE IS LEGAL' : '❌ TRADE IS NOT LEGAL',
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Avg safety score: ${result.avgSafetyScore.toStringAsFixed(0)}/100',
              style: const TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Text(
              result.recommendation,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: CIPTheme.textPrimary, fontSize: 14, height: 1.5),
            ),
          ]),
        )
            .animate().fadeIn(duration: 300.ms).scale(
                begin: const Offset(0.96, 0.96)),
        const SizedBox(height: 16),

        // Side by side summary
        Row(children: [
          Expanded(
            child: _SideSummary(
              label:   'Offered',
              data:    result.offered,
              color:   CIPTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SideSummary(
              label:   'Requested',
              data:    result.requested,
              color:   CIPTheme.warning,
            ),
          ),
        ]),
      ],
    );
  }
}

class _SideSummary extends StatelessWidget {
  final String label;
  final Map<String, dynamic> data;
  final Color color;

  const _SideSummary(
      {required this.label, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final isLegal = data['is_legal'] as bool? ?? true;
    final score   = (data['safety_score'] as num?)?.toDouble() ?? 0;
    final fatigue = data['fatigue_level'] as String? ?? 'LOW';
    final summary = data['summary']       as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isLegal
            ? color.withOpacity(0.07)
            : CIPTheme.error.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isLegal ? color.withOpacity(0.3) : CIPTheme.error.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(
            isLegal ? '✅ Legal' : '❌ Not Legal',
            style: TextStyle(
                color: isLegal ? CIPTheme.success : CIPTheme.error,
                fontSize: 13,
                fontWeight: FontWeight.w700),
          ),
          Text('Score: ${score.toStringAsFixed(0)}/100',
              style: const TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 11)),
          Text('Fatigue: $fatigue',
              style: const TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 6),
          Text(summary,
              style: const TextStyle(
                  color: CIPTheme.textMuted,
                  fontSize: 10, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Duty section (compact input for one side of a trade) ─────────────────────

class _DutySection extends StatelessWidget {
  final String  title, subtitle;
  final Color   color;
  final DateTime? start, end, next;
  final int  legs, dhLegs, blockMins, rptHour;
  final bool isIntl;
  final ValueChanged<DateTime?> onStartChanged, onEndChanged, onNextChanged;
  final ValueChanged<int>  onLegsChanged, onDhChanged, onBlockChanged, onRptChanged;
  final ValueChanged<bool> onIntlChanged;

  const _DutySection({
    required this.title, required this.subtitle, required this.color,
    required this.start, required this.end, required this.next,
    required this.legs, required this.dhLegs, required this.blockMins,
    required this.rptHour, required this.isIntl,
    required this.onStartChanged, required this.onEndChanged,
    required this.onNextChanged, required this.onLegsChanged,
    required this.onDhChanged, required this.onBlockChanged,
    required this.onRptChanged, required this.onIntlChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(subtitle,
              style: const TextStyle(
                  color: CIPTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 12),

          // Compact date-time row
          _CompactDTPicker('Start', start, onStartChanged, context),
          const SizedBox(height: 8),
          _CompactDTPicker('End',   end,   onEndChanged,   context),
          const SizedBox(height: 8),
          _CompactDTPicker('Next Duty (opt)', next, onNextChanged, context),
          const SizedBox(height: 10),

          // Numeric row
          Row(children: [
            _MiniStepper('Legs', legs, onLegsChanged, 0, 12),
            const SizedBox(width: 8),
            _MiniStepper('DH',  dhLegs, onDhChanged,  0, 8),
            const SizedBox(width: 8),
            _MiniStepper('Rpt\nHour', rptHour, onRptChanged, 0, 23),
          ]),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('International',
                  style: TextStyle(
                      color: CIPTheme.textSecondary, fontSize: 12)),
              Switch(
                value:       isIntl,
                onChanged:   onIntlChanged,
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactDTPicker extends StatelessWidget {
  final String    label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final BuildContext parentCtx;

  const _CompactDTPicker(this.label, this.value, this.onChanged, this.parentCtx);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: parentCtx,
          initialDate: value ?? DateTime.now().toUtc(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                    primary: CIPTheme.primary)),
            child: child!,
          ),
        );
        if (d == null) return;
        final t = await showTimePicker(
          context: parentCtx,
          initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now().toUtc()),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                    primary: CIPTheme.primary)),
            child: child!,
          ),
        );
        if (t == null) return;
        onChanged(DateTime.utc(d.year, d.month, d.day, t.hour, t.minute));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: CIPTheme.navLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: value != null
                  ? CIPTheme.primary.withOpacity(0.4)
                  : CIPTheme.divider),
        ),
        child: Row(children: [
          Icon(Icons.schedule,
              color: value != null ? CIPTheme.primary : CIPTheme.textMuted,
              size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value != null
                  ? value!.toUtc().toIso8601String().substring(0, 16) + 'Z'
                  : label,
              style: TextStyle(
                  color: value != null
                      ? CIPTheme.textPrimary
                      : CIPTheme.textMuted,
                  fontSize: 12),
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: () => onChanged(null),
              child: const Icon(Icons.clear,
                  color: CIPTheme.textMuted, size: 12),
            ),
        ]),
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  final String label;
  final int    value;
  final ValueChanged<int> onChanged;
  final int    min, max;
  const _MiniStepper(this.label, this.value, this.onChanged, this.min, this.max);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: CIPTheme.navLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CIPTheme.divider),
        ),
        child: Column(children: [
          Text(label,
              style: const TextStyle(
                  color: CIPTheme.textMuted, fontSize: 9),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: value > min ? () => onChanged(value - 1) : null,
              child: Icon(Icons.remove,
                  size: 14,
                  color: value > min
                      ? CIPTheme.primary
                      : CIPTheme.textMuted),
            ),
            const SizedBox(width: 6),
            Text('$value',
                style: const TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: value < max ? () => onChanged(value + 1) : null,
              child: Icon(Icons.add,
                  size: 14,
                  color: value < max
                      ? CIPTheme.primary
                      : CIPTheme.textMuted),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _CrewTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CrewTypeSelector({required this.value, required this.onChanged});

  static const _options = {
    'cabin_standard':  'Cabin — Standard',
    'cabin_long_haul': 'Cabin — Long Haul',
    'cockpit':         'Cockpit',
    'augmented':       'Augmented',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 6,
      children: _options.entries.map((e) {
        final active = e.key == value;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: active
                  ? CIPTheme.primary.withOpacity(0.15)
                  : CIPTheme.navLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: active ? CIPTheme.primary : CIPTheme.divider,
                  width: active ? 1.5 : 1),
            ),
            child: Text(e.value,
                style: TextStyle(
                    color: active
                        ? CIPTheme.primary
                        : CIPTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: active
                        ? FontWeight.w700
                        : FontWeight.w400)),
          ),
        );
      }).toList(),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: CIPTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3));
}
