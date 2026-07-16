// Trade Recommendation Models
// All UI-facing models — no hidden labels, only operational data

enum FatigueLevel { low, medium, high }
enum TradeOutcome { accepted, rejected, viewed, expired }
enum PRNContactStatus { pending, sent, failed }

// ── Trade Match ───────────────────────────────────────────────────────────────

class TradeMatch {
  final String prn;
  final double compatibilityPct;
  final bool isLegal;
  final FatigueLevel fatigueLevel;
  final String routeMatchLabel;
  final List<String> reasons;
  final Map<String, double> componentScores;
  PRNContactStatus contactStatus;
  String? contactNote;

  TradeMatch({
    required this.prn,
    required this.compatibilityPct,
    required this.isLegal,
    required this.fatigueLevel,
    required this.routeMatchLabel,
    required this.reasons,
    required this.componentScores,
    this.contactStatus = PRNContactStatus.pending,
    this.contactNote,
  });

  factory TradeMatch.fromMap(Map<String, dynamic> m) => TradeMatch(
    prn:              m['prn']               ?? '',
    compatibilityPct: (m['compatibility_pct'] as num?)?.toDouble() ?? 0,
    isLegal:          m['is_legal']           ?? true,
    fatigueLevel:     _fatigue(m['fatigue_level']),
    routeMatchLabel:  m['route_match_label']  ?? 'Unknown',
    reasons:          List<String>.from(m['reasons'] ?? []),
    componentScores:  Map<String, double>.from(
      (m['component_scores'] as Map? ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
    ),
  );

  static FatigueLevel _fatigue(dynamic v) {
    switch ((v ?? '').toString().toLowerCase()) {
      case 'high':   return FatigueLevel.high;
      case 'medium': return FatigueLevel.medium;
      default:       return FatigueLevel.low;
    }
  }

  String get compatibilityLabel => '${compatibilityPct.toStringAsFixed(0)}%';

  String get statusEmoji {
    switch (contactStatus) {
      case PRNContactStatus.sent:    return '✅';
      case PRNContactStatus.failed:  return '❌';
      case PRNContactStatus.pending: return '⏳';
    }
  }
}

// ── Search result ─────────────────────────────────────────────────────────────

class TradeSearchResult {
  final String route;
  final String month;
  final int totalScanned;
  final int legalCount;
  final int matchCount;
  final bool isColdStart;
  final List<TradeMatch> matches;

  const TradeSearchResult({
    required this.route,
    required this.month,
    required this.totalScanned,
    required this.legalCount,
    required this.matchCount,
    required this.isColdStart,
    required this.matches,
  });

  factory TradeSearchResult.fromMap(Map<String, dynamic> m) => TradeSearchResult(
    route:        m['route']          ?? '',
    month:        m['month']          ?? '',
    totalScanned: m['total_scanned']  ?? 0,
    legalCount:   m['legal_count']    ?? 0,
    matchCount:   m['match_count']    ?? 0,
    isColdStart:  m['is_cold_start']  ?? true,
    matches: (m['matches'] as List? ?? [])
        .map((e) => TradeMatch.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

// ── Preference summary (user-facing only) ─────────────────────────────────────

class UserPreferenceSummary {
  final int totalEvents;
  final bool isColdStart;
  final List<String> topRoutes;
  final List<String> topDestinations;
  final String preferredTiming;
  final String fatigueTolerance;
  final bool prefersInternational;
  final bool prefersLongLayovers;
  final bool avoidsEarlySignin;

  const UserPreferenceSummary({
    required this.totalEvents,
    required this.isColdStart,
    required this.topRoutes,
    required this.topDestinations,
    required this.preferredTiming,
    required this.fatigueTolerance,
    required this.prefersInternational,
    required this.prefersLongLayovers,
    required this.avoidsEarlySignin,
  });

  factory UserPreferenceSummary.fromMap(Map<String, dynamic> m) =>
      UserPreferenceSummary(
        totalEvents:         m['totalEvents']          ?? 0,
        isColdStart:         m['isColdStart']          ?? true,
        topRoutes:           List<String>.from(m['topRoutes'] ?? []),
        topDestinations:     List<String>.from(m['topDestinations'] ?? []),
        preferredTiming:     m['preferredTiming']      ?? 'morning',
        fatigueTolerance:    m['fatigueToleranceLevel']?? 'medium',
        prefersInternational:m['prefersInternational'] ?? false,
        prefersLongLayovers: m['prefersLongLayovers']  ?? false,
        avoidsEarlySignin:   m['avoidsEarlySignin']    ?? false,
      );
}
