import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/constants/constants.dart';
import '../models/rest_models.dart';

class RestLegalityService {
  final _dio = Dio(BaseOptions(baseUrl: AppConfig.aiServiceUrl));

  RestLegalityService() {
    // 0.1b — attach the caller's Firebase ID token to every request so the
    // (now authenticated) Python endpoints accept it.
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }

  // ── Shared request builder ─────────────────────────────────────────────────

  Map<String, dynamic> _buildRequest({
    required DateTime dutyStartUtc,
    required DateTime dutyEndUtc,
    required int      reportLocalHour,
    required int      numOperatingLegs,
    int     numDeadheadLegs   = 0,
    int     blockMinutes      = 0,
    bool    isInternational   = false,
    bool    isAugmented       = false,
    String  localTz           = 'Asia/Riyadh',
    double  carryOverHours    = 0.0,
    DateTime? nextDutyStartUtc,
    String  crewType          = 'cabin_standard',
    int     restBeforeMins    = 660,
    double  tzDeltaHours      = 0.0,
  }) =>
      {
        'duty_start_utc':      dutyStartUtc.toUtc().toIso8601String(),
        'duty_end_utc':        dutyEndUtc.toUtc().toIso8601String(),
        'report_local_hour':   reportLocalHour,
        'num_operating_legs':  numOperatingLegs,
        'num_deadhead_legs':   numDeadheadLegs,
        'block_minutes':       blockMinutes,
        'is_international':    isInternational,
        'is_augmented':        isAugmented,
        'local_tz':            localTz,
        'carry_over_hours':    carryOverHours,
        if (nextDutyStartUtc != null)
          'next_duty_start_utc': nextDutyStartUtc.toUtc().toIso8601String(),
        'crew_type':           crewType,
        'rest_before_mins':    restBeforeMins,
        'tz_delta_hours':      tzDeltaHours,
      };

