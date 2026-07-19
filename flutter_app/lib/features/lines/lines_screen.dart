import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_cache_service.dart';
import '../../shared/widgets/offline_widgets.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../shared/widgets/legality_badge.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../../shared/widgets/mode_switcher.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

final activeMonthProvider = StateProvider<String>((ref) {
  return DateFormat('yyyy-MM').format(DateTime.now());
});

final nlpFilterProvider = StateProvider<String>((ref) => '');

final lineSearchQueryProvider = StateProvider<String>((ref) => '');
final lineDestinationFilterProvider =
    StateProvider<Set<String>>((ref) => <String>{});
final lineExcludeDestinationFilterProvider =
    StateProvider<Set<String>>((ref) => <String>{});
final lineTypeFilterProvider = StateProvider<Set<String>>((ref) => <String>{});
final lineMinBlockHoursProvider = StateProvider<double>((ref) => 0);
final lineMaxBlockHoursProvider = StateProvider<double>((ref) => 0);
final lineMinCreditHoursProvider = StateProvider<double>((ref) => 0);
final lineMaxCreditHoursProvider = StateProvider<double>((ref) => 0);
final lineMinDaysOffProvider = StateProvider<int>((ref) => 0);
final lineMaxLegsProvider = StateProvider<int>((ref) => 0);
final lineMinLayoversProvider = StateProvider<int>((ref) => 0);
final lineCarryOverOnlyProvider = StateProvider<bool>((ref) => false);
final lineNoCarryOverProvider = StateProvider<bool>((ref) => false);
final lineStarDaysOnlyProvider = StateProvider<bool>((ref) => false);
final lineFourLegOnlyProvider = StateProvider<bool>((ref) => false);

final filteredLinesProvider = Provider<AsyncValue<List<FlightLine>>>((ref) {
  final month = ref.watch(activeMonthProvider);
  final linesAsync = ref.watch(flightLinesProvider(month));
  final query = ref.watch(lineSearchQueryProvider).toLowerCase().trim();

  final includeDestinations = ref.watch(lineDestinationFilterProvider);
  final excludeDestinations = ref.watch(lineExcludeDestinationFilterProvider);
  final lineTypes = ref.watch(lineTypeFilterProvider);

  final minBlock = ref.watch(lineMinBlockHoursProvider);
  final maxBlock = ref.watch(lineMaxBlockHoursProvider);
  final minCredit = ref.watch(lineMinCreditHoursProvider);
  final maxCredit = ref.watch(lineMaxCreditHoursProvider);
  final minDaysOff = ref.watch(lineMinDaysOffProvider);
  final maxLegs = ref.watch(lineMaxLegsProvider);
  final minLayovers = ref.watch(lineMinLayoversProvider);

  final carryOverOnly = ref.watch(lineCarryOverOnlyProvider);
  final noCarryOver = ref.watch(lineNoCarryOverProvider);
  final starDaysOnly = ref.watch(lineStarDaysOnlyProvider);
  final fourLegOnly = ref.watch(lineFourLegOnlyProvider);

  return linesAsync.whenData((lines) {
    return lines.where((line) {
      final destinationSet =
          line.destinations.map((d) => d.toUpperCase()).toSet();
      final destinationsText =
          line.destinations.map((d) => d.toLowerCase()).join(' ');

      final matchesSearch = query.isEmpty ||
          line.lineNumber.toLowerCase().contains(query) ||
          destinationsText.contains(query);

      final matchesIncluded = includeDestinations.isEmpty ||
          includeDestinations.any(destinationSet.contains);

      final matchesExcluded = excludeDestinations.isEmpty ||
          !excludeDestinations.any(destinationSet.contains);

      final type = line.lineType.toUpperCase();
      final matchesType = lineTypes.isEmpty || lineTypes.contains(type);

      final blockHours = line.summary.totalBlockHours > 0
          ? line.summary.totalBlockHours
          : line.blockHours;
      final creditHours =
          line.creditHours > 0 ? line.creditHours : line.summary.totalDutyHours;
      final legs = line.totalLegs > 0 ? line.totalLegs : line.summary.totalLegs;
      final layovers = line.summary.layoverCount;

      final hasCarryOver =
          line.carryOver.trim().isNotEmpty || line.carryOverHours > 0;

      final matchesBlock =
          blockHours >= minBlock && (maxBlock <= 0 || blockHours <= maxBlock);
      final matchesCredit = creditHours >= minCredit &&
          (maxCredit <= 0 || creditHours <= maxCredit);
      final matchesDaysOff = line.daysOff.length >= minDaysOff;
      final matchesLegs = maxLegs <= 0 || legs <= maxLegs;
      final matchesLayovers = layovers >= minLayovers;
      final matchesCarry =
          (!carryOverOnly || hasCarryOver) && (!noCarryOver || !hasCarryOver);
      final matchesStar = !starDaysOnly || line.hasStarDays;
      final matchesFourLeg = !fourLegOnly || line.fourLegCount > 0;

      return matchesSearch &&
          matchesIncluded &&
          matchesExcluded &&
          matchesType &&
          matchesBlock &&
          matchesCredit &&
          matchesDaysOff &&
          matchesLegs &&
          matchesLayovers &&
          matchesCarry &&
          matchesStar &&
          matchesFourLeg;
    }).toList();
  });
});

