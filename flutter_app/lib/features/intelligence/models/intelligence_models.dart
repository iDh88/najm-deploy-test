// lib/features/intelligence/models/intelligence_models.dart
// All Phase 2 data models in one file for simplicity

enum FatigueLevel { low, medium, high }
enum LineTag {
  highFatigue, recoveryFriendly, heavyDeadhead, highIncome,
  internationalHeavy, earlySigninHeavy, longDuty, nightHeavy,
  shortHaulIntensive, optimalBalance, standard
}
enum InsightType { warning, positive, info, tip }
enum SegmentType { operating, deadhead, positioning }

// ── Fatigue ──────────────────────────────────────────────────────────────────

class FatigueScore {
  final double raw;
  final FatigueLevel level;
  final int percentage;
  final int woclMinutes;
  final bool earlySignin;
  final bool nightOps;
  final List<FatigueFactor> factors;

  const FatigueScore({
    required this.raw, required this.level, required this.percentage,
    required this.woclMinutes, required this.earlySignin,
    required this.nightOps, required this.factors,
  });

  factory FatigueScore.fromMap(Map<String, dynamic> m) => FatigueScore(
    raw:          (m['raw'] as num?)?.toDouble() ?? 0,
    level:        _fatigueLevel(m['level']),
    percentage:   m['percentage'] ?? (((m['raw'] ?? 0) as num) * 100).toInt(),
    woclMinutes:  m['woclMinutes'] ?? 0,
    earlySignin:  m['earlySignin'] ?? false,
    nightOps:     m['nightOps'] ?? false,
    factors:      [],
  );

  static FatigueLevel _fatigueLevel(dynamic v) {
    switch ((v ?? '').toString().toUpperCase()) {
      case 'HIGH':   return FatigueLevel.high;
      case 'MEDIUM': return FatigueLevel.medium;
      default:       return FatigueLevel.low;
    }
  }

  String get levelLabel => level.name.toUpperCase();
  String get levelEmoji => level == FatigueLevel.high ? '🔴'
      : level == FatigueLevel.medium ? '🟡' : '🟢';
}

class FatigueFactor {
  final String name;
  final double score;
  final String description;
  const FatigueFactor({required this.name, required this.score, required this.description});
}

class FatiguePoint {
  final DateTime day;
  final double score;
  final double cumulative;
  final FatigueLevel level;
  final String label;
  final double delta;

  const FatiguePoint({
    required this.day, required this.score, required this.cumulative,
    required this.level, required this.label, required this.delta,
  });

  factory FatiguePoint.fromMap(Map<String, dynamic> m) => FatiguePoint(
    day:        DateTime.tryParse(m['day'] ?? '') ?? DateTime.now(),
    score:      (m['score'] as num?)?.toDouble() ?? 0,
    cumulative: (m['cumulative'] as num?)?.toDouble() ?? 0,
    level:      FatigueScore._fatigueLevel(m['level']),
    label:      m['label'] ?? '',
    delta:      (m['delta'] as num?)?.toDouble() ?? 0,
  );
}

class LineFatigueProfile {
  final double averageFatigue;
  final double peakFatigue;
  final int highFatigueDays;
  final FatigueLevel overallLevel;
  final int woclTotalMinutes;
  final int earlySigninCount;
  final List<FatiguePoint> timeline;

  const LineFatigueProfile({
    required this.averageFatigue, required this.peakFatigue,
    required this.highFatigueDays, required this.overallLevel,
    required this.woclTotalMinutes, required this.earlySigninCount,
    required this.timeline,
  });

  factory LineFatigueProfile.fromMap(Map<String, dynamic> m) => LineFatigueProfile(
    averageFatigue:   (m['averageFatigue'] as num?)?.toDouble() ?? 0,
    peakFatigue:      (m['peakFatigue']    as num?)?.toDouble() ?? 0,
    highFatigueDays:  m['highFatigueDays'] ?? 0,
    overallLevel:     FatigueScore._fatigueLevel(m['level']),
    woclTotalMinutes: m['woclMinutes']     ?? 0,
    earlySigninCount: m['earlySigninCount']?? 0,
    timeline:         [],
  );

  int get fatiguePercentage => (averageFatigue * 100).round();
}

// ── Line classification ───────────────────────────────────────────────────────

class LineClassification {
  final String primary;
  final List<String> allTags;
  final String label;
  final String color;
  final String icon;

  const LineClassification({
    required this.primary, required this.allTags,
    required this.label, required this.color, required this.icon,
  });

  factory LineClassification.fromMap(Map<String, dynamic> m) => LineClassification(
    primary: m['primary'] ?? 'STANDARD',
    allTags: List<String>.from(m['allTags'] ?? []),
    label:   m['label']   ?? 'Standard',
    color:   m['color']   ?? '#64748B',
    icon:    m['icon']    ?? '📋',
  );
}

// ── Insight ───────────────────────────────────────────────────────────────────

