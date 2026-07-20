// Subscription System — Flutter Models
// Mirrors python_services/subscription_engine/models.py response shapes.

enum PlanTier { free, pro }

enum SubscriptionStatus { none, trial, active, expired, cancelled, granted }

enum FeatureAccessLevel { public_, proOnly }

enum SubscriptionEventType {
  trialStarted,
  trialExtended,
  trialExpired,
  subscriptionActivated,
  subscriptionRenewed,
  subscriptionCancelled,
  subscriptionExpired,
  adminGrantedDays,
  adminRevoked,
  promoActivated,
  referralRewardGranted,
}

PlanTier _planTierFromApi(String? v) =>
    v?.toUpperCase() == 'PRO' ? PlanTier.pro : PlanTier.free;

SubscriptionStatus _statusFromApi(String? v) {
  switch ((v ?? '').toUpperCase()) {
    case 'TRIAL':     return SubscriptionStatus.trial;
    case 'ACTIVE':     return SubscriptionStatus.active;
    case 'EXPIRED':    return SubscriptionStatus.expired;
    case 'CANCELLED':  return SubscriptionStatus.cancelled;
    case 'GRANTED':    return SubscriptionStatus.granted;
    default:           return SubscriptionStatus.none;
  }
}

FeatureAccessLevel _accessFromApi(String? v) =>
    v?.toUpperCase() == 'PRO_ONLY'
        ? FeatureAccessLevel.proOnly
        : FeatureAccessLevel.public_;

SubscriptionEventType _eventTypeFromApi(String v) {
  switch (v.toUpperCase()) {
    case 'TRIAL_STARTED':              return SubscriptionEventType.trialStarted;
    case 'TRIAL_EXTENDED':             return SubscriptionEventType.trialExtended;
    case 'TRIAL_EXPIRED':              return SubscriptionEventType.trialExpired;
    case 'SUBSCRIPTION_ACTIVATED':     return SubscriptionEventType.subscriptionActivated;
    case 'SUBSCRIPTION_RENEWED':       return SubscriptionEventType.subscriptionRenewed;
    case 'SUBSCRIPTION_CANCELLED':     return SubscriptionEventType.subscriptionCancelled;
    case 'SUBSCRIPTION_EXPIRED':       return SubscriptionEventType.subscriptionExpired;
    case 'ADMIN_GRANTED_DAYS':         return SubscriptionEventType.adminGrantedDays;
    case 'ADMIN_REVOKED':              return SubscriptionEventType.adminRevoked;
    case 'PROMO_ACTIVATED':            return SubscriptionEventType.promoActivated;
    case 'REFERRAL_REWARD_GRANTED':    return SubscriptionEventType.referralRewardGranted;
    default:                           return SubscriptionEventType.adminGrantedDays;
  }
}

extension SubscriptionEventTypeX on SubscriptionEventType {
  String get icon {
    switch (this) {
      case SubscriptionEventType.trialStarted:           return '🎁';
      case SubscriptionEventType.trialExtended:          return '⏳';
      case SubscriptionEventType.trialExpired:           return '⌛';
      case SubscriptionEventType.subscriptionActivated:  return '✅';
      case SubscriptionEventType.subscriptionRenewed:    return '🔄';
      case SubscriptionEventType.subscriptionCancelled:  return '🛑';
      case SubscriptionEventType.subscriptionExpired:    return '⚠️';
      case SubscriptionEventType.adminGrantedDays:       return '✨';
      case SubscriptionEventType.adminRevoked:           return '🚫';
      case SubscriptionEventType.promoActivated:         return '🎉';
      case SubscriptionEventType.referralRewardGranted:  return '🎁';
    }
  }
}

// ── Entitlement (the main "what can I access" response) ──────────────────────

class Entitlement {
  final bool subscriptionsEnabled;
  final PlanTier tier;
  final SubscriptionStatus status;
  final bool isProActive;
  final bool trialActive;
  final int? trialDaysRemaining;
  final DateTime? expirationDate;

  /// When the trial began. Null for paid plans — the subscription document
  /// stores no start date for them, so the Profile card shows "—" instead of
  /// inventing a date.
  final DateTime? trialStartedAt;
  final Map<String, FeatureAccessLevel> featureAccess;

  const Entitlement({
    required this.subscriptionsEnabled,
    required this.tier,
    required this.status,
    required this.isProActive,
    required this.trialActive,
    this.trialDaysRemaining,
    this.expirationDate,
    this.trialStartedAt,
    required this.featureAccess,
  });

  factory Entitlement.fromMap(Map<String, dynamic> m) => Entitlement(
    subscriptionsEnabled: m['subscriptionsEnabled'] as bool? ?? false,
    tier: _planTierFromApi(m['tier'] as String?),
    status: _statusFromApi(m['status'] as String?),
    isProActive: m['isProActive'] as bool? ?? false,
    trialActive: m['trialActive'] as bool? ?? false,
    trialDaysRemaining: m['trialDaysRemaining'] as int?,
    expirationDate: m['expirationDate'] != null
        ? DateTime.tryParse(m['expirationDate'] as String) : null,
    trialStartedAt: m['trialStartedAt'] != null
        ? DateTime.tryParse(m['trialStartedAt'] as String) : null,
    featureAccess: (m['featureAccess'] as Map? ?? {}).map(
        (k, v) => MapEntry(k.toString(), _accessFromApi(v.toString()))),
  );

  /// Default entitlement used before the first API call resolves —
  /// fails open exactly like the backend does during free launch.
  factory Entitlement.freeLaunchDefault() => const Entitlement(
    subscriptionsEnabled: false,
    tier: PlanTier.free,
    status: SubscriptionStatus.none,
    isProActive: false,
    trialActive: false,
    featureAccess: {},
  );

