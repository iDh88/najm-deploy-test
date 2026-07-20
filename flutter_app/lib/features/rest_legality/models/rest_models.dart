// Rest & Legality Engine — Flutter Models

enum LegalityStatus { legal, legalMarginal, notLegal }
enum FatigueLevel   { low, medium, high }
enum ViolationSeverity { violation, warning, advisory }

// ── Violation ─────────────────────────────────────────────────────────────────

class LegalityViolation {
  final ViolationSeverity severity;
  final String rule;
  final String description;
  final String actual;
  final String? limit;
  final String? excess;

  const LegalityViolation({
    required this.severity,
    required this.rule,
    required this.description,
    required this.actual,
    this.limit,
    this.excess,
  });

  factory LegalityViolation.fromMap(Map<String, dynamic> m) =>
      LegalityViolation(
        severity:    _sev(m['severity']),
        rule:        m['rule'] as String?        ?? '',
        description: m['description'] as String? ?? '',
        actual:      m['actual'] as String?      ?? '',
        limit:       m['limit'] as String?,
        excess:      m['excess'] as String?,
      );

  static ViolationSeverity _sev(dynamic v) {
    switch ((v ?? '').toString().toUpperCase()) {
      case 'VIOLATION': return ViolationSeverity.violation;
      case 'WARNING':   return ViolationSeverity.warning;
      default:          return ViolationSeverity.advisory;
    }
  }

  String get emoji {
    switch (severity) {
      case ViolationSeverity.violation: return '❌';
      case ViolationSeverity.warning:   return '⚠️';
      case ViolationSeverity.advisory:  return 'ℹ️';
    }
  }
}

// ── Rest Window ───────────────────────────────────────────────────────────────

class RestWindowResult {
  final int    durationMins;
  final int    minimumMins;
  final int    marginMins;
  final bool   isSufficient;
  final bool   isMarginal;
  final String durationLabel;
  final String minimumLabel;
  final String marginLabel;
  final String localStart;
  final String localEnd;

  const RestWindowResult({
    required this.durationMins,
    required this.minimumMins,
    required this.marginMins,
    required this.isSufficient,
    required this.isMarginal,
    required this.durationLabel,
    required this.minimumLabel,
    required this.marginLabel,
    required this.localStart,
    required this.localEnd,
  });

  factory RestWindowResult.fromMap(Map<String, dynamic> m) => RestWindowResult(
    durationMins:  m['duration_mins'] as int?  ?? 0,
    minimumMins:   m['minimum_mins'] as int?   ?? 0,
    marginMins:    m['margin_mins'] as int?    ?? 0,
    isSufficient:  m['is_sufficient'] as bool?  ?? true,
    isMarginal:    m['is_marginal'] as bool?    ?? false,
    durationLabel: m['duration_label'] as String? ?? '—',
    minimumLabel:  m['minimum_label'] as String?  ?? '—',
    marginLabel:   m['margin_label'] as String?   ?? '—',
    localStart:    m['local_start'] as String?    ?? '',
    localEnd:      m['local_end'] as String?      ?? '',
  );

  double get fillRatio =>
      minimumMins > 0 ? (durationMins / minimumMins).clamp(0.0, 2.0) : 0.0;
}

// ── FDP Result ────────────────────────────────────────────────────────────────

class FDPResult {
  final int    actualMins;
  final int    limitMins;
  final int    marginMins;
  final bool   isWithinLimit;
  final bool   isMarginal;
  final bool   earlySignin;
  final bool   woclPenetration;
  final int    woclMinutes;
  final String actualLabel;
  final String limitLabel;
  final String marginLabel;

  const FDPResult({
    required this.actualMins,
    required this.limitMins,
    required this.marginMins,
    required this.isWithinLimit,
    required this.isMarginal,
    required this.earlySignin,
    required this.woclPenetration,
    required this.woclMinutes,
    required this.actualLabel,
    required this.limitLabel,
    required this.marginLabel,
  });

  factory FDPResult.fromMap(Map<String, dynamic> m) => FDPResult(
    actualMins:     m['actual_mins'] as int?      ?? 0,
    limitMins:      m['limit_mins'] as int?       ?? 840,
    marginMins:     m['margin_mins'] as int?      ?? 0,
    isWithinLimit:  m['is_within_limit'] as bool?  ?? true,
    isMarginal:     m['is_marginal'] as bool?      ?? false,
    earlySignin:    m['early_signin'] as bool?     ?? false,
    woclPenetration:m['wocl_penetration'] as bool? ?? false,
    woclMinutes:    m['wocl_minutes'] as int?     ?? 0,
    actualLabel:    m['actual_label'] as String?     ?? '—',
    limitLabel:     m['limit_label'] as String?      ?? '—',
    marginLabel:    m['margin_label'] as String?     ?? '—',
  );

