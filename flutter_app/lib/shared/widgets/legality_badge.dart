import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';

// ─── LegalityBadge ────────────────────────────────────────────────────────────
/// Compact pill showing legality status. Tappable to open LegalityPanel.
class LegalityBadge extends StatelessWidget {
  final bool hasViolations;
  final bool hasWarnings;
  final List<LegalityViolation> violations;
  final VoidCallback? onTap;

  const LegalityBadge({
    super.key,
    required this.hasViolations,
    required this.hasWarnings,
    this.violations = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, label) = hasViolations
        ? (Icons.shield, CIPTheme.violationRed, CIPTheme.violationRedBg, 'Violation')
        : hasWarnings
            ? (Icons.shield_outlined, CIPTheme.warningAmber, CIPTheme.warningAmberBg, 'Warning')
            : (Icons.shield, CIPTheme.legalGreen, CIPTheme.legalGreenBg, 'Legal');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── LegalityPanel ────────────────────────────────────────────────────────────
/// Expandable panel showing full legality check results with per-violation detail.
class LegalityPanel extends StatefulWidget {
  final LegalityResult result;
  const LegalityPanel({super.key, required this.result});

  @override
  State<LegalityPanel> createState() => _LegalityPanelState();
}

class _LegalityPanelState extends State<LegalityPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final allPassed = widget.result.passed && widget.result.warnings.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: allPassed
            ? CIPTheme.legalGreenBg
            : !widget.result.passed
                ? CIPTheme.violationRedBg
                : CIPTheme.warningAmberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allPassed
              ? CIPTheme.legalGreen
              : !widget.result.passed
                  ? CIPTheme.violationRed
                  : CIPTheme.warningAmber,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: !allPassed ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    widget.result.passed ? Icons.check_circle : Icons.cancel,
                    color: widget.result.passed
                        ? CIPTheme.legalGreen
                        : CIPTheme.violationRed,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.result.passed
                              ? 'All legality checks passed'
                              : '${widget.result.violations.length} violation(s) found',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: widget.result.passed
                                ? CIPTheme.legalGreen
                                : CIPTheme.violationRed,
                          ),
                        ),
                        if (widget.result.warnings.isNotEmpty)
                          Text(
                            '${widget.result.warnings.length} warning(s)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: CIPTheme.warningAmber,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!allPassed)
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: CIPTheme.grey500,
                    ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.result.violations.map(
              (v) => _ViolationRow(violation: v, isViolation: true),
            ),
            ...widget.result.warnings.map(
              (v) => _ViolationRow(violation: v, isViolation: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _ViolationRow extends StatelessWidget {
  final LegalityViolation violation;
  final bool isViolation;

  const _ViolationRow({required this.violation, required this.isViolation});

  @override
  Widget build(BuildContext context) {
    final color =
        isViolation ? CIPTheme.violationRed : CIPTheme.warningAmber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isViolation
                ? Icons.error_outline
                : Icons.warning_amber_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  violation.ruleDescriptionAr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
                Text(
                  violation.ruleDescription,
                  style: const TextStyle(
                    fontSize: 11,
                    color: CIPTheme.grey500,
                  ),
                ),
                Text(
                  'Actual: ${violation.actualValue.toStringAsFixed(1)} ${violation.unit} '
                  '(required: ${violation.requiredValue.toStringAsFixed(1)} ${violation.unit})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: CIPTheme.grey700,
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
