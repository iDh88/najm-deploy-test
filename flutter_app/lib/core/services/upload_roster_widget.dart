import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'storage_service.dart';

/// Reusable upload widget — shows progress, handles state transitions,
/// and notifies parent on success. Use on the Lines screen upload card.
class UploadRosterWidget extends ConsumerWidget {
  final VoidCallback? onSuccess;

  const UploadRosterWidget({super.key, this.onSuccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadProvider);

    ref.listen(uploadProvider, (_, next) {
      if (next.status == UploadStatus.success) {
        onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Roster uploaded: ${next.fileName ?? ""}'),
            backgroundColor: CIPTheme.legalGreen,
          ),
        );
        Future.delayed(const Duration(seconds: 2), () {
          ref.read(uploadProvider.notifier).reset();
        });
      } else if (next.status == UploadStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage ?? 'Upload failed'),
            backgroundColor: CIPTheme.violationRed,
          ),
        );
      }
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        children: [
          _buildIcon(uploadState.status),
          const SizedBox(height: 12),
          _buildTitle(uploadState),
          const SizedBox(height: 4),
          _buildSubtitle(uploadState),

          // Progress bar during upload
          if (uploadState.status == UploadStatus.uploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: uploadState.progress,
                backgroundColor: CIPTheme.grey100,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  CIPTheme.saudiNavy,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(uploadState.progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: CIPTheme.grey500),
            ),
          ],

          // Processing spinner
          if (uploadState.status == UploadStatus.processing)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CIPTheme.saudiNavy,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Analysing flight lines...',
                    style: TextStyle(fontSize: 13, color: CIPTheme.grey500),
                  ),
                ],
              ),
            ),

          // Upload button (idle or success/error states)
          if (!uploadState.isActive) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(uploadProvider.notifier).pickAndUpload(),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Select Excel Roster'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supported: .xlsx, .xls · Max 10 MB',
              style: TextStyle(fontSize: 11, color: CIPTheme.grey500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon(UploadStatus status) {
    return switch (status) {
      UploadStatus.success =>
        const Icon(Icons.check_circle, color: CIPTheme.legalGreen, size: 48),
      UploadStatus.error =>
        const Icon(Icons.error_outline, color: CIPTheme.violationRed, size: 48),
      UploadStatus.uploading =>
        const Icon(Icons.cloud_upload_outlined, color: CIPTheme.saudiNavy, size: 48),
      UploadStatus.processing =>
        const Icon(Icons.analytics_outlined, color: CIPTheme.saudiGold, size: 48),
      _ =>
        const Icon(Icons.upload_file_outlined, color: CIPTheme.grey500, size: 48),
    };
  }

  Widget _buildTitle(UploadState state) {
    final text = switch (state.status) {
      UploadStatus.picking    => 'Selecting file...',
      UploadStatus.uploading  => 'Uploading ${state.fileName ?? ""}',
      UploadStatus.processing => 'Processing roster...',
      UploadStatus.success    => 'Upload complete ✓',
      UploadStatus.error      => 'Upload failed',
      UploadStatus.idle       => 'Upload Monthly Roster',
    };
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
    );
  }

  Widget _buildSubtitle(UploadState state) {
    final text = switch (state.status) {
      UploadStatus.processing => 'Extracting flight lines and checking legality',
      UploadStatus.success    => 'Month: ${state.month ?? ""}',
      UploadStatus.error      => state.errorMessage ?? 'Please try again',
      _                       => 'Upload your monthly roster Excel file',
    };
    return Text(
      text,
      style: const TextStyle(color: CIPTheme.grey500, fontSize: 12),
      textAlign: TextAlign.center,
    );
  }
}
