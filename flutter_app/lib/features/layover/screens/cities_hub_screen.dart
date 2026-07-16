import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
// NOTE: this screen intentionally renders the seeded destination list below;
// live city documents are consumed by city_detail_screen via LayoverService.

// Seeded destination cities
final _seedCities = [
  {'code': 'CAI', 'name': 'Cairo',         'country': 'Egypt',        'emoji': '🏺'},
  {'code': 'IST', 'name': 'Istanbul',      'country': 'Turkey',       'emoji': '🕌'},
  {'code': 'KUL', 'name': 'Kuala Lumpur',  'country': 'Malaysia',     'emoji': '🏙️'},
  {'code': 'DXB', 'name': 'Dubai',         'country': 'UAE',          'emoji': '🌆'},
  {'code': 'LHR', 'name': 'London',        'country': 'UK',           'emoji': '🎡'},
  {'code': 'CDG', 'name': 'Paris',         'country': 'France',       'emoji': '🗼'},
  {'code': 'JFK', 'name': 'New York',      'country': 'USA',          'emoji': '🗽'},
  {'code': 'SIN', 'name': 'Singapore',     'country': 'Singapore',    'emoji': '🦁'},
  {'code': 'BKK', 'name': 'Bangkok',       'country': 'Thailand',     'emoji': '🛕'},
  {'code': 'FRA', 'name': 'Frankfurt',     'country': 'Germany',      'emoji': '🏰'},
  {'code': 'AMS', 'name': 'Amsterdam',     'country': 'Netherlands',  'emoji': '🌷'},
  {'code': 'NRT', 'name': 'Tokyo',         'country': 'Japan',        'emoji': '⛩️'},
  {'code': 'SYD', 'name': 'Sydney',        'country': 'Australia',    'emoji': '🦘'},
  {'code': 'LAX', 'name': 'Los Angeles',   'country': 'USA',          'emoji': '🌴'},
  {'code': 'MXP', 'name': 'Milan',         'country': 'Italy',        'emoji': '🍕'},
  {'code': 'BCN', 'name': 'Barcelona',     'country': 'Spain',        'emoji': '🏟️'},
  {'code': 'DOH', 'name': 'Doha',          'country': 'Qatar',        'emoji': '🌙'},
  {'code': 'MNL', 'name': 'Manila',        'country': 'Philippines',  'emoji': '🌺'},
  {'code': 'DEL', 'name': 'Delhi',         'country': 'India',        'emoji': '🕍'},
  {'code': 'KHI', 'name': 'Karachi',       'country': 'Pakistan',     'emoji': '🌊'},
];

class CitiesHubScreen extends StatefulWidget {
  const CitiesHubScreen({super.key});
  @override
  State<CitiesHubScreen> createState() => _CitiesHubScreenState();
}

class _CitiesHubScreenState extends State<CitiesHubScreen> {
  final _search = TextEditingController();
  String _query = '';

  List<Map<String, String>> get _filtered => _query.isEmpty
      ? _seedCities
      : _seedCities
          .where((c) =>
              c['name']!.toLowerCase().contains(_query.toLowerCase()) ||
              c['code']!.toLowerCase().contains(_query.toLowerCase()) ||
              c['country']!.toLowerCase().contains(_query.toLowerCase()))
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [NajmTheme.navyMid, NajmTheme.navy],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: NajmTheme.goldGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text('✈', style: TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NAJM',
                                  style: TextStyle(
                                    color: NajmTheme.gold,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 4,
                                  )),
                              Text('Crew Intelligence Platform',
                                  style: TextStyle(
                                    color: NajmTheme.textSecondary,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  )),
                            ],
                          ),
                          const Spacer(),
                          // F30: entry point to the Saved Places screen —
                          // the bookmark write-path existed but the list of
                          // saves was unreachable from anywhere in the app.
                          IconButton(
                            onPressed: () => context.push('/layover/saved'),
                            tooltip: 'Saved Places',
                            icon: const Icon(Icons.bookmark_outline,
                                color: NajmTheme.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Layover Cities',
                        style: TextStyle(
                          color: NajmTheme.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_seedCities.length} destinations · crew-curated',
                        style: const TextStyle(
                          color: NajmTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Search
                      TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        style: const TextStyle(color: NajmTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search city or airport code…',
                          prefixIcon: const Icon(Icons.search,
                              color: NajmTheme.textMuted, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      color: NajmTheme.textMuted, size: 18),
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── City Grid ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final city = _filtered[i];
                  return _CityCard(city: city, index: i);
                },
                childCount: _filtered.length,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityCard extends StatelessWidget {
  final Map<String, String> city;
  final int index;
  const _CityCard({required this.city, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/layover/${city['code']}'),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [NajmTheme.navyCard, NajmTheme.navyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                right: -10,
                bottom: -10,
                child: Text(
                  city['emoji']!,
                  style: const TextStyle(fontSize: 72),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: NajmTheme.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: NajmTheme.gold.withOpacity(0.3)),
                      ),
                      child: Text(
                        city['code']!,
                        style: const TextStyle(
                          color: NajmTheme.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      city['name']!,
                      style: const TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      city['country']!,
                      style: const TextStyle(
                        color: NajmTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            color: NajmTheme.textMuted, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to explore',
                          style: const TextStyle(
                            color: NajmTheme.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios,
                            color: NajmTheme.gold, size: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: index * 40))
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.1, end: 0),
    );
  }
}
