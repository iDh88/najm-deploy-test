import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/intelligence_models.dart';
import '../providers/intelligence_providers.dart';

class PairingDetailScreen extends ConsumerWidget {
  final String pairingId;
  final String lineId;

  const PairingDetailScreen({
    super.key,
    required this.pairingId,
    required this.lineId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pairingsAsync = ref.watch(pairingsProvider(lineId));

    return pairingsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: NajmTheme.navy,
        body: Center(child: CircularProgressIndicator(color: NajmTheme.gold)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: NajmTheme.navy,
        body: Center(
            child: Text(e.toString(),
                style: const TextStyle(color: NajmTheme.error))),
      ),
      data: (pairings) {
        final pairing =
            pairings.where((p) => p.id == pairingId).firstOrNull;
        if (pairing == null) {
          return Scaffold(
            backgroundColor: NajmTheme.navy,
            appBar: AppBar(backgroundColor: NajmTheme.navyMid),
            body: const Center(
                child: Text('Pairing not found',
                    style: TextStyle(color: NajmTheme.textSecondary))),
          );
        }
        return _PairingDetailView(pairing: pairing);
      },
    );
  }
}

class _PairingDetailView extends StatelessWidget {
  final Pairing pairing;
  const _PairingDetailView({required this.pairing});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navyMid,
        title: Text(pairing.pairingNumber,
            style: const TextStyle(
                color: NajmTheme.gold, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: NajmTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // Header metrics
          _HeaderMetrics(pairing: pairing),
          const SizedBox(height: 16),

          // Legality card
          _LegalityCard(pairing: pairing),
          const SizedBox(height: 16),

          // Pattern flags
          if (pairing.patternFlags.isNotEmpty) ...[
            _PatternFlagsCard(flags: pairing.patternFlags),
            const SizedBox(height: 16),
          ],

          // Segment ladder
          _SegmentLadder(pairing: pairing),
        ],
      ),
    );
  }
}

// ── Header Metrics ────────────────────────────────────────────────────────────

class _HeaderMetrics extends StatelessWidget {
  final Pairing pairing;
  const _HeaderMetrics({required this.pairing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _MetricPill('Block', '${pairing.blockHours.toStringAsFixed(1)}h',
          NajmTheme.gold),
      const SizedBox(width: 8),
      _MetricPill('Duty', '${pairing.dutyHours.toStringAsFixed(1)}h',
          NajmTheme.info),
      const SizedBox(width: 8),
      _MetricPill('FDP', '${pairing.fdpHours.toStringAsFixed(1)}h',
          NajmTheme.warning),
      const SizedBox(width: 8),
      _MetricPill('Legs', '${pairing.segments.length}',
          NajmTheme.saudiGreen),
    ]);
  }
}

class _MetricPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MetricPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 17, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(
                  color: NajmTheme.textMuted, fontSize: 10)),
        ]),
      ),
    );
  }
}

// ── Legality Card ─────────────────────────────────────────────────────────────

class _LegalityCard extends StatelessWidget {
  final Pairing pairing;
  const _LegalityCard({required this.pairing});

  @override
  Widget build(BuildContext context) {
    final legal = pairing.isLegal;
    final m = pairing.legalityMargins;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (legal ? NajmTheme.success : NajmTheme.error)
            .withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (legal ? NajmTheme.success : NajmTheme.error)
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              legal ? Icons.verified_outlined : Icons.warning_amber_outlined,
              color: legal ? NajmTheme.success : NajmTheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              legal ? 'Legality: COMPLIANT' : 'Legality: VIOLATION DETECTED',
              style: TextStyle(
                  color: legal ? NajmTheme.success : NajmTheme.error,
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 14),

          // FDP margin
          _LegalityBar(
            label: 'FDP',
            actual: (m['fdpActualMins'] as num?)?.toDouble() ?? 0,
            limit:  (m['fdpLimitMins']  as num?)?.toDouble() ?? 720,
            unit:   'min',
          ),
          const SizedBox(height: 10),

          // Rest margin
          _LegalityBar(
            label: 'Rest After',
            actual: (m['restActualMins'] as num?)?.toDouble() ?? 0,
            limit:  (m['restMinMins']    as num?)?.toDouble() ?? 600,
            unit:   'min',
            invertBar: true, // more rest = better
          ),
          const SizedBox(height: 10),

          // Block margin
          _LegalityBar(
            label: 'Daily Block',
            actual: (m['blockActualMins'] as num?)?.toDouble() ?? 0,
            limit:  510, // 8:30
            unit:   'min',
          ),
        ],
      ),
    );
  }
}

class _LegalityBar extends StatelessWidget {
  final String label, unit;
  final double actual, limit;
  final bool invertBar;
  const _LegalityBar({
    required this.label, required this.actual, required this.limit,
    required this.unit, this.invertBar = false,
  });

  double get ratio => invertBar
      ? (actual / limit).clamp(0.0, 1.5)
      : (actual / limit).clamp(0.0, 1.0);

  Color get barColor {
    if (invertBar) {
      // More rest = greener
      if (ratio >= 1.1) return NajmTheme.success;
      if (ratio >= 1.0) return NajmTheme.warning;
      return NajmTheme.error;
    }
    if (ratio >= 1.0) return NajmTheme.error;
    if (ratio >= 0.85) return NajmTheme.warning;
    return NajmTheme.success;
  }

