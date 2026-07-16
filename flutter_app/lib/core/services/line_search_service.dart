import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/filter_models.dart';

/// Client for the filter-engine search surface (/v1/lines).
///
/// This is the ONLY path client code should use to search lines — Manual,
/// AI, and Hybrid mode all go through [search]; they differ only in whether
/// [SearchRequest.clauses] and/or [SearchRequest.aiInstruction] are set. The
/// server enforces the golden rule (manual filters locked, AI additive-only)
/// and returns full disclosure of what ran.
///
/// Auth/base-URL pattern matches ai_service.dart / intelligence_service.dart:
/// --dart-define=AI_SERVICE_URL host, Firebase ID-token Bearer interceptor.
class LineSearchService {
  final Dio _dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(BaseOptions(
      baseUrl: const String.fromEnvironment('AI_SERVICE_URL',
          defaultValue: 'http://localhost:8080'),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token =
              await FirebaseAuth.instance.currentUser?.getIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {}
        handler.next(options);
      },
    ));
    return dio;
  }

  /// The filter catalog — render Manual-Mode controls from this so new
  /// server-side filters appear without an app release. `requires_field`
  /// entries should render disabled with their note ("coming soon").
  Future<List<FilterCatalogEntry>> getFilterCatalog() async {
    final res = await _dio.get('/v1/lines/filters');
    final list = (res.data['filters'] as List<dynamic>? ?? const []);
    return list
        .map((e) => FilterCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One call, three modes:
  ///   Manual : clauses only
  ///   AI     : aiInstruction only
  ///   Hybrid : clauses (locked) + aiInstruction
  Future<SearchResponse> search(SearchRequest request) async {
    final res = await _dio.post('/v1/lines/search', data: request.toJson());
    return SearchResponse.fromJson(res.data as Map<String, dynamic>);
  }
}
