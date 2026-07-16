import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';
import 'upgrade_prompt_sheet.dart';

/// Wrap any gated screen/widget with this. While subscriptions are
/// globally disabled (free launch), this renders `child` immediately —
/// no flicker, no upgrade UI, ever. Once subscriptions are enabled by
/// an admin, this same wrapper starts enforcing access without any
/// code change on the call site.
class FeatureGateWrapper extends ConsumerWidget {
  final String featureKey;
  final Widget child;

  /// Optional: a preview of value to show even when blocked, e.g.
  /// "8 legal trade matches found" before the upgrade prompt.
  final Widget? valuePreview;

  const FeatureGateWrapper({
    super.key,
    required this.featureKey,
    required this.child,
    this.valuePreview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlementAsync = ref.watch(entitlementProvider);

    return entitlementAsync.when(
      loading: () => child,
      error: (_, __) => child,
      data: (entitlement) {
        if (entitlement.canUse(featureKey)) {
          return child;
        }
        return _BlockedView(featureKey: featureKey, valuePreview: valuePreview);
      },
    );
  }
}

class _BlockedView extends StatelessWidget {
  final String featureKey;
  final Widget? valuePreview;

  const _BlockedView({required this.featureKey, this.valuePreview});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CIPTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (valuePreview != null) ...[
                valuePreview!,
                const SizedBox(height: 16),
              ],
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: CIPTheme.primary.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium_outlined,
                            color: CIPTheme.primary, size: 32),
                      ),
                      const SizedBox(height: 20),
                      const Text('This is a Pro feature',
                          style: TextStyle(
                              color: CIPTheme.textPrimary,
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text(
                        'Upgrade to Najm Pro to unlock this\nand other premium tools.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: CIPTheme.textSecondary,
                            fontSize: 13, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => showUpgradePromptSheet(
                            context, featureKey: featureKey),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CIPTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('See Pro Plans',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// For inline gating of a button/action rather than a whole screen.
class FeatureGateBuilder extends ConsumerWidget {
  final String featureKey;
  final Widget Function(BuildContext context, bool canUse) builder;

  const FeatureGateBuilder({
    super.key, required this.featureKey, required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement = watchEntitlement(ref);
    return builder(context, entitlement.canUse(featureKey));
  }
}
