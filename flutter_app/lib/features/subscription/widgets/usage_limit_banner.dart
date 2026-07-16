import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';
import 'upgrade_prompt_sheet.dart';

/// Shows "3 of 5 trade searches used this month" style banner.
/// Renders nothing while subscriptions are disabled or the feature
/// is unlimited — so it's always safe to drop into any gated screen.
class UsageLimitBanner extends ConsumerWidget {
  final String featureKey;
  final String featureLabel;

  const UsageLimitBanner({
    super.key, required this.featureKey, required this.featureLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = watchEntitlement(ref);
    if (!entitlement.subscriptionsEnabled || entitlement.isProActive) {
      return const SizedBox.shrink();
    }

    final usageAsync = ref.watch(usageStatusProvider(featureKey));

    return usageAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (usage) {
        if (usage.isUnlimited) return const SizedBox.shrink();

        final isNearLimit = usage.remaining <= 1 && usage.remaining >= 0;
        final color = isNearLimit ? CIPTheme.warning : CIPTheme.textSecondary;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(isNearLimit ? Icons.warning_amber_rounded : Icons.bar_chart,
                color: color, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${usage.used} of ${usage.limit} $featureLabel used this month',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            if (isNearLimit)
              GestureDetector(
                onTap: () => showUpgradePromptSheet(
                  context,
                  featureKey: featureKey,
                  valueHeadline: '${usage.used} of ${usage.limit} used',
                  valueSubtext: 'Upgrade to Pro for unlimited $featureLabel',
                ),
                child: const Text('Upgrade',
                    style: TextStyle(
                        color: CIPTheme.primary,
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ]),
        );
      },
    );
  }
}

/// Small "PRO" badge — drop next to any feature label in the UI.
class ProBadge extends ConsumerWidget {
  final String featureKey;

  const ProBadge({super.key, required this.featureKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = watchEntitlement(ref);

    if (!entitlement.subscriptionsEnabled) return const SizedBox.shrink();
    final level = entitlement.featureAccess[featureKey];
    if (level != FeatureAccessLevel.proOnly) return const SizedBox.shrink();
    if (entitlement.isProActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CIPTheme.primary, Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text('PRO',
          style: TextStyle(
              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    );
  }
}
