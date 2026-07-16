import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../models/knowledge_models.dart';
import '../providers/knowledge_providers.dart';
import '../widgets/knowledge_widgets.dart';

class KnowledgeCenterScreen extends ConsumerStatefulWidget {
  const KnowledgeCenterScreen({super.key});

  @override
  ConsumerState<KnowledgeCenterScreen> createState() =>
      _KnowledgeCenterScreenState();
}

class _KnowledgeCenterScreenState
    extends ConsumerState<KnowledgeCenterScreen> {
  DocumentCategory? _category;

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentListProvider(_category));

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Knowledge Center',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: CategoryFilterBar(
              selected: _category,
              onChanged: (c) => setState(() => _category = c),
            ),
          ),
          Expanded(
            child: docsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: CIPTheme.primary)),
              error: (e, _) => Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(e.toString(),
                    style: const TextStyle(color: CIPTheme.error),
                    textAlign: TextAlign.center),
              )),
              data: (docs) {
                if (docs.isEmpty) {
                  return const _EmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => DocumentCard(
                    document: docs[i],
                    index: i,
                    onTap: () => context.push(
                        '/admin/knowledge/${docs[i].id}'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/knowledge/upload'),
        backgroundColor: CIPTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Document',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📚', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('No documents yet',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Upload operational manuals, policies, and bulletins\n'
              'to power the Najm AI assistant.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
