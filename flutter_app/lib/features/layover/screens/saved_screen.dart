// Saved Places — the user's bookmarked layover recommendations.
//
// F30: this was a static placeholder ("Your saved spots") with no data,
// no route, and no entry point, while the save/bookmark write-path
// (LayoverService.toggleSave → userSaves/{uid}_{recId}) was fully live.
// It now lists the user's saves newest-first, reusing RecommendationCard
// so like/save/rating behavior is identical to the city hub.
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/recommendation.dart';
import '../services/layover_service.dart';
import '../widgets/recommendation_card.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final _service = LayoverService();
  late Future<List<Recommendation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getSavedRecommendations();
  }

  Future<void> _refresh() async {
    final fresh = _service.getSavedRecommendations();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navyMid,
        title: const Text('Saved Places'),
      ),
      body: FutureBuilder<List<Recommendation>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: NajmTheme.gold));
          }
          if (snap.hasError) {
            return _ErrorState(
                message: snap.error.toString(), onRetry: _refresh);
          }
          final recs = snap.data ?? const [];
          if (recs.isEmpty) return _EmptyState(onRefresh: _refresh);

          return RefreshIndicator(
            color: NajmTheme.gold,
            backgroundColor: NajmTheme.navyMid,
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: recs.length,
              itemBuilder: (context, i) => RecommendationCard(
                recommendation: recs[i],
                index: i,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    // Wrapped in a scrollable so pull-to-refresh works on the empty state.
    return RefreshIndicator(
      color: NajmTheme.gold,
      backgroundColor: NajmTheme.navyMid,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🔖', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 16),
                  Text(
                    'Your saved spots',
                    style: TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Bookmark recommendations to access\nthem quickly during your layover.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: NajmTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: NajmTheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Couldn\'t load your saved places.\n$message',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: NajmTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: NajmTheme.gold,
                side: const BorderSide(color: NajmTheme.gold),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
