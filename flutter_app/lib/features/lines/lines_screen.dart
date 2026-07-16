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

final filteredLinesProvider = Provider<AsyncValue<List<FlightLine>>>((ref) {
  final month = ref.watch(activeMonthProvider);
  final linesAsync = ref.watch(flightLinesProvider(month));
  final query = ref.watch(lineSearchQueryProvider).toLowerCase();

  return linesAsync.whenData((lines) {
    if (query.isEmpty) return lines;
    return lines.where((line) =>
      line.lineNumber.contains(query) ||
      line.destinations.any((d) => d.toLowerCase().contains(query))
    ).toList();
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

  List<FlightLine> _sortLines(List<FlightLine> lines, String sortBy, UserMode? mode) {
    final sorted = [...lines];
    switch (sortBy) {
      case 'salary':
        sorted.sort((a, b) => b.summary.estimatedSalaryMax.compareTo(a.summary.estimatedSalaryMax));
      case 'rest':
        sorted.sort((a, b) => b.summary.restQualityScore.compareTo(a.summary.restQualityScore));
      case 'daysOff':
        sorted.sort((a, b) => b.daysOff.length.compareTo(a.daysOff.length));
      default: // composite
        sorted.sort((a, b) => b.summary.compositeScore.compareTo(a.summary.compositeScore));
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
              onChanged: (v) => ref.read(lineSearchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search or ask Najm... (e.g. "lines with London layovers")',
                hintStyle: const TextStyle(fontSize: 13, color: CIPTheme.grey500),
                prefixIcon: const Icon(Icons.auto_awesome, color: CIPTheme.saudiGold, size: 20),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (query) {
                if (query.isNotEmpty && query.contains(' ')) {
                  // Natural language query — route to AI
                  context.push(Routes.assistant, extra: {'initialQuery': query});
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

// ─── Sort Chips ───────────────────────────────────────────────────────────────
class _SortChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _SortChips({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = [
      ('composite', '⭐ Best Match'),
      ('salary', '💰 Salary'),
      ('rest', '😴 Rest'),
      ('daysOff', '📅 Days Off'),
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
    final salaryFormatted = NumberFormat.currency(symbol: 'SAR ', decimalDigits: 0)
        .format(summary.estimatedSalaryMin);

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
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3 ? CIPTheme.saudiGold.withOpacity(0.15) : CIPTheme.grey100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? CIPTheme.saudiGold : CIPTheme.grey500,
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
                          fontSize: 16, fontWeight: FontWeight.bold, color: CIPTheme.saudiNavy
                        ),
                      ),
                      Text(
                        line.destinations.take(4).join(' · '),
                        style: const TextStyle(fontSize: 12, color: CIPTheme.grey500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                LegalityBadge(hasViolations: false, hasWarnings: false),
              ],
            ),

            const SizedBox(height: 12),

            // Score bar
            _ScoreBar(score: summary.compositeScore, mode: userMode),

            const SizedBox(height: 12),

            // Stats row
            Row(
              children: [
                _StatPill(icon: Icons.access_time, label: '${summary.totalDutyHours.toStringAsFixed(0)}h duty'),
                const SizedBox(width: 8),
                _StatPill(icon: Icons.flight, label: '${summary.totalLegs} legs'),
                const SizedBox(width: 8),
                _StatPill(icon: Icons.hotel, label: '${summary.layoverCount} layovers'),
                const Spacer(),
                Text(
                  salaryFormatted,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: CIPTheme.moneyGreen
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final double score;
  final UserMode mode;
  const _ScoreBar({required this.score, required this.mode});

  @override
  Widget build(BuildContext context) {
    final color = switch (mode) {
      UserMode.money => CIPTheme.moneyGreen,
      UserMode.rest => CIPTheme.restBlue,
      UserMode.balanced => CIPTheme.saudiNavy,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Match Score', style: TextStyle(fontSize: 11, color: CIPTheme.grey500)),
            Text('${score.toStringAsFixed(0)}/100',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: CIPTheme.grey100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: CIPTheme.grey500),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 12, color: CIPTheme.grey700)),
      ],
    );
  }
}

// ─── Upload Roster Card ───────────────────────────────────────────────────────
class _UploadRosterCard extends StatelessWidget {
  const _UploadRosterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CIPTheme.saudiNavy.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.saudiNavy.withOpacity(0.2), style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 40, color: CIPTheme.saudiNavy),
          const SizedBox(height: 8),
          const Text('Upload Monthly Roster', style: TextStyle(
            fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Inter'
          )),
          const Text('Upload Monthly Roster (.xlsx)', style: TextStyle(color: CIPTheme.grey500, fontSize: 13)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {/* Launch file picker */},
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Select Excel File'),
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
            const Text('No Lines Available', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter'
            )),
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
