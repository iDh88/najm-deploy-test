// Filter-engine wire contract (mirror of python_services/filter_engine).
//
// Plain Dart (no codegen) so this compiles independently of build_runner.
// The Manual-Mode UI should render itself from GET /v1/lines/filters
// (FilterCatalogEntry list) — a new server-side filter appears in the app
// with NO release. See VISION_GAP_ANALYSIS.md → "Client phases".

/// One entry of GET /v1/lines/filters — enough to render a control:
/// range → dual slider/number pair · set_any/all/none → chips (enumValues
/// when present, free-text otherwise) · bool → switch · enum → segmented.
class FilterCatalogEntry {
  final String id;
  final String category;
  final String label;
  final String kind; // range | set_any | set_all | set_none | bool | enum
  final String status; // active | requires_field
  final String unit;
  final List<String> enumValues;
  final String note;

  const FilterCatalogEntry({
    required this.id,
    required this.category,
    required this.label,
    required this.kind,
    required this.status,
    this.unit = '',
    this.enumValues = const [],
    this.note = '',
  });

  bool get isActive => status == 'active';

  factory FilterCatalogEntry.fromJson(Map<String, dynamic> j) =>
      FilterCatalogEntry(
        id: j['id'] ?? '',
        category: j['category'] ?? '',
        label: j['label'] ?? '',
        kind: j['kind'] ?? '',
        status: j['status'] ?? 'active',
        unit: j['unit'] ?? '',
        enumValues: List<String>.from(j['enum_values'] ?? const []),
        note: j['note'] ?? '',
      );
}

/// One constraint. `value` shape depends on the filter's kind:
/// range → {"min"?: num, "max"?: num} · set_* → List&lt;String&gt; ·
/// bool → bool · enum → String.
class FilterClause {
  final String filterId;
  final dynamic value;
  final String source; // manual | ai

  const FilterClause({
    required this.filterId,
    required this.value,
    this.source = 'manual',
  });

  Map<String, dynamic> toJson() =>
      {'filter_id': filterId, 'value': value, 'source': source};

  factory FilterClause.fromJson(Map<String, dynamic> j) => FilterClause(
        filterId: j['filter_id'] ?? '',
        value: j['value'],
        source: j['source'] ?? 'manual',
      );
}

class SearchRequest {
  final String? month;
  final List<FilterClause> clauses; // manual — LOCKED in hybrid mode
  final String? aiInstruction; // AI/Hybrid: natural language
  final String rankMode; // money | rest | balanced
  final int limit;

  const SearchRequest({
    this.month,
    this.clauses = const [],
    this.aiInstruction,
    this.rankMode = 'balanced',
    this.limit = 50,
  });

  Map<String, dynamic> toJson() => {
        if (month != null) 'month': month,
        'clauses': clauses.map((c) => c.toJson()).toList(),
        if (aiInstruction != null) 'ai_instruction': aiInstruction,
        'rank_mode': rankMode,
        'limit': limit,
      };
}

class MatchedFilter {
  final String filterId;
  final String label;
  final String source;
  const MatchedFilter(
      {required this.filterId, required this.label, required this.source});

  factory MatchedFilter.fromJson(Map<String, dynamic> j) => MatchedFilter(
        filterId: j['filter_id'] ?? '',
        label: j['label'] ?? '',
        source: j['source'] ?? 'manual',
      );
}

/// One ranked result — carries the FULL "why": which filters admitted it,
/// the per-component score breakdown, and human-readable reasons. Render the
/// reasons as ✓ lines (vision: never a black box).
class RankedResult {
  final String lineId;
  final String lineNumber;
  final int rank;
  final double totalScore;
  final Map<String, double> componentScores;
  final List<MatchedFilter> matchedFilters;
  final List<String> explanation;

  const RankedResult({
    required this.lineId,
    required this.lineNumber,
    required this.rank,
    required this.totalScore,
    required this.componentScores,
    required this.matchedFilters,
    required this.explanation,
  });

  factory RankedResult.fromJson(Map<String, dynamic> j) => RankedResult(
        lineId: j['line_id'] ?? '',
        lineNumber: j['line_number'] ?? '',
        rank: (j['rank'] ?? 0) as int,
        totalScore: (j['total_score'] ?? 0).toDouble(),
        componentScores: (j['component_scores'] as Map<String, dynamic>? ??
                const {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        matchedFilters: (j['matched_filters'] as List<dynamic>? ?? const [])
            .map((e) => MatchedFilter.fromJson(e as Map<String, dynamic>))
            .toList(),
        explanation:
            List<String>.from(j['explanation'] ?? const <String>[]),
      );
}

/// Full disclosure of what actually ran — including every AI clause that
/// was dropped and the reason ("locked by a manual filter", validation
/// message, …). Surface `droppedAi` in the UI so Hybrid Mode is honest.
class AppliedFilters {
  final List<FilterClause> manual;
  final List<FilterClause> ai;
  final List<Map<String, dynamic>> droppedAi;

  const AppliedFilters(
      {this.manual = const [], this.ai = const [], this.droppedAi = const []});

  factory AppliedFilters.fromJson(Map<String, dynamic> j) => AppliedFilters(
        manual: (j['manual'] as List<dynamic>? ?? const [])
            .map((e) => FilterClause.fromJson(e as Map<String, dynamic>))
            .toList(),
        ai: (j['ai'] as List<dynamic>? ?? const [])
            .map((e) => FilterClause.fromJson(e as Map<String, dynamic>))
            .toList(),
        droppedAi: (j['dropped_ai'] as List<dynamic>? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
      );
}

class SearchResponse {
  final List<RankedResult> results;
  final int totalMatched;
  final int totalScanned;
  final AppliedFilters applied;
  final String rankMode;
  final String? aiSummary;

  const SearchResponse({
    required this.results,
    required this.totalMatched,
    required this.totalScanned,
    required this.applied,
    required this.rankMode,
    this.aiSummary,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> j) => SearchResponse(
        results: (j['results'] as List<dynamic>? ?? const [])
            .map((e) => RankedResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalMatched: (j['total_matched'] ?? 0) as int,
        totalScanned: (j['total_scanned'] ?? 0) as int,
        applied: AppliedFilters.fromJson(
            j['applied'] as Map<String, dynamic>? ?? const {}),
        rankMode: j['rank_mode'] ?? 'balanced',
        aiSummary: j['ai_summary'],
      );
}
