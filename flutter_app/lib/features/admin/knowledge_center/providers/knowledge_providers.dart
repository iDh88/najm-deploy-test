import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/knowledge_models.dart';
import '../services/knowledge_center_service.dart';

final knowledgeCenterServiceProvider =
    Provider<KnowledgeCenterService>((_) => KnowledgeCenterService());

// ── Document list ─────────────────────────────────────────────────────────────

final documentListProvider =
    FutureProvider.family<List<KnowledgeDocument>, DocumentCategory?>(
  (ref, category) => ref
      .read(knowledgeCenterServiceProvider)
      .listDocuments(category: category),
);

final documentVersionsProvider =
    FutureProvider.family<List<DocumentVersion>, String>(
  (ref, documentId) =>
      ref.read(knowledgeCenterServiceProvider).listVersions(documentId),
);

final changeSummariesProvider =
    FutureProvider.family<List<DocumentChangeSummary>, String>(
  (ref, documentId) => ref
      .read(knowledgeCenterServiceProvider)
      .listChangeSummaries(documentId),
);

// ── Upload state ──────────────────────────────────────────────────────────────

enum UploadStatus { idle, uploading, processing, success, error }

class DocUploadState {
  final UploadStatus status;
  final String? error;
  final Map<String, dynamic>? result;

  const DocUploadState({this.status = UploadStatus.idle, this.error, this.result});

  DocUploadState copyWith({UploadStatus? status, String? error,
    Map<String, dynamic>? result}) =>
      DocUploadState(
        status: status ?? this.status,
        error: error,
        result: result ?? this.result,
      );
}

class DocUploadNotifier extends StateNotifier<DocUploadState> {
  final KnowledgeCenterService _svc;
  DocUploadNotifier(this._svc) : super(const DocUploadState());

  Future<void> uploadNew({
    required File file,
    required String name,
    required DocumentCategory category,
    required String description,
    required DateTime effectiveDate,
    DateTime? expirationDate,
  }) async {
    state = state.copyWith(status: UploadStatus.uploading, error: null);
    try {
      final result = await _svc.uploadNewDocument(
        file: file, name: name, category: category,
        description: description, effectiveDate: effectiveDate,
        expirationDate: expirationDate,
      );
      state = state.copyWith(status: UploadStatus.success, result: result);
    } catch (e) {
      state = state.copyWith(status: UploadStatus.error, error: e.toString());
    }
  }

  Future<void> uploadReplacement({
    required String documentId,
    required File file,
    required DateTime effectiveDate,
    DateTime? expirationDate,
  }) async {
    state = state.copyWith(status: UploadStatus.uploading, error: null);
    try {
      final result = await _svc.uploadNewVersion(
        documentId: documentId, file: file,
        effectiveDate: effectiveDate, expirationDate: expirationDate,
      );
      state = state.copyWith(status: UploadStatus.success, result: result);
    } catch (e) {
      state = state.copyWith(status: UploadStatus.error, error: e.toString());
    }
  }

  void reset() => state = const DocUploadState();
}

final docUploadProvider =
    StateNotifierProvider<DocUploadNotifier, DocUploadState>(
  (ref) => DocUploadNotifier(ref.read(knowledgeCenterServiceProvider)),
);

// ── Ask Operations AI chat state ──────────────────────────────────────────────

class AskChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  const AskChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  AskChatState copyWith({
    List<ChatMessage>? messages, bool? isLoading, String? error,
  }) =>
      AskChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AskChatNotifier extends StateNotifier<AskChatState> {
  final KnowledgeCenterService _svc;
  AskChatNotifier(this._svc) : super(const AskChatState());

  Future<void> send(String query, {DocumentCategory? category}) async {
    final userMsg = ChatMessage(
      text: query, isUser: true, timestamp: DateTime.now());
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

    try {
      final answer = await _svc.ask(query, category: category);
      final aiMsg = ChatMessage(
        text: answer.answer, isUser: false, answer: answer,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() => state = const AskChatState();
}

final askChatProvider =
    StateNotifierProvider<AskChatNotifier, AskChatState>(
  (ref) => AskChatNotifier(ref.read(knowledgeCenterServiceProvider)),
);
