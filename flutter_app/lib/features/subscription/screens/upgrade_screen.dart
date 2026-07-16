import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';

/// Full upgrade/plans screen. Purchase buttons are wired to RevenueCat's
/// future SDK call sites — marked clearly below — but today (pre-store
/// integration) the "Subscribe" action falls back to starting a free
/// trial, since there is no live billing yet.
class UpgradeScreen extends ConsumerWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);
    final entitlement = watchEntitlement(ref);
    final trialState = ref.watch(trialStartProvider);

    ref.listen<TrialStartState>(trialStartProvider, (prev, next) {
      if (next.message != null && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            backgroundColor: next.success == true ? CIPTheme.success : CIPTheme.error,
          ),
        );
        if (next.success == true) context.pop();
      }
    });

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Najm Pro', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push('/subscription/account-history'),
            child: const Text('Account', style: TextStyle(color: CIPTheme.primary)),
          ),
        ],
      ),
      body: plansAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: CIPTheme.primary)),
        error: (e, _) => Center(child: Text(e.toString(),
            style: const TextStyle(color: CIPTheme.error))),
        data: (plans) {
          final free = plans.where((p) => p.tier == PlanTier.free).firstOrNull;
          final pro  = plans.where((p) => p.tier == PlanTier.pro).firstOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (entitlement.trialActive) _ActiveTrialBanner(
                  daysRemaining: entitlement.trialDaysRemaining),

              if (pro != null) _PlanComparisonCard(
                plan: pro,
                highlighted: true,
                ctaLabel: _ctaLabel(entitlement),
                onTap: () => _handleCta(context, ref, entitlement),
              ),
              const SizedBox(height: 16),
              if (free != null) _PlanComparisonCard(
                plan: free,
                highlighted: false,
                ctaLabel: entitlement.tier == PlanTier.free && !entitlement.isProActive
                    ? 'Current Plan' : null,
                onTap: null,
              ),

              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: CIPTheme.navLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: CIPTheme.textMuted, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Subscriptions help support Najm\'s continued development. '
                      'You can cancel anytime — your access continues until the end '
                      'of the current billing period.',
                      style: TextStyle(color: CIPTheme.textMuted, fontSize: 11, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  String _ctaLabel(Entitlement e) {
    if (e.isProActive) return 'Current Plan';
    if (e.status == SubscriptionStatus.expired || e.status == SubscriptionStatus.none) {
      return e.trialDaysRemaining == null ? 'Start Free Trial' : 'Subscribe';
    }
    return 'Subscribe';
  }

  void _handleCta(BuildContext context, WidgetRef ref, Entitlement e) {
    if (e.isProActive) return;

    // ── RevenueCat integration point ────────────────────────────────────────
    // When App Store / Google Play billing is live via RevenueCat, replace
    // this branch with:
    //   final customerInfo = await Purchases.purchasePackage(package);
    //   then call the backend to sync the resulting entitlement.
    // Until then, the only way to get Pro access pre-trial is the free trial.
    if (e.status == SubscriptionStatus.none) {
      ref.read(trialStartProvider.notifier).start();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscriptions are not yet available for purchase.')),
      );
    }
  }
}

class _ActiveTrialBanner extends StatelessWidget {
  final int? daysRemaining;
  const _ActiveTrialBanner({this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.success.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle, color: CIPTheme.success, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            daysRemaining != null
                ? 'You\'re in your free trial — $daysRemaining day${daysRemaining == 1 ? '' : 's'} remaining'
                : 'You\'re in your free trial',
            style: const TextStyle(
                color: CIPTheme.success, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _PlanComparisonCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final bool highlighted;
  final String? ctaLabel;
  final VoidCallback? onTap;

  const _PlanComparisonCard({
    required this.plan, required this.highlighted, this.ctaLabel, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: highlighted
            ? LinearGradient(
                colors: [CIPTheme.primary.withOpacity(0.12), CIPTheme.primary.withOpacity(0.02)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              )
            : null,
        color: highlighted ? null : CIPTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? CIPTheme.primary.withOpacity(0.4) : CIPTheme.divider,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(plan.displayName,
                style: TextStyle(
                    color: highlighted ? CIPTheme.primary : CIPTheme.textPrimary,
                    fontSize: 20, fontWeight: FontWeight.w800)),
            if (highlighted) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CIPTheme.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('RECOMMENDED',
                    style: TextStyle(
                        color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ],
            const Spacer(),
            if (plan.priceLabel != null)
              Text(plan.priceLabel!,
                  style: const TextStyle(
                      color: CIPTheme.textPrimary,
                      fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(plan.description,
              style: const TextStyle(color: CIPTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          ...plan.benefits.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Icon(Icons.check_circle_outline,
                  color: highlighted ? CIPTheme.primary : CIPTheme.success, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(b,
                  style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13))),
            ]),
          )),
          if (ctaLabel != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: onTap == null
                  ? OutlinedButton(
                      onPressed: null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(ctaLabel!,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    )
                  : ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CIPTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(ctaLabel!,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