  // ── Calculate rest + FDP ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> calculate({
    required DateTime dutyStartUtc,
    required DateTime dutyEndUtc,
    required int      reportLocalHour,
    required int      numOperatingLegs,
    int     numDeadheadLegs  = 0,
    int     blockMinutes     = 0,
    bool    isInternational  = false,
    String  localTz          = 'Asia/Riyadh',
    double  carryOverHours   = 0.0,
    DateTime? nextDutyStartUtc,
    String  crewType         = 'cabin_standard',
  }) async {
    final res = await _dio.post(
      '/v1/rest/calculate',
      data: _buildRequest(
        dutyStartUtc:     dutyStartUtc,
        dutyEndUtc:       dutyEndUtc,
        reportLocalHour:  reportLocalHour,
        numOperatingLegs: numOperatingLegs,
        numDeadheadLegs:  numDeadheadLegs,
        blockMinutes:     blockMinutes,
        isInternational:  isInternational,
        localTz:          localTz,
        carryOverHours:   carryOverHours,
        nextDutyStartUtc: nextDutyStartUtc,
        crewType:         crewType,
      ),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ── Legality check ─────────────────────────────────────────────────────────

  Future<LegalityResult> validate({
    required DateTime dutyStartUtc,
    required DateTime dutyEndUtc,
    required int      reportLocalHour,
    required int      numOperatingLegs,
    int     numDeadheadLegs  = 0,
    int     blockMinutes     = 0,
    bool    isInternational  = false,
    bool    isAugmented      = false,
    String  localTz          = 'Asia/Riyadh',
    double  carryOverHours   = 0.0,
    DateTime? nextDutyStartUtc,
    String  crewType         = 'cabin_standard',
  }) async {
    final res = await _dio.post(
      '/v1/rest/validate',
      data: _buildRequest(
        dutyStartUtc:     dutyStartUtc,
        dutyEndUtc:       dutyEndUtc,
        reportLocalHour:  reportLocalHour,
        numOperatingLegs: numOperatingLegs,
        numDeadheadLegs:  numDeadheadLegs,
        blockMinutes:     blockMinutes,
        isInternational:  isInternational,
        isAugmented:      isAugmented,
        localTz:          localTz,
        carryOverHours:   carryOverHours,
        nextDutyStartUtc: nextDutyStartUtc,
        crewType:         crewType,
      ),
    );
    return LegalityResult.fromMap(Map<String, dynamic>.from(res.data));
  }

  // ── Fatigue score ──────────────────────────────────────────────────────────

  Future<FatigueScoreResult> scoreFatigue({
    required DateTime dutyStartUtc,
    required DateTime dutyEndUtc,
    required int      reportLocalHour,
    required int      numOperatingLegs,
    int     numDeadheadLegs = 0,
    String  localTz         = 'Asia/Riyadh',
    int     restBeforeMins  = 660,
    double  tzDeltaHours    = 0.0,
    String  crewType        = 'cabin_standard',
  }) async {
    final res = await _dio.post(
      '/v1/rest/fatigue',
      data: _buildRequest(
        dutyStartUtc:     dutyStartUtc,
        dutyEndUtc:       dutyEndUtc,
        reportLocalHour:  reportLocalHour,
        numOperatingLegs: numOperatingLegs,
        numDeadheadLegs:  numDeadheadLegs,
        localTz:          localTz,
        restBeforeMins:   restBeforeMins,
        tzDeltaHours:     tzDeltaHours,
        crewType:         crewType,
      ),
    );
    return FatigueScoreResult.fromMap(Map<String, dynamic>.from(res.data));
  }

  // ── Safety report (combined) ───────────────────────────────────────────────

  Future<SafetyReport> safetyReport({
    required DateTime dutyStartUtc,
    required DateTime dutyEndUtc,
    required int      reportLocalHour,
    required int      numOperatingLegs,
    int     numDeadheadLegs  = 0,
    int     blockMinutes     = 0,
    bool    isInternational  = false,
    bool    isAugmented      = false,
    String  localTz          = 'Asia/Riyadh',
    double  carryOverHours   = 0.0,
    DateTime? nextDutyStartUtc,
    int     restBeforeMins   = 660,
    double  tzDeltaHours     = 0.0,
    String  crewType         = 'cabin_standard',
  }) async {
    final res = await _dio.post(
      '/v1/rest/safety',
      data: _buildRequest(
        dutyStartUtc:     dutyStartUtc,
        dutyEndUtc:       dutyEndUtc,
        reportLocalHour:  reportLocalHour,
        numOperatingLegs: numOperatingLegs,
        numDeadheadLegs:  numDeadheadLegs,
        blockMinutes:     blockMinutes,
        isInternational:  isInternational,
        isAugmented:      isAugmented,
        localTz:          localTz,
        carryOverHours:   carryOverHours,
        nextDutyStartUtc: nextDutyStartUtc,
        restBeforeMins:   restBeforeMins,
        tzDeltaHours:     tzDeltaHours,
        crewType:         crewType,
      ),
    );
    return SafetyReport.fromMap(Map<String, dynamic>.from(res.data));
  }

  // ── Trade legality ─────────────────────────────────────────────────────────

  Future<TradeSafetyResult> validateTrade({
    required Map<String, dynamic> offered,
    required Map<String, dynamic> requested,
    String crewType        = 'cabin_standard',
    int    restBeforeMins  = 660,
  }) async {
    final res = await _dio.post('/v1/rest/trade', data: {
      'offered':          offered,
      'requested':        requested,
      'crew_type':        crewType,
      'rest_before_mins': restBeforeMins,
    });
    return TradeSafetyResult.fromMap(Map<String, dynamic>.from(res.data));
  }

  // ── Rules reference ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getRules(
      {String crewType = 'cabin_standard'}) async {
    final res = await _dio.get(
        '/v1/rest/rules', queryParameters: {'crew_type': crewType});
    return Map<String, dynamic>.from(res.data);
  }
}
