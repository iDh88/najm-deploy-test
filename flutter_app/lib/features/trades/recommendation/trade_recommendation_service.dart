import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/constants/constants.dart';
import 'models.dart';

class TradeRecommendationService {
  final _dio = Dio(BaseOptions(baseUrl: AppConfig.aiServiceUrl));
  final _db  = FirebaseFirestore.instance;

  TradeRecommendationService() {
    // 0.1b — authenticate every request with the caller's Firebase ID token.
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<TradeSearchResult> searchTrades({
    required String userId,
    required String rank,
    required String month,
    required String routeKey,
    required double blockHours,
    required double dutyHours,
    required int    fdpMinutes,
    required int    signinHour,
    required double layoverHours,
    required bool   isInternational,
    required bool   hasDeadhead,
    required double fatigueScore,
    required List<int> tripDates,
    int maxResults = 20,
  }) async {
    final res = await _dio.post('/v1/trade/search', data: {
      'requesting_user_id': userId,
      'requesting_rank':    rank,
      'month':              month,
      'route_key':          routeKey,
      'block_hours':        blockHours,
      'duty_hours':         dutyHours,
      'fdp_minutes':        fdpMinutes,
      'signin_hour':        signinHour,
      'layover_hours':      layoverHours,
      'is_international':   isInternational,
      'has_deadhead':       hasDeadhead,
      'fatigue_score':      fatigueScore,
      'trip_dates':         tripDates,
      'max_results':        maxResults,
    });
    return TradeSearchResult.fromMap(
        Map<String, dynamic>.from(res.data));
  }

  // ── Behavioral events ────────────────────────────────────────────────────

  Future<void> recordEvent({
    required String userId,
    required String tradeId,
    required TradeOutcome outcome,
    required String routeKey,
    required List<String> destinations,
    required double blockHours,
    required double dutyHours,
    required double fatigueScore,
    required bool isInternational,
    required bool hasDeadhead,
    required int signinHour,
    required double layoverHours,
    double restAfterHours = 11.0,
  }) async {
    try {
      await _dio.post('/v1/trade/events', data: {
        'user_id':          userId,
        'trade_id':         tradeId,
        'outcome':          outcome.name,
        'route_key':        routeKey,
        'destinations':     destinations,
        'block_hours':      blockHours,
        'duty_hours':       dutyHours,
        'fatigue_score':    fatigueScore,
        'is_international': isInternational,
        'has_deadhead':     hasDeadhead,
        'signin_hour':      signinHour,
        'layover_hours':    layoverHours,
        'rest_after_hours': restAfterHours,
      });
    } catch (_) {
      // Non-critical — fire and forget
    }
  }

  // ── Preference summary ───────────────────────────────────────────────────

  Future<UserPreferenceSummary?> getPreferenceSummary(String userId) async {
    try {
      final res = await _dio.get('/v1/trade/profile/$userId');
      return UserPreferenceSummary.fromMap(
          Map<String, dynamic>.from(res.data));
    } catch (_) {
      return null;
    }
  }

  // ── PRN contact tracking (Firestore direct) ──────────────────────────────

  Future<void> updatePRNStatus({
    required String userId,
    required String tradeId,
    required String prn,
    required PRNContactStatus status,
    String? note,
  }) async {
    await _db
        .collection('tradeContacts')
        .doc('${userId}_${tradeId}_$prn')
        .set({
      'userId':  userId,
      'tradeId': tradeId,
      'prn':     prn,
      'status':  status.name,
      'note':    note,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<Map<String, dynamic>>> prnStatusStream(
      String userId, String tradeId) {
    return _db
        .collection('tradeContacts')
        .where('userId',  isEqualTo: userId)
        .where('tradeId', isEqualTo: tradeId)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }
}