class LineInsight {
  final InsightType type;
  final String icon;
  final String titleEn;
  final String bodyEn;
  final String titleAr;
  final String bodyAr;
  final int priority;
  final String? metricValue;

  const LineInsight({
    required this.type, required this.icon,
    required this.titleEn, required this.bodyEn,
    required this.titleAr, required this.bodyAr,
    required this.priority, this.metricValue,
  });

  factory LineInsight.fromMap(Map<String, dynamic> m) => LineInsight(
    type:        _insightType(m['type']),
    icon:        m['icon']       ?? 'ℹ️',
    titleEn:     m['titleEn']    ?? '',
    bodyEn:      m['bodyEn']     ?? '',
    titleAr:     m['titleAr']    ?? '',
    bodyAr:      m['bodyAr']     ?? '',
    priority:    m['priority']   ?? 5,
    metricValue: m['metricValue'],
  );

  static InsightType _insightType(dynamic v) {
    switch ((v ?? '').toString().toUpperCase()) {
      case 'WARNING':  return InsightType.warning;
      case 'POSITIVE': return InsightType.positive;
      case 'TIP':      return InsightType.tip;
      default:         return InsightType.info;
    }
  }
}

// ── Summary ───────────────────────────────────────────────────────────────────

class LineSummary {
  final double blockHours;
  final double dutyHours;
  final double deadheadHours;
  final int totalPairings;
  final int operatingLegs;
  final int deadheadLegs;
  final int offDays;
  final int openDays;
  final double estimatedCredit;
  final double estimatedPerDiem;
  final List<String> uniqueDestinations;
  final int internationalCount;
  final int domesticCount;

  const LineSummary({
    required this.blockHours, required this.dutyHours,
    required this.deadheadHours, required this.totalPairings,
    required this.operatingLegs, required this.deadheadLegs,
    required this.offDays, required this.openDays,
    required this.estimatedCredit, required this.estimatedPerDiem,
    required this.uniqueDestinations, required this.internationalCount,
    required this.domesticCount,
  });

  factory LineSummary.fromMap(Map<String, dynamic> m) => LineSummary(
    blockHours:        (m['blockHours']        as num?)?.toDouble() ?? 0,
    dutyHours:         (m['dutyHours']         as num?)?.toDouble() ?? 0,
    deadheadHours:     (m['deadheadHours']     as num?)?.toDouble() ?? 0,
    totalPairings:     m['totalPairings']      ?? 0,
    operatingLegs:     m['operatingLegs']      ?? 0,
    deadheadLegs:      m['deadheadLegs']       ?? 0,
    offDays:           m['offDays']            ?? 0,
    openDays:          m['openDays']           ?? 0,
    estimatedCredit:   (m['estimatedCredit']   as num?)?.toDouble() ?? 0,
    estimatedPerDiem:  (m['estimatedPerDiem']  as num?)?.toDouble() ?? 0,
    uniqueDestinations:List<String>.from(m['uniqueDestinations'] ?? []),
    internationalCount:m['internationalCount'] ?? 0,
    domesticCount:     m['domesticCount']      ?? 0,
  );

  double get deadheadRatio =>
      (operatingLegs + deadheadLegs) > 0
          ? deadheadLegs / (operatingLegs + deadheadLegs)
          : 0;
}

// ── Monthly Line (top-level) ──────────────────────────────────────────────────

class MonthlyLine {
  final String id;
  final String lineNumber;
  final String period;
  final String userId;
  final LineClassification classification;
  final LineSummary summary;
  final LineFatigueProfile fatigueProfile;
  final List<LineInsight> insights;
  final DateTime createdAt;

  const MonthlyLine({
    required this.id, required this.lineNumber, required this.period,
    required this.userId, required this.classification,
    required this.summary, required this.fatigueProfile,
    required this.insights, required this.createdAt,
  });

  factory MonthlyLine.fromFirestore(String docId, Map<String, dynamic> m) =>
      MonthlyLine(
        id:             docId,
        lineNumber:     m['lineNumber']  ?? docId,
        period:         m['period']      ?? '',
        userId:         m['userId']      ?? '',
        classification: LineClassification.fromMap(
            Map<String, dynamic>.from(m['classification'] ?? {})),
        summary:        LineSummary.fromMap(
            Map<String, dynamic>.from(m['summary'] ?? {})),
        fatigueProfile: LineFatigueProfile.fromMap(
            Map<String, dynamic>.from(m['fatigueProfile'] ?? {})),
        insights:       (m['insights'] as List? ?? [])
            .map((i) => LineInsight.fromMap(Map<String, dynamic>.from(i)))
            .toList(),
        createdAt:      (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      );
}

// ── Pairing ───────────────────────────────────────────────────────────────────

class PairingSegment {
  final String flightNumber;
  final String origin;
  final String destination;
  final String departureUtc;
  final String arrivalUtc;
  final int blockMinutes;
  final bool isDeadhead;
  final String? aircraftType;
  final double timezoneDelta;

