import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';

/// Shows the value-first upgrade prompt as a bottom sheet.
Future<void> showUpgradePromptSheet(
  BuildContext context, {
  required String featureKey,
  String? valueHeadline,
  String? valueSubtext,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: CIPTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => UpgradePromptSheet(
      featureKey: featureKey,
      valueHeadline: valueHeadline,
      valueSubtext: valueSubtext,
    ),
  );
}

class UpgradePromptSheet extends ConsumerWidget {
  final String featureKey;
  final String? valueHeadline;
  final String? valueSubtext;

  const UpgradePromptSheet({
    super.key,
    required this.featureKey,
    this.valueHeadline,
    this.valueSubtext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: CIPTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (valueHeadline != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CIPTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CIPTheme.success.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle, color: CIPTheme.success, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(valueHeadline!,
                            style: const TextStyle(
                                color: CIPTheme.textPrimary,
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        if (valueSubtext != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(valueSubtext!,
                                style: const TextStyle(
                                    color: CIPTheme.textSecondary, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
            ],

            const Text('Upgrade to Najm Pro',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text(
              'Unlock unlimited access to every tool Najm offers.',
              style: TextStyle(color: CIPTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),

            plansAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: CIPTheme.primary)),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (plans) {
                final pro = plans.where((p) => p.tier == PlanTier.pro).firstOrNull;
                if (pro == null) return const SizedBox.shrink();
                return _ProPlanCard(plan: pro);
              },
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/subscription/upgrade');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CIPTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continue',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not now',
                    style: TextStyle(color: CIPTheme.textMuted, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProPlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  const _ProPlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CIPTheme.primary.withOpacity(0.10), CIPTheme.primary.withOpacity(0.02)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CIPTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(plan.displayName,
                style: const TextStyle(
                    color: CIPTheme.primary,
                    fontSize: 16, fontWeight: FontWeight.w800)),
            if (plan.priceLabel != null) ...[
              const Spacer(),
              Text(plan.priceLabel!,
                  style: const TextStyle(
                      color: CIPTheme.textPrimary,
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ]),
          const SizedBox(height: 4),
          Text(plan.description,
              style: const TextStyle(color: CIPTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 12),
          ...plan.benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              const Icon(Icons.check, color: CIPTheme.success, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(b,
                  style: const TextStyle(
                      color: CIPTheme.textPrimary, fontSize: 13))),
            ]),
          )),
        ],
      ),
    );
  }
}