  double get usageRatio =>
      limitMins > 0 ? (actualMins / limitMins).clamp(0.0, 1.2) : 0.0;
}

// ── Carry Over ────────────────────────────────────────────────────────────────

class CarryOverResult {
  final double carryOverHours;
  final double maxAllowedHours;
  final bool   isWithinLimit;
  final double percentageUsed;
  final double remainingHours;

  const CarryOverResult({
    required this.carryOverHours,
    required this.maxAllowedHours,
    required this.isWithinLimit,
    required this.percentageUsed,
    required this.remainingHours,
  });

  factory CarryOverResult.fromMap(Map<String, dynamic> m) => CarryOverResult(
    carryOverHours:  (m['carry_over_hours']  as num?)?.toDouble() ?? 0,
    maxAllowedHours: (m['max_allowed_hours'] as num?)?.toDouble() ?? 30,
    isWithinLimit:   m['is_within_limit'] as bool?    ?? true,
    percentageUsed:  (m['percentage_used']   as num?)?.toDouble() ?? 0,
    remainingHours:  (m['remaining_hours']   as num?)?.toDouble() ?? 30,
  );
}

// ── Fatigue Factor ────────────────────────────────────────────────────────────

class FatigueFactor {
  final String name;
  final double score;
  final double weight;
  final double weighted;
  final String description;

  const FatigueFactor({
    required this.name,
    required this.score,
    required this.weight,
    required this.weighted,
    required this.description,
  });

  factory FatigueFactor.fromMap(Map<String, dynamic> m) => FatigueFactor(
    name:        m['name'] as String?        ?? '',
    score:       (m['score']      as num?)?.toDouble() ?? 0,
    weight:      (m['weight']     as num?)?.toDouble() ?? 0,
    weighted:    (m['weighted']   as num?)?.toDouble() ?? 0,
    description: m['description'] as String? ?? '',
  );
}

// ── Fatigue Score ─────────────────────────────────────────────────────────────

class FatigueScoreResult {
  final double       raw;
  final int          percentage;
  final FatigueLevel level;
  final String       levelEmoji;
  final int          woclMinutes;
  final bool         earlySignin;
  final String       recommendation;
  final List<FatigueFactor> factors;

  const FatigueScoreResult({
    required this.raw,
    required this.percentage,
    required this.level,
    required this.levelEmoji,
    required this.woclMinutes,
    required this.earlySignin,
    required this.recommendation,
    required this.factors,
  });

  factory FatigueScoreResult.fromMap(Map<String, dynamic> m) =>
      FatigueScoreResult(
        raw:            (m['raw']        as num?)?.toDouble() ?? 0,
        percentage:     m['percentage'] as int?  ?? 0,
        level:          _fl(m['level']),
        levelEmoji:     m['level_emoji'] as String? ?? '🟢',
        woclMinutes:    m['wocl_minutes'] as int? ?? 0,
        earlySignin:    m['early_signin'] as bool? ?? false,
        recommendation: m['recommendation'] as String? ?? '',
        factors: (m['factors'] as List? ?? [])
            .map((f) => FatigueFactor.fromMap(Map<String, dynamic>.from(f as Map)))
            .toList(),
      );

  static FatigueLevel _fl(dynamic v) {
    switch ((v ?? '').toString().toUpperCase()) {
      case 'HIGH':   return FatigueLevel.high;
      case 'MEDIUM': return FatigueLevel.medium;
      default:       return FatigueLevel.low;
    }
  }
}

// ── Legality Result ───────────────────────────────────────────────────────────

class LegalityResult {
  final bool                 isLegal;
  final String               statusLabel;
  final String               statusEmoji;
  final double               safetyScore;
  final List<LegalityViolation> violations;
  final List<LegalityViolation> warnings;
  final List<LegalityViolation> advisories;
  final RestWindowResult?    rest;
  final FDPResult?           fdp;
  final CarryOverResult?     carryOver;
  final String?              totalDutyLabel;

  const LegalityResult({
    required this.isLegal,
    required this.statusLabel,
    required this.statusEmoji,
    required this.safetyScore,
    required this.violations,
    required this.warnings,
    required this.advisories,
    this.rest,
    this.fdp,
    this.carryOver,
    this.totalDutyLabel,
  });