  const PairingSegment({
    required this.flightNumber, required this.origin,
    required this.destination, required this.departureUtc,
    required this.arrivalUtc, required this.blockMinutes,
    required this.isDeadhead, this.aircraftType,
    required this.timezoneDelta,
  });

  factory PairingSegment.fromMap(Map<String, dynamic> m) => PairingSegment(
    flightNumber:  m['flightNumber'] ?? '',
    origin:        m['origin']       ?? '',
    destination:   m['destination']  ?? '',
    departureUtc:  m['departureUtc'] ?? '',
    arrivalUtc:    m['arrivalUtc']   ?? '',
    blockMinutes:  m['blockMinutes'] ?? 0,
    isDeadhead:    m['isDeadhead']   ?? false,
    aircraftType:  m['aircraftType'],
    timezoneDelta: (m['timezoneDelta'] as num?)?.toDouble() ?? 0,
  );

  double get blockHours => blockMinutes / 60;

  String get routeLabel => '$origin→$destination';
}

class Pairing {
  final String id;
  final String lineId;
  final String pairingNumber;
  final List<String> dates;
  final int dutyMinutes;
  final int blockMinutes;
  final int fdpMinutes;
  final String classification;
  final List<String> patternFlags;
  final bool isLegal;
  final bool isInternational;
  final double deadheadRatio;
  final List<PairingSegment> segments;
  final Map<String, dynamic> legalityMargins;

  const Pairing({
    required this.id, required this.lineId, required this.pairingNumber,
    required this.dates, required this.dutyMinutes, required this.blockMinutes,
    required this.fdpMinutes, required this.classification,
    required this.patternFlags, required this.isLegal,
    required this.isInternational, required this.deadheadRatio,
    required this.segments, required this.legalityMargins,
  });

  factory Pairing.fromFirestore(String docId, Map<String, dynamic> m) => Pairing(
    id:              docId,
    lineId:          m['lineId']          ?? '',
    pairingNumber:   m['pairingNumber']   ?? '',
    dates:           List<String>.from(m['dates'] ?? []),
    dutyMinutes:     m['dutyMinutes']     ?? 0,
    blockMinutes:    m['blockMinutes']    ?? 0,
    fdpMinutes:      m['fdpMinutes']      ?? 0,
    classification:  m['classification'] ?? 'STANDARD',
    patternFlags:    List<String>.from(m['patternFlags'] ?? []),
    isLegal:         m['isLegal']         ?? true,
    isInternational: m['isInternational'] ?? false,
    deadheadRatio:   (m['deadheadRatio']  as num?)?.toDouble() ?? 0,
    segments: (m['segments'] as List? ?? [])
        .map((s) => PairingSegment.fromMap(Map<String, dynamic>.from(s)))
        .toList(),
    legalityMargins: Map<String, dynamic>.from(m['legalityMargins'] ?? {}),
  );

  double get dutyHours  => dutyMinutes  / 60;
  double get blockHours => blockMinutes / 60;
  double get fdpHours   => fdpMinutes   / 60;

  List<PairingSegment> get operatingSegments =>
      segments.where((s) => !s.isDeadhead).toList();
  List<PairingSegment> get deadheadSegments =>
      segments.where((s) => s.isDeadhead).toList();
}

// ── Comparison ────────────────────────────────────────────────────────────────

class LineComparison {
  final String lineAId;
  final String lineBId;
  final String lineALabel;
  final String lineBLabel;
  final double blockHoursDelta;
  final double fatigueDelta;
  final double incomeDelta;
  final int deadheadDelta;
  final String winner;
  final String recommendation;
  final String recommendationEn;
  final Map<String, double> lineARadar;
  final Map<String, double> lineBRadar;

  const LineComparison({
    required this.lineAId, required this.lineBId,
    required this.lineALabel, required this.lineBLabel,
    required this.blockHoursDelta, required this.fatigueDelta,
    required this.incomeDelta, required this.deadheadDelta,
    required this.winner, required this.recommendation,
    required this.recommendationEn,
    required this.lineARadar, required this.lineBRadar,
  });

  factory LineComparison.fromMap(Map<String, dynamic> m) => LineComparison(
    lineAId:          m['lineAId']           ?? '',
    lineBId:          m['lineBId']           ?? '',
    lineALabel:       m['lineALabel']        ?? 'Line A',
    lineBLabel:       m['lineBLabel']        ?? 'Line B',
    blockHoursDelta:  (m['blockHoursDelta']  as num?)?.toDouble() ?? 0,
    fatigueDelta:     (m['fatigueDelta']     as num?)?.toDouble() ?? 0,
    incomeDelta:      (m['incomeDelta']      as num?)?.toDouble() ?? 0,
    deadheadDelta:    m['deadheadDelta']     ?? 0,
    winner:           m['winner']            ?? 'EQUAL',
    recommendation:   m['recommendation']   ?? '',
    recommendationEn: m['recommendationEn'] ?? '',
    lineARadar: Map<String, double>.from(
        (m['lineARadar'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
    lineBRadar: Map<String, double>.from(
        (m['lineBRadar'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()))),
  );
}
