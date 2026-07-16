import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/period_utils.dart';
import '../models/intelligence_models.dart';
import '../providers/intelligence_providers.dart';
import '../widgets/all_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════════
// UPLOAD SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final _periodCtrl = TextEditingController(text: 'JUN-2026');
  String? _selectedPath;
  String? _selectedName;

  @override
  void dispose() {
    _periodCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    // F27: real file picker (was a hardcoded /tmp mock path).
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    final file = result?.files.single;
    if (file == null || file.path == null) return;
    setState(() {
      _selectedPath = file.path;
      _selectedName = file.name;
    });
  }

  /// Parses the 4-digit year out of a period string like "JUN-2026";
  /// falls back to the current year so the value is never hardcoded.
  /// Logic lives in core/utils/period_utils.dart (unit-tested).
  int _yearFromPeriod(String period) => yearFromPeriod(period);

  Future<void> _upload() async {
    if (_selectedPath == null) return;
    // F27: authenticated identity (was 'demo_user'). The Python service also
    // pins the upload to the token uid server-side (F11), so this value is
    // display/bookkeeping — spoofing it buys nothing.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You must be signed in to upload a schedule.')));
      }
      return;
    }
    await ref.read(uploadProvider.notifier).upload(
      filePath: _selectedPath!,
      userId:   uid,
      period:   _periodCtrl.text,
      year:     _yearFromPeriod(_periodCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upload = ref.watch(uploadProvider);

    ref.listen<UploadState>(uploadProvider, (prev, next) {
      if (next.status == UploadStatus.complete && next.lineId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analysis complete!'),
            backgroundColor: NajmTheme.success,
          ),
        );
        context.push('/intelligence/lines/${next.lineId}');
        ref.read(uploadProvider.notifier).reset();
      }
    });

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navyMid,
        title: const Text('Upload Schedule PDF'),
        leading: IconButton(
          icon: const Icon(Icons.close, color: NajmTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drop zone
            GestureDetector(
              onTap: _selectedPath == null ? _pickFile : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 180,
                decoration: BoxDecoration(
                  color: _selectedPath != null
                      ? NajmTheme.gold.withOpacity(0.08)
                      : NajmTheme.navyLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedPath != null
                        ? NajmTheme.gold
                        : NajmTheme.cardBorder,
                    width: _selectedPath != null ? 1.5 : 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _selectedPath == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📄', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          const Text('Tap to select PDF',
                              style: TextStyle(
                                  color: NajmTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          const Text('Monthly line schedule',
                              style: TextStyle(
                                  color: NajmTheme.textMuted, fontSize: 13)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: NajmTheme.gold, size: 40),
                          const SizedBox(height: 12),
                          Text(_selectedName ?? 'File selected',
                              style: const TextStyle(
                                  color: NajmTheme.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: _pickFile,
                            child: const Text('Change file',
                                style: TextStyle(
                                    color: NajmTheme.textSecondary,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Period
            const Text('Schedule Period',
                style: TextStyle(
                    color: NajmTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _periodCtrl,
              style: const TextStyle(color: NajmTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. JUN-2026',
                prefixIcon: Icon(Icons.calendar_month_outlined,
                    color: NajmTheme.textMuted, size: 18),
              ),
            ),
            const SizedBox(height: 32),

            // Progress
            if (upload.status != UploadStatus.idle) ...[
              _ProgressSection(upload: upload),
              const SizedBox(height: 24),
            ],

            // Submit
            if (upload.status == UploadStatus.idle ||
                upload.status == UploadStatus.failed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedPath != null ? _upload : null,
                  icon: const Icon(Icons.rocket_launch_outlined),
                  label: const Text('Start Intelligence Analysis'),
                ),
              ),

            if (upload.error != null) ...[
              const SizedBox(height: 12),
              Text(upload.error!,
                  style: const TextStyle(
                      color: NajmTheme.error, fontSize: 12)),
            ],

            const SizedBox(height: 32),
            _WhatHappensCard(),
          ],
        ),
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final UploadState upload;
  const _ProgressSection({required this.upload});

  String get _label {
    switch (upload.status) {
      case UploadStatus.uploading:   return 'Uploading PDF…';
      case UploadStatus.processing:  return 'Running intelligence analysis…';
      case UploadStatus.complete:    return 'Analysis complete!';
      case UploadStatus.failed:      return 'Failed';
      default:                       return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NajmTheme.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (upload.status == UploadStatus.complete)
              const Icon(Icons.check_circle, color: NajmTheme.success, size: 18)
            else
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: NajmTheme.gold),
              ),
            const SizedBox(width: 10),
            Text(_label, style: const TextStyle(
                color: NajmTheme.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: upload.progress,
              backgroundColor: NajmTheme.navyLight,
              valueColor: const AlwaysStoppedAnimation(NajmTheme.gold),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text('${(upload.progress * 100).round()}%',
              style: const TextStyle(
                  color: NajmTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _WhatHappensCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      ('📥', 'PDF Upload',    'Your schedule PDF is securely uploaded'),
      ('🔍', 'Extraction',   'Text and structure extracted (3-layer pipeline)'),
      ('✈️', 'Pairing Parse','Pairings, segments, duty periods reconstructed'),
      ('🔋', 'Fatigue Score','FRMS-based fatigue model applied to every duty'),
      ('🏷️', 'Classification','Line classified: High Fatigue, Recovery Friendly, etc.'),
      ('💡', 'Insights',     'Smart operational insights generated'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NajmTheme.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What happens when you upload',
              style: TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.$1, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$2, style: const TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(s.$3, style: const TextStyle(
                        color: NajmTheme.textMuted, fontSize: 11)),
                  ],
                )),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SEARCH SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  // F27: authenticated identity (was 'demo_user'). Router guards ensure a
  // signed-in user before this screen is reachable; empty-string fallback
  // keeps the provider family key non-null if that invariant ever breaks.
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchProvider(_userId).notifier).search();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider(_userId));

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navyMid,
        title: const Text('Smart Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: NajmTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (state.filters.hasActiveFilters)
            TextButton(
              onPressed: () => ref
                  .read(searchProvider(_userId).notifier)
                  .clearFilters(),
              child: const Text('Clear',
                  style: TextStyle(color: NajmTheme.gold, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _SearchFilterBar(
            filters: state.filters,
            onChanged: (f) => ref
                .read(searchProvider(_userId).notifier)
                .updateFilters(f),
          ),
          const Divider(height: 1, color: NajmTheme.divider),

          // Results
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: NajmTheme.gold))
                : state.results.isEmpty
                    ? const Center(
                        child: Text('No lines match your filters',
                            style: TextStyle(color: NajmTheme.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.results.length,
                        itemBuilder: (_, i) =>
                            _SearchResultCard(line: state.results[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchFilterBar extends StatelessWidget {
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;
  const _SearchFilterBar({required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: '🔋 Low Fatigue',
            active: filters.fatigueLevel == 'LOW',
            onTap: () => onChanged(filters.copyWith(
                fatigueLevel: filters.fatigueLevel == 'LOW' ? null : 'LOW')),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '🌍 International',
            active: filters.isInternational == true,
            onTap: () => onChanged(filters.copyWith(
                isInternational: filters.isInternational == true ? null : true)),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '🚫 No Deadhead',
            active: filters.hasDeadhead == false,
            onTap: () => onChanged(filters.copyWith(
                hasDeadhead: filters.hasDeadhead == false ? null : false)),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '💰 High Credit',
            active: filters.minCredit == 80,
            onTap: () => onChanged(filters.copyWith(
                minCredit: filters.minCredit == 80 ? null : 80)),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: '⚠️ High Fatigue',
            active: filters.fatigueLevel == 'HIGH',
            onTap: () => onChanged(filters.copyWith(
                fatigueLevel: filters.fatigueLevel == 'HIGH' ? null : 'HIGH')),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? NajmTheme.gold.withOpacity(0.15) : NajmTheme.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? NajmTheme.gold : NajmTheme.cardBorder),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? NajmTheme.gold : NajmTheme.textSecondary,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final MonthlyLine line;
  const _SearchResultCard({required this.line});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/intelligence/lines/${line.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NajmTheme.navyCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
        child: Row(
          children: [
            LineClassificationBadge(classification: line.classification),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Line ${line.lineNumber}  ·  ${line.period}',
                      style: const TextStyle(
                          color: NajmTheme.textPrimary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${line.summary.blockHours.toStringAsFixed(0)}h block · '
                    '${line.fatigueProfile.fatiguePercentage}% fatigue · '
                    '${line.summary.offDays} off days',
                    style: const TextStyle(
                        color: NajmTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: NajmTheme.textMuted, size: 13),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COMPARISON SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ComparisonScreen extends ConsumerWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state     = ref.watch(comparisonProvider);
    // F27: authenticated identity (was 'demo_user').
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final linesAsync = ref.watch(userLinesProvider(uid));

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navyMid,
        title: const Text('Line Comparison'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: NajmTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: linesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: NajmTheme.gold)),
        error: (e, _) => Center(child: Text(e.toString(),
            style: const TextStyle(color: NajmTheme.error))),
        data: (lines) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Select two lines to compare',
                style: TextStyle(
                    color: NajmTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),

            // Line A picker
            _LinePicker(
              label: 'Line A',
              color: NajmTheme.gold,
              lines: lines,
              selectedId: state.lineAId,
              onSelected: (id) =>
                  ref.read(comparisonProvider.notifier).selectLineA(id),
            ),
            const SizedBox(height: 10),

            // VS divider
            const Center(
              child: Text('VS',
                  style: TextStyle(
                      color: NajmTheme.textMuted,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
            ),
            const SizedBox(height: 10),

            // Line B picker
            _LinePicker(
              label: 'Line B',
              color: NajmTheme.info,
              lines: lines,
              selectedId: state.lineBId,
              onSelected: (id) =>
                  ref.read(comparisonProvider.notifier).selectLineB(id),
            ),
            const SizedBox(height: 24),

            // Compare button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isReady && !state.isLoading
                    ? () => ref.read(comparisonProvider.notifier).compare()
                    : null,
                icon: state.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: NajmTheme.navy))
                    : const Icon(Icons.compare_arrows),
                label: const Text('Compare Lines'),
              ),
            ),

            // Results
            if (state.result != null) ...[
              const SizedBox(height: 28),
              _ComparisonResult(comparison: state.result!),
            ],
          ],
        ),
      ),
    );
  }
}

class _LinePicker extends StatelessWidget {
  final String label;
  final Color color;
  final List<MonthlyLine> lines;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const _LinePicker({
    required this.label, required this.color, required this.lines,
    required this.selectedId, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = lines.where((l) => l.id == selectedId).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NajmTheme.navyCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: selected != null ? color.withOpacity(0.5) : NajmTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11,
                  fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 10),
          if (selected != null) ...[
            Row(children: [
              LineClassificationBadge(classification: selected.classification),
              const SizedBox(width: 10),
              Text('Line ${selected.lineNumber}  ·  ${selected.period}',
                  style: const TextStyle(
                      color: NajmTheme.textPrimary, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 38,
            child: DropdownButtonFormField<String>(
              value: selectedId,
              dropdownColor: NajmTheme.navyMid,
              style: const TextStyle(color: NajmTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              hint: const Text('Select line…',
                  style: TextStyle(color: NajmTheme.textMuted, fontSize: 13)),
              items: lines.map((l) => DropdownMenuItem(
                value: l.id,
                child: Text('Line ${l.lineNumber}  ·  ${l.period}'),
              )).toList(),
              onChanged: (v) { if (v != null) onSelected(v); },
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonResult extends StatelessWidget {
  final LineComparison comparison;
  const _ComparisonResult({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final isA = comparison.winner == 'A';
    final isB = comparison.winner == 'B';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Winner banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NajmTheme.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NajmTheme.success.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Text(
                comparison.winner == 'EQUAL'
                    ? '🤝 Equally Matched'
                    : isA
                        ? '🏆 ${comparison.lineALabel} Wins'
                        : '🏆 ${comparison.lineBLabel} Wins',
                style: const TextStyle(
                    color: NajmTheme.success,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(comparison.recommendationEn,
                  style: const TextStyle(
                      color: NajmTheme.textSecondary, fontSize: 13),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Delta metrics
        const Text('Comparison Breakdown',
            style: TextStyle(
                color: NajmTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        _DeltaRow('Block Hours', comparison.blockHoursDelta, 'h',
            higherIsBetter: true),
        _DeltaRow('Fatigue Load',
            comparison.fatigueDelta * 100, '%',
            higherIsBetter: false),
        _DeltaRow('Est. Credit', comparison.incomeDelta, 'h',
            higherIsBetter: true),
        _DeltaRow('Deadhead Legs',
            comparison.deadheadDelta.toDouble(), '',
            higherIsBetter: false),

        const SizedBox(height: 20),

        // Radar axes
        const Text('Radar Scores',
            style: TextStyle(
                color: NajmTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...['fatigue', 'income', 'recovery', 'deadhead', 'legality', 'efficiency']
            .map((axis) => _RadarRow(
                  axis:   axis,
                  scoreA: comparison.lineARadar[axis] ?? 0,
                  scoreB: comparison.lineBRadar[axis] ?? 0,
                )),
      ],
    );
  }
}

class _DeltaRow extends StatelessWidget {
  final String label;
  final double delta;
  final String unit;
  final bool higherIsBetter;
  const _DeltaRow(this.label, this.delta, this.unit,
      {required this.higherIsBetter});

  @override
  Widget build(BuildContext context) {
    final isPositive = delta > 0;
    final isBetter   = higherIsBetter ? isPositive : !isPositive;
    final color = delta.abs() < 0.5 ? NajmTheme.textMuted
        : isBetter ? NajmTheme.success : NajmTheme.error;
    final sign = isPositive ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: NajmTheme.navyCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
        child: Row(children: [
          Text(label, style: const TextStyle(
              color: NajmTheme.textSecondary, fontSize: 13)),
          const Spacer(),
          Text(
            delta.abs() < 0.5 ? 'Equal'
                : '$sign${delta.toStringAsFixed(1)}$unit (A vs B)',
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

class _RadarRow extends StatelessWidget {
  final String axis;
  final double scoreA, scoreB;
  const _RadarRow({required this.axis, required this.scoreA, required this.scoreB});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(axis.toUpperCase(),
                style: const TextStyle(
                    color: NajmTheme.textMuted,
                    fontSize: 10, letterSpacing: 0.8)),
            const Spacer(),
            Text('A: ${(scoreA * 100).round()}%',
                style: const TextStyle(
                    color: NajmTheme.gold, fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 10),
            Text('B: ${(scoreB * 100).round()}%',
                style: const TextStyle(
                    color: NajmTheme.info, fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: scoreA, minHeight: 6,
                backgroundColor: NajmTheme.navyLight,
                valueColor: const AlwaysStoppedAnimation(NajmTheme.gold),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: scoreB, minHeight: 6,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(
                    NajmTheme.info.withOpacity(0.5)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