  /// Resolves whether a specific feature is currently usable.
  /// While subscriptions are globally disabled, everything is open.
  bool canUse(String featureKey) {
    if (!subscriptionsEnabled) return true;
    if (isProActive) return true;
    final level = featureAccess[featureKey] ?? FeatureAccessLevel.public_;
    return level == FeatureAccessLevel.public_;
  }
}

// ── Usage status ──────────────────────────────────────────────────────────────

class UsageStatus {
  final String featureKey;
  final int used;
  final int limit;
  final int remaining;
  final bool isUnlimited;
  final DateTime resetsAt;

  const UsageStatus({
    required this.featureKey,
    required this.used,
    required this.limit,
    required this.remaining,
    required this.isUnlimited,
    required this.resetsAt,
  });

  factory UsageStatus.fromMap(Map<String, dynamic> m) => UsageStatus(
    featureKey: m['featureKey'] as String? ?? '',
    used: m['used'] as int? ?? 0,
    limit: m['limit'] as int? ?? 0,
    remaining: m['remaining'] as int? ?? -1,
    isUnlimited: m['isUnlimited'] as bool? ?? true,
    resetsAt: DateTime.tryParse(m['resetsAt'] as String? ?? '') ?? DateTime.now(),
  );

  double get usedFraction =>
      isUnlimited || limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
}

// ── Feature check decision ────────────────────────────────────────────────────

class FeatureCheckResult {
  final bool allowed;
  final String reason;
  final bool requiresUpgrade;
  final int? usageUsed;
  final int? usageLimit;

  const FeatureCheckResult({
    required this.allowed,
    required this.reason,
    required this.requiresUpgrade,
    this.usageUsed,
    this.usageLimit,
  });

  factory FeatureCheckResult.fromMap(Map<String, dynamic> m) => FeatureCheckResult(
    allowed: m['allowed'] as bool? ?? true,
    reason: m['reason'] as String? ?? 'free_launch',
    requiresUpgrade: m['requiresUpgrade'] as bool? ?? false,
    usageUsed: m['usageUsed'] as int?,
    usageLimit: m['usageLimit'] as int?,
  );
}

// ── Plan ───────────────────────────────────────────────────────────────────────

class SubscriptionPlan {
  final PlanTier tier;
  final String displayName;
  final String description;
  final List<String> benefits;
  final String? priceLabel;
  final bool isActive;

  const SubscriptionPlan({
    required this.tier,
    required this.displayName,
    required this.description,
    required this.benefits,
    this.priceLabel,
    required this.isActive,
  });

  factory SubscriptionPlan.fromMap(Map<String, dynamic> m) => SubscriptionPlan(
    tier: _planTierFromApi(m['tier'] as String?),
    displayName: m['displayName'] as String? ?? '',
    description: m['description'] as String? ?? '',
    benefits: List<String>.from(m['benefits'] as List? ?? []),
    priceLabel: m['priceLabel'] as String?,
    isActive: m['isActive'] as bool? ?? true,
  );
}

// ── Account history event ─────────────────────────────────────────────────────

class AccountHistoryEvent {
  final String id;
  final SubscriptionEventType eventType;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const AccountHistoryEvent({
    required this.id,
    required this.eventType,
    required this.description,
    required this.metadata,
    required this.createdAt,
  });

  factory AccountHistoryEvent.fromMap(Map<String, dynamic> m) => AccountHistoryEvent(
    id: m['id'] as String? ?? '',
    eventType: _eventTypeFromApi(m['eventType'] as String? ?? 'ADMIN_GRANTED_DAYS'),
    description: m['description'] as String? ?? '',
    metadata: Map<String, dynamic>.from(m['metadata'] as Map? ?? {}),
    createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

// ── Referral ──────────────────────────────────────────────────────────────────

class ReferralTierInfo {
  final int invitesRequired;
  final int rewardDays;
  final String label;

  const ReferralTierInfo({
    required this.invitesRequired,
    required this.rewardDays,
    required this.label,
  });

  factory ReferralTierInfo.fromMap(Map<String, dynamic> m) => ReferralTierInfo(
    invitesRequired: m['invitesRequired'] as int? ?? 1,
    rewardDays: m['rewardDays'] as int? ?? 7,
    label: m['label'] as String? ?? '',
  );
}

class ReferralStatus {
  final String referralCode;
  final int successfulInvites;
  final List<int> rewardsClaimed;
  final bool campaignActive;
  final List<ReferralTierInfo> tiers;

  const ReferralStatus({
    required this.referralCode,
    required this.successfulInvites,
    required this.rewardsClaimed,
    required this.campaignActive,
    required this.tiers,
  });

  factory ReferralStatus.fromMap(Map<String, dynamic> m) {
    final campaign = m['campaign'] as Map<String, dynamic>?;
    return ReferralStatus(
      referralCode: m['referralCode'] as String? ?? '',
      successfulInvites: m['successfulInvites'] as int? ?? 0,
      rewardsClaimed: List<int>.from(m['rewardsClaimed'] as List? ?? []),
      campaignActive: campaign?['isActive'] as bool? ?? false,
      tiers: ((campaign?['tiers'] as List?) ?? [])
          .map((t) => ReferralTierInfo.fromMap(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }

  /// Next tier not yet claimed, or null if all claimed / none configured.
  ReferralTierInfo? get nextTier {
    final unclaimed = tiers.where(
        (t) => !rewardsClaimed.contains(t.invitesRequired)).toList()
      ..sort((a, b) => a.invitesRequired.compareTo(b.invitesRequired));
    return unclaimed.isEmpty ? null : unclaimed.first;
  }
}
