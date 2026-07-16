import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app/theme.dart';
import '../models/rest_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LEGALITY STATUS CARD
// ══════════════════════════════════════════════════════════════════════════════

class LegalityCard extends StatelessWidget {
  final LegalityResult result;
  final bool compact;

  const LegalityCard({super.key, required this.result, this.compact = false});

  Color get _statusColor {
    switch (result.status) {
      case LegalityStatus.legal:         return CIPTheme.success;
      case LegalityStatus.legalMarginal: return CIPTheme.warning;
      case LegalityStatus.notLegal:      return CIPTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(compact ? 10 : 18),
        border: Border.all(color: _statusColor.withOpacity(0.35)),
      ),
      child: compact ? _CompactContent(result: result, color: _statusColor)
                     : _FullContent(result: result, color: _statusColor),
    ).animate().fadeIn(duration: 280.ms).scale(begin: const Offset(0.97, 0.97));
  }
}

class _CompactContent extends StatelessWidget {
  final LegalityResult result;
  final Color color;
  const _CompactContent({required this.result, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(result.statusEmoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(result.statusLabel,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w700)),
      const Spacer(),
      Text('${result.safetyScore.toStringAsFixed(0)}/100',
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w800)),
    ]);
  }
}

class _FullContent extends StatelessWidget {
  final LegalityResult result;
  final Color color;
  const _FullContent({required this.result, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status row
        Row(children: [
          Text(result.statusEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.statusLabel,
                    style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                Text('Safety score: ${result.safetyScore.toStringAsFixed(0)}/100',
                    style: const TextStyle(
                        color: CIPTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          // Score ring
          _ScoreRing(score: result.safetyScore, color: color),
        ]),

        if (result.allIssues.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(height: 1, color: CIPTheme.divider),
          const SizedBox(height: 10),
          ...result.allIssues.take(3).map((v) => _ViolationRow(v: v)),
          if (result.allIssues.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${result.allIssues.length - 3} more issues',
                style: const TextStyle(
                    color: CIPTheme.textMuted, fontSize: 11),
              ),
            ),
        ],
      ],
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final double score;
  final Color  color;
  const _ScoreRing({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52, height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value:            score / 100,
            strokeWidth:      4,
            backgroundColor:  CIPTheme.navLight,
            valueColor:       AlwaysStoppedAnimation(color),
          ),
          Text(score.toStringAsFixed(0),
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ViolationRow extends StatelessWidget {
  final LegalityViolation v;
  const _ViolationRow({required this.v});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.rule,
                    style: const TextStyle(
                        color: CIPTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                Text(v.description,
                    style: const TextStyle(
                        color: CIPTheme.textSecondary,
                        fontSize: 11,
                        height: 1.3)),
              ],
            ),
          ),
          if (v.actual.isNotEmpty)
            Text(v.actual,
                style: const TextStyle(
                    color: CIPTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FATIGUE BAR WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class FatigueBar extends StatelessWidget {
  final FatigueScoreResult result;
  final bool showFactors;

  const FatigueBar({super.key, required this.result, this.showFactors = false});

  Color get _color {
    switch (result.level) {
      case FatigueLevel.high:   return CIPTheme.error;
      case FatigueLevel.medium: return CIPTheme.warning;
      case FatigueLevel.low:    return CIPTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(result.levelEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${result.level.name.toUpperCase()} FATIGUE',
                      style: TextStyle(
                          color: _color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  Text(result.recommendation,
                      style: const TextStyle(
                          color: CIPTheme.textSecondary,
                          fontSize: 11,
                          height: 1.4)),
                ],
              ),
            ),
            Text('${result.percentage}%',
                style: TextStyle(
                    color: _color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:            result.raw.clamp(0.0, 1.0),
              backgroundColor:  CIPTheme.navLight,
              valueColor:       AlwaysStoppedAnimation(_color),
              minHeight:        8,
            ),
          ),

          if (showFactors && result.factors.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Contributing factors',
                style: TextStyle(
                    color: CIPTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            ...((result.factors.where((f) => f.weighted > 0.01).toList()
                  ..sort((a, b) => b.weighted.compareTo(a.weighted)))
                .take(4)
                .map((f) => _FactorRow(factor: f))
                .toList()),
          ],
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  final FatigueFactor factor;
  const _FactorRow({required this.factor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(factor.name,
              style: const TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 10)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:           factor.score.clamp(0.0, 1.0),
              backgroundColor: CIPTheme.navLight,
              valueColor:      const AlwaysStoppedAnimation(CIPTheme.primary),
              minHeight:       4,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${(factor.weighted * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
                color: CIPTheme.textMuted, fontSize: 9)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REST COUNTDOWN WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class RestCountdownWidget extends StatelessWidget {
  final RestWindowResult rest;
  const RestCountdownWidget({super.key, required this.rest});

  Color get _color {
    if (!rest.isSufficient) return CIPTheme.error;
    if (rest.isMarginal)    return CIPTheme.warning;
    return CIPTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.hotel, color: _color, size: 18),
            const SizedBox(width: 8),
            Text('Rest Window',
                style: TextStyle(
                    color: _color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (!rest.isSufficient)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CIPTheme.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('INSUFFICIENT',
                    style: TextStyle(
                        color: CIPTheme.error,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5)),
              ),
          ]),
          const SizedBox(height: 10),

          Row(children: [
            _RestStat('Actual',    rest.durationLabel, _color),
            const SizedBox(width: 12),
            _RestStat('Minimum',   rest.minimumLabel,  CIPTheme.textSecondary),
            const SizedBox(width: 12),
            _RestStat('Margin',    rest.marginLabel,
                rest.marginMins >= 0 ? CIPTheme.success : CIPTheme.error),
          ]),

          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           rest.fillRatio.clamp(0.0, 1.0),
              backgroundColor: CIPTheme.navLight,
              valueColor:      AlwaysStoppedAnimation(_color),
              minHeight:       6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(rest.localStart,
                  style: const TextStyle(
                      color: CIPTheme.textMuted, fontSize: 10)),
              Text(rest.localEnd,
                  style: const TextStyle(
                      color: CIPTheme.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RestStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: CIPTheme.textMuted, fontSize: 10)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FDP WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class FDPWidget extends StatelessWidget {
  final FDPResult fdp;
  const FDPWidget({super.key, required this.fdp});

  Color get _color {
    if (!fdp.isWithinLimit) return CIPTheme.error;
    if (fdp.isMarginal)     return CIPTheme.warning;
    return CIPTheme.success;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('⏱️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Flight Duty Period',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (fdp.earlySignin)
              _Tag('🌅 Early Sign-In', CIPTheme.warning),
            if (fdp.woclPenetration) ...[
              const SizedBox(width: 6),
              _Tag('🌙 WOCL', CIPTheme.error),
            ],
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _FDPStat('Actual',  fdp.actualLabel, _color),
            _FDPStat('Limit',   fdp.limitLabel,  CIPTheme.textSecondary),
            _FDPStat('Margin',  fdp.marginLabel,
                fdp.marginMins >= 0 ? CIPTheme.success : CIPTheme.error),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           fdp.usageRatio.clamp(0.0, 1.0),
              backgroundColor: CIPTheme.navLight,
              valueColor:      AlwaysStoppedAnimation(_color),
              minHeight:       6,
            ),
          ),
          if (fdp.woclMinutes > 0) ...[
            const SizedBox(height: 6),
            Text('${fdp.woclMinutes}min inside WOCL window (02:00–05:59)',
                style: const TextStyle(
                    color: CIPTheme.textMuted, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _FDPStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _FDPStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label,
            style: const TextStyle(
                color: CIPTheme.textMuted, fontSize: 10)),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color  color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