  String _fmt(double mins) {
    final h = mins ~/ 60;
    final m = (mins % 60).round();
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  color: NajmTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          Text('${_fmt(actual)} / ${_fmt(limit)}',
              style: TextStyle(
                  color: barColor,
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (invertBar
                ? (actual / limit).clamp(0.0, 1.0)
                : ratio),
            backgroundColor: NajmTheme.navyLight,
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// ── Pattern Flags ─────────────────────────────────────────────────────────────

class _PatternFlagsCard extends StatelessWidget {
  final List<String> flags;
  const _PatternFlagsCard({required this.flags});

  static const _flagMeta = {
    'REPEATED_DESTINATION':   ('🔁', 'Repeated Destination',    NajmTheme.info),
    'BACK_TO_BACK_DEADHEAD':  ('🔄', 'Back-to-Back Deadhead',   NajmTheme.warning),
    'MINIMUM_REST_ONLY':      ('⚠️', 'Minimum Rest Only',       NajmTheme.error),
    'MULTI_TIMEZONE':         ('🌐', 'Multi-Timezone',          NajmTheme.info),
    'WOCL_PENETRATION':       ('🌙', 'WOCL Penetration',        NajmTheme.error),
    'EARLY_SIGNIN':           ('🌅', 'Early Sign-In',           NajmTheme.warning),
    'LATE_RELEASE':           ('🌆', 'Late Release',            NajmTheme.warning),
    'HIGH_BLOCK_SINGLE_DUTY': ('⏱️', 'High Block Single Duty',  NajmTheme.warning),
  };

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
        children: [
          const Text('Pattern Flags',
              style: TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 6,
            children: flags.map((f) {
              final meta = _flagMeta[f];
              final icon  = meta?.$1 ?? '📍';
              final label = meta?.$2 ?? f.replaceAll('_', ' ');
              final color = meta?.$3 ?? NajmTheme.textSecondary;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 5),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Segment Ladder ────────────────────────────────────────────────────────────

class _SegmentLadder extends StatelessWidget {
  final Pairing pairing;
  const _SegmentLadder({required this.pairing});

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
          const Text('Flight Segments',
              style: TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...pairing.segments.asMap().entries.map((e) =>
              _SegmentRow(segment: e.value, index: e.key)
                  .animate(delay: Duration(milliseconds: e.key * 60))
                  .fadeIn(duration: 250.ms)
                  .slideX(begin: 0.04, end: 0)),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final PairingSegment segment;
  final int index;
  const _SegmentRow({required this.segment, required this.index});

  @override
  Widget build(BuildContext context) {
    final isDH    = segment.isDeadhead;
    final accent  = isDH ? NajmTheme.info : NajmTheme.gold;

    return Column(
      children: [
        // Connector line
        if (index > 0)
          Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 18),
            color: NajmTheme.divider,
          ),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon column
            Column(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.4)),
                ),
                child: Center(
                  child: Icon(
                    isDH
                        ? Icons.airline_seat_recline_normal
                        : Icons.flight,
                    color: accent, size: 16,
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDH
                      ? NajmTheme.info.withOpacity(0.05)
                      : NajmTheme.navyLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDH
                        ? NajmTheme.info.withOpacity(0.2)
                        : NajmTheme.cardBorder,
                    style: isDH
                        ? BorderStyle.solid
                        : BorderStyle.solid,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      // Flight number
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(segment.flightNumber,
                            style: TextStyle(
                                color: accent, fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                      if (isDH) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: NajmTheme.info.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: NajmTheme.info.withOpacity(0.3)),
                          ),
                          child: const Text('DEADHEAD',
                              style: TextStyle(
                                  color: NajmTheme.info,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                      const Spacer(),
                      Text('${segment.blockHours.toStringAsFixed(1)}h',
                          style: const TextStyle(
                              color: NajmTheme.textMuted, fontSize: 12)),
                    ]),
                    const SizedBox(height: 8),

                    // Route row
                    Row(children: [
                      _AirportBox(code: segment.origin),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                                height: 1,
                                color: NajmTheme.divider),
                            Icon(Icons.flight, color: accent, size: 14),
                          ],
                        ),
                      ),
                      _AirportBox(code: segment.destination),
                    ]),
                    const SizedBox(height: 8),

                    // Times
                    Row(children: [
                      Text(
                        segment.departureUtc.length >= 10
                            ? segment.departureUtc.substring(11, 16)
                            : segment.departureUtc,
                        style: const TextStyle(
                            color: NajmTheme.textSecondary, fontSize: 12),
                      ),
                      const Text(' → ',
                          style: TextStyle(
                              color: NajmTheme.textMuted, fontSize: 12)),
                      Text(
                        segment.arrivalUtc.length >= 10
                            ? segment.arrivalUtc.substring(11, 16)
                            : segment.arrivalUtc,
                        style: const TextStyle(
                            color: NajmTheme.textSecondary, fontSize: 12),
                      ),
                      const Text(' UTC',
                          style: TextStyle(
                              color: NajmTheme.textMuted, fontSize: 10)),
                      const Spacer(),
                      if (segment.aircraftType != null)
                        Text(segment.aircraftType!,
                            style: const TextStyle(
                                color: NajmTheme.textMuted, fontSize: 11)),
                    ]),

                    // TZ delta
                    if (segment.timezoneDelta.abs() > 0.5) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${segment.timezoneDelta > 0 ? '+' : ''}${segment.timezoneDelta.toStringAsFixed(1)}h timezone shift',
                        style: const TextStyle(
                            color: NajmTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AirportBox extends StatelessWidget {
  final String code;
  const _AirportBox({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: NajmTheme.navy,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Text(code,
          style: const TextStyle(
              color: NajmTheme.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w700,
              letterSpacing: 0.5)),
    );
  }
}
