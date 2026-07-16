// ═══════════════════════════════════════════════════════════════════════════
// shared/widgets/legality_badge.dart
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';

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
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color,
            )),
          ],
        ),
      ),
    );
  }
}

// Expanded legality detail panel for line/trade detail screens
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
    final hasIssues = !widget.result.passed || widget.result.warnings.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: widget.result.passed && widget.result.warnings.isEmpty
            ? CIPTheme.legalGreenBg
            : !widget.result.passed
                ? CIPTheme.violationRedBg
                : CIPTheme.warningAmberBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.result.passed && widget.result.warnings.isEmpty
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
            onTap: hasIssues ? () => setState(() => _expanded = !_expanded) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    widget.result.passed ? Icons.check_circle : Icons.cancel,
                    color: widget.result.passed ? CIPTheme.legalGreen : CIPTheme.violationRed,
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
                            color: widget.result.passed ? CIPTheme.legalGreen : CIPTheme.violationRed,
                          ),
                        ),
                        if (widget.result.warnings.isNotEmpty)
                          Text('${widget.result.warnings.length} warning(s)',
                              style: const TextStyle(fontSize: 12, color: CIPTheme.warningAmber)),
                      ],
                    ),
                  ),
                  if (hasIssues)
                    Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                        color: CIPTheme.grey500),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.result.violations.map((v) => _ViolationRow(violation: v, isViolation: true)),
            ...widget.result.warnings.map((v) => _ViolationRow(violation: v, isViolation: false)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isViolation ? Icons.error_outline : Icons.warning_amber_outlined,
            size: 16,
            color: isViolation ? CIPTheme.violationRed : CIPTheme.warningAmber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(violation.ruleDescriptionAr,
                    style: const TextStyle(fontSize: 12, fontFamily: 'Inter')),
                Text(violation.ruleDescription, style: const TextStyle(fontSize: 11, color: CIPTheme.grey500)),
                Text(
                  'Actual: ${violation.actualValue.toStringAsFixed(1)} ${violation.unit} '
                  '(required: ${violation.requiredValue.toStringAsFixed(1)} ${violation.unit})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CIPTheme.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// shared/widgets/skeleton_loader.dart
// ═══════════════════════════════════════════════════════════════════════════

class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: CIPTheme.grey200,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// shared/widgets/mode_switcher.dart
// ═══════════════════════════════════════════════════════════════════════════

class ModeSwitcher extends ConsumerWidget {
  final UserMode currentMode;
  const ModeSwitcher({super.key, required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Mode:', style: TextStyle(fontSize: 12, color: CIPTheme.grey700)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: UserMode.values.map((mode) {
                final isSelected = mode == currentMode;
                final (emoji, label, color) = switch (mode) {
                  UserMode.money => ('💰', 'Money', CIPTheme.moneyGreen),
                  UserMode.rest => ('😴', 'Rest', CIPTheme.restBlue),
                  UserMode.balanced => ('⚖️', 'Balanced', CIPTheme.balancedPurple),
                };

                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final user = ref.read(currentUserProvider).valueOrNull;
                      if (user == null) return;
                      final authService = ref.read(authServiceProvider);
                      await authService.updateUserMode(user.id, mode);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? color : CIPTheme.grey200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 14)),
                          Text(label, style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                            color: isSelected ? color : CIPTheme.grey500,
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════
// shared/widgets/main_shell.dart — Bottom nav shell
// ═══════════════════════════════════════════════════════════════════════════

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _locationToIndex(location),
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.flight_outlined), selectedIcon: Icon(Icons.flight), label: 'Lines'),
          NavigationDestination(icon: Icon(Icons.how_to_vote_outlined), selectedIcon: Icon(Icons.how_to_vote), label: 'Bids'),
          NavigationDestination(icon: Icon(Icons.swap_horiz_outlined), selectedIcon: Icon(Icons.swap_horiz), label: 'Trades'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Najm'),
        ],
      ),
    );
  }

  int _locationToIndex(String location) {
    if (location.startsWith('/lines')) return 1;
    if (location.startsWith('/bids')) return 2;
    if (location.startsWith('/trades')) return 3;
    if (location.startsWith('/assistant')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');
      case 1: context.go('/lines');
      case 2: context.go('/bids');
      case 3: context.go('/trades');
      case 4: context.go('/assistant');
    }
  }
}
