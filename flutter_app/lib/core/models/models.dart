// ─── models.dart — All core domain models ────────────────────────────────────
// Run: flutter pub run build_runner build --delete-conflicting-outputs

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'models.freezed.dart';
part 'models.g.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum CrewRank { GD, PCA, BUT, CHF, SNF, YCA, CA, FO }
enum UserMode { money, rest, balanced }
enum SubscriptionTier { free, pro, elite, enterprise }
enum LegType { domestic, international, positioning }
enum LegalityStatus { legal, warning, violation }
enum BidStatus { draft, submitted, awarded, rejected, withdrawn }
enum TradeType { direct, openDrop, pickUp, swap }
enum TradeStatus { draft, open, matched, pendingConfirm, confirmed, rejected, expired, cancelled }
enum LegalitySeverity { blocking, warning }

// ─── User Model ──────────────────────────────────────────────────────────────

@freezed
class CIPUser with _$CIPUser {
  const factory CIPUser({
    required String id,
    required String crewId,
    required String name,
    required String nameAr,
    required CrewRank rank,
    required String baseStation,
    @Default([]) List<String> fleetTypes,
    required String email,
    @Default('') String phone,
    @Default(UserPreferences()) UserPreferences preferences,
    @Default(UserMode.balanced) UserMode userMode,
    @Default(SubscriptionTier.free) SubscriptionTier subscriptionTier,
    DateTime? subscriptionExpiry,
    // stripeCustomerId removed (0.3) — legacy Stripe is not in the roadmap;
    // json_serializable ignores the stale key on existing Firestore docs.
    @Default({}) Map<String, double> preferenceVector,
    @Default(1) int coldStartPhase,
    @Default(0) int totalMonthsActive,
    @Default(PrivacyConsents()) PrivacyConsents privacyConsents,
    @Default('ar') String locale,
    required DateTime createdAt,
    required DateTime lastActiveAt,
  }) = _CIPUser;

  factory CIPUser.fromJson(Map<String, dynamic> json) => _$CIPUserFromJson(json);

  factory CIPUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CIPUser.fromJson({...data, 'id': doc.id});
  }
}

@freezed
class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    @Default([]) List<String> preferredDest,
    @Default([]) List<String> avoidedDest,
    @Default([]) List<int> preferredOff,  // 0=Sun, 1=Mon...
    @Default(120) double maxDutyHours,
    @Default(10) double minRestHours,
    @Default(true) bool homebaseReturn,
  }) = _UserPreferences;

  factory UserPreferences.fromJson(Map<String, dynamic> json) =>
      _$UserPreferencesFromJson(json);
}

@freezed
class PrivacyConsents with _$PrivacyConsents {
  const factory PrivacyConsents({
    @Default(false) bool behaviorTracking,
    @Default(false) bool collaborativeFiltering,
    DateTime? consentDate,
  }) = _PrivacyConsents;

  factory PrivacyConsents.fromJson(Map<String, dynamic> json) =>
      _$PrivacyConsentsFromJson(json);
}

// ─── Flight Line Model ───────────────────────────────────────────────────────

@freezed
class FlightLine with _$FlightLine {
  const factory FlightLine({
    required String id,
    required String lineNumber,
    required String month,
    required String userId,
    @Default('') String rank,
    required DateTime uploadedAt,
    @Default('pending') String validationStatus,
    @Default(LineSummary()) LineSummary summary,
    @Default([]) List<String> destinations,
    @Default([]) List<int> daysOff,
    @Default(true) bool isActive,
    @Default([]) List<FlightLeg> legs,
  }) = _FlightLine;

  factory FlightLine.fromJson(Map<String, dynamic> json) =>
      _$FlightLineFromJson(json);

  factory FlightLine.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlightLine.fromJson({...data, 'id': doc.id});
  }
}

