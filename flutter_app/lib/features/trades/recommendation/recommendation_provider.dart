import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models.dart';
import 'trade_recommendation_service.dart';

final _svc = TradeRecommendationService();

// ── Service provider ──────────────────────────────────────────────────────────

final tradeRecommendationServiceProvider =
    Provider<TradeRecommendationService>((_) => TradeRecommendationService());

// ── Search state ──────────────────────────────────────────────────────────────

enum SearchStatus { idle, loading, loaded, error }

class TradeSearchState {
  final SearchStatus status;
  final TradeSearchResult? result;
  final String? error;
  final String activeTradeId; // session ID for PRN tracking

  const TradeSearchState({
    this.status = SearchStatus.idle,
    this.result,
    this.error,
    this.activeTradeId = '',
  });

  TradeSearchState copyWith({
    SearchStatus? status,
    TradeSearchResult? result,
    String? error,
    String? activeTradeId,
  }) =>
      TradeSearchState(
        status:        status        ?? this.status,
        result:        result        ?? this.result,
        error:         error,
        activeTradeId: activeTradeId ?? this.activeTradeId,
      );

  bool get hasResults  => result != null && result!.matches.isNotEmpty;
  bool get isLoading   => status == SearchStatus.loading;
}

class TradeSearchNotifier extends StateNotifier<TradeSearchState> {
  final TradeRecommendationService _svc;

  TradeSearchNotifier(this._svc) : super(const TradeSearchState());

  Future<void> search({
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
  }) async {
    state = state.copyWith(status: SearchStatus.loading, error: null);
    try {
      final result = await _svc.searchTrades(
        userId:         userId,
        rank:           rank,
        month:          month,
        routeKey:       routeKey,
        blockHours:     blockHours,
        dutyHours:      dutyHours,
        fdpMinutes:     fdpMinutes,
        signinHour:     signinHour,
        layoverHours:   layoverHours,
        isInternational:isInternational,
        hasDeadhead:    hasDeadhead,
        fatigueScore:   fatigueScore,
        tripDates:      tripDates,
      );

      // Generate a session ID for PRN tracking
      final sessionId =
          '${userId}_${routeKey.replaceAll('-', '')}_${DateTime.now().millisecondsSinceEpoch}';

      state = state.copyWith(
        status:        SearchStatus.loaded,
        result:        result,
        activeTradeId: sessionId,
      );

      // Record view event for each match (background, non-blocking)
      for (final m in result.matches) {
        _svc.recordEvent(
          userId:         userId,
          tradeId:        sessionId,
          outcome:        TradeOutcome.viewed,
          routeKey:       routeKey,
          destinations:   routeKey.split('-'),
          blockHours:     blockHours,
          dutyHours:      dutyHours,
          fatigueScore:   fatigueScore,
          isInternational:isInternational,
          hasDeadhead:    hasDeadhead,
          signinHour:     signinHour,
          layoverHours:   layoverHours,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: SearchStatus.error,
        error:  e.toString(),
      );
    }
  }

  void reset() => state = const TradeSearchState();

  Future<void> recordAccepted({
    required String userId,
    required String prn,
    required double blockHours,
    required double dutyHours,
    required double fatigueScore,
    required bool   isInternational,
    required bool   hasDeadhead,
    required int    signinHour,
    required double layoverHours,
  }) async {
    if (state.activeTradeId.isEmpty || state.result == null) return;
    await _svc.recordEvent(
      userId:         userId,
      tradeId:        '${state.activeTradeId}_$prn',
      outcome:        TradeOutcome.accepted,
      routeKey:       state.result!.route,
      destinations:   state.result!.route.split('-'),
      blockHours:     blockHours,
      dutyHours:      dutyHours,
      fatigueScore:   fatigueScore,
      isInternational:isInternational,
      hasDeadhead:    hasDeadhead,
      signinHour:     signinHour,
      layoverHours:   layoverHours,
    );
  }
}

final tradeSearchProvider =
    StateNotifierProvider<TradeSearchNotifier, TradeSearchState>(
  (ref) => TradeSearchNotifier(ref.read(tradeRecommendationServiceProvider)),
);

// ── PRN contact status stream ─────────────────────────────────────────────────

final prnStatusStreamProvider =
    StreamProvider.family<List<Map<String, dynamic>>, _PRNKey>(
  (ref, key) => ref
      .read(tradeRecommendationServiceProvider)
      .prnStatusStream(key.userId, key.tradeId),
);

class _PRNKey {
  final String userId, tradeId;
  const _PRNKey(this.userId, this.tradeId);
}

// ── Preference summary ────────────────────────────────────────────────────────

final preferenceSummaryProvider =
    FutureProvider.family<UserPreferenceSummary?, String>(
  (ref, userId) =>
      ref.read(tradeRecommendationServiceProvider).getPreferenceSummary(userId),
);
