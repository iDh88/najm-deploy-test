import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../shared/constants/constants.dart';
import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../shared/widgets/skeleton_loader.dart';

// ── Enums ─────────────────────────────────────────────────────────
enum TradeSearchMode {
  exactRoute('Exact Route', '🎯'),
  similarHours('Similar Hours', '⏱'),
  betterRest('Better Rest', '😴'),
  lowestFatigue('Lowest Fatigue', '⚡'),
  highestIncome('Highest Income', '💰'),
  smartFlex('Smart Match', '🧠');
  final String label; final String emoji;
  const TradeSearchMode(this.label, this.emoji);
}

enum TradeFatigueLevel { low, medium, high }
enum TradeDifficulty { easy, medium, hard }

// ── Match Result Model ────────────────────────────────────────────
class TradeMatchResult {
  final String matchId, lineId, lineNumber, ownerPRN;
  final String date, departureTime, routePattern;
  final List<String> legTypePattern;
  final double blockHours, dutyHours, restAfterHours, income;
  final bool legalityPassed, hasCarryOver, hasDeadhead;
  final String legalitySummary;
  final List<String> legalityViolations, legalityWarnings;
  final TradeFatigueLevel fatigueLevel;
  final double fatigueScore;
  final List<String> fatigueFactors, fatigueComparison;
  final double tradeScore;
  final List<String> scoreReasons;
  final String recommendation;
  final TradeDifficulty difficulty;
  final String? phoneNumber;

  const TradeMatchResult({
    required this.matchId, required this.lineId, required this.lineNumber,
    required this.ownerPRN, required this.date, required this.departureTime,
    required this.routePattern, required this.legTypePattern,
    required this.blockHours, required this.dutyHours,
    required this.restAfterHours, required this.income,
    required this.legalityPassed, required this.hasCarryOver,
    required this.hasDeadhead, required this.legalitySummary,
    required this.legalityViolations, required this.legalityWarnings,
    required this.fatigueLevel, required this.fatigueScore,
    required this.fatigueFactors, required this.fatigueComparison,
    required this.tradeScore, required this.scoreReasons,
    required this.recommendation, required this.difficulty,
    this.phoneNumber,
  });

  factory TradeMatchResult.fromJson(Map<String, dynamic> j) {
    final leg = j['legality'] as Map? ?? {};
    final fat = j['fatigue']  as Map? ?? {};
    final sc  = j['tradeScore'] as Map? ?? {};
    return TradeMatchResult(
      matchId:            j['matchId'] as String? ?? '',
      lineId:             j['lineId'] as String? ?? '',
      lineNumber:         j['lineNumber'] as String? ?? '',
      ownerPRN:           j['ownerPRN'] as String? ?? '',
      date:               j['date'] as String? ?? '',
      departureTime:      j['departureTime'] as String? ?? '',
      routePattern:       j['routePattern'] as String? ?? '',
      legTypePattern:     List<String>.from(j['legTypePattern'] as List? ?? []),
      blockHours:         ((j['blockHours'] ?? 0) as num).toDouble(),
      dutyHours:          ((j['dutyHours'] ?? 0) as num).toDouble(),
      restAfterHours:     ((j['restAfterHours'] ?? 0) as num).toDouble(),
      income:             ((j['income'] ?? 0) as num).toDouble(),
      legalityPassed:     leg['passed'] as bool? ?? false,
      hasCarryOver:       j['hasCarryOver'] as bool? ?? false,
      hasDeadhead:        j['hasDeadhead'] as bool? ?? false,
      legalitySummary:    leg['summary'] as String? ?? '',
      legalityViolations: (leg['violations'] as List? ?? [])
          .map((v) => (v as Map)['ruleName']?.toString() ?? '').toList(),
      legalityWarnings:   (leg['warnings'] as List? ?? [])
          .map((v) => (v as Map)['ruleName']?.toString() ?? '').toList(),
      fatigueLevel:       _parseFatigue(fat['level']),
      fatigueScore:       ((fat['score'] ?? 0) as num).toDouble(),
      fatigueFactors:     List<String>.from(fat['factors'] as List? ?? []),
      fatigueComparison:  [fat['comparison']?.toString() ?? ''],
      tradeScore:         ((sc['total'] ?? 0) as num).toDouble(),
      scoreReasons:       List<String>.from(sc['reasons'] as List? ?? []),
      recommendation:     sc['recommendation'] as String? ?? '',
      difficulty:         _parseDiff(j['difficulty']),
      phoneNumber:        j['phoneNumber'] as String?,
    );
  }

