import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../models/rest_models.dart';

/// Vertical visual timeline:
/// Duty Start → Duty End (Release) → Rest Window → Briefing → Next Duty
class DutyTimelineWidget extends StatelessWidget {
  final LegalityResult legality;
  final String?        nextDutyLabel;

  const DutyTimelineWidget({
    super.key,
    required this.legality,
    this.nextDutyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final fdp  = legality.fdp;
    final rest = legality.rest;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Duty Timeline',
              style: TextStyle(
                  color: CIPTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // ── Duty Start ──────────────────────────────────────────────────
          _TimelineNode(
            icon:    Icons.flag_outlined,
            color:   CIPTheme.primary,
            label:   'Duty Start',
            sublabel:'Report / Briefing',
          ),

          // ── FDP bar ─────────────────────────────────────────────────────
          if (fdp != null)
            _TimelineConnector(
              label:  fdp.actualLabel,
              sublabel: 'Flight Duty Period',
              color: fdp.isWithinLimit
                  ? (fdp.isMarginal ? CIPTheme.warning : CIPTheme.primary)
                  : CIPTheme.error,
              fillRatio: fdp.usageRatio.clamp(0.0, 1.0),
              tag: fdp.earlySignin ? '🌅 Early' : null,
            )
          else
            _TimelineConnector(
              label:    legality.totalDutyLabel ?? '—',
              sublabel: 'Duty Period',
              color:    CIPTheme.primary,
            ),

          // ── Release ─────────────────────────────────────────────────────
          _TimelineNode(
            icon:    Icons.check_circle_outline,
            color:   legality.isLegal ? CIPTheme.success : CIPTheme.error,
            label:   'Duty End / Release',
            sublabel: legality.isLegal ? 'Legal release' : 'Violation detected',
            badge:   legality.statusEmoji,
          ),

          // ── Rest window ─────────────────────────────────────────────────
          if (rest != null) ...[
            _TimelineConnector(
              label:    rest.durationLabel,
              sublabel: 'Rest Window  (min: ${rest.minimumLabel})',
              color: rest.isSufficient
                  ? (rest.isMarginal ? CIPTheme.warning : CIPTheme.success)
                  : CIPTheme.error,
              fillRatio: rest.fillRatio.clamp(0.0, 1.0),
              tag: !rest.isSufficient ? '❌ Short' : null,
            ),

            // ── Briefing ────────────────────────────────────────────────
            _TimelineNode(
              icon:    Icons.alarm,
              color:   CIPTheme.info,
              label:   'Briefing',
              sublabel:'Pre-flight report',
            ),

            // ── Next Duty ───────────────────────────────────────────────
            _TimelineNode(
              icon:    Icons.flight_takeoff,
              color:   CIPTheme.primary,
              label:   nextDutyLabel ?? 'Next Duty Start',
              sublabel:'',
              isLast:  true,
            ),
          ] else ...[
            _TimelineNode(
              icon:    Icons.more_horiz,
              color:   CIPTheme.textMuted,
              label:   'Next duty not provided',
              sublabel:'Add next duty for rest analysis',
              isLast:  true,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TimelineNode extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   sublabel;
  final String?  badge;
  final bool     isLast;

  const _TimelineNode({
    required this.icon,
    required this.color,
    required this.label,
    required this.sublabel,
    this.badge,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon column
        Column(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          if (!isLast)
            Container(
              width: 2, height: 8,
              color: CIPTheme.divider,
            ),
        ]),
        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: CIPTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      if (sublabel.isNotEmpty)
                        Text(sublabel,
                            style: const TextStyle(
                                color: CIPTheme.textMuted,
                                fontSize: 11)),
                    ],
                  ),
                ),
                if (badge != null)
                  Text(badge!, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  final String  label;
  final String  sublabel;
  final Color   color;
  final double  fillRatio;
  final String? tag;

  const _TimelineConnector({
    required this.label,
    required this.sublabel,
    required this.color,
    this.fillRatio = 1.0,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Vertical bar
        Column(children: [
          Container(
            width: 2, height: 6,
            color: CIPTheme.divider,
          ),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Container(
              width: 2,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.3), color],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Container(
            width: 2, height: 6,
            color: CIPTheme.divider,
          ),
        ]),
        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  if (tag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CIPTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(tag!,
                          style: const TextStyle(
                              color: CIPTheme.error,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value:           fillRatio,
                    backgroundColor: color.withOpacity(0.15),
                    valueColor:      AlwaysStoppedAnimation(color),
                    minHeight:       4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(sublabel,
                    style: const TextStyle(
                        color: CIPTheme.textMuted,
                        fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