@freezed
class LineSummary with _$LineSummary {
  const factory LineSummary({
    @Default(0) int totalLegs,
    @Default(0) double totalBlockHours,
    @Default(0) double totalDutyHours,
    @Default(0) int totalDutyDays,
    @Default(0) int internationalLegs,
    @Default(0) int domesticLegs,
    @Default(0) int layoverCount,
    @Default(0) double estimatedSalaryMin,
    @Default(0) double estimatedSalaryMax,
    @Default(0) double salaryScore,
    @Default(0) double restQualityScore,
    @Default(0) double compositeScore,
  }) = _LineSummary;

  factory LineSummary.fromJson(Map<String, dynamic> json) =>
      _$LineSummaryFromJson(json);
}

// ─── Flight Leg Model ────────────────────────────────────────────────────────

@freezed
class FlightLeg with _$FlightLeg {
  const factory FlightLeg({
    required String id,
    required String lineId,
    required String flightNumber,
    required String origin,
    required String destination,
    @Default(LegType.domestic) LegType legType,
    required DateTime departureLT,
    required DateTime arrivalLT,
    required DateTime departureUTC,
    required DateTime arrivalUTC,
    required DateTime dutyStart,
    required DateTime dutyEnd,
    required DateTime releaseTime,
    @Default(0) double blockHours,
    @Default(0) double fdpHours,
    @Default('') String aircraftType,
    @Default(false) bool layover,
    @Default(0) double layoverHours,
    @Default(0) double payRate,
    @Default(0) double estimatedPay,
    @Default(0) double perDiem,
    @Default(LegalityStatus.legal) LegalityStatus legalityStatus,
    @Default([]) List<String> legalityFlags,
    @Default(0) double restAfterHours,
    @Default(0) double restBeforeHours,
    @Default(0) int sequence,
  }) = _FlightLeg;

  factory FlightLeg.fromJson(Map<String, dynamic> json) =>
      _$FlightLegFromJson(json);

  factory FlightLeg.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlightLeg.fromJson({...data, 'id': doc.id});
  }
}

// ─── Bid Model ───────────────────────────────────────────────────────────────

@freezed
class Bid with _$Bid {
  const factory Bid({
    required String id,
    required String userId,
    required String lineId,
    required String lineNumber,
    required String month,
    @Default(1) int priority,
    @Default(BidStatus.draft) BidStatus status,
    @Default(UserMode.balanced) UserMode userMode,
    @Default('') String rank,
    @Default(false) bool isAutoBid,
    @Default([]) List<String> autoReasons,
    @Default(BidScoreSnapshot()) BidScoreSnapshot scoreAtBid,
    @Default(0) double estimatedSalary,
    required DateTime submittedAt,
    DateTime? windowClosedAt,
    DateTime? awardedAt,
    DateTime? withdrawnAt,
  }) = _Bid;

  factory Bid.fromJson(Map<String, dynamic> json) => _$BidFromJson(json);

  factory Bid.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bid.fromJson({...data, 'id': doc.id});
  }
}

@freezed
class BidScoreSnapshot with _$BidScoreSnapshot {
  const factory BidScoreSnapshot({
    @Default(0) double salaryScore,
    @Default(0) double restScore,
    @Default(0) double prefScore,
    @Default(0) double composite,
  }) = _BidScoreSnapshot;

  factory BidScoreSnapshot.fromJson(Map<String, dynamic> json) =>
      _$BidScoreSnapshotFromJson(json);
}

// ─── Trade Model ─────────────────────────────────────────────────────────────

@freezed
class Trade with _$Trade {
  const factory Trade({
    required String id,
    @Default(TradeType.openDrop) TradeType type,
    required String initiatorId,
    @Default('') String initiatorRank,
    String? receiverId,
    @Default(TradeStatus.draft) TradeStatus status,
    required TradeLeg offeredLeg,
    TradeLeg? requestedLeg,
    @Default(TradeLegality()) TradeLegality legality,
    @Default(false) bool isAnonymous,
    @Default('') String note,
    required DateTime expiresAt,
    DateTime? confirmedAt,
    required DateTime createdAt,
  }) = _Trade;