  static TradeFatigueLevel _parseFatigue(dynamic v) =>
      v?.toString().toLowerCase() == 'high'   ? TradeFatigueLevel.high :
      v?.toString().toLowerCase() == 'medium' ? TradeFatigueLevel.medium :
      TradeFatigueLevel.low;

  static TradeDifficulty _parseDiff(dynamic v) =>
      v?.toString().toLowerCase() == 'hard'   ? TradeDifficulty.hard :
      v?.toString().toLowerCase() == 'medium' ? TradeDifficulty.medium :
      TradeDifficulty.easy;
}

// ── Provider ─────────────────────────────────────────────────────
final tradeIntelProvider =
    StateNotifierProvider<TradeIntelNotifier, TradeIntelState>(
        (ref) => TradeIntelNotifier(ref));

class TradeIntelState {
  final bool loading;
  final List<TradeMatchResult> results;
  final String? error;
  final TradeSearchMode mode;
  final bool legalOnly, noCarryOver, morningOnly, similarBlock, sameRoute;
  final Set<String> selectedOutreach;

  const TradeIntelState({
    this.loading = false, this.results = const [],
    this.error, this.mode = TradeSearchMode.smartFlex,
    this.legalOnly = true, this.noCarryOver = false,
    this.morningOnly = false, this.similarBlock = false,
    this.sameRoute = false, this.selectedOutreach = const {},
  });

  TradeIntelState copyWith({
    bool? loading, List<TradeMatchResult>? results, String? error,
    TradeSearchMode? mode, bool? legalOnly, bool? noCarryOver,
    bool? morningOnly, bool? similarBlock, bool? sameRoute,
    Set<String>? selectedOutreach,
  }) => TradeIntelState(
    loading: loading ?? this.loading, results: results ?? this.results,
    error: error, mode: mode ?? this.mode,
    legalOnly: legalOnly ?? this.legalOnly,
    noCarryOver: noCarryOver ?? this.noCarryOver,
    morningOnly: morningOnly ?? this.morningOnly,
    similarBlock: similarBlock ?? this.similarBlock,
    sameRoute: sameRoute ?? this.sameRoute,
    selectedOutreach: selectedOutreach ?? this.selectedOutreach,
  );
}

class TradeIntelNotifier extends StateNotifier<TradeIntelState> {
  final Ref _ref;
  TradeIntelNotifier(this._ref) : super(const TradeIntelState());

  void setMode(TradeSearchMode m) => state = state.copyWith(mode: m);
  void toggleLegal()    => state = state.copyWith(legalOnly: !state.legalOnly);
  void toggleCarryOver()=> state = state.copyWith(noCarryOver: !state.noCarryOver);
  void toggleMorning()  => state = state.copyWith(morningOnly: !state.morningOnly);
  void toggleSimilar()  => state = state.copyWith(similarBlock: !state.similarBlock);
  void toggleSameRoute()=> state = state.copyWith(sameRoute: !state.sameRoute);

  void toggleOutreach(String id) {
    final s = Set<String>.from(state.selectedOutreach);
    s.contains(id) ? s.remove(id) : s.add(id);
    state = state.copyWith(selectedOutreach: s);
  }

  Future<void> search(String lineId, String pairingId, String month) async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    state = state.copyWith(loading: true, error: null, results: []);
    try {
      final url = AppConfig.aiServiceUrl;
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final resp = await http.post(
        Uri.parse('$url/v1/trade-intel/search'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': user.id, 'userPRN': user.crewId,
          'userLineId': lineId, 'targetPairingId': pairingId,
          'searchMode': state.mode.name, 'month': month,
          'filters': {
            'legalOnly': state.legalOnly,
            'noCarryOver': state.noCarryOver,
            'morningFlightsOnly': state.morningOnly,
            'similarBlockHours': state.similarBlock,
            'sameRoutePattern': state.sameRoute,
          },
          'maxResults': 20,
        }),
      ).timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        state = state.copyWith(
          loading: false,
          results: (data['results'] as List? ?? [])
              .map((r) => TradeMatchResult.fromJson(r as Map<String, dynamic>))
              .toList(),
        );
      } else {
        state = state.copyWith(loading: false, error: 'Search failed (${resp.statusCode})');
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Connection error: $e');
    }
  }
}

