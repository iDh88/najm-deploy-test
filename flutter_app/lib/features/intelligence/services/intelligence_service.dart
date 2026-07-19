import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/intelligence_models.dart';

class IntelligenceService {
  final _db = FirebaseFirestore.instance;

  // Same base URL contract as core/services/ai_service.dart: the Python
  // service host comes from --dart-define=AI_SERVICE_URL (see .env.example),
  // never a hardcoded host. The previous value ('http://localhost:8000') was
  // unreachable in every environment — wrong port (service listens on 8080),
  // no production host, and requests carried NO Authorization header, so the
  // server's verify_service_or_user dependency rejected every call with 401.
  final Dio _dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: const String.fromEnvironment('AI_SERVICE_URL',
          defaultValue: 'http://localhost:8080'),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await FirebaseAuth.instance.currentUser?.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        handler.next(options);
      },
    ));
    return dio;
  }

  // ── Upload ──────────────────────────────────────────────────────────────────

  Future<String> uploadPDF({
    required String filePath,
    required String userId,
    required String period,
    required int year,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'schedule.pdf'),
    });
    final res = await _dio.post(
      '/v1/intelligence/upload',
      data: form,
      queryParameters: {'user_id': userId, 'period': period, 'year': year},
    );
    return res.data['uploadId'] as String;
  }

  Future<Map<String, dynamic>> getUploadStatus(String uploadId) async {
    final res = await _dio.get('/v1/intelligence/upload/$uploadId/status');
    return Map<String, dynamic>.from(res.data);
  }

  // ── Lines ───────────────────────────────────────────────────────────────────

  Stream<List<MonthlyLine>> userLinesStream(String userId) {
    return _db.collection('flightLines').snapshots().map((s) {
      final lines = s.docs
          .map((d) => _monthlyLineFromFlightLine(
                d.id,
                Map<String, dynamic>.from(d.data()),
              ))
          .toList();

      lines.sort((a, b) {
        final an = int.tryParse(a.lineNumber) ?? 0;
        final bn = int.tryParse(b.lineNumber) ?? 0;
        return an.compareTo(bn);
      });

      return lines;
    });
  }

  Future<MonthlyLine?> getLine(String lineId) async {
    final doc = await _db.collection('flightLines').doc(lineId).get();
    if (!doc.exists) return null;
    return _monthlyLineFromFlightLine(
      doc.id,
      Map<String, dynamic>.from(doc.data()!),
    );
  }

  MonthlyLine _monthlyLineFromFlightLine(String docId, Map<String, dynamic> m) {
    final rawSummary = Map<String, dynamic>.from(m['summary'] ?? {});
    final destinations = List<String>.from(m['destinations'] ?? []);
    final daysOff = List.from(m['daysOff'] ?? []);
    final uploadedAt = m['uploadedAt'];
    final createdAt =
        uploadedAt is Timestamp ? uploadedAt.toDate() : DateTime.now();

    final blockHours = (rawSummary['totalBlockHours'] as num?)?.toDouble() ??
        (m['blockHours'] as num?)?.toDouble() ??
        0.0;
    final dutyHours = (rawSummary['totalDutyHours'] as num?)?.toDouble() ??
        (m['creditHours'] as num?)?.toDouble() ??
        0.0;
    final totalLegs = (rawSummary['totalLegs'] as num?)?.toInt() ??
        (m['totalLegs'] as num?)?.toInt() ??
        0;

    return MonthlyLine.fromFirestore(docId, {
      'lineNumber': m['lineNumber']?.toString() ?? docId,
      'period': m['month'] ?? '',
      'userId': m['userId'] ?? 'global',
      'createdAt': Timestamp.fromDate(createdAt),
      'summary': {
        'blockHours': blockHours,
        'dutyHours': dutyHours,
        'deadheadHours': 0.0,
        'totalPairings': totalLegs,
        'operatingLegs': totalLegs,
        'deadheadLegs': 0,
        'offDays': daysOff.length,
        'openDays': 31 - daysOff.length,
        'estimatedCredit': dutyHours,
        'estimatedPerDiem': 0.0,
        'uniqueDestinations': destinations,
        'internationalCount':
            rawSummary['internationalLegs'] ?? destinations.length,
        'domesticCount': rawSummary['domesticLegs'] ?? 0,
      },
      'classification': {
        'isInternational': destinations.isNotEmpty,
        'hasDeadhead': false,
        'routeType': 'mixed',
        'tags': destinations,
      },
      'fatigueProfile': {
        'overallLevel': 'low',
        'score': 0,
        'riskFactors': [],
      },
      'insights': [],
    });
  }

  Future<List<Pairing>> getPairings(String lineId) async {
    final snap = await _db
        .collection('pairings')
        .where('lineId', isEqualTo: lineId)
        .get();
    return snap.docs
        .map((d) =>
            Pairing.fromFirestore(d.id, Map<String, dynamic>.from(d.data())))
        .toList();
  }

  Future<List<FatiguePoint>> getFatigueTimeline(String lineId) async {
    final snap = await _db
        .collection('monthly_lines')
        .doc(lineId)
        .collection('timeline')
        .orderBy('day')
        .get();
    return snap.docs
        .map((d) => FatiguePoint.fromMap(Map<String, dynamic>.from(d.data())))
        .toList();
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  Future<List<MonthlyLine>> searchLines({
    required String userId,
    String? fatigueLevel,
    bool? hasDeadhead,
    bool? isInternational,
    double? minCredit,
    double? maxDutyHours,
    String? period,
    int limit = 20,
  }) async {
    final res = await _dio.get('/v1/intelligence/search', queryParameters: {
      'user_id': userId,
      if (fatigueLevel != null) 'fatigue_level': fatigueLevel,
      if (hasDeadhead != null) 'has_deadhead': hasDeadhead,
      if (isInternational != null) 'is_international': isInternational,
      if (minCredit != null) 'min_credit': minCredit,
      if (maxDutyHours != null) 'max_duty_hours': maxDutyHours,
      if (period != null) 'period': period,
      'limit': limit,
    });
    return (res.data as List)
        .map((m) => MonthlyLine.fromFirestore(
            m['lineNumber'] ?? '', Map<String, dynamic>.from(m)))
        .toList();
  }

  // ── Compare ─────────────────────────────────────────────────────────────────

  Future<LineComparison> compareLines(String lineAId, String lineBId) async {
    final res = await _dio.post('/v1/intelligence/compare', data: {
      'line_a_id': lineAId,
      'line_b_id': lineBId,
    });
    return LineComparison.fromMap(Map<String, dynamic>.from(res.data));
  }
}