// ─── Lines Screen ─────────────────────────────────────────────────────────────

class LinesScreen extends ConsumerStatefulWidget {
  const LinesScreen({super.key});

  @override
  ConsumerState<LinesScreen> createState() => _LinesScreenState();
}

class _LinesScreenState extends ConsumerState<LinesScreen> {
  final _searchController = TextEditingController();
  bool _showUpload = false;
  String _sortBy = 'composite'; // composite | salary | rest | daysOff

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linesAsync = ref.watch(filteredLinesProvider);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final connectivity = ref.watch(connectivityProvider);

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: const Text('Flight Lines'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Upload Roster',
            onPressed: () => setState(() => _showUpload = !_showUpload),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode switcher bar
          if (user != null) ModeSwitcher(currentMode: user.userMode),

          // NLP Filter + Search bar
          _NajmFilterBar(controller: _searchController),

          // Advanced filters
          const _LineFilterPanel(),

          // Sort chips
          _SortChips(
            selected: _sortBy,
            onChanged: (val) => setState(() => _sortBy = val),
          ),

          // Upload prompt
          if (_showUpload) const _UploadRosterCard(),

          // Lines list
          Expanded(
            child: Column(
              children: [
                if (!connectivity.isOnline)
                  const CachedDataCard(dataType: 'lines'),
                Expanded(
                  child: linesAsync.when(
                    data: (lines) {
                      if (lines.isEmpty) {
                        return _EmptyLinesState(hasUpload: !_showUpload);
                      }
                      final sorted = _sortLines(lines, _sortBy, user?.userMode);
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return LineCard(
                            line: sorted[index],
                            rank: index + 1,
                            userMode: user?.userMode ?? UserMode.balanced,
                            onTap: () =>
                                context.push('/lines/${sorted[index].id}'),
                          );
                        },
                      );
                    },
                    loading: () => _LinesSkeletonList(),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlightLine> _sortLines(
      List<FlightLine> lines, String sortBy, UserMode? mode) {
    final sorted = [...lines];
    switch (sortBy) {
      case 'salary':
        sorted.sort((a, b) => b.summary.estimatedSalaryMax
            .compareTo(a.summary.estimatedSalaryMax));
      case 'rest':
        sorted.sort((a, b) =>
            b.summary.restQualityScore.compareTo(a.summary.restQualityScore));
      case 'daysOff':
        sorted.sort((a, b) => b.daysOff.length.compareTo(a.daysOff.length));
      default: // composite
        sorted.sort((a, b) =>
            b.summary.compositeScore.compareTo(a.summary.compositeScore));
    }
    return sorted;
  }
}

// ─── Najm NLP Filter Bar ──────────────────────────────────────────────────────
class _NajmFilterBar extends ConsumerWidget {
  final TextEditingController controller;
  const _NajmFilterBar({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              onChanged: (v) =>
                  ref.read(lineSearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText:
                    'Search or ask Najm... (e.g. "lines with London layovers")',
                hintStyle:
                    const TextStyle(fontSize: 13, color: CIPTheme.grey500),
                prefixIcon: const Icon(Icons.auto_awesome,
                    color: CIPTheme.saudiGold, size: 20),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          controller.clear();
                          ref.read(lineSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: CIPTheme.grey100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty && query.contains(' ')) {
                  // Natural language query — route to AI
                  context
                      .push(Routes.assistant, extra: {'initialQuery': query});
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.mic_outlined, color: CIPTheme.saudiNavy),
            onPressed: () => context.push(Routes.assistant),
            tooltip: 'Voice Search',
          ),
        ],
      ),
    );
  }
}

class _LineFilterPanel extends ConsumerWidget {
  const _LineFilterPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines =
        ref.watch(filteredLinesProvider).valueOrNull ?? const <FlightLine>[];
    final allLines = ref
            .watch(flightLinesProvider(ref.watch(activeMonthProvider)))
            .valueOrNull ??
        lines;

    final destinations = allLines
        .expand((l) => l.destinations)
        .map((d) => d.toUpperCase())
        .toSet()
        .toList()
      ..sort();

    final types = allLines
        .map((l) => l.lineType.toUpperCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final include = ref.watch(lineDestinationFilterProvider);
    final exclude = ref.watch(lineExcludeDestinationFilterProvider);
    final lineTypes = ref.watch(lineTypeFilterProvider);

    final activeCount = include.length +
        exclude.length +
        lineTypes.length +
        (ref.watch(lineMinBlockHoursProvider) > 0 ? 1 : 0) +
        (ref.watch(lineMaxBlockHoursProvider) > 0 ? 1 : 0) +
        (ref.watch(lineMinCreditHoursProvider) > 0 ? 1 : 0) +
        (ref.watch(lineMaxCreditHoursProvider) > 0 ? 1 : 0) +
        (ref.watch(lineMinDaysOffProvider) > 0 ? 1 : 0) +
        (ref.watch(lineMaxLegsProvider) > 0 ? 1 : 0) +
        (ref.watch(lineMinLayoversProvider) > 0 ? 1 : 0) +
        (ref.watch(lineCarryOverOnlyProvider) ? 1 : 0) +
        (ref.watch(lineNoCarryOverProvider) ? 1 : 0) +
        (ref.watch(lineStarDaysOnlyProvider) ? 1 : 0) +
        (ref.watch(lineFourLegOnlyProvider) ? 1 : 0);

    void openFilters() => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _LinesFilterSheet(
            destinations: destinations,
            lineTypes: types,
            totalLines: allLines.length,
            visibleLines: lines.length,
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.tune, size: 20),
                label: Text(
                  activeCount == 0 ? 'Filters' : 'Filters ($activeCount)',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onPressed: openFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CIPTheme.saudiNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: CIPTheme.grey100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CIPTheme.grey200),
                ),
                child: Text(
                  '${lines.length}/${allLines.length} lines',
                  style: const TextStyle(
                    color: CIPTheme.grey900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (destinations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: CIPTheme.grey100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CIPTheme.grey200),
                  ),
                  child: Text(
                    '${destinations.length} destinations',
                    style: const TextStyle(
                      color: CIPTheme.grey700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (activeCount > 0)
                TextButton.icon(
                  onPressed: () => _clearLineFilters(ref),
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
          if (activeCount > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...include.map((d) => _ActiveFilterChip(label: 'Include $d')),
                  ...exclude.map((d) => _ActiveFilterChip(label: 'Exclude $d')),
                  ...lineTypes.map((t) => _ActiveFilterChip(label: t)),
                  if (ref.watch(lineNoCarryOverProvider))
                    const _ActiveFilterChip(label: 'No carry over'),
                  if (ref.watch(lineCarryOverOnlyProvider))
                    const _ActiveFilterChip(label: 'Carry over'),
                  if (ref.watch(lineStarDaysOnlyProvider))
                    const _ActiveFilterChip(label: 'Star days'),
                  if (ref.watch(lineFourLegOnlyProvider))
                    const _ActiveFilterChip(label: '4LG'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinesFilterSheet extends ConsumerWidget {
  final List<String> destinations;
  final List<String> lineTypes;
  final int totalLines;
  final int visibleLines;

  const _LinesFilterSheet({
    required this.destinations,
    required this.lineTypes,
    required this.totalLines,
    required this.visibleLines,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final include = ref.watch(lineDestinationFilterProvider);
    final exclude = ref.watch(lineExcludeDestinationFilterProvider);
    final selectedTypes = ref.watch(lineTypeFilterProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.98,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CIPTheme.grey50,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: CIPTheme.grey300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Filter Lines',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '$visibleLines/$totalLines',
                      style: const TextStyle(
                        color: CIPTheme.saudiNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  children: [
                    _FilterSection(
                      title: 'Line Types',
                      subtitle:
                          'Filter by TRNG / LINE / reserve types from uploaded file',
                      icon: Icons.category_outlined,
                      children: lineTypes.isEmpty
                          ? [const Text('No line types found')]
                          : lineTypes
                              .map((type) => _NumberChip(
                                    label: type,
                                    selected: selectedTypes.contains(type),
                                    onTap: () => _toggleSetValue(
                                      ref,
                                      lineTypeFilterProvider,
                                      type,
                                    ),
                                  ))
                              .toList(),
                    ),
                    _FilterSection(
                      title: 'Include Destinations',
                      subtitle:
                          'Show lines containing any selected destination',
                      icon: Icons.flight_takeoff,
                      children: _destinationChips(
                        destinations,
                        selected: include,
                        onSelected: (value) => _toggleSetValue(
                          ref,
                          lineDestinationFilterProvider,
                          value,
                        ),
                      ),
                    ),
                    _FilterSection(
                      title: 'Exclude Destinations',
                      subtitle:
                          'Hide lines containing any selected destination',
                      icon: Icons.block,
                      children: _destinationChips(
                        destinations,
                        selected: exclude,
                        danger: true,
                        onSelected: (value) => _toggleSetValue(
                          ref,
                          lineExcludeDestinationFilterProvider,
                          value,
                        ),
                      ),
                    ),
                    _FilterSection(
                      title: 'Carry Over / Special',
                      subtitle: 'Use metadata parsed from the lines file',
                      icon: Icons.swap_horiz,
                      children: [
                        _NumberChip(
                          label: 'No carry over',
                          selected: ref.watch(lineNoCarryOverProvider),
                          onTap: () {
                            final next = !ref.read(lineNoCarryOverProvider);
                            ref.read(lineNoCarryOverProvider.notifier).state =
                                next;
                            if (next) {
                              ref
                                  .read(lineCarryOverOnlyProvider.notifier)
                                  .state = false;
                            }
                          },
                        ),
                        _NumberChip(
                          label: 'Has carry over',
                          selected: ref.watch(lineCarryOverOnlyProvider),
                          onTap: () {
                            final next = !ref.read(lineCarryOverOnlyProvider);
                            ref.read(lineCarryOverOnlyProvider.notifier).state =
                                next;
                            if (next) {
                              ref.read(lineNoCarryOverProvider.notifier).state =
                                  false;
                            }
                          },
                        ),
                        _NumberChip(
                          label: 'Star days',
                          selected: ref.watch(lineStarDaysOnlyProvider),
                          onTap: () => ref
                              .read(lineStarDaysOnlyProvider.notifier)
                              .state = !ref.read(lineStarDaysOnlyProvider),
                        ),
                        _NumberChip(
                          label: 'Has 4LG',
                          selected: ref.watch(lineFourLegOnlyProvider),
                          onTap: () => ref
                              .read(lineFourLegOnlyProvider.notifier)
                              .state = !ref.read(lineFourLegOnlyProvider),
                        ),
                      ],
                    ),
                    _FilterSection(
                      title: 'Block Hours',
                      subtitle: 'Minimum / maximum block hours',
                      icon: Icons.schedule,
                      children: [
                        _NumberChip(
                            label: 'Min 65h',
                            selected:
                                ref.watch(lineMinBlockHoursProvider) == 65,
                            onTap: () => ref
                                .read(lineMinBlockHoursProvider.notifier)
                                .state = 65),
                        _NumberChip(
                            label: 'Min 70h',
                            selected:
                                ref.watch(lineMinBlockHoursProvider) == 70,
                            onTap: () => ref
                                .read(lineMinBlockHoursProvider.notifier)
                                .state = 70),
                        _NumberChip(
                            label: 'Min 75h',
                            selected:
                                ref.watch(lineMinBlockHoursProvider) == 75,
                            onTap: () => ref
                                .read(lineMinBlockHoursProvider.notifier)
                                .state = 75),
                        _NumberChip(
                            label: 'Max 70h',
                            selected:
                                ref.watch(lineMaxBlockHoursProvider) == 70,
                            onTap: () => ref
                                .read(lineMaxBlockHoursProvider.notifier)
                                .state = 70),
                        _NumberChip(
                            label: 'Max 75h',
                            selected:
                                ref.watch(lineMaxBlockHoursProvider) == 75,
                            onTap: () => ref
                                .read(lineMaxBlockHoursProvider.notifier)
                                .state = 75),
                      ],
                    ),
                    _FilterSection(
                      title: 'Credit / Off / Legs / Layovers',
                      subtitle:
                          'Detailed numeric filters from parsed line fields',
                      icon: Icons.query_stats,
                      children: [
                        _NumberChip(
                            label: 'CR ≥ 70',
                            selected:
                                ref.watch(lineMinCreditHoursProvider) == 70,
                            onTap: () => ref
                                .read(lineMinCreditHoursProvider.notifier)
                                .state = 70),
                        _NumberChip(
                            label: 'CR ≥ 75',
                            selected:
                                ref.watch(lineMinCreditHoursProvider) == 75,
                            onTap: () => ref
                                .read(lineMinCreditHoursProvider.notifier)
                                .state = 75),
                        _NumberChip(
                            label: 'OFF ≥ 10',
                            selected: ref.watch(lineMinDaysOffProvider) == 10,
                            onTap: () => ref
                                .read(lineMinDaysOffProvider.notifier)
                                .state = 10),
                        _NumberChip(
                            label: 'OFF ≥ 12',
                            selected: ref.watch(lineMinDaysOffProvider) == 12,
                            onTap: () => ref
                                .read(lineMinDaysOffProvider.notifier)
                                .state = 12),
                        _NumberChip(
                            label: 'LEG ≤ 18',
                            selected: ref.watch(lineMaxLegsProvider) == 18,
                            onTap: () => ref
                                .read(lineMaxLegsProvider.notifier)
                                .state = 18),
                        _NumberChip(
                            label: 'LEG ≤ 22',
                            selected: ref.watch(lineMaxLegsProvider) == 22,
                            onTap: () => ref
                                .read(lineMaxLegsProvider.notifier)
                                .state = 22),
                        _NumberChip(
                            label: 'Layovers ≥ 5',
                            selected: ref.watch(lineMinLayoversProvider) == 5,
                            onTap: () => ref
                                .read(lineMinLayoversProvider.notifier)
                                .state = 5),
                        _NumberChip(
                            label: 'Layovers ≥ 8',
                            selected: ref.watch(lineMinLayoversProvider) == 8,
                            onTap: () => ref
                                .read(lineMinLayoversProvider.notifier)
                                .state = 8),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: CIPTheme.grey200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _clearLineFilters(ref),
                          child: const Text('Clear All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _destinationChips(
    List<String> values, {
    required Set<String> selected,
    required ValueChanged<String> onSelected,
    bool danger = false,
  }) {
    return values
        .map((value) => _NumberChip(
              label: value,
              selected: selected.contains(value),
              danger: danger,
              onTap: () => onSelected(value),
            ))
        .toList();
  }
}

void _toggleSetValue(
  WidgetRef ref,
  StateProvider<Set<String>> provider,
  String value,
) {
  final next = {...ref.read(provider)};
  if (next.contains(value)) {
    next.remove(value);
  } else {
    next.add(value);
  }
  ref.read(provider.notifier).state = next;
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;

  const _ActiveFilterChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: CIPTheme.saudiNavy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CIPTheme.saudiNavy.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: CIPTheme.saudiNavy,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _FilterSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CIPTheme.saudiNavy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: CIPTheme.saudiNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: CIPTheme.grey900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CIPTheme.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _NumberChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  const _NumberChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = danger ? CIPTheme.violationRed : CIPTheme.saudiNavy;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? selectedColor : CIPTheme.grey100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? selectedColor : CIPTheme.grey200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : CIPTheme.grey700,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

void _clearLineFilters(WidgetRef ref) {
  ref.read(lineSearchQueryProvider.notifier).state = '';
  ref.read(lineDestinationFilterProvider.notifier).state = <String>{};
  ref.read(lineExcludeDestinationFilterProvider.notifier).state = <String>{};
  ref.read(lineTypeFilterProvider.notifier).state = <String>{};

  ref.read(lineMinBlockHoursProvider.notifier).state = 0;
  ref.read(lineMaxBlockHoursProvider.notifier).state = 0;
  ref.read(lineMinCreditHoursProvider.notifier).state = 0;
  ref.read(lineMaxCreditHoursProvider.notifier).state = 0;
  ref.read(lineMinDaysOffProvider.notifier).state = 0;
  ref.read(lineMaxLegsProvider.notifier).state = 0;
  ref.read(lineMinLayoversProvider.notifier).state = 0;

  ref.read(lineCarryOverOnlyProvider.notifier).state = false;
  ref.read(lineNoCarryOverProvider.notifier).state = false;
  ref.read(lineStarDaysOnlyProvider.notifier).state = false;
  ref.read(lineFourLegOnlyProvider.notifier).state = false;
}

class _FilterBox extends StatelessWidget {
  final double width;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  const _FilterBox({
    required this.width,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _LineCountBar extends StatelessWidget {
  final int showing;
  final int total;
  const _LineCountBar({required this.showing, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Showing $showing of $total lines',
          style: const TextStyle(
              color: CIPTheme.grey700, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _LineFactsBar extends StatelessWidget {
  final LineSummary summary;
  final int daysOffCount;
  const _LineFactsBar({required this.summary, required this.daysOffCount});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _StatPill(
            icon: Icons.schedule,
            label: '${summary.totalDutyHours.toStringAsFixed(0)}h duty'),
        _StatPill(icon: Icons.flight, label: '${summary.totalLegs} legs'),
        _StatPill(icon: Icons.hotel, label: '${summary.layoverCount} layovers'),
        _StatPill(icon: Icons.calendar_month, label: '$daysOffCount days off'),
      ],
    );
  }
}

// ─── Sort Chips ───────────────────────────────────────────────────────────────
class _SortChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _SortChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('lineNumber', 'Line No.'),
      ('block', 'Block Hours'),
      ('duty', 'Lower Duty'),
      ('daysOff', 'Days Off'),
      ('layovers', 'Layovers'),
    ];

    return Container(
      height: 44,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: options.map((opt) {
          final isSelected = selected == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(opt.$2),
              selected: isSelected,
              onSelected: (_) => onChanged(opt.$1),
              selectedColor: CIPTheme.saudiNavy.withOpacity(0.1),
              checkmarkColor: CIPTheme.saudiNavy,
              labelStyle: TextStyle(
                color: isSelected ? CIPTheme.saudiNavy : CIPTheme.grey700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Line Card ────────────────────────────────────────────────────────────────
class LineCard extends StatelessWidget {
  final FlightLine line;
  final int rank;
  final UserMode userMode;
  final VoidCallback onTap;

  const LineCard({
    super.key,
    required this.line,
    required this.rank,
    required this.userMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final summary = line.summary;
    final hasSalary = summary.estimatedSalaryMax > 0;
    final salaryFormatted = hasSalary
        ? NumberFormat.currency(symbol: 'SAR ', decimalDigits: 0)
            .format(summary.estimatedSalaryMax)
        : '${summary.totalBlockHours.toStringAsFixed(1)}h block';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CIPTheme.grey200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Rank badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? CIPTheme.saudiGold.withOpacity(0.15)
                        : CIPTheme.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            rank <= 3 ? CIPTheme.saudiGold : CIPTheme.grey500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Line ${line.lineNumber}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CIPTheme.saudiNavy),
                      ),
                      Text(
                        line.destinations.take(4).join(' · '),
                        style: const TextStyle(
                            fontSize: 12, color: CIPTheme.grey500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                LegalityBadge(hasViolations: false, hasWarnings: false),
              ],
            ),

            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _StatPill(
                    icon: Icons.access_time,
                    label:
                        '${summary.totalDutyHours.toStringAsFixed(0)}h duty'),
                const SizedBox(width: 8),
                _StatPill(
                    icon: Icons.flight, label: '${summary.totalLegs} legs'),
                const SizedBox(width: 8),
                _StatPill(
                    icon: Icons.hotel,
                    label: '${summary.layoverCount} layovers'),
                const Spacer(),
                Text(
                  salaryFormatted,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: CIPTheme.moneyGreen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: CIPTheme.grey500),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: CIPTheme.grey700,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UploadRosterCard extends StatelessWidget {
  const _UploadRosterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CIPTheme.warningAmberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CIPTheme.warningAmber.withOpacity(0.35)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: CIPTheme.warningAmber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Upload is handled from the admin panel for now.',
              style: TextStyle(
                color: CIPTheme.grey700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyLinesState extends StatelessWidget {
  final bool hasUpload;
  const _EmptyLinesState({required this.hasUpload});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✈️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('No Lines Available',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter')),
            const SizedBox(height: 8),
            const Text(
              'Upload your monthly roster Excel file to see available flight lines',
              textAlign: TextAlign.center,
              style: TextStyle(color: CIPTheme.grey500),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinesSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const SkeletonLoader(height: 140),
    );
  }
}