// ── Search Screen ─────────────────────────────────────────────────
class TradeIntelSearchScreen extends ConsumerStatefulWidget {
  final String lineId, pairingId, month;
  const TradeIntelSearchScreen({super.key,
      required this.lineId, required this.pairingId, required this.month});

  @override
  ConsumerState<TradeIntelSearchScreen> createState() => _State();
}

class _State extends ConsumerState<TradeIntelSearchScreen> {
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    final n = ref.read(tradeIntelProvider.notifier);
    final s = ref.watch(tradeIntelProvider);

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        backgroundColor: Colors.white, foregroundColor: CIPTheme.grey900,
        elevation: 0,
        title: const Text('Trade Intelligence',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            icon: Icon(Icons.tune,
                color: _showFilters ? CIPTheme.saudiNavy : CIPTheme.grey500),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mode selector
          _buildModeSelector(s, n),
          if (_showFilters) _buildFilters(s, n),
          const Divider(height: 1),
          // Results
          Expanded(
            child: s.loading ? _buildLoading()
                : s.error != null ? _buildError(s.error!)
                : s.results.isEmpty ? _buildEmpty()
                : _buildResults(s, n),
          ),
          if (s.selectedOutreach.isNotEmpty) _buildOutreachBar(s),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: s.loading ? null : () => n.search(
            widget.lineId, widget.pairingId, widget.month),
        backgroundColor: CIPTheme.saudiNavy,
        icon: s.loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.search, color: Colors.white),
        label: Text(s.loading ? 'Searching...' : 'Find Trades',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildModeSelector(TradeIntelState s, TradeIntelNotifier n) =>
    Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: TradeSearchMode.values.map((mode) {
            final sel = s.mode == mode;
            return GestureDetector(
              onTap: () => n.setMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? CIPTheme.saudiNavy : CIPTheme.grey100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? CIPTheme.saudiNavy : CIPTheme.grey200),
                ),
                child: Row(children: [
                  Text(mode.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(mode.label, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : CIPTheme.grey700)),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );

  Widget _buildFilters(TradeIntelState s, TradeIntelNotifier n) =>
    Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(spacing: 8, runSpacing: 6, children: [
        _chip('Legal Only',    s.legalOnly,    n.toggleLegal),
        _chip('No Carry Over', s.noCarryOver,  n.toggleCarryOver),
        _chip('Morning Only',  s.morningOnly,  n.toggleMorning),
        _chip('Similar Block', s.similarBlock, n.toggleSimilar),
        _chip('Same Route',    s.sameRoute,    n.toggleSameRoute),
      ]),
    );

  Widget _chip(String label, bool active, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? CIPTheme.saudiNavy : CIPTheme.grey100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active ? CIPTheme.saudiNavy : CIPTheme.grey200),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? Colors.white : CIPTheme.grey700)),
      ),
    );

  Widget _buildLoading() => ListView.builder(
    padding: const EdgeInsets.all(16), itemCount: 4,
    itemBuilder: (_, i) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SkeletonLoader(height: 160, borderRadius: 12)));

  Widget _buildError(String e) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('⚠️', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('Search Failed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 8),
      Text(e, textAlign: TextAlign.center,
          style: const TextStyle(color: CIPTheme.grey500, fontSize: 13)),
    ])));

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔍', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 16),
      const Text('No trades found',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      const SizedBox(height: 8),
      const Text('Try a different mode or adjust filters.',
          textAlign: TextAlign.center,
          style: TextStyle(color: CIPTheme.grey500, fontSize: 14)),
    ])));

  Widget _buildResults(TradeIntelState s, TradeIntelNotifier n) =>
    ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: s.results.length,
      itemBuilder: (_, i) => _TradeCard(
        result: s.results[i], rank: i + 1,
        isSelected: s.selectedOutreach.contains(s.results[i].matchId),
        onOutreach: () => n.toggleOutreach(s.results[i].matchId),
      ));

  Widget _buildOutreachBar(TradeIntelState s) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          final selected = s.results
              .where((r) => s.selectedOutreach.contains(r.matchId)).toList();
          context.push('/trade-intel/outreach', extra: selected);
        },
        icon: const Icon(Icons.chat, size: 16, color: Colors.white),
        label: Text(
            'Contact ${s.selectedOutreach.length} crew via WhatsApp',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF25D366),
          minimumSize: const Size(double.infinity, 48)),
      ),
    ),
  );
}

