import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme.dart';
import '../models.dart';

class MatchCard extends StatefulWidget {
  final TradeMatch match;
  final int index;
  final String tradeId;
  final String userId;
  final VoidCallback onViewBreakdown;
  final VoidCallback onOpenPRN;
  final VoidCallback onAccepted;

  const MatchCard({
    super.key,
    required this.match,
    required this.index,
    required this.tradeId,
    required this.userId,
    required this.onViewBreakdown,
    required this.onOpenPRN,
    required this.onAccepted,
  });

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  bool _prnCopied = false;

  Color get _compatColor {
    final p = widget.match.compatibilityPct;
    if (p >= 80) return CIPTheme.success;
    if (p >= 60) return CIPTheme.primary;
    if (p >= 40) return CIPTheme.warning;
    return CIPTheme.error;
  }

  Color get _fatigueColor {
    switch (widget.match.fatigueLevel) {
      case FatigueLevel.low:    return CIPTheme.success;
      case FatigueLevel.medium: return CIPTheme.warning;
      case FatigueLevel.high:   return CIPTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: m.isLegal
              ? CIPTheme.divider
              : CIPTheme.error.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _compatColor.withOpacity(0.2),
                        _compatColor.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _compatColor.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                          color: _compatColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // PRN + copy
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PRN',
                          style: TextStyle(
                              color: CIPTheme.textMuted,
                              fontSize: 10,
                              letterSpacing: 0.8)),
                      Row(
                        children: [
                          Text(m.prn,
                              style: const TextStyle(
                                  color: CIPTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: m.prn));
                              setState(() => _prnCopied = true);
                              Future.delayed(const Duration(seconds: 2), () {
                                if (mounted) setState(() => _prnCopied = false);
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _prnCopied
                                    ? CIPTheme.success.withOpacity(0.15)
                                    : CIPTheme.navLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _prnCopied
                                        ? CIPTheme.success
                                        : CIPTheme.divider),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _prnCopied ? Icons.check : Icons.copy,
                                    color: _prnCopied
                                        ? CIPTheme.success
                                        : CIPTheme.textMuted,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _prnCopied ? 'Copied' : 'Copy',
                                    style: TextStyle(
                                        color: _prnCopied
                                            ? CIPTheme.success
                                            : CIPTheme.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Compatibility score
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      m.compatibilityLabel,
                      style: TextStyle(
                          color: _compatColor,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1),
                    ),
                    const Text('match',
                        style: TextStyle(
                            color: CIPTheme.textMuted,
                            fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Badge row ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Badge(
                  label: m.isLegal ? '✅ Legal' : '❌ Illegal',
                  color: m.isLegal ? CIPTheme.success : CIPTheme.error,
                ),
                const SizedBox(width: 8),
                _Badge(
                  label: '🔋 ${m.fatigueLevel.name[0].toUpperCase()}${m.fatigueLevel.name.substring(1)} Fatigue',
                  color: _fatigueColor,
                ),
                const SizedBox(width: 8),
                _Badge(
                  label: '✈️ ${m.routeMatchLabel}',
                  color: CIPTheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Reasons ───────────────────────────────────────────────────────
          if (m.reasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Why this match',
                      style: TextStyle(
                          color: CIPTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  ...m.reasons.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            color: CIPTheme.primary, size: 13),
                        const SizedBox(width: 6),
                        Text(r,
                            style: const TextStyle(
                                color: CIPTheme.textSecondary,
                                fontSize: 12)),
                      ],
                    ),
                  )),
                ],
              ),
            ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: CIPTheme.divider),

          // ── Actions row ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                // Score breakdown
                Expanded(
                  child: _ActionBtn(
                    label:   'Score Details',
                    icon:    Icons.analytics_outlined,
                    color:   CIPTheme.textSecondary,
                    onTap:   widget.onViewBreakdown,
                  ),
                ),
                const SizedBox(width: 8),
                // Contact via PRN
                Expanded(
                  flex: 2,
                  child: _ActionBtn(
                    label:   'Contact via PRN',
                    icon:    Icons.send_outlined,
                    color:   CIPTheme.primary,
                    filled:  true,
                    onTap:   widget.onOpenPRN,
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

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color:  filled ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: filled ? null : Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14,
                color: filled ? Colors.white : color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: filled ? Colors.white : color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
