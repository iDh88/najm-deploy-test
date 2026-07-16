import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_models.dart';
import '../services/subscription_service.dart';

final subscriptionServiceProvider =
    Provider<SubscriptionService>((_) => SubscriptionService());

// ── Entitlement — the core "what can this user access" provider ──────────────

final entitlementProvider = FutureProvider<Entitlement>((ref) async {
  try {
    return await ref.read(subscriptionServiceProvider).getEntitlement();
  } catch (_) {
    return Entitlement.freeLaunchDefault();
  }
});

/// Convenience accessor for synchronous reads. Falls back to the
/// free-launch default until the real entitlement resolves.
Entitlement watchEntitlement(WidgetRef ref) {
  return ref.watch(entitlementProvider).maybeWhen(
    data: (e) => e,
    orElse: () => Entitlement.freeLaunchDefault(),
  );
}

// ── Usage status per feature ──────────────────────────────────────────────────

final usageStatusProvider =
    FutureProvider.family<UsageStatus, String>((ref, featureKey) {
  return ref.read(subscriptionServiceProvider).getUsage(featureKey);
});

// ── Feature check (one-shot, not cached) ──────────────────────────────────────

final featureCheckProvider =
    FutureProvider.family<FeatureCheckResult, ({String featureKey, bool consume})>(
  (ref, args) => ref
      .read(subscriptionServiceProvider)
      .checkFeature(args.featureKey, consumeUsage: args.consume),
);

// ── Plans (public, no auth) ────────────────────────────────────────────────────

final plansProvider = FutureProvider<List<SubscriptionPlan>>((ref) {
  return ref.read(subscriptionServiceProvider).getPlans();
});

// ── Account history ────────────────────────────────────────────────────────────

final accountHistoryProvider = FutureProvider<List<AccountHistoryEvent>>((ref) {
  return ref.read(subscriptionServiceProvider).getHistory();
});

// ── Trial start ────────────────────────────────────────────────────────────────

class TrialStartState {
  final bool isLoading;
  final String? message;
  final bool? success;
  const TrialStartState({this.isLoading = false, this.message, this.success});
}

class TrialStartNotifier extends StateNotifier<TrialStartState> {
  final SubscriptionService _svc;
  final Ref _ref;
  TrialStartNotifier(this._svc, this._ref) : super(const TrialStartState());

  Future<void> start() async {
    state = const TrialStartState(isLoading: true);
    final result = await _svc.startTrial();
    state = TrialStartState(message: result.message, success: result.success);
    if (result.success) {
      _ref.invalidate(entitlementProvider);
    }
  }
}

final trialStartProvider =
    StateNotifierProvider<TrialStartNotifier, TrialStartState>(
  (ref) => TrialStartNotifier(ref.read(subscriptionServiceProvider), ref),
);

// ── Referral ──────────────────────────────────────────────────────────────────

final referralStatusProvider = FutureProvider<ReferralStatus>((ref) {
  return ref.read(subscriptionServiceProvider).getReferralStatus();
});

class ApplyReferralState {
  final bool isLoading;
  final String? message;
  final bool? success;
  const ApplyReferralState({this.isLoading = false, this.message, this.success});
}

class ApplyReferralNotifier extends StateNotifier<ApplyReferralState> {
  final SubscriptionService _svc;
  final Ref _ref;
  ApplyReferralNotifier(this._svc, this._ref) : super(const ApplyReferralState());

  Future<void> apply(String code) async {
    state = const ApplyReferralState(isLoading: true);
    final result = await _svc.applyReferralCode(code);
    state = ApplyReferralState(message: result.message, success: result.success);
    if (result.success) {
      _ref.invalidate(referralStatusProvider);
    }
  }
}

final applyReferralProvider =
    StateNotifierProvider<ApplyReferralNotifier, ApplyReferralState>(
  (ref) => ApplyReferralNotifier(ref.read(subscriptionServiceProvider), ref),
);