  factory LegalityResult.fromMap(Map<String, dynamic> m) => LegalityResult(
    isLegal:     m['is_legal'] as bool?      ?? true,
    statusLabel: m['status_label'] as String?  ?? 'LEGAL',
    statusEmoji: m['status_emoji'] as String?  ?? '✅',
    safetyScore: (m['safety_score'] as num?)?.toDouble() ?? 100,
    violations: (m['violations'] as List? ?? [])
        .map((v) => LegalityViolation.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList(),
    warnings: (m['warnings'] as List? ?? [])
        .map((v) => LegalityViolation.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList(),
    advisories: (m['advisories'] as List? ?? [])
        .map((v) => LegalityViolation.fromMap(Map<String, dynamic>.from(v as Map)))
        .toList(),
    rest:     m['rest']      != null
        ? RestWindowResult.fromMap(Map<String, dynamic>.from(m['rest'] as Map))      : null,
    fdp:      m['fdp']       != null
        ? FDPResult.fromMap(Map<String, dynamic>.from(m['fdp'] as Map))              : null,
    carryOver:m['carry_over']!= null
        ? CarryOverResult.fromMap(Map<String, dynamic>.from(m['carry_over'] as Map)): null,
    totalDutyLabel: m['total_duty_label'] as String?,
  );

  LegalityStatus get status {
    if (!isLegal) return LegalityStatus.notLegal;
    if (warnings.isNotEmpty) return LegalityStatus.legalMarginal;
    return LegalityStatus.legal;
  }

  List<LegalityViolation> get allIssues =>
      [...violations, ...warnings, ...advisories];
}

// ── Safety Report ─────────────────────────────────────────────────────────────

class SafetyReport {
  final bool              isLegal;
  final bool              isSafe;
  final double            safetyScore;
  final String            fatigueLevel;
  final double            fatigueScore;
  final String            summary;
  final double            legalityComponent;
  final double            fatigueComponent;
  final double            restComponent;
  final double            fdpComponent;
  final LegalityResult?   legality;
  final FatigueScoreResult? fatigue;

  const SafetyReport({
    required this.isLegal,
    required this.isSafe,
    required this.safetyScore,
    required this.fatigueLevel,
    required this.fatigueScore,
    required this.summary,
    required this.legalityComponent,
    required this.fatigueComponent,
    required this.restComponent,
    required this.fdpComponent,
    this.legality,
    this.fatigue,
  });

  factory SafetyReport.fromMap(Map<String, dynamic> m) => SafetyReport(
    isLegal:           m['is_legal'] as bool?            ?? true,
    isSafe:            m['is_safe'] as bool?             ?? true,
    safetyScore:       (m['safety_score']       as num?)?.toDouble() ?? 100,
    fatigueLevel:      m['fatigue_level'] as String?        ?? 'LOW',
    fatigueScore:      (m['fatigue_score']       as num?)?.toDouble() ?? 0,
    summary:           m['summary'] as String?             ?? '',
    legalityComponent: (m['legality_component'] as num?)?.toDouble() ?? 0,
    fatigueComponent:  (m['fatigue_component']  as num?)?.toDouble() ?? 0,
    restComponent:     (m['rest_component']     as num?)?.toDouble() ?? 0,
    fdpComponent:      (m['fdp_component']      as num?)?.toDouble() ?? 0,
    legality: m['legality'] != null
        ? LegalityResult.fromMap(Map<String, dynamic>.from(m['legality'] as Map))   : null,
    fatigue: m['fatigue'] != null
        ? FatigueScoreResult.fromMap(Map<String, dynamic>.from(m['fatigue'] as Map)): null,
  );
}

// ── Trade Safety Result ───────────────────────────────────────────────────────

class TradeSafetyResult {
  final bool   tradeIsSafe;
  final double avgSafetyScore;
  final String recommendation;
  final Map<String, dynamic> offered;
  final Map<String, dynamic> requested;

  const TradeSafetyResult({
    required this.tradeIsSafe,
    required this.avgSafetyScore,
    required this.recommendation,
    required this.offered,
    required this.requested,
  });

  factory TradeSafetyResult.fromMap(Map<String, dynamic> m) => TradeSafetyResult(
    tradeIsSafe:    m['trade_is_safe'] as bool?    ?? false,
    avgSafetyScore: (m['avg_safety_score'] as num?)?.toDouble() ?? 0,
    recommendation: m['recommendation'] as String?  ?? '',
    offered:   Map<String, dynamic>.from(m['offered'] as Map?   ?? {}),
    requested: Map<String, dynamic>.from(m['requested'] as Map? ?? {}),
  );
}
