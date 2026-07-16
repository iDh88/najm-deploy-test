import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme.dart';
import '../models/knowledge_models.dart';
import '../providers/knowledge_providers.dart';
import '../widgets/knowledge_widgets.dart';

class DocumentDetailScreen extends ConsumerStatefulWidget {
  final String documentId;
  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final versionsAsync = ref.watch(documentVersionsProvider(widget.documentId));
    final changesAsync  = ref.watch(changeSummariesProvider(widget.documentId));

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Document History',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: CIPTheme.primary,
          labelColor: CIPTheme.primary,
          unselectedLabelColor: CIPTheme.textMuted,
          tabs: const [
            Tab(text: 'Versions'),
            Tab(text: 'Change History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ── Versions tab ──────────────────────────────────────────────
          versionsAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: CIPTheme.primary)),
            error: (e, _) => Center(child: Text(e.toString(),
                style: const TextStyle(color: CIPTheme.error))),
            data: (versions) {
              if (versions.isEmpty) {
                return const Center(
                    child: Text('No versions found',
                        style: TextStyle(color: CIPTheme.textSecondary)));
              }
              final activeId = versions
                  .firstWhere((v) => v.status == DocumentStatus.active,
                      orElse: () => versions.first)
                  .id;
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: versions.length,
                itemBuilder: (_, i) => VersionTile(
                  version: versions[i],
                  isActive: versions[i].id == activeId,
                  onDownload: () => _downloadVersion(versions[i].id),
                ),
              );
            },
          ),

          // ── Change history tab ────────────────────────────────────────
          changesAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: CIPTheme.primary)),
            error: (e, _) => Center(child: Text(e.toString(),
                style: const TextStyle(color: CIPTheme.error))),
            data: (summaries) {
              if (summaries.isEmpty) {
                return const Center(
                    child: Text('No version changes recorded yet',
                        style: TextStyle(color: CIPTheme.textSecondary)));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: summaries.length,
                itemBuilder: (_, i) =>
                    ChangeSummaryCard(summary: summaries[i]),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/admin/knowledge/upload?replace=${widget.documentId}',
        ),
        backgroundColor: CIPTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload New Version',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _downloadVersion(String versionId) async {
    try {
      final url = await ref
          .read(knowledgeCenterServiceProvider)
          .getAdminDownloadUrl(widget.documentId, versionId);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }
}
