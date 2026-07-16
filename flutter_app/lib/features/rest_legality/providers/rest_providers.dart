import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rest_models.dart';
import '../services/rest_legality_service.dart';

// ── Service ───────────────────────────────────────────────────────────────────

final restLegalityServiceProvider = Provider<RestLegalityService>(
  (_) => RestLegalityService(),
);

// ── Calculator state ──────────────────────────────────────────────────────────

enum RestCalcStatus { idle, loading, loaded, error }

class RestCalcState {
  final RestCalcStatus     status;
  final LegalityResult?    legality;
  final FatigueScoreResult?fatigue;
  final SafetyReport?      safety;
  final String?            error;

  const RestCalcState({
    this.status   = RestCalcStatus.idle,
    this.legality,
    this.fatigue,
    this.safety,
    this.error,
  });

  bool get isLoading => status == RestCalcStatus.loading;
  bool get hasResult => status == RestCalcStatus.loaded && safety != null;

  RestCalcState copyWith({
    RestCalcStatus?     status,
    LegalityResult?     legality,
    FatigueScoreResult? fatigue,
    SafetyReport?       safety,
    String?             error,
  }) =>
      RestCalcState(
        status:   status   ?? this.status,
        legality: legality ?? this.legality,
        fatigue:  fatigue  ?? this.fatigue,
        safety:   safety   ?? this.safety,
        error:    error,
      );
}

class RestCalcNotifier extends StateNotifier<RestCalcState> {
  final RestLegalityService _svc;

  RestCalcNotifier(this._svc) : super(const RestCalcState());

  Future<void> calculate({
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
    state = state.copyWith(status: RestCalcStatus.loading, error: null);
    try {
      final safety = await _svc.safetyReport(
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
      );
      state = state.copyWith(
        status:   RestCalcStatus.loaded,
        safety:   safety,
        legality: safety.legality,
        fatigue:  safety.fatigue,
      );
    } catch (e) {
      state = state.copyWith(
        status: RestCalcStatus.error,
        error:  e.toString(),
      );
    }
  }

  void reset() => state = const RestCalcState();
}

final restCalcProvider =
    StateNotifierProvider<RestCalcNotifier, RestCalcState>(
  (ref) => RestCalcNotifier(ref.read(restLegalityServiceProvider)),
);

// ── Trade safety provider ─────────────────────────────────────────────────────

final tradeSafetyProvider =
    FutureProvider.family<TradeSafetyResult, TradeSafetyRequest>(
  (ref, req) => ref
      .read(restLegalityServiceProvider)
      .validateTrade(
        offered:       req.offered,
        requested:     req.requested,
        crewType:      req.crewType,
        restBeforeMins:req.restBeforeMins,
      ),
);

class TradeSafetyRequest {
  final Map<String, dynamic> offered;
  final Map<String, dynamic> requested;
  final String crewType;
  final int    restBeforeMins;

  const TradeSafetyRequest({
    required this.offered,
    required this.requested,
    this.crewType       = 'cabin_standard',
    this.restBeforeMins = 660,
  });
}

// ── Rules provider ────────────────────────────────────────────────────────────

final rulesProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, crewType) =>
      ref.read(restLegalityServiceProvider).getRules(crewType: crewType),
);