// ── Trade Card ────────────────────────────────────────────────────
class _TradeCard extends StatelessWidget {
  final TradeMatchResult result;
  final int rank;
  final bool isSelected;
  final VoidCallback onOutreach;
  const _TradeCard({required this.result, required this.rank,
      required this.isSelected, required this.onOutreach});

  @override
  Widget build(BuildContext context) {
    final sc = result.tradeScore;
    final scoreColor = sc >= 80 ? CIPTheme.legalGreen
        : sc >= 60 ? CIPTheme.warningAmber : CIPTheme.violationRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? CIPTheme.saudiNavy : CIPTheme.grey200,
          width: isSelected ? 2 : 1),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            // Rank
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? CIPTheme.saudiGold.withOpacity(0.15)
                    : CIPTheme.grey100,
                borderRadius: BorderRadius.circular(7)),
              child: Center(child: Text('#$rank',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: rank <= 3 ? CIPTheme.saudiGold : CIPTheme.grey500)))),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Line ${result.lineNumber}',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w800, color: CIPTheme.saudiNavy)),
                Text('PRN: ${result.ownerPRN}  ·  ${result.date}',
                    style: const TextStyle(fontSize: 11, color: CIPTheme.grey500)),
              ])),
            // Score badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: Text('${sc.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                      color: scoreColor))),
          ]),
        ),
        // Route timeline
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: _RouteTimeline(
              route: result.routePattern, legTypes: result.legTypePattern)),
        // Stats + tags
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: BoxDecoration(
            color: CIPTheme.grey50,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
          child: Column(children: [
            Row(children: [
              _stat('⏱', '${result.blockHours.toStringAsFixed(1)}h'),
              const SizedBox(width: 10),
              _stat('📋', '${result.dutyHours.toStringAsFixed(1)}h duty'),
              const SizedBox(width: 10),
              _stat('💤', '${result.restAfterHours.toStringAsFixed(1)}h rest'),
              const Spacer(),
              Text('SAR ${result.income.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      fontSize: 13, color: CIPTheme.moneyGreen)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _tag(result.legalityPassed ? 'Legal ✅' : 'Illegal ❌',
                  result.legalityPassed ? CIPTheme.legalGreen : CIPTheme.violationRed),
              const SizedBox(width: 6),
              _tag(_fatLabel(result.fatigueLevel), _fatColor(result.fatigueLevel)),
              const SizedBox(width: 6),
              _tag(result.difficulty.name.toUpperCase(),
                  result.difficulty == TradeDifficulty.easy
                      ? CIPTheme.legalGreen : result.difficulty == TradeDifficulty.medium
                      ? CIPTheme.warningAmber : CIPTheme.violationRed),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: result.ownerPRN));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PRN copied!'),
                        duration: Duration(seconds: 1)));
                },
                child: const Icon(Icons.copy, size: 16, color: CIPTheme.grey500)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onOutreach,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF25D366).withOpacity(0.12)
                        : CIPTheme.grey100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: isSelected
                            ? const Color(0xFF25D366) : CIPTheme.grey200)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.chat, size: 13,
                        color: isSelected
                            ? const Color(0xFF25D366) : CIPTheme.grey500),
                    const SizedBox(width: 4),
                    Text('Contact', style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? const Color(0xFF25D366) : CIPTheme.grey500)),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(String icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Text(icon, style: const TextStyle(fontSize: 11)),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: CIPTheme.grey700))]);

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(fontSize: 10,
        fontWeight: FontWeight.w700, color: color)));

  String _fatLabel(TradeFatigueLevel l) =>
      l == TradeFatigueLevel.low ? 'Fatigue: LOW'
      : l == TradeFatigueLevel.medium ? 'Fatigue: MED' : 'Fatigue: HIGH';

  Color _fatColor(TradeFatigueLevel l) =>
      l == TradeFatigueLevel.low ? CIPTheme.legalGreen
      : l == TradeFatigueLevel.medium ? CIPTheme.warningAmber : CIPTheme.violationRed;
}

