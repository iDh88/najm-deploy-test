import 'package:flutter/material.dart';
import '../../../../app/theme.dart';
import '../../../subscription/models/subscription_models.dart';

/// Grid of feature → access-level toggles, the core of "Admin must decide
/// which features are Free or Pro from the Admin Panel, no code deploy."
class FeatureAccessToggleGrid extends StatelessWidget {
  final Map<String, Map<String, dynamic>> featureAccess;
  final void Function(String featureKey, FeatureAccessLevel newLevel) onChanged;

  const FeatureAccessToggleGrid({
    super.key, required this.featureAccess, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = featureAccess.entries.toList()
      ..sort((a, b) => (a.value['displayName'] as String? ?? '')
          .compareTo(b.value['displayName'] as String? ?? ''));

    return Column(
      children: entries.map((e) {
        final key = e.key;
        final displayName = e.value['displayName'] ?? key;
        final isPro = e.value['accessLevel'] == 'PRO_ONLY';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: CIPTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CIPTheme.divider),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName as String,
                      style: const TextStyle(
                          color: CIPTheme.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(key,
                      style: const TextStyle(color: CIPTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
            _AccessToggle(
              isPro: isPro,
              onChanged: (newIsPro) => onChanged(
                key,
                newIsPro ? FeatureAccessLevel.proOnly : FeatureAccessLevel.public_,
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

class _AccessToggle extends StatelessWidget {
  final bool isPro;
  final ValueChanged<bool> onChanged;
  const _AccessToggle({required this.isPro, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CIPTheme.navLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegmentButton(
            label: 'Free', active: !isPro,
            color: CIPTheme.success,
            onTap: () => onChanged(false),
          ),
          _SegmentButton(
            label: 'Pro', active: isPro,
            color: CIPTheme.primary,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _SegmentButton({
    required this.label, required this.active, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? color : CIPTheme.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PLAN CARD — editable plan summary in admin panel
// ══════════════════════════════════════════════════════════════════════════════

class PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onEdit;

  const PlanCard({super.key, required this.plan, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isPro = plan.tier == PlanTier.pro;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isPro ? CIPTheme.primary.withOpacity(0.3) : CIPTheme.divider),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (isPro ? CIPTheme.primary : CIPTheme.success).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPro ? Icons.workspace_premium_outlined : Icons.card_membership_outlined,
            color: isPro ? CIPTheme.primary : CIPTheme.success, size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(plan.displayName,
                    style: const TextStyle(
                        color: CIPTheme.textPrimary,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (!plan.isActive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CIPTheme.textMuted.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text('INACTIVE',
                        style: TextStyle(
                            color: CIPTheme.textMuted, fontSize: 8,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              Text('${plan.benefits.length} benefits listed',
                  style: const TextStyle(color: CIPTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined, color: CIPTheme.textMuted, size: 18),
          onPressed: onEdit,
        ),
      ]),
    );
  }
}
