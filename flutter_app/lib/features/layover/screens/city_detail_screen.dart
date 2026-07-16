import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../models/recommendation.dart';
import '../services/layover_service.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/category_tab_bar.dart';
import '../widgets/filter_bar.dart';

class CityDetailScreen extends StatefulWidget {
  final String cityId;
  final String? initialTab;
  const CityDetailScreen({super.key, required this.cityId, this.initialTab});

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = LayoverService();
  String _sortBy = 'Trending';
  bool _halalOnly = false;
  bool _openNow = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  static const _tabs = [
    LayoverCategory(id: 'all',          label: 'All',            icon: '🌐'),
    ...AppConstants.layoverCategories,
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab != null) {
      initialIndex = _tabs.indexWhere((t) => t.id == widget.initialTab);
      if (initialIndex < 0) initialIndex = 0;
    }
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String get _activeCategory {
    final idx = _tabController.index;
    return _tabs[idx].id;
  }

  @override
  Widget build(BuildContext context) {
    // City display info from seed data
    final cityInfo = _cityInfo(widget.cityId);

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          // ── App Bar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: NajmTheme.navyMid,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: NajmTheme.textPrimary),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: NajmTheme.gold),
                onPressed: () => context.push(
                  '/layover/${widget.cityId}/add?category=$_activeCategory',
                ),
                tooltip: 'Add Recommendation',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cityInfo['name']!,
                    style: const TextStyle(
                      color: NajmTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${cityInfo['emoji']} ${cityInfo['country']}  ·  ${widget.cityId}',
                    style: const TextStyle(
                      color: NajmTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [NajmTheme.navyMid, NajmTheme.navy],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 20,
                      top: 40,
                      child: Text(
                        cityInfo['emoji']!,
                        style: const TextStyle(fontSize: 100),
                      ),
                    ),
                    // Popular this month badge
                    Positioned(
                      left: 16,
                      top: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: NajmTheme.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: NajmTheme.gold.withOpacity(0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.trending_up,
                                color: NajmTheme.gold, size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Most Popular This Month',
                              style: TextStyle(
                                color: NajmTheme.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Search Bar ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: NajmTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, budget, distance…',
                  prefixIcon:
                      const Icon(Icons.search, color: NajmTheme.textMuted, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: NajmTheme.textMuted, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                ),
              ),
            ),
          ),

          // ── Tabs ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: CategoryTabBar(
              tabs: _tabs,
              controller: _tabController,
              onTabChanged: (_) => setState(() {}),
            ),
          ),

          // ── Filter Bar ───────────────────────────────────
          SliverToBoxAdapter(
            child: FilterBar(
              sortBy: _sortBy,
              halalOnly: _halalOnly,
              openNow: _openNow,
              onSortChanged: (v) => setState(() => _sortBy = v),
              onHalalChanged: (v) => setState(() => _halalOnly = v),
              onOpenNowChanged: (v) => setState(() => _openNow = v),
            ),
          ),
        ],

        // ── Content ───────────────────────────────────────
        body: TabBarView(
          controller: _tabController,
          children: _tabs.map((tab) {
            return _CategoryList(
              cityId: widget.cityId,
              category: tab.id,
              sortBy: _sortBy,
              halalOnly: _halalOnly,
              searchQuery: _searchQuery,
              service: _service,
            );
          }).toList(),
        ),
      ),

      // ── FAB ───────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/layover/${widget.cityId}/add?category=$_activeCategory',
        ),
        backgroundColor: NajmTheme.gold,
        foregroundColor: NajmTheme.navy,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Spot',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Map<String, String> _cityInfo(String code) {
    const cities = {
      'CAI': {'name': 'Cairo',        'country': 'Egypt',       'emoji': '🏺'},
      'IST': {'name': 'Istanbul',     'country': 'Turkey',      'emoji': '🕌'},
      'KUL': {'name': 'Kuala Lumpur', 'country': 'Malaysia',    'emoji': '🏙️'},
      'DXB': {'name': 'Dubai',        'country': 'UAE',         'emoji': '🌆'},
      'LHR': {'name': 'London',       'country': 'UK',          'emoji': '🎡'},
      'CDG': {'name': 'Paris',        'country': 'France',      'emoji': '🗼'},
      'JFK': {'name': 'New York',     'country': 'USA',         'emoji': '🗽'},
      'SIN': {'name': 'Singapore',    'country': 'Singapore',   'emoji': '🦁'},
      'BKK': {'name': 'Bangkok',      'country': 'Thailand',    'emoji': '🛕'},
      'FRA': {'name': 'Frankfurt',    'country': 'Germany',     'emoji': '🏰'},
      'AMS': {'name': 'Amsterdam',    'country': 'Netherlands', 'emoji': '🌷'},
      'NRT': {'name': 'Tokyo',        'country': 'Japan',       'emoji': '⛩️'},
      'SYD': {'name': 'Sydney',       'country': 'Australia',   'emoji': '🦘'},
      'LAX': {'name': 'Los Angeles',  'country': 'USA',         'emoji': '🌴'},
      'MXP': {'name': 'Milan',        'country': 'Italy',       'emoji': '🍕'},
      'BCN': {'name': 'Barcelona',    'country': 'Spain',       'emoji': '🏟️'},
      'DOH': {'name': 'Doha',         'country': 'Qatar',       'emoji': '🌙'},
      'MNL': {'name': 'Manila',       'country': 'Philippines', 'emoji': '🌺'},
      'DEL': {'name': 'Delhi',        'country': 'India',       'emoji': '🕍'},
      'KHI': {'name': 'Karachi',      'country': 'Pakistan',    'emoji': '🌊'},
    };
    return cities[code] ?? {'name': code, 'country': '', 'emoji': '🌍'};
  }
}

// ── Category list ──────────────────────────────────────────────────────────
class _CategoryList extends StatelessWidget {
  final String cityId;
  final String category;
  final String sortBy;
  final bool halalOnly;
  final String searchQuery;
  final LayoverService service;

  const _CategoryList({
    required this.cityId,
    required this.category,
    required this.sortBy,
    required this.halalOnly,
    required this.searchQuery,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Recommendation>>(
      stream: service.recommendationsStream(
        cityId: cityId,
        category: category == 'all' ? null : category,
        halalOnly: halalOnly,
        sortBy: sortBy,
      ),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _ShimmerList();
        }
        if (snap.hasError) {
          return _ErrorState(message: snap.error.toString());
        }

        var recs = snap.data ?? [];

        // Client-side search filter
        if (searchQuery.isNotEmpty) {
          final q = searchQuery.toLowerCase();
          recs = recs.where((r) {
            return r.name.toLowerCase().contains(q) ||
                r.description.toLowerCase().contains(q) ||
                (r.address?.toLowerCase().contains(q) ?? false);
          }).toList();
        }

        if (recs.isEmpty) return const _EmptyState();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: recs.length,
          itemBuilder: (ctx, i) => RecommendationCard(
            recommendation: recs[i],
            index: i,
          )
              .animate(delay: Duration(milliseconds: i * 50))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.05, end: 0),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'No recommendations yet',
            style: TextStyle(
                color: NajmTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first crew member to\nadd a spot here!',
            textAlign: TextAlign.center,
            style: TextStyle(color: NajmTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message,
          style: const TextStyle(color: NajmTheme.error, fontSize: 13)),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        height: 160,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: NajmTheme.navyLight,
          borderRadius: BorderRadius.circular(16),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: NajmTheme.navyCard),
    );
  }
}