// ── Route Timeline ────────────────────────────────────────────────
class _RouteTimeline extends StatelessWidget {
  final String route;
  final List<String> legTypes;
  const _RouteTimeline({required this.route, required this.legTypes});

  @override
  Widget build(BuildContext context) {
    final airports = route.split('→');
    if (airports.length < 2) return Text(route,
        style: const TextStyle(fontWeight: FontWeight.w600, color: CIPTheme.grey700));
    return Row(children: [
      for (int i = 0; i < airports.length; i++) ...[
        _dot(airports[i].trim()),
        if (i < airports.length - 1)
          Expanded(child: _arrow(i < legTypes.length ? legTypes[i] : 'OPERATING')),
      ],
    ]);
  }

  Widget _dot(String code) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(color: CIPTheme.saudiNavy,
        borderRadius: BorderRadius.circular(8)),
    child: Center(child: Text(code.length > 3 ? code.substring(0,3) : code,
        style: const TextStyle(color: Colors.white, fontSize: 9,
            fontWeight: FontWeight.w800, letterSpacing: 0.5))));

  Widget _arrow(String type) {
    final isDH = type == 'DEADHEAD';
    return Column(children: [
      Row(children: [
        Expanded(child: Container(height: 1.5,
            color: isDH ? CIPTheme.warningAmber : CIPTheme.saudiNavy,
            margin: const EdgeInsets.symmetric(horizontal: 4))),
        Icon(Icons.arrow_forward, size: 12,
            color: isDH ? CIPTheme.warningAmber : CIPTheme.saudiNavy),
      ]),
      const SizedBox(height: 2),
      Text(isDH ? 'DH' : 'OP', style: TextStyle(fontSize: 8,
          fontWeight: FontWeight.w700,
          color: isDH ? CIPTheme.warningAmber : CIPTheme.grey500)),
    ]);
  }
}

// ── WhatsApp Outreach Screen ──────────────────────────────────────
class TradeOutreachScreen extends ConsumerStatefulWidget {
  final List<TradeMatchResult> matches;
  const TradeOutreachScreen({super.key, required this.matches});

  @override
  ConsumerState<TradeOutreachScreen> createState() => _OutreachState();
}

class _OutreachState extends ConsumerState<TradeOutreachScreen> {
  final _msg   = TextEditingController();
  final _phone = TextEditingController();
  int _idx = 0;
  final Map<String, String> _phones = {};
  final Map<String, String> _status = {};

  @override
  void initState() {
    super.initState();
    _msg.text = 'Hi, I would like to discuss a trade with you. Are you interested? Please let me know.';
    for (final m in widget.matches) {
      if (m.phoneNumber != null) _phones[m.ownerPRN] = m.phoneNumber!;
    }
  }

  @override
  void dispose() { _msg.dispose(); _phone.dispose(); super.dispose(); }

