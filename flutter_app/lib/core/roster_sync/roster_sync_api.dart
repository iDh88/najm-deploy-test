import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'sync_models.dart';

/// HTTP client for /v1/roster-sync — the only path device sync code uses to
/// talk to the backend. Auth/base-URL pattern matches the platform's other
/// service clients (AI_SERVICE_URL dart-define + Firebase ID-token Bearer).
///
/// NOTE: no method on this client accepts credentials. Connection creation
/// (POST /connections) carries only provider_id + non-sensitive client_meta;
/// the server independently rejects credential-shaped keys in any payload.
class RosterSyncApi {
  final Dio _dio;

  RosterSyncApi({Dio? dio}) : _dio = dio ?? _buildDio();

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

  Future<List<ProviderInfo>> getProviders() async {
    final res = await _dio.get('/v1/roster-sync/providers');
    return (res.data['providers'] as List<dynamic>? ?? const [])
        .map((e) => ProviderInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Registers the connection server-side (status tracking only).
  Future<Map<String, dynamic>> registerConnection(String providerId,
      {Map<String, dynamic> clientMeta = const {}}) async {
    final res = await _dio.post('/v1/roster-sync/connections', data: {
      'provider_id': providerId,
      'client_meta': clientMeta,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> deleteConnection(String providerId) async {
    await _dio.delete('/v1/roster-sync/connections/$providerId');
  }

  Future<Map<String, dynamic>> syncNow(String providerId) async {
    final res =
        await _dio.post('/v1/roster-sync/connections/$providerId/sync-now');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<ImportResult> importRoster(
      String providerId, RosterPayload payload) async {
    final res = await _dio.post('/v1/roster-sync/import', data: {
      'provider_id': providerId,
      'period': payload.period,
      'year': payload.year,
      'payload_kind': payload.kind,
      'payload': payload.payload,
    });
    return ImportResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<SyncStatus> getStatus() async {
    final res = await _dio.get('/v1/roster-sync/status');
    return SyncStatus.fromJson(res.data as Map<String, dynamic>);
  }
}
