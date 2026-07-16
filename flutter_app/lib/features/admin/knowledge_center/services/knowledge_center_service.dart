import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/constants/constants.dart';
import '../models/knowledge_models.dart';

class KnowledgeCenterService {
  final _dio = Dio(BaseOptions(baseUrl: AppConfig.aiServiceUrl));

  Future<Map<String, String>> _authHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {'Authorization': 'Bearer $token'};
  }

  // ── Admin: Upload ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> uploadNewDocument({
    required File file,
    required String name,
    required DocumentCategory category,
    required String description,
    required DateTime effectiveDate,
    DateTime? expirationDate,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
          filename: file.path.split('/').last),
      'name': name,
      'category': category.apiValue,
      'description': description,
      'effective_date': effectiveDate.toIso8601String(),
      if (expirationDate != null)
        'expiration_date': expirationDate.toIso8601String(),
    });

    final res = await _dio.post(
      '/v1/knowledge/documents',
      data: form,
      options: Options(headers: await _authHeaders()),
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> uploadNewVersion({
    required String documentId,
    required File file,
    required DateTime effectiveDate,
    DateTime? expirationDate,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path,
          filename: file.path.split('/').last),
      'effective_date': effectiveDate.toIso8601String(),
      if (expirationDate != null)
        'expiration_date': expirationDate.toIso8601String(),
    });

    final res = await _dio.post(
      '/v1/knowledge/documents/$documentId/versions',
      data: form,
      options: Options(headers: await _authHeaders()),
    );
    return Map<String, dynamic>.from(res.data);
  }

  // ── Admin: List / Manage ─────────────────────────────────────────────────────

  Future<List<KnowledgeDocument>> listDocuments({
    DocumentCategory? category,
  }) async {
    final res = await _dio.get(
      '/v1/knowledge/documents',
      queryParameters: category != null ? {'category': category.apiValue} : null,
      options: Options(headers: await _authHeaders()),
    );
    return (res.data as List)
        .map((m) => KnowledgeDocument.fromMap(m['id'], Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<DocumentVersion>> listVersions(String documentId) async {
    final res = await _dio.get(
      '/v1/knowledge/documents/$documentId/versions',
      options: Options(headers: await _authHeaders()),
    );
    return (res.data as List)
        .map((m) => DocumentVersion.fromMap(m['id'], Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<List<DocumentChangeSummary>> listChangeSummaries(
      String documentId) async {
    final res = await _dio.get(
      '/v1/knowledge/documents/$documentId/changes',
      options: Options(headers: await _authHeaders()),
    );
    return (res.data as List)
        .map((m) => DocumentChangeSummary.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> disableDocument(String documentId) async {
    await _dio.patch(
      '/v1/knowledge/documents/$documentId/disable',
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<void> enableDocument(String documentId) async {
    await _dio.patch(
      '/v1/knowledge/documents/$documentId/enable',
      options: Options(headers: await _authHeaders()),
    );
  }

  Future<String> getAdminDownloadUrl(
      String documentId, String versionId) async {
    final res = await _dio.get(
      '/v1/knowledge/documents/$documentId/versions/$versionId/download-url',
      options: Options(headers: await _authHeaders()),
    );
    return res.data['url'] as String;
  }

  // ── User-facing: Ask Operations AI ───────────────────────────────────────────

  Future<AskAnswer> ask(String query, {DocumentCategory? category}) async {
    final res = await _dio.post('/v1/knowledge/ask', data: {
      'query': query,
      if (category != null) 'category': category.apiValue,
    });
    return AskAnswer.fromMap(Map<String, dynamic>.from(res.data));
  }

  Future<List<String>> listCategories() async {
    final res = await _dio.get('/v1/knowledge/categories');
    return List<String>.from(res.data);
  }
}
