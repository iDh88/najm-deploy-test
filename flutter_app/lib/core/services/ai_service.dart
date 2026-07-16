import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../models/models.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final aiServiceProvider = Provider<AIService>((ref) {
  final dio = ref.watch(_dioProvider);
  return AIService(dio: dio);
});

final _dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('AI_SERVICE_URL',
        defaultValue: 'https://cip-ai-service-xxxx-uc.a.run.app'),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      if (const String.fromEnvironment('AI_SERVICE_TOKEN').isNotEmpty)
        'Authorization': 'Bearer ${const String.fromEnvironment('AI_SERVICE_TOKEN')}',
    },
  ));

  // Auth interceptor — inject Firebase ID token
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      try {
        final auth = ref.read(firebaseAuthProvider);
        final token = await auth.currentUser?.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {}
      handler.next(options);
    },
  ));

  return dio;
});

// ─── Response Models ──────────────────────────────────────────────────────────
class AIResponse {
  final String text;
  final String intentType;
  final int responseTimeMs;
  final FlightLine? lineCard;
  final LegalityResult? legalityCard;
  final List<RankedLine> rankedLines;

  const AIResponse({
    required this.text,
    required this.intentType,
    required this.responseTimeMs,
    this.lineCard,
    this.legalityCard,
    this.rankedLines = const [],
  });
}

class LegalityCheckResponse {
  final bool passed;
  final LegalityResult initiatorResult;
  final LegalityResult receiverResult;

  const LegalityCheckResponse({
    required this.passed,
    required this.initiatorResult,
    required this.receiverResult,
  });
}

class RankingResponse {
  final List<RankedLine> lines;
  const RankingResponse({required this.lines});
}

// ─── AI Service ───────────────────────────────────────────────────────────────
class AIService {
  final Dio _dio;

  AIService({required Dio dio}) : _dio = dio;

