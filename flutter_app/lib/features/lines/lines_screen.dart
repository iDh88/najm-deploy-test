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
final lineDestinationFilterProvider = StateProvider<String>((ref) => '');
final lineMinBlockHoursProvider = StateProvider<double>((ref) => 0);
final lineMinDaysOffProvider = StateProvider<int>((ref) => 0);

final filteredLinesProvider = Provider<AsyncValue<List<FlightLine>>>((ref) {
  final month = ref.watch(activeMonthProvider);
  final linesAsync = ref.watch(flightLinesProvider(month));
  final query = ref.watch(lineSearchQueryProvider).toLowerCase().trim();
  final destination =
      ref.watch(lineDestinationFilterProvider).toLowerCase().trim();
  final minBlock = ref.watch(lineMinBlockHoursProvider);
  final minDaysOff = ref.watch(lineMinDaysOffProvider);

  return linesAsync.whenData((lines) {
    return lines.where((line) {
      final matchesSearch = query.isEmpty ||
          line.lineNumber.toLowerCase().contains(query) ||
          line.destinations.any((d) => d.toLowerCase().contains(query));

      final matchesDestination = destination.isEmpty ||
          line.destinations.any((d) => d.toLowerCase().contains(destination));

      final matchesBlock = line.summary.totalBlockHours >= minBlock;
      final matchesDaysOff = line.daysOff.length >= minDaysOff;

      return matchesSearch &&
          matchesDestination &&
          matchesBlock &&
          matchesDaysOff;
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
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterBox(
            width: 130,
            label: 'Destination',
            hint: 'CAI, LHR...',
            onChanged: (v) =>
                ref.read(lineDestinationFilterProvider.notifier).state = v,
          ),
          const SizedBox(width: 8),
          _FilterBox(
            width: 120,
            label: 'Min block',
            hint: '60',
            keyboardType: TextInputType.number,
            onChanged: (v) => ref
                .read(lineMinBlockHoursProvider.notifier)
                .state = double.tryParse(v) ?? 0,
          ),
          const SizedBox(width: 8),
          _FilterBox(
            width: 120,
            label: 'Min days off',
            hint: '10',
            keyboardType: TextInputType.number,
            onChanged: (v) => ref.read(lineMinDaysOffProvider.notifier).state =
                int.tryParse(v) ?? 0,
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              ref.read(lineSearchQueryProvider.notifier).state = '';
              ref.read(lineDestinationFilterProvider.notifier).state = '';
              ref.read(lineMinBlockHoursProvider.notifier).state = 0;
              ref.read(lineMinDaysOffProvider.notifier).state = 0;
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
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
