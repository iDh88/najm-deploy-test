import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../models.dart';

class ScoreBreakdownSheet extends StatelessWidget {
  final TradeMatch match;
  const ScoreBreakdownSheet({super.key, required this.match});

  static const _labels = {
    'legality':  ('⚖️', 'Legality',              'GACA FTL compliance & rest margins'),
    'fatigue':   ('🔋', 'Fatigue Impact',         'Combined duty + rest quality score'),
    'route':     ('✈️', 'Route Familiarity',      'How often this crew flies similar routes'),
    'schedule':  ('📅', 'Schedule Compatibility', 'Open days, carry-over, FDP fit'),
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.4,
      maxChildSize:     0.85,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: CIPTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Score Breakdown',
                        style: TextStyle(
                            color: CIPTheme.textPrimary,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('PRN: ${match.prn}',
                        style: const TextStyle(
                            color: CIPTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              // Overall score circle
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      _compatColor(match.compatibilityPct),
                      _compatColor(match.compatibilityPct).withOpacity(0.2),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CIPTheme.card),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          match.compatibilityLabel,
                          style: TextStyle(
                              color: _compatColor(match.compatibilityPct),
                              fontSize: 14,
                              fontWeight: FontWeight.w900),
                        ),
                        const Text('match',
                            style: TextStyle(
                                color: CIPTheme.textMuted,
                                fontSize: 8)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const Divider(height: 1, color: CIPTheme.divider),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                ...match.componentScores.entries.map((e) {
                  final meta = _labels[e.key];
                  if (meta == null) return const SizedBox.shrink();
                  return _ScoreRow(
                    icon:        meta.$1,
                    label:       meta.$2,
                    description: meta.$3,
                    score:       e.value,
                  );
                }),
                const SizedBox(height: 20),
                // What this means callout
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CIPTheme.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: CIPTheme.primary.withOpacity(0.2)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How scores are calculated',
                          style: TextStyle(
                              color: CIPTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      SizedBox(height: 6),
                      Text(
                        'Scores are based entirely on operational data: '
                        'schedule compatibility, route history, GACA legality '
                        'rules, and fatigue analysis. No personal or demographic '
                        'data is used.',
                        style: TextStyle(
                            color: CIPTheme.textSecondary,
                            fontSize: 12, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _compatColor(double p) {
    if (p >= 80) return CIPTheme.success;
    if (p >= 60) return CIPTheme.primary;
    if (p >= 40) return CIPTheme.warning;
    return CIPTheme.error;
  }
}

class _ScoreRow extends StatelessWidget {
  final String icon, label, description;
  final double score;
  const _ScoreRow({
    required this.icon, required this.label,
    required this.description, required this.score,
  });

  Color get _color {
    if (score >= 75) return CIPTheme.success;
    if (score >= 50) return CIPTheme.primary;
    if (score >= 30) return CIPTheme.warning;
    return CIPTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: CIPTheme.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text('${score.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: _color,
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              backgroundColor: CIPTheme.navLight,
              valueColor: AlwaysStoppedAnimation(_color),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 4),
          Text(description,
              style: const TextStyle(
                  color: CIPTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