  factory Trade.fromJson(Map<String, dynamic> json) => _$TradeFromJson(json);

  factory Trade.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Trade.fromJson({...data, 'id': doc.id});
  }
}

@freezed
class TradeLeg with _$TradeLeg {
  const factory TradeLeg({
    required String legId,
    required String lineId,
    required String flightNumber,
    required String origin,
    required String destination,
    required DateTime departureUTC,
  }) = _TradeLeg;

  factory TradeLeg.fromJson(Map<String, dynamic> json) =>
      _$TradeLegFromJson(json);
}

@freezed
class TradeLegality with _$TradeLegality {
  const factory TradeLegality({
    @Default(false) bool checked,
    DateTime? checkedAt,
    @Default(LegalityResult()) LegalityResult initiatorResult,
    @Default(LegalityResult()) LegalityResult receiverResult,
  }) = _TradeLegality;

  factory TradeLegality.fromJson(Map<String, dynamic> json) =>
      _$TradeLegalityFromJson(json);
}

// ─── Legality Models ─────────────────────────────────────────────────────────

@freezed
class LegalityResult with _$LegalityResult {
  const factory LegalityResult({
    @Default(true) bool passed,
    @Default([]) List<LegalityViolation> violations,
    @Default([]) List<LegalityViolation> warnings,
  }) = _LegalityResult;

  factory LegalityResult.fromJson(Map<String, dynamic> json) =>
      _$LegalityResultFromJson(json);
}

@freezed
class LegalityViolation with _$LegalityViolation {
  const factory LegalityViolation({
    required String ruleId,
    required String ruleDescription,
    required String ruleDescriptionAr,
    required double actualValue,
    required double requiredValue,
    required String unit,
    @Default(LegalitySeverity.blocking) LegalitySeverity severity,
    @Default([]) List<String> affectedLegIds,
  }) = _LegalityViolation;

  factory LegalityViolation.fromJson(Map<String, dynamic> json) =>
      _$LegalityViolationFromJson(json);
}

// ─── Ranked Line Model (for Smart Ranking display) ───────────────────────────

@freezed
class RankedLine with _$RankedLine {
  const factory RankedLine({
    required FlightLine line,
    @Default(0) double compositeScore,
    @Default(0) double salaryScore,
    @Default(0) double restScore,
    @Default(0) double destPrefScore,
    @Default(0) double regularityScore,
    @Default(0) int rank,
    required String explanation,
    required String explanationAr,
  }) = _RankedLine;

  factory RankedLine.fromJson(Map<String, dynamic> json) =>
      _$RankedLineFromJson(json);
}

// ─── AI Message Model ────────────────────────────────────────────────────────

@freezed
class AIMessage with _$AIMessage {
  const factory AIMessage({
    required String id,
    required String role,  // 'user' | 'assistant'
    required String content,
    @Default('') String intentType,
    required DateTime timestamp,
    @Default(0) int responseTimeMs,
    // Rich content cards
    FlightLine? lineCard,
    Trade? tradeCard,
    LegalityResult? legalityCard,
  }) = _AIMessage;

  factory AIMessage.fromJson(Map<String, dynamic> json) =>
      _$AIMessageFromJson(json);
}

// ─── Notification Model ──────────────────────────────────────────────────────

@freezed
class CIPNotification with _$CIPNotification {
  const factory CIPNotification({
    required String id,
    required String userId,
    required String type,
    required String title,
    required String titleAr,
    required String body,
    required String bodyAr,
    @Default('') String deepLink,
    @Default(false) bool read,
    required DateTime sentAt,
  }) = _CIPNotification;

  factory CIPNotification.fromJson(Map<String, dynamic> json) =>
      _$CIPNotificationFromJson(json);
}
