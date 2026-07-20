import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/intelligence_models.dart';
import '../services/intelligence_service.dart';

// ── Service singleton ────────────────────────────────────────────────────────

final intelligenceServiceProvider = Provider<IntelligenceService>(
  (_) => IntelligenceService(),
);

// ── User lines stream ─────────────────────────────────────────────────────────

final userLinesProvider = StreamProvider.family<List<MonthlyLine>, String>(
  (ref, userId) =>
      ref.read(intelligenceServiceProvider).userLinesStream(userId),
);

// ── Single line ───────────────────────────────────────────────────────────────

final lineDetailProvider = FutureProvider.family<MonthlyLine?, String>(
  (ref, lineId) => ref.read(intelligenceServiceProvider).getLine(lineId),
);

// ── Pairings ──────────────────────────────────────────────────────────────────

final pairingsProvider = FutureProvider.family<List<Pairing>, String>(
  (ref, lineId) => ref.read(intelligenceServiceProvider).getPairings(lineId),
);

// ── Fatigue timeline ──────────────────────────────────────────────────────────

final fatigueTimelineProvider =
    FutureProvider.family<List<FatiguePoint>, String>(
  (ref, lineId) =>
      ref.read(intelligenceServiceProvider).getFatigueTimeline(lineId),
);

// ── Upload state ──────────────────────────────────────────────────────────────

enum UploadStatus { idle, uploading, processing, complete, failed }

class UploadState {
  final UploadStatus status;
  final String uploadId;
  final String? lineId;
  final String? error;
  final double progress;

  const UploadState({
    this.status   = UploadStatus.idle,
    this.uploadId = '',
    this.lineId,
    this.error,
    this.progress = 0,
  });

  UploadState copyWith({
    UploadStatus? status, String? uploadId,
    String? lineId, String? error, double? progress,
  }) => UploadState(
    status:   status   ?? this.status,
    uploadId: uploadId ?? this.uploadId,
    lineId:   lineId   ?? this.lineId,
    error:    error    ?? this.error,
    progress: progress ?? this.progress,
  );
}

class UploadNotifier extends StateNotifier<UploadState> {
  final IntelligenceService _svc;

  UploadNotifier(this._svc) : super(const UploadState());

  Future<void> upload({
    required String filePath,
    required String userId,
    required String period,
    required int year,
  }) async {
    state = state.copyWith(status: UploadStatus.uploading, progress: 0.1);
    try {
      final uploadId = await _svc.uploadPDF(
        filePath: filePath, userId: userId, period: period, year: year,
      );
      state = state.copyWith(
        status: UploadStatus.processing, uploadId: uploadId, progress: 0.4,
      );
      await _pollStatus(uploadId);
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.failed, error: e.toString(),
      );
    }
  }

  Future<void> _pollStatus(String uploadId) async {
    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 3));
      final status = await _svc.getUploadStatus(uploadId);
      final s = status['status'] as String;
      if (s == 'complete') {
        state = state.copyWith(
          status: UploadStatus.complete,
          lineId: status['lineId'] as String?,
          progress: 1.0,
        );
        return;
      }
      if (s == 'failed') {
        state = state.copyWith(
          status: UploadStatus.failed,
          error: status['error'] as String? ?? 'Processing failed',
        );
        return;
      }
      state = state.copyWith(progress: 0.4 + (i / 60) * 0.5);
    }
    state = state.copyWith(
      status: UploadStatus.failed, error: 'Processing timed out',
    );
  }

  void reset() => state = const UploadState();
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>(
  (ref) => UploadNotifier(ref.read(intelligenceServiceProvider)),
);

// ── Search state ──────────────────────────────────────────────────────────────

class SearchFilters {
  final String? fatigueLevel;
  final bool? hasDeadhead;
  final bool? isInternational;
  final double? minCredit;
  final double? maxDutyHours;
  final String query;