  bool get _done => _idx >= widget.matches.length;
  TradeMatchResult get _current => widget.matches[_idx];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CIPTheme.grey50,
    appBar: AppBar(
      backgroundColor: Colors.white, foregroundColor: CIPTheme.grey900,
      title: const Text('WhatsApp Outreach',
          style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        if (!_done) Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(child: Text('${_idx + 1} / ${widget.matches.length}',
              style: const TextStyle(color: CIPTheme.grey500,
                  fontWeight: FontWeight.w700)))),
      ],
    ),
    body: _done ? _buildDone() : _buildFlow(),
  );

  Widget _buildFlow() {
    final m = _current;
    final phone = _phones[m.ownerPRN] ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Progress
        LinearProgressIndicator(value: _idx / widget.matches.length,
            backgroundColor: CIPTheme.grey200,
            valueColor: const AlwaysStoppedAnimation(CIPTheme.saudiNavy)),
        const SizedBox(height: 16),
        // Match info card
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: CIPTheme.saudiNavy,
                  borderRadius: BorderRadius.circular(6)),
              child: Text('Line ${m.lineNumber}', style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
            const SizedBox(width: 8),
            Text('${m.tradeScore.toStringAsFixed(0)}% match',
                style: const TextStyle(color: CIPTheme.legalGreen,
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          _row('PRN', m.ownerPRN), _row('Route', m.routePattern),
          _row('Date', m.date), _row('Block', '${m.blockHours.toStringAsFixed(1)}h'),
        ])),
        const SizedBox(height: 12),
        // Step 1: Copy PRN
        _stepCard(1, 'Copy PRN', 'Search in Outlook to get their phone number',
          Row(children: [
            Expanded(child: Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: CIPTheme.grey50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CIPTheme.grey200)),
              child: Text(m.ownerPRN, style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w900, color: CIPTheme.saudiNavy,
                  letterSpacing: 2)))),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: m.ownerPRN));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('PRN copied!'), duration: Duration(seconds: 1)));
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: CIPTheme.saudiNavy, foregroundColor: Colors.white)),
          ])),
        const SizedBox(height: 10),
        // Step 2: Phone
        _stepCard(2, 'Enter Phone Number',
          phone.isNotEmpty ? '✅ Previously saved' : 'Paste from Outlook',
          TextFormField(
            controller: _phone..text = phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '+966 5X XXX XXXX', filled: true,
              fillColor: CIPTheme.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: CIPTheme.grey200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: CIPTheme.grey200)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            onChanged: (v) => setState(() => _phones[m.ownerPRN] = v))),
        const SizedBox(height: 10),
        // Step 3: Message
        _stepCard(3, 'Message', 'Edit if needed',
          TextFormField(controller: _msg, maxLines: 4,
            decoration: InputDecoration(filled: true, fillColor: CIPTheme.grey50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: CIPTheme.grey200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: CIPTheme.grey200))))),
        const SizedBox(height: 20),
        // Actions
        Row(children: [
          Expanded(child: OutlinedButton(
              onPressed: () => _advance('skipped'),
              child: const Text('Skip'))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: _phones[m.ownerPRN]?.isNotEmpty == true ? _openWhatsApp : null,
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Open WhatsApp', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48)))),
        ]),
        if (_status[m.ownerPRN] == 'opened') ...[
          const SizedBox(height: 12),
          SizedBox(width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _advance('sent'),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark as Sent ✅'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: CIPTheme.legalGreen,
                  foregroundColor: Colors.white))),
        ],
      ]));
  }

  void _openWhatsApp() async {
    final p = (_phones[_current.ownerPRN] ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    final d = p.startsWith('+') ? p.substring(1) : p;
    final url = Uri.parse('https://wa.me/$d?text=${Uri.encodeComponent(_msg.text)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      setState(() => _status[_current.ownerPRN] = 'opened');
    }
  }

  void _advance(String status) => setState(() {
    _status[_current.ownerPRN] = status;
    _idx++;
    _phone.clear();
  });

  Widget _buildDone() {
    final sent = _status.values.where((s) => s == 'sent').length;
    return Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 20),
        const Text('Outreach Complete',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        const SizedBox(height: 8),
        Text('Sent to $sent of ${widget.matches.length} crew members.',
            style: const TextStyle(color: CIPTheme.grey500, fontSize: 15)),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: () => context.pop(),
            child: const Text('Back to Results')),
      ])));
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200)),
    child: child);

  Widget _stepCard(int step, String title, String sub, Widget child) =>
    _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 22, height: 22,
          decoration: const BoxDecoration(color: CIPTheme.saudiNavy, shape: BoxShape.circle),
          child: Center(child: Text('$step', style: const TextStyle(color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
      Padding(padding: const EdgeInsets.only(left: 30, top: 2, bottom: 10),
          child: Text(sub, style: const TextStyle(color: CIPTheme.grey500, fontSize: 12))),
      child,
    ]));

  Widget _row(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 55, child: Text(l,
          style: const TextStyle(fontSize: 12, color: CIPTheme.grey500))),
      Text(v, style: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.w600, color: CIPTheme.grey900)),
    ]));
}
