import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Client for GET /v1/ai/status — the Profile "AI Status" card.
///
/// Every field here has a real server-side source (see
/// python_services/ai/status_router.py). Notably absent: daily AI usage —
/// that already lives in the subscription service and the app already has
/// `usageStatusProvider`. Duplicating it would create a second source of
/// truth for a billing-adjacent number.

class AiEngine {
  final String engine;
  final String trigger; // triggered | queued | on_demand

  const AiEngine({required this.engine, required this.trigger});

  /// "bid_recommendation_engine" → "Bid Recommendation"
  String get displayName => label;

  String get label {
    final words = engine
        .replaceAll('_engine', '')
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return words;
  }

  factory AiEngine.fromJson(Map<String, dynamic> j) => AiEngine(
        engine: j['engine'] ?? '',
        trigger: j['trigger'] ?? '',
      );
}

class KnowledgeBaseStatus {
  final bool available;
  final int documents;
  final int documentsDisabled;
  final int? latestVersion;

  /// Null when the knowledge base is empty — the UI must show "—", never a
  /// fabricated "updated today".
  final DateTime? lastUpdated;

  const KnowledgeBaseStatus({
    required this.available,
    required this.documents,
    this.documentsDisabled = 0,
    this.latestVersion,
    this.lastUpdated,
  });

  factory KnowledgeBaseStatus.fromJson(Map<String, dynamic> j) =>
      KnowledgeBaseStatus(
        available: j['available'] == true,
        documents: (j['documents'] ?? 0) as int,
        documentsDisabled: (j['documents_disabled'] ?? 0) as int,
        latestVersion: j['latest_version'] as int?,
        lastUpdated: j['last_updated'] == null
            ? null
            : DateTime.tryParse(j['last_updated'].toString()),
      );
}

class AiStatus {
  final String status; // online | unconfigured
  final String statusDetail;
  final String provider;
  final String model;
  final String serviceVersion;
  final List<AiEngine> engines;
  final KnowledgeBaseStatus knowledgeBase;

  const AiStatus({
    required this.status,
    required this.statusDetail,
    required this.provider,
    required this.model,
    required this.serviceVersion,
    required this.engines,
    required this.knowledgeBase,
  });

  bool get isOnline => status == 'online';

  factory AiStatus.fromJson(Map<String, dynamic> j) => AiStatus(
        status: j['status'] ?? 'unconfigured',
        statusDetail: j['status_detail'] ?? '',
        provider: j['provider'] ?? '',
        model: j['model'] ?? '',
        serviceVersion: j['service_version'] ?? '',
        engines: (j['engines'] as List<dynamic>? ?? const [])
            .map((e) => AiEngine.fromJson(e as Map<String, dynamic>))
            .toList(),
        knowledgeBase: KnowledgeBaseStatus.fromJson(
            j['knowledge_base'] as Map<String, dynamic>? ?? const {}),
      );
}

class AiStatusService {
  final Dio _dio;

  AiStatusService({Dio? dio}) : _dio = dio ?? _buildDio();

  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: const String.fromEnvironment('AI_SERVICE_URL',
          defaultValue: 'http://localhost:8080'),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
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

  Future<AiStatus> getStatus() async {
    final res = await _dio.get('/v1/ai/status');
    return AiStatus.fromJson(res.data as Map<String, dynamic>);
  }
}
