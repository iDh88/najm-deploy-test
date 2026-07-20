import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/constants/constants.dart';
import '../models/subscription_models.dart';

class SubscriptionService {
  final _dio = Dio(BaseOptions(baseUrl: AppConfig.aiServiceUrl));

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  // ── User-facing ───────────────────────────────────────────────────────────────

  Future<Entitlement> getEntitlement() async {
    final res = await _dio.get(
      '/v1/subscription/me/entitlement',
      options: Options(headers: await _authHeaders()),
    );
    return Entitlement.fromMap(Map<String, dynamic>.from(res.data as Map));
  }

  Future<FeatureCheckResult> checkFeature(
    String featureKey, {
    bool consumeUsage = false,
  }) async {
    final res = await _dio.post(
      '/v1/subscription/me/check-feature',
      data: {'feature_key': featureKey, 'consume_usage': consumeUsage},
      options: Options(headers: await _authHeaders()),
    );
    return FeatureCheckResult.fromMap(Map<String, dynamic>.from(res.data as Map));
  }

  Future<UsageStatus> getUsage(String featureKey) async {
    final res = await _dio.get(
      '/v1/subscription/me/usage/$featureKey',
      options: Options(headers: await _authHeaders()),
    );
    return UsageStatus.fromMap(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<AccountHistoryEvent>> getHistory() async {
    final res = await _dio.get(
      '/v1/subscription/me/history',
      options: Options(headers: await _authHeaders()),
    );
    return (res.data as List)
        .map((m) => AccountHistoryEvent.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<List<SubscriptionPlan>> getPlans() async {
    final res = await _dio.get('/v1/subscription/plans');
    final map = Map<String, dynamic>.from(res.data as Map);
    return map.values
        .map((v) => SubscriptionPlan.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList();
  }

  Future<({bool success, String message})> startTrial() async {
    try {
      final res = await _dio.post(
        '/v1/subscription/me/trial/start',
        options: Options(headers: await _authHeaders()),
      );
      return (success: true, message: res.data['message'] as String);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] as String?;
      return (success: false, message: detail ?? 'Could not start trial.');
    }
  }

  Future<ReferralStatus> getReferralStatus() async {
    final res = await _dio.get(
      '/v1/subscription/me/referral',
      options: Options(headers: await _authHeaders()),
    );
    return ReferralStatus.fromMap(Map<String, dynamic>.from(res.data as Map));
  }

  Future<({bool success, String message})> applyReferralCode(String code) async {
    try {
      final res = await _dio.post(
        '/v1/subscription/me/referral/apply',
        data: {'code': code},
        options: Options(headers: await _authHeaders()),
      );
      return (success: true, message: res.data['message'] as String);
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] as String?;
      return (success: false, message: detail ?? 'Could not apply referral code.');
    }
  }

  // ── Admin ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> adminGetFullConfig() async {
    final res = await _dio.get(
      '/v1/subscription/admin/config',
      options: Options(headers: await _authHeaders()),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> adminSetMasterSwitch(bool enabled) async {
    await _dio.patch(
      '/v1/subscription/admin/config/master-switch',
      data: {'enabled': enabled},
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> adminSetFeatureAccess(String featureKey, FeatureAccessLevel level) async {
    await _dio.patch(
      '/v1/subscription/admin/config/feature-access',
      data: {
        'feature_key': featureKey,
        'access_level': level == FeatureAccessLevel.proOnly ? 'PRO_ONLY' : 'PUBLIC',
      },
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> adminSetUsageLimit(String featureKey, int monthlyLimit) async {
    await _dio.patch(
      '/v1/subscription/admin/config/usage-limit',
      data: {'feature_key': featureKey, 'monthly_limit': monthlyLimit},
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> adminUpdatePlan({
    required PlanTier tier,
    required String displayName,
    required String description,
    required List<String> benefits,
    String? priceLabel,
    bool isActive = true,
  }) async {
    await _dio.patch(
      '/v1/subscription/admin/config/plan',
      data: {
        'tier': tier == PlanTier.pro ? 'PRO' : 'FREE',
        'display_name': displayName,
        'description': description,
        'benefits': benefits,
        'price_label': priceLabel,
        'is_active': isActive,
      },
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> adminUpdateTrialConfig({
    required bool enabled,
    required int durationDays,
    bool requiresNoPriorTrial = true,
  }) async {
    await _dio.patch(
      '/v1/subscription/admin/config/trial',
      data: {
        'enabled': enabled,
        'duration_days': durationDays,
        'requires_no_prior_trial': requiresNoPriorTrial,
      },
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> adminActivateUser(String userId, {int? durationDays}) async {
    await _dio.post(
      '/v1/subscription/admin/users/activate',
      data: {'user_id': userId, 'duration_days': durationDays},
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> adminRevokeUser(String userId, {String reason = ''}) async {
    await _dio.post(
      '/v1/subscription/admin/users/revoke',
      data: {'user_id': userId, 'reason': reason},
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> adminGrantDays(String userId, int days, {String reason = ''}) async {
    await _dio.post(
      '/v1/subscription/admin/users/grant-days',
      data: {'user_id': userId, 'days': days, 'reason': reason},
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<Map<String, dynamic>> adminGetUserSubscription(String userId) async {
    final res = await _dio.get(
      '/v1/subscription/admin/users/$userId/subscription',
      options: Options(headers: await _authHeaders()),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<AccountHistoryEvent>> adminGetUserHistory(String userId) async {
    final res = await _dio.get(
      '/v1/subscription/admin/users/$userId/history',
      options: Options(headers: await _authHeaders()),
    );
    return (res.data as List)
        .map((m) => AccountHistoryEvent.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> adminExtendTrial(String userId, int days, {String reason = ''}) async {
    await _dio.post(
      '/v1/subscription/admin/trial/extend',
      queryParameters: {'user_id': userId, 'days': days, 'reason': reason},
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<Map<String, dynamic>> adminGetReferralCampaign() async {
    final res = await _dio.get(
      '/v1/subscription/admin/referral/campaign',
      options: Options(headers: await _authHeaders()),
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> adminUpdateReferralCampaign({
    required bool isActive,
    required List<ReferralTierInfo> tiers,
  }) async {
    await _dio.patch(
      '/v1/subscription/admin/referral/campaign',
      data: {
        'is_active': isActive,
        'tiers': tiers.map((t) => {
          'invites_required': t.invitesRequired,
          'reward_days': t.rewardDays,
          'label': t.label,
        }).toList(),
      },
      options: Options(headers: await _authHeaders()),
    );
  }
}
