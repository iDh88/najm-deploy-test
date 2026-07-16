import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/intelligence_models.dart';
import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LINE CLASSIFICATION BADGE
// ══════════════════════════════════════════════════════════════════════════════

class LineClassificationBadge extends StatelessWidget {
  final LineClassification classification;
  final bool large;
  const LineClassificationBadge({
    super.key, required this.classification, this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    try {
      color = Color(int.parse(
          classification.color.replaceAll('#', 'FF'), radix: 16));
    } catch (_) {
      color = NajmTheme.textSecondary;
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 12 : 8,
          vertical:   large ? 6  : 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(large ? 10 : 6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(classification.icon,
              style: TextStyle(fontSize: large ? 16 : 11)),
          SizedBox(width: large ? 6 : 4),
          Text(
            classification.label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: large ? 12 : 9,
              fontWeight: FontWeight.w800,
              letterSpacing: large ? 0.8 : 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// INSIGHT CARD
// ══════════════════════════════════════════════════════════════════════════════

class InsightCardWidget extends StatelessWidget {
  final LineInsight insight;
  final int index;
  const InsightCardWidget({super.key, required this.insight, required this.index});

  Color get _typeColor {
    switch (insight.type) {
      case InsightType.warning:  return NajmTheme.error;
      case InsightType.positive: return NajmTheme.success;
      case InsightType.tip:      return NajmTheme.gold;
      case InsightType.info:     return NajmTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _typeColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _typeColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(insight.icon,
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(insight.titleEn,
                        style: TextStyle(
                            color: _typeColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (insight.metricValue != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(insight.metricValue!,
                          style: TextStyle(
                              color: _typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(insight.bodyEn,
                    style: const TextStyle(
                        color: NajmTheme.textSecondary,
                        fontSize: 13,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 80))
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.04, end: 0);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FATIGUE CHART — line chart with colored zones
// ══════════════════════════════════════════════════════════════════════════════

class FatigueChartWidget extends StatelessWidget {
  final List<FatiguePoint> points;
  const FatigueChartWidget({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: NajmTheme.navyCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
        child: const Center(
          child: Text('No fatigue data',
              style: TextStyle(color: NajmTheme.textMuted)),
        ),
      );
    }

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
          const Text('Fatigue Timeline',
              style: TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Cumulative fatigue load across the month',
              style: TextStyle(color: NajmTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: CustomPaint(
              painter: _FatigueChartPainter(points: points),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 12),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(NajmTheme.success, 'Low'),
              const SizedBox(width: 16),
              _LegendDot(NajmTheme.warning, 'Medium'),
              const SizedBox(width: 16),
              _LegendDot(NajmTheme.error, 'High'),
            ],
          ),
          const SizedBox(height: 12),
          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Day 1',
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 10)),
              Text('Day ${points.length}',
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: NajmTheme.textMuted, fontSize: 10)),
    ]);
  }
}

class _FatigueChartPainter extends CustomPainter {
  final List<FatiguePoint> points;
  _FatigueChartPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final n = points.length;

    // Background zone bands
    _drawZone(canvas, w, h, 0.65, 1.0,
        const Color(0x15EF4444)); // High (red tint)
    _drawZone(canvas, w, h, 0.35, 0.65,
        const Color(0x15F59E0B)); // Medium (amber tint)
    _drawZone(canvas, w, h, 0.0, 0.35,
        const Color(0x1122C55E)); // Low (green tint)

    // Zone lines
    final zoneLinePaint = Paint()
      ..color = NajmTheme.divider
      ..strokeWidth = 0.5;
    for (final y in [0.35, 0.65]) {
      final yPx = h - y * h;
      canvas.drawLine(Offset(0, yPx), Offset(w, yPx), zoneLinePaint);
    }

    // Build path
    final path     = Path();
    final fillPath = Path();
    bool first = true;

    for (int i = 0; i < n; i++) {
      final x = i / (n - 1) * w;
      final y = h - points[i].cumulative.clamp(0.0, 1.0) * h;

      if (first) {
        path.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(w, h);
    fillPath.close();

    // Fill gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          NajmTheme.gold.withOpacity(0.25),
          NajmTheme.gold.withOpacity(0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePaint = Paint()
      ..color = NajmTheme.gold
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Dots at data points (sampled)
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < n; i += (n / 10).ceil().clamp(1, 5)) {
      final x   = i / (n - 1) * w;
      final val = points[i].cumulative.clamp(0.0, 1.0);
      final y   = h - val * h;
      dotPaint.color = _levelColor(points[i].level);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  void _drawZone(Canvas canvas, double w, double h,
      double yLow, double yHigh, Color color) {
    final paint = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTRB(0, h - yHigh * h, w, h - yLow * h),
      paint,
    );
  }

  Color _levelColor(FatigueLevel l) {
    switch (l) {
      case FatigueLevel.high:   return NajmTheme.error;
      case FatigueLevel.medium: return NajmTheme.warning;
      case FatigueLevel.low:    return NajmTheme.success;
    }
  }

  @override
  bool shouldRepaint(_FatigueChartPainter old) => old.points != points;
}

// ══════════════════════════════════════════════════════════════════════════════
// PAIRING GANTT
// ══════════════════════════════════════════════════════════════════════════════

class PairingGanttWidget extends StatelessWidget {
  final List<Pairing> pairings;
  const PairingGanttWidget({super.key, required this.pairings});

  @override
  Widget build(BuildContext context) {
    if (pairings.isEmpty) return const SizedBox.shrink();

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
          const Text('Pairing Overview',
              style: TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          // Simple bar chart — one bar per pairing
          ...pairings.take(8).map((p) => _GanttBar(pairing: p)),
          if (pairings.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+${pairings.length - 8} more pairings',
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 11)),
            ),
          const SizedBox(height: 12),
          // Legend
          Row(children: [
            _GanttLegend(NajmTheme.gold, 'Operating'),
            const SizedBox(width: 12),
            _GanttLegend(NajmTheme.info, 'Deadhead'),
          ]),
        ],
      ),
    );
  }
}

class _GanttBar extends StatelessWidget {
  final Pairing pairing;
  const _GanttBar({required this.pairing});

  @override
  Widget build(BuildContext context) {
    final total = pairing.blockMinutes > 0 ? pairing.blockMinutes : 1;
    final opMins = pairing.operatingSegments
        .fold(0, (s, seg) => s + seg.blockMinutes);
    final dhMins = pairing.deadheadSegments
        .fold(0, (s, seg) => s + seg.blockMinutes);
    final opRatio = opMins / total;
    final dhRatio = dhMins / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 60,
          child: Text(pairing.pairingNumber,
              style: const TextStyle(
                  color: NajmTheme.textSecondary, fontSize: 10)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(children: [
              if (opRatio > 0)
                Expanded(
                  flex: (opRatio * 100).round(),
                  child: Container(
                    height: 16,
                    color: NajmTheme.gold,
                  ),
                ),
              if (dhRatio > 0)
                Expanded(
                  flex: (dhRatio * 100).round(),
                  child: Container(
                    height: 16,
                    color: NajmTheme.info.withOpacity(0.7),
                  ),
                ),
              if (opRatio + dhRatio < 1)
                Expanded(
                  flex: ((1 - opRatio - dhRatio) * 100).round().clamp(1, 100),
                  child: Container(height: 16, color: NajmTheme.navyLight),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text('${pairing.blockHours.toStringAsFixed(1)}h',
            style: const TextStyle(
                color: NajmTheme.textMuted, fontSize: 10)),
      ]),
    );
  }
}

class _GanttLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _GanttLegend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 12, height: 8,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: NajmTheme.textMuted, fontSize: 10)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MONTHLY HEATMAP CALENDAR
// ══════════════════════════════════════════════════════════════════════════════

class MonthlyHeatmapWidget extends StatelessWidget {
  final MonthlyLine line;
  const MonthlyHeatmapWidget({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    // Parse period to get month/year
    final parts = line.period.split('-');
    final monthLabels = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,
      'MAY': 5, 'JUN': 6, 'JUL': 7, 'AUG': 8,
      'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    };
    final month = monthLabels[parts.first.toUpperCase()] ?? 1;
    final year  = int.tryParse(parts.last) ?? 2026;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOfWeek = DateTime(year, month, 1).weekday % 7; // 0=Sun

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
          Text(line.period,
              style: const TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Fatigue heatmap — tap a day to see details',
              style: TextStyle(color: NajmTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 16),

          // Day headers
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) =>
              Expanded(
                child: Center(
                  child: Text(d,
                      style: const TextStyle(
                          color: NajmTheme.textMuted,
                          fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: firstDayOfWeek + daysInMonth,
            itemBuilder: (_, i) {
              if (i < firstDayOfWeek) {
                return const SizedBox.shrink();
              }
              final day = i - firstDayOfWeek + 1;
              return _HeatmapDay(
                day: day,
                // Simulate fatigue level — real impl uses timeline data
                level: _simulateLevel(day),
              );
            },
          ),
          const SizedBox(height: 16),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HeatLegend(NajmTheme.navyLight, 'Off'),
              const SizedBox(width: 12),
              _HeatLegend(NajmTheme.success.withOpacity(0.6), 'Low'),
              const SizedBox(width: 12),
              _HeatLegend(NajmTheme.warning.withOpacity(0.7), 'Medium'),
              const SizedBox(width: 12),
              _HeatLegend(NajmTheme.error.withOpacity(0.7), 'High'),
            ],
          ),
        ],
      ),
    );
  }

  FatigueLevel _simulateLevel(int day) {
    // Pseudo-random level — real impl maps from fatigue timeline
    if (day % 7 == 0 || day % 7 == 6) return FatigueLevel.low; // weekend
    if (day % 4 == 0) return FatigueLevel.high;
    if (day % 3 == 0) return FatigueLevel.medium;
    return FatigueLevel.low;
  }
}

class _HeatmapDay extends StatelessWidget {
  final int day;
  final FatigueLevel? level;
  const _HeatmapDay({required this.day, this.level});

  Color get _bg {
    switch (level) {
      case FatigueLevel.high:   return NajmTheme.error.withOpacity(0.65);
      case FatigueLevel.medium: return NajmTheme.warning.withOpacity(0.55);
      case FatigueLevel.low:    return NajmTheme.success.withOpacity(0.45);
      default:                  return NajmTheme.navyLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text('$day',
            style: TextStyle(
                color: level != null
                    ? Colors.white
                    : NajmTheme.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _HeatLegend(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(color: NajmTheme.textMuted, fontSize: 10)),
    ]);
  }
}