  // ── Chat with Najm assistant ───────────────────────────────────────────────
  Future<AIResponse> chat({
    required String userId,
    required String message,
    required List<AIMessage> history,
    String? activeMonth,
    String? activeLineId,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post('/v1/ai/chat', data: {
        'userId': userId,
        'message': message,
        'history': history.map((m) => {
          'role': m.role,
          'content': m.content,
          'timestamp': m.timestamp.toIso8601String(),
        }).toList(),
        'context': {
          'activeMonth': activeMonth,
          'activeLineId': activeLineId,
        },
      });

      stopwatch.stop();
      final data = response.data as Map<String, dynamic>;

      return AIResponse(
        text: data['text'] as String? ?? 'Sorry, I could not process that request.',
        intentType: data['intentType'] as String? ?? 'unknown',
        responseTimeMs: stopwatch.elapsedMilliseconds,
        legalityCard: data['legalityCard'] != null
            ? _parseLegalityResult(data['legalityCard'] as Map<String, dynamic>)
            : null,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      final errorMsg = _parseDioError(e);
      return AIResponse(
        text: errorMsg,
        intentType: 'error',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ── Check legality for a trade ─────────────────────────────────────────────
  Future<LegalityCheckResponse> checkTradeLegality({
    required String initiatorId,
    required String receiverId,
    required String offeredLegId,
    required String requestedLegId,
  }) async {
    try {
      final response = await _dio.post('/v1/legality/check-trade', data: {
        'initiatorId': initiatorId,
        'receiverId': receiverId,
        'offeredLegId': offeredLegId,
        'requestedLegId': requestedLegId,
      });

      final data = response.data as Map<String, dynamic>;
      return LegalityCheckResponse(
        passed: data['passed'] as bool? ?? false,
        initiatorResult: _parseLegalityResult(data['initiatorResult'] as Map<String, dynamic>? ?? {}),
        receiverResult: _parseLegalityResult(data['receiverResult'] as Map<String, dynamic>? ?? {}),
      );
    } on DioException catch (e) {
      throw Exception('Legality check failed: ${_parseDioError(e)}');
    }
  }

  // ── Check legality for a bid ───────────────────────────────────────────────
  Future<LegalityResult> checkBidLegality({
    required String userId,
    required String lineId,
  }) async {
    try {
      final response = await _dio.post('/v1/legality/check-bid', data: {
        'userId': userId,
        'lineId': lineId,
      });
      return _parseLegalityResult(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Legality check failed: ${_parseDioError(e)}');
    }
  }

  // ── Get ranked lines for user ──────────────────────────────────────────────
  Future<List<RankedLine>> getRankedLines({
    required String userId,
    required String month,
    required String userMode,
  }) async {
    try {
      final response = await _dio.post('/v1/ranking/rank', data: {
        'userId': userId,
        'month': month,
        'userMode': userMode,
      });

      final data = response.data as Map<String, dynamic>;
      final items = data['rankedLines'] as List<dynamic>? ?? [];
      return items.map((item) => _parseRankedLine(item as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Ranking failed: ${_parseDioError(e)}');
    }
  }

  // ── Get auto-bid suggestions ───────────────────────────────────────────────
  Future<List<BidSuggestionResult>> getAutoBidSuggestions({
    required String userId,
    required String month,
    required String userMode,
  }) async {
    try {
      final response = await _dio.post('/v1/auto-bid/suggest', data: {
        'userId': userId,
        'month': month,
        'userMode': userMode,
      });

      final data = response.data as Map<String, dynamic>;
      final items = data['suggestions'] as List<dynamic>? ?? [];
      return items.map((item) {
        final m = item as Map<String, dynamic>;
        return BidSuggestionResult(
          lineId: m['lineId'] as String,
          lineNumber: m['lineNumber'] as String,
          compositeScore: (m['compositeScore'] as num).toDouble(),
          reasons: (m['reasons'] as List<dynamic>).cast<String>(),
          reasonsAr: (m['reasonsAr'] as List<dynamic>).cast<String>(),
          estimatedSalary: (m['estimatedSalary'] as num).toDouble(),
          isLegal: m['isLegal'] as bool? ?? true,
        );
      }).toList();
    } on DioException catch (e) {
      throw Exception('Auto-bid suggestions failed: ${_parseDioError(e)}');
    }
  }

  // ── Log behavior event ─────────────────────────────────────────────────────
  Future<void> logBehaviorEvent({
    required String userId,
    required String eventType,
    required Map<String, dynamic> metadata,
    String userMode = 'balanced',
  }) async {
    try {
      await _dio.post('/v1/auto-bid/update-preference', data: {
        'userId': userId,
        'eventType': eventType,
        'metadata': metadata,
        'userMode': userMode,
      });
    } catch (_) {
      // Silently fail — behavior logging should never block UX
    }
  }

  // ── Parse utilities ────────────────────────────────────────────────────────
  LegalityResult _parseLegalityResult(Map<String, dynamic> data) {
    List<LegalityViolation> parseViolations(dynamic list) {
      if (list == null) return [];
      return (list as List<dynamic>).map((v) {
        final m = v as Map<String, dynamic>;
        return LegalityViolation(
          ruleId: m['ruleId'] as String? ?? '',
          ruleDescription: m['ruleDescription'] as String? ?? '',
          ruleDescriptionAr: m['ruleDescriptionAr'] as String? ?? '',
          actualValue: (m['actualValue'] as num?)?.toDouble() ?? 0,
          requiredValue: (m['requiredValue'] as num?)?.toDouble() ?? 0,
          unit: m['unit'] as String? ?? 'hours',
          severity: m['severity'] == 'warning'
              ? LegalitySeverity.warning : LegalitySeverity.blocking,
          affectedLegIds: (m['affectedLegIds'] as List<dynamic>?)?.cast<String>() ?? [],
        );
      }).toList();
    }

    return LegalityResult(
      passed: data['passed'] as bool? ?? true,
      violations: parseViolations(data['violations']),
      warnings: parseViolations(data['warnings']),
    );
  }

  RankedLine _parseRankedLine(Map<String, dynamic> data) {
    return RankedLine(
      line: FlightLine(
        id: data['lineId'] as String? ?? '',
        lineNumber: data['lineNumber'] as String? ?? '',
        month: data['month'] as String? ?? '',
        userId: '',
        uploadedAt: DateTime.now(),
        summary: LineSummary(
          compositeScore: (data['compositeScore'] as num?)?.toDouble() ?? 0,
          salaryScore: (data['salaryScore'] as num?)?.toDouble() ?? 0,
          restQualityScore: (data['restScore'] as num?)?.toDouble() ?? 0,
          estimatedSalaryMax: (data['estimatedSalary'] as num?)?.toDouble() ?? 0,
        ),
      ),
      compositeScore: (data['compositeScore'] as num?)?.toDouble() ?? 0,
      salaryScore: (data['salaryScore'] as num?)?.toDouble() ?? 0,
      restScore: (data['restScore'] as num?)?.toDouble() ?? 0,
      rank: data['rank'] as int? ?? 0,
      explanation: data['explanation'] as String? ?? '',
      explanationAr: data['explanationAr'] as String? ?? '',
    );
  }

  String _parseDioError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('detail')) return data['detail'].toString();
    }
    if (e.type == DioExceptionType.connectionTimeout) return 'Connection timed out. Please try again.';
    if (e.type == DioExceptionType.receiveTimeout) return 'Request took too long. Please try again.';
    return 'Network error. Please check your connection.';
  }
}

// ─── Supporting types ─────────────────────────────────────────────────────────
class BidSuggestionResult {
  final String lineId;
  final String lineNumber;
  final double compositeScore;
  final List<String> reasons;
  final List<String> reasonsAr;
  final double estimatedSalary;
  final bool isLegal;

  const BidSuggestionResult({
    required this.lineId,
    required this.lineNumber,
    required this.compositeScore,
    required this.reasons,
    required this.reasonsAr,
    required this.estimatedSalary,
    required this.isLegal,
  });
}
