import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';

import '../auth/auth_provider.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────
final storageServiceProvider = Provider<StorageService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return StorageService(storage: FirebaseStorage.instance, auth: auth);
});

// ─── Upload State ─────────────────────────────────────────────────────────────
enum UploadStatus { idle, picking, uploading, processing, success, error }

class UploadState {
  final UploadStatus status;
  final double progress;       // 0.0 – 1.0
  final String? fileName;
  final String? errorMessage;
  final String? storageRef;    // path in Firebase Storage on success
  final String? month;         // detected month from filename

  const UploadState({
    this.status = UploadStatus.idle,
    this.progress = 0.0,
    this.fileName,
    this.errorMessage,
    this.storageRef,
    this.month,
  });

  UploadState copyWith({
    UploadStatus? status,
    double? progress,
    String? fileName,
    String? errorMessage,
    String? storageRef,
    String? month,
  }) => UploadState(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    fileName: fileName ?? this.fileName,
    errorMessage: errorMessage ?? this.errorMessage,
    storageRef: storageRef ?? this.storageRef,
    month: month ?? this.month,
  );

  bool get isActive =>
      status == UploadStatus.picking ||
      status == UploadStatus.uploading ||
      status == UploadStatus.processing;
}

// ─── Upload Notifier ──────────────────────────────────────────────────────────
class UploadNotifier extends StateNotifier<UploadState> {
  final StorageService _storageService;
  final String _userId;

  UploadNotifier({required StorageService storageService, required String userId})
      : _storageService = storageService,
        _userId = userId,
        super(const UploadState());

  Future<void> pickAndUpload() async {
    state = state.copyWith(status: UploadStatus.picking);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = state.copyWith(status: UploadStatus.idle);
        return;
      }

      final file = result.files.first;
      if (file.path == null) {
        state = state.copyWith(
          status: UploadStatus.error,
          errorMessage: 'Could not read file path',
        );
        return;
      }

      final fileName = file.name;
      final month = _extractMonthFromFileName(fileName);

      state = state.copyWith(
        status: UploadStatus.uploading,
        fileName: fileName,
        month: month,
        progress: 0.0,
      );

      final storageRef = await _storageService.uploadRoster(
        userId: _userId,
        filePath: file.path!,
        month: month,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );

      state = state.copyWith(
        status: UploadStatus.processing,
        storageRef: storageRef,
        progress: 1.0,
      );

      // Processing is handled by Cloud Function trigger — we just mark success
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(status: UploadStatus.success);
    } catch (e) {
      state = state.copyWith(
        status: UploadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const UploadState();

  /// Extract month string "YYYY-MM" from filename patterns like:
  /// "Roster_June_2026.xlsx", "2026-06.xlsx", "Line_2026_06.xlsx"
  String _extractMonthFromFileName(String fileName) {
    final base = path.basenameWithoutExtension(fileName);

    // Pattern: YYYY-MM
    final isoMatch = RegExp(r'(\d{4})[_\-](\d{2})').firstMatch(base);
    if (isoMatch != null) {
      return '${isoMatch.group(1)}-${isoMatch.group(2)}';
    }

    // Pattern: Month name + year (English)
    final months = {
      'january': '01', 'february': '02', 'march': '03', 'april': '04',
      'may': '05', 'june': '06', 'july': '07', 'august': '08',
      'september': '09', 'october': '10', 'november': '11', 'december': '12',
      'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
      'jun': '06', 'jul': '07', 'aug': '08', 'sep': '09',
      'oct': '10', 'nov': '11', 'dec': '12',
    };
    final lower = base.toLowerCase();
    for (final entry in months.entries) {
      if (lower.contains(entry.key)) {
        final yearMatch = RegExp(r'(\d{4})').firstMatch(base);
        if (yearMatch != null) {
          return '${yearMatch.group(1)}-${entry.value}';
        }
      }
    }

    // Default to current month
    return DateFormat('yyyy-MM').format(DateTime.now());
  }
}

final uploadProvider = StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  final storageService = ref.watch(storageServiceProvider);
  return UploadNotifier(
    storageService: storageService,
    userId: user?.uid ?? '',
  );
});

// ─── Storage Service ──────────────────────────────────────────────────────────
class StorageService {
  final FirebaseStorage _storage;
  final dynamic _auth;

  StorageService({required FirebaseStorage storage, required dynamic auth})
      : _storage = storage,
        _auth = auth;

  /// Upload a roster Excel file to Firebase Storage.
  /// Returns the storage reference path on success.
  Future<String> uploadRoster({
    required String userId,
    required String filePath,
    required String month,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    final fileSize = await file.length();
    if (fileSize > 10 * 1024 * 1024) {  // 10 MB limit
      throw Exception('File too large. Maximum size is 10 MB.');
    }

    final storageRef = 'users/$userId/rosters/$month.xlsx';
    final ref = _storage.ref(storageRef);

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        customMetadata: {
          'userId': userId,
          'month': month,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    // Track progress
    uploadTask.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      }
    });

    await uploadTask;
    return storageRef;
  }

  /// Delete a roster file from Storage
  Future<void> deleteRoster({required String userId, required String month}) async {
    final ref = _storage.ref('users/$userId/rosters/$month.xlsx');
    try {
      await ref.delete();
    } catch (_) {
      // File may not exist — ignore
    }
  }

  /// Get download URL for a stored file
  Future<String> getDownloadUrl(String storageRef) async {
    return await _storage.ref(storageRef).getDownloadURL();
  }

  /// List all uploaded rosters for a user
  Future<List<String>> listRosters(String userId) async {
    final ref = _storage.ref('users/$userId/rosters');
    final result = await ref.listAll();
    return result.items.map((item) => item.name.replaceAll('.xlsx', '')).toList();
  }
}