  const SearchFilters({
    this.fatigueLevel, this.hasDeadhead, this.isInternational,
    this.minCredit, this.maxDutyHours, this.query = '',
  });

  bool get hasActiveFilters =>
      fatigueLevel != null || hasDeadhead != null ||
      isInternational != null || minCredit != null ||
      maxDutyHours != null || query.isNotEmpty;

  SearchFilters copyWith({
    String? fatigueLevel, bool? hasDeadhead, bool? isInternational,
    double? minCredit, double? maxDutyHours, String? query,
  }) => SearchFilters(
    fatigueLevel:    fatigueLevel    ?? this.fatigueLevel,
    hasDeadhead:     hasDeadhead     ?? this.hasDeadhead,
    isInternational: isInternational ?? this.isInternational,
    minCredit:       minCredit       ?? this.minCredit,
    maxDutyHours:    maxDutyHours    ?? this.maxDutyHours,
    query:           query           ?? this.query,
  );

  SearchFilters clear() => const SearchFilters();
}

class SearchState {
  final SearchFilters filters;
  final List<MonthlyLine> results;
  final bool isLoading;
  final String? error;

  const SearchState({
    this.filters  = const SearchFilters(),
    this.results  = const [],
    this.isLoading = false,
    this.error,
  });

  SearchState copyWith({
    SearchFilters? filters, List<MonthlyLine>? results,
    bool? isLoading, String? error,
  }) => SearchState(
    filters:   filters   ?? this.filters,
    results:   results   ?? this.results,
    isLoading: isLoading ?? this.isLoading,
    error:     error,
  );
}

class SearchNotifier extends StateNotifier<SearchState> {
  final IntelligenceService _svc;
  final String _userId;

  SearchNotifier(this._svc, this._userId) : super(const SearchState());

  Future<void> search() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await _svc.searchLines(
        userId:          _userId,
        fatigueLevel:    state.filters.fatigueLevel,
        hasDeadhead:     state.filters.hasDeadhead,
        isInternational: state.filters.isInternational,
        minCredit:       state.filters.minCredit,
        maxDutyHours:    state.filters.maxDutyHours,
      );
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void updateFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters);
    search();
  }

  void clearFilters() {
    state = state.copyWith(filters: const SearchFilters());
    search();
  }
}

final searchProvider =
    StateNotifierProvider.family<SearchNotifier, SearchState, String>(
  (ref, userId) =>
      SearchNotifier(ref.read(intelligenceServiceProvider), userId),
);

// ── Comparison ────────────────────────────────────────────────────────────────

class ComparisonState {
  final String? lineAId;
  final String? lineBId;
  final LineComparison? result;
  final bool isLoading;
  final String? error;

  const ComparisonState({
    this.lineAId, this.lineBId, this.result,
    this.isLoading = false, this.error,
  });

  bool get isReady => lineAId != null && lineBId != null;

  ComparisonState copyWith({
    String? lineAId, String? lineBId, LineComparison? result,
    bool? isLoading, String? error,
  }) => ComparisonState(
    lineAId:   lineAId   ?? this.lineAId,
    lineBId:   lineBId   ?? this.lineBId,
    result:    result    ?? this.result,
    isLoading: isLoading ?? this.isLoading,
    error:     error,
  );
}

class ComparisonNotifier extends StateNotifier<ComparisonState> {
  final IntelligenceService _svc;

  ComparisonNotifier(this._svc) : super(const ComparisonState());

  void selectLineA(String id) => state = state.copyWith(lineAId: id);
  void selectLineB(String id) => state = state.copyWith(lineBId: id);

  Future<void> compare() async {
    if (!state.isReady) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _svc.compareLines(state.lineAId!, state.lineBId!);
      state = state.copyWith(result: result, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reset() => state = const ComparisonState();
}

final comparisonProvider =
    StateNotifierProvider<ComparisonNotifier, ComparisonState>(
  (ref) => ComparisonNotifier(ref.read(intelligenceServiceProvider)),
);
