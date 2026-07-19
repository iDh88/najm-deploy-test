// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CIPUserImpl _$$CIPUserImplFromJson(Map<String, dynamic> json) =>
    _$CIPUserImpl(
      id: json['id'] as String,
      crewId: json['crewId'] as String,
      name: json['name'] as String,
      nameAr: json['nameAr'] as String,
      rank: $enumDecode(_$CrewRankEnumMap, json['rank']),
      baseStation: json['baseStation'] as String,
      fleetTypes: (json['fleetTypes'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      preferences: json['preferences'] == null
          ? const UserPreferences()
          : UserPreferences.fromJson(
              json['preferences'] as Map<String, dynamic>),
      userMode: $enumDecodeNullable(_$UserModeEnumMap, json['userMode']) ??
          UserMode.balanced,
      subscriptionTier: $enumDecodeNullable(
              _$SubscriptionTierEnumMap, json['subscriptionTier']) ??
          SubscriptionTier.free,
      subscriptionExpiry: json['subscriptionExpiry'] == null
          ? null
          : DateTime.parse(json['subscriptionExpiry'] as String),
      preferenceVector:
          (json['preferenceVector'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, (e as num).toDouble()),
              ) ??
              const {},
      coldStartPhase: (json['coldStartPhase'] as num?)?.toInt() ?? 1,
      totalMonthsActive: (json['totalMonthsActive'] as num?)?.toInt() ?? 0,
      privacyConsents: json['privacyConsents'] == null
          ? const PrivacyConsents()
          : PrivacyConsents.fromJson(
              json['privacyConsents'] as Map<String, dynamic>),
      locale: json['locale'] as String? ?? 'ar',
      accountStatus: json['accountStatus'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastActiveAt: DateTime.parse(json['lastActiveAt'] as String),
    );

Map<String, dynamic> _$$CIPUserImplToJson(_$CIPUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'crewId': instance.crewId,
      'name': instance.name,
      'nameAr': instance.nameAr,
      'rank': _$CrewRankEnumMap[instance.rank]!,
      'baseStation': instance.baseStation,
      'fleetTypes': instance.fleetTypes,
      'email': instance.email,
      'phone': instance.phone,
      'preferences': instance.preferences,
      'userMode': _$UserModeEnumMap[instance.userMode]!,
      'subscriptionTier': _$SubscriptionTierEnumMap[instance.subscriptionTier]!,
      'subscriptionExpiry': instance.subscriptionExpiry?.toIso8601String(),
      'preferenceVector': instance.preferenceVector,
      'coldStartPhase': instance.coldStartPhase,
      'totalMonthsActive': instance.totalMonthsActive,
      'privacyConsents': instance.privacyConsents,
      'locale': instance.locale,
      'accountStatus': instance.accountStatus,
      'createdAt': instance.createdAt.toIso8601String(),
      'lastActiveAt': instance.lastActiveAt.toIso8601String(),
    };

const _$CrewRankEnumMap = {
  CrewRank.GD: 'GD',
  CrewRank.PCA: 'PCA',
  CrewRank.BUT: 'BUT',
  CrewRank.CHF: 'CHF',
  CrewRank.SNF: 'SNF',
  CrewRank.YCA: 'YCA',
  CrewRank.CA: 'CA',
  CrewRank.FO: 'FO',
};

const _$UserModeEnumMap = {
  UserMode.money: 'money',
  UserMode.rest: 'rest',
  UserMode.balanced: 'balanced',
};

const _$SubscriptionTierEnumMap = {
  SubscriptionTier.free: 'free',
  SubscriptionTier.pro: 'pro',
  SubscriptionTier.elite: 'elite',
  SubscriptionTier.enterprise: 'enterprise',
};

_$UserPreferencesImpl _$$UserPreferencesImplFromJson(
        Map<String, dynamic> json) =>
    _$UserPreferencesImpl(
      preferredDest: (json['preferredDest'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      avoidedDest: (json['avoidedDest'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      preferredOff: (json['preferredOff'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      maxDutyHours: (json['maxDutyHours'] as num?)?.toDouble() ?? 120,
      minRestHours: (json['minRestHours'] as num?)?.toDouble() ?? 10,
      homebaseReturn: json['homebaseReturn'] as bool? ?? true,
    );

Map<String, dynamic> _$$UserPreferencesImplToJson(
        _$UserPreferencesImpl instance) =>
    <String, dynamic>{
      'preferredDest': instance.preferredDest,
      'avoidedDest': instance.avoidedDest,
      'preferredOff': instance.preferredOff,
      'maxDutyHours': instance.maxDutyHours,
      'minRestHours': instance.minRestHours,
      'homebaseReturn': instance.homebaseReturn,
    };

_$PrivacyConsentsImpl _$$PrivacyConsentsImplFromJson(
        Map<String, dynamic> json) =>
    _$PrivacyConsentsImpl(
      behaviorTracking: json['behaviorTracking'] as bool? ?? false,
      collaborativeFiltering: json['collaborativeFiltering'] as bool? ?? false,
      consentDate: json['consentDate'] == null
          ? null
          : DateTime.parse(json['consentDate'] as String),
    );

Map<String, dynamic> _$$PrivacyConsentsImplToJson(
        _$PrivacyConsentsImpl instance) =>
    <String, dynamic>{
      'behaviorTracking': instance.behaviorTracking,
      'collaborativeFiltering': instance.collaborativeFiltering,
      'consentDate': instance.consentDate?.toIso8601String(),
    };

_$FlightLineImpl _$$FlightLineImplFromJson(Map<String, dynamic> json) =>
    _$FlightLineImpl(
      id: json['id'] as String,
      lineNumber: json['lineNumber'] as String,
      month: json['month'] as String,
      userId: json['userId'] as String,
      rank: json['rank'] as String? ?? '',
      lineType: json['lineType'] as String? ?? '',
      carryOver: json['carryOver'] as String? ?? '',
      base: json['base'] as String? ?? '',
      category: json['category'] as String? ?? '',
      creditHours: (json['creditHours'] as num?)?.toDouble() ?? 0,
      blockHours: (json['blockHours'] as num?)?.toDouble() ?? 0,
      carryOverHours: (json['carryOverHours'] as num?)?.toDouble() ?? 0,
      totalLegs: (json['totalLegs'] as num?)?.toInt() ?? 0,
      fourLegCount: (json['fourLegCount'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
      allowance: (json['allowance'] as num?)?.toDouble() ?? 0,
      income: (json['income'] as num?)?.toDouble() ?? 0,
      hasStarDays: json['hasStarDays'] as bool? ?? false,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      validationStatus: json['validationStatus'] as String? ?? 'pending',
      summary: json['summary'] == null
          ? const LineSummary()
          : LineSummary.fromJson(json['summary'] as Map<String, dynamic>),
      destinations: (json['destinations'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      destinationDetails: (json['destinationDetails'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      daysOff: (json['daysOff'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      isActive: json['isActive'] as bool? ?? true,
      legs: (json['legs'] as List<dynamic>?)
              ?.map((e) => FlightLeg.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$FlightLineImplToJson(_$FlightLineImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lineNumber': instance.lineNumber,
      'month': instance.month,
      'userId': instance.userId,
      'rank': instance.rank,
      'lineType': instance.lineType,
      'carryOver': instance.carryOver,
      'base': instance.base,
      'category': instance.category,
      'creditHours': instance.creditHours,
      'blockHours': instance.blockHours,
      'carryOverHours': instance.carryOverHours,
      'totalLegs': instance.totalLegs,
      'fourLegCount': instance.fourLegCount,
      'expense': instance.expense,
      'allowance': instance.allowance,
      'income': instance.income,
      'hasStarDays': instance.hasStarDays,
      'uploadedAt': instance.uploadedAt.toIso8601String(),
      'validationStatus': instance.validationStatus,
      'summary': instance.summary,
      'destinations': instance.destinations,
      'destinationDetails': instance.destinationDetails,
      'daysOff': instance.daysOff,
      'isActive': instance.isActive,
      'legs': instance.legs,
    };

_$LineSummaryImpl _$$LineSummaryImplFromJson(Map<String, dynamic> json) =>
    _$LineSummaryImpl(
      totalLegs: (json['totalLegs'] as num?)?.toInt() ?? 0,
      totalBlockHours: (json['totalBlockHours'] as num?)?.toDouble() ?? 0,
      totalDutyHours: (json['totalDutyHours'] as num?)?.toDouble() ?? 0,
      totalDutyDays: (json['totalDutyDays'] as num?)?.toInt() ?? 0,
      internationalLegs: (json['internationalLegs'] as num?)?.toInt() ?? 0,
      domesticLegs: (json['domesticLegs'] as num?)?.toInt() ?? 0,
      layoverCount: (json['layoverCount'] as num?)?.toInt() ?? 0,
      estimatedSalaryMin: (json['estimatedSalaryMin'] as num?)?.toDouble() ?? 0,
      estimatedSalaryMax: (json['estimatedSalaryMax'] as num?)?.toDouble() ?? 0,
      salaryScore: (json['salaryScore'] as num?)?.toDouble() ?? 0,
      restQualityScore: (json['restQualityScore'] as num?)?.toDouble() ?? 0,
      compositeScore: (json['compositeScore'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$$LineSummaryImplToJson(_$LineSummaryImpl instance) =>
    <String, dynamic>{
      'totalLegs': instance.totalLegs,
      'totalBlockHours': instance.totalBlockHours,
      'totalDutyHours': instance.totalDutyHours,
      'totalDutyDays': instance.totalDutyDays,
      'internationalLegs': instance.internationalLegs,
      'domesticLegs': instance.domesticLegs,
      'layoverCount': instance.layoverCount,
      'estimatedSalaryMin': instance.estimatedSalaryMin,
      'estimatedSalaryMax': instance.estimatedSalaryMax,
      'salaryScore': instance.salaryScore,
      'restQualityScore': instance.restQualityScore,
      'compositeScore': instance.compositeScore,
    };

_$FlightLegImpl _$$FlightLegImplFromJson(Map<String, dynamic> json) =>
    _$FlightLegImpl(
      id: json['id'] as String,
      lineId: json['lineId'] as String,
      flightNumber: json['flightNumber'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      legType: $enumDecodeNullable(_$LegTypeEnumMap, json['legType']) ??
          LegType.domestic,
      departureLT: DateTime.parse(json['departureLT'] as String),
      arrivalLT: DateTime.parse(json['arrivalLT'] as String),
      departureUTC: DateTime.parse(json['departureUTC'] as String),
      arrivalUTC: DateTime.parse(json['arrivalUTC'] as String),
      dutyStart: DateTime.parse(json['dutyStart'] as String),
      dutyEnd: DateTime.parse(json['dutyEnd'] as String),
      releaseTime: DateTime.parse(json['releaseTime'] as String),
      blockHours: (json['blockHours'] as num?)?.toDouble() ?? 0,
      fdpHours: (json['fdpHours'] as num?)?.toDouble() ?? 0,
      aircraftType: json['aircraftType'] as String? ?? '',
      layover: json['layover'] as bool? ?? false,
      layoverHours: (json['layoverHours'] as num?)?.toDouble() ?? 0,
      payRate: (json['payRate'] as num?)?.toDouble() ?? 0,
      estimatedPay: (json['estimatedPay'] as num?)?.toDouble() ?? 0,
      perDiem: (json['perDiem'] as num?)?.toDouble() ?? 0,
      legalityStatus: $enumDecodeNullable(
              _$LegalityStatusEnumMap, json['legalityStatus']) ??
          LegalityStatus.legal,
      legalityFlags: (json['legalityFlags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      restAfterHours: (json['restAfterHours'] as num?)?.toDouble() ?? 0,
      restBeforeHours: (json['restBeforeHours'] as num?)?.toDouble() ?? 0,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$FlightLegImplToJson(_$FlightLegImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lineId': instance.lineId,
      'flightNumber': instance.flightNumber,
      'origin': instance.origin,
      'destination': instance.destination,
      'legType': _$LegTypeEnumMap[instance.legType]!,
      'departureLT': instance.departureLT.toIso8601String(),
      'arrivalLT': instance.arrivalLT.toIso8601String(),
      'departureUTC': instance.departureUTC.toIso8601String(),
      'arrivalUTC': instance.arrivalUTC.toIso8601String(),
      'dutyStart': instance.dutyStart.toIso8601String(),
      'dutyEnd': instance.dutyEnd.toIso8601String(),
      'releaseTime': instance.releaseTime.toIso8601String(),
      'blockHours': instance.blockHours,
      'fdpHours': instance.fdpHours,
      'aircraftType': instance.aircraftType,
      'layover': instance.layover,
      'layoverHours': instance.layoverHours,
      'payRate': instance.payRate,
      'estimatedPay': instance.estimatedPay,
      'perDiem': instance.perDiem,
      'legalityStatus': _$LegalityStatusEnumMap[instance.legalityStatus]!,
      'legalityFlags': instance.legalityFlags,
      'restAfterHours': instance.restAfterHours,
      'restBeforeHours': instance.restBeforeHours,
      'sequence': instance.sequence,
    };

const _$LegTypeEnumMap = {
  LegType.domestic: 'domestic',
  LegType.international: 'international',
  LegType.positioning: 'positioning',
};

const _$LegalityStatusEnumMap = {
  LegalityStatus.legal: 'legal',
  LegalityStatus.warning: 'warning',
  LegalityStatus.violation: 'violation',
};

_$BidImpl _$$BidImplFromJson(Map<String, dynamic> json) => _$BidImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      lineId: json['lineId'] as String,
      lineNumber: json['lineNumber'] as String,
      month: json['month'] as String,
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      status: $enumDecodeNullable(_$BidStatusEnumMap, json['status']) ??
          BidStatus.draft,
      userMode: $enumDecodeNullable(_$UserModeEnumMap, json['userMode']) ??
          UserMode.balanced,
      rank: json['rank'] as String? ?? '',
      lineType: json['lineType'] as String? ?? '',
      carryOver: json['carryOver'] as String? ?? '',
      base: json['base'] as String? ?? '',
      category: json['category'] as String? ?? '',
      creditHours: (json['creditHours'] as num?)?.toDouble() ?? 0,
      blockHours: (json['blockHours'] as num?)?.toDouble() ?? 0,
      carryOverHours: (json['carryOverHours'] as num?)?.toDouble() ?? 0,
      totalLegs: (json['totalLegs'] as num?)?.toInt() ?? 0,
      fourLegCount: (json['fourLegCount'] as num?)?.toInt() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
      allowance: (json['allowance'] as num?)?.toDouble() ?? 0,
      income: (json['income'] as num?)?.toDouble() ?? 0,
      hasStarDays: json['hasStarDays'] as bool? ?? false,
      isAutoBid: json['isAutoBid'] as bool? ?? false,
      autoReasons: (json['autoReasons'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      scoreAtBid: json['scoreAtBid'] == null
          ? const BidScoreSnapshot()
          : BidScoreSnapshot.fromJson(
              json['scoreAtBid'] as Map<String, dynamic>),
      estimatedSalary: (json['estimatedSalary'] as num?)?.toDouble() ?? 0,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      windowClosedAt: json['windowClosedAt'] == null
          ? null
          : DateTime.parse(json['windowClosedAt'] as String),
      awardedAt: json['awardedAt'] == null
          ? null
          : DateTime.parse(json['awardedAt'] as String),
      withdrawnAt: json['withdrawnAt'] == null
          ? null
          : DateTime.parse(json['withdrawnAt'] as String),
    );

Map<String, dynamic> _$$BidImplToJson(_$BidImpl instance) => <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'lineId': instance.lineId,
      'lineNumber': instance.lineNumber,
      'month': instance.month,
      'priority': instance.priority,
      'status': _$BidStatusEnumMap[instance.status]!,
      'userMode': _$UserModeEnumMap[instance.userMode]!,
      'rank': instance.rank,
      'lineType': instance.lineType,
      'carryOver': instance.carryOver,
      'base': instance.base,
      'category': instance.category,
      'creditHours': instance.creditHours,
      'blockHours': instance.blockHours,
      'carryOverHours': instance.carryOverHours,
      'totalLegs': instance.totalLegs,
      'fourLegCount': instance.fourLegCount,
      'expense': instance.expense,
      'allowance': instance.allowance,
      'income': instance.income,
      'hasStarDays': instance.hasStarDays,
      'isAutoBid': instance.isAutoBid,
      'autoReasons': instance.autoReasons,
      'scoreAtBid': instance.scoreAtBid,
      'estimatedSalary': instance.estimatedSalary,
      'submittedAt': instance.submittedAt.toIso8601String(),
      'windowClosedAt': instance.windowClosedAt?.toIso8601String(),
      'awardedAt': instance.awardedAt?.toIso8601String(),
      'withdrawnAt': instance.withdrawnAt?.toIso8601String(),
    };

const _$BidStatusEnumMap = {
  BidStatus.draft: 'draft',
  BidStatus.submitted: 'submitted',
  BidStatus.awarded: 'awarded',
  BidStatus.rejected: 'rejected',
  BidStatus.withdrawn: 'withdrawn',
};

_$BidScoreSnapshotImpl _$$BidScoreSnapshotImplFromJson(
        Map<String, dynamic> json) =>
    _$BidScoreSnapshotImpl(
      salaryScore: (json['salaryScore'] as num?)?.toDouble() ?? 0,
      restScore: (json['restScore'] as num?)?.toDouble() ?? 0,
      prefScore: (json['prefScore'] as num?)?.toDouble() ?? 0,
      composite: (json['composite'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$$BidScoreSnapshotImplToJson(
        _$BidScoreSnapshotImpl instance) =>
    <String, dynamic>{
      'salaryScore': instance.salaryScore,
      'restScore': instance.restScore,
      'prefScore': instance.prefScore,
      'composite': instance.composite,
    };

_$TradeImpl _$$TradeImplFromJson(Map<String, dynamic> json) => _$TradeImpl(
      id: json['id'] as String,
      type: $enumDecodeNullable(_$TradeTypeEnumMap, json['type']) ??
          TradeType.openDrop,
      initiatorId: json['initiatorId'] as String,
      initiatorRank: json['initiatorRank'] as String? ?? '',
      receiverId: json['receiverId'] as String?,
      status: $enumDecodeNullable(_$TradeStatusEnumMap, json['status']) ??
          TradeStatus.draft,
      offeredLeg: TradeLeg.fromJson(json['offeredLeg'] as Map<String, dynamic>),
      requestedLeg: json['requestedLeg'] == null
          ? null
          : TradeLeg.fromJson(json['requestedLeg'] as Map<String, dynamic>),
      legality: json['legality'] == null
          ? const TradeLegality()
          : TradeLegality.fromJson(json['legality'] as Map<String, dynamic>),
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      note: json['note'] as String? ?? '',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$TradeImplToJson(_$TradeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$TradeTypeEnumMap[instance.type]!,
      'initiatorId': instance.initiatorId,
      'initiatorRank': instance.initiatorRank,
      'receiverId': instance.receiverId,
      'status': _$TradeStatusEnumMap[instance.status]!,
      'offeredLeg': instance.offeredLeg,
      'requestedLeg': instance.requestedLeg,
      'legality': instance.legality,
      'isAnonymous': instance.isAnonymous,
      'note': instance.note,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$TradeTypeEnumMap = {
  TradeType.direct: 'direct',
  TradeType.openDrop: 'openDrop',
  TradeType.pickUp: 'pickUp',
  TradeType.swap: 'swap',
};

const _$TradeStatusEnumMap = {
  TradeStatus.draft: 'draft',
  TradeStatus.open: 'open',
  TradeStatus.matched: 'matched',
  TradeStatus.pendingConfirm: 'pendingConfirm',
  TradeStatus.confirmed: 'confirmed',
  TradeStatus.rejected: 'rejected',
  TradeStatus.expired: 'expired',
  TradeStatus.cancelled: 'cancelled',
};

_$TradeLegImpl _$$TradeLegImplFromJson(Map<String, dynamic> json) =>
    _$TradeLegImpl(
      legId: json['legId'] as String,
      lineId: json['lineId'] as String,
      flightNumber: json['flightNumber'] as String,
      origin: json['origin'] as String,
      destination: json['destination'] as String,
      departureUTC: DateTime.parse(json['departureUTC'] as String),
    );

Map<String, dynamic> _$$TradeLegImplToJson(_$TradeLegImpl instance) =>
    <String, dynamic>{
      'legId': instance.legId,
      'lineId': instance.lineId,
      'flightNumber': instance.flightNumber,
      'origin': instance.origin,
      'destination': instance.destination,
      'departureUTC': instance.departureUTC.toIso8601String(),
    };

_$TradeLegalityImpl _$$TradeLegalityImplFromJson(Map<String, dynamic> json) =>
    _$TradeLegalityImpl(
      checked: json['checked'] as bool? ?? false,
      checkedAt: json['checkedAt'] == null
          ? null
          : DateTime.parse(json['checkedAt'] as String),
      initiatorResult: json['initiatorResult'] == null
          ? const LegalityResult()
          : LegalityResult.fromJson(
              json['initiatorResult'] as Map<String, dynamic>),
      receiverResult: json['receiverResult'] == null
          ? const LegalityResult()
          : LegalityResult.fromJson(
              json['receiverResult'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$TradeLegalityImplToJson(_$TradeLegalityImpl instance) =>
    <String, dynamic>{
      'checked': instance.checked,
      'checkedAt': instance.checkedAt?.toIso8601String(),
      'initiatorResult': instance.initiatorResult,
      'receiverResult': instance.receiverResult,
    };

_$LegalityResultImpl _$$LegalityResultImplFromJson(Map<String, dynamic> json) =>
    _$LegalityResultImpl(
      passed: json['passed'] as bool? ?? true,
      violations: (json['violations'] as List<dynamic>?)
              ?.map(
                  (e) => LegalityViolation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map(
                  (e) => LegalityViolation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$LegalityResultImplToJson(
        _$LegalityResultImpl instance) =>
    <String, dynamic>{
      'passed': instance.passed,
      'violations': instance.violations,
      'warnings': instance.warnings,
    };

_$LegalityViolationImpl _$$LegalityViolationImplFromJson(
        Map<String, dynamic> json) =>
    _$LegalityViolationImpl(
      ruleId: json['ruleId'] as String,
      ruleDescription: json['ruleDescription'] as String,
      ruleDescriptionAr: json['ruleDescriptionAr'] as String,
      actualValue: (json['actualValue'] as num).toDouble(),
      requiredValue: (json['requiredValue'] as num).toDouble(),
      unit: json['unit'] as String,
      severity:
          $enumDecodeNullable(_$LegalitySeverityEnumMap, json['severity']) ??
              LegalitySeverity.blocking,
      affectedLegIds: (json['affectedLegIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$LegalityViolationImplToJson(
        _$LegalityViolationImpl instance) =>
    <String, dynamic>{
      'ruleId': instance.ruleId,
      'ruleDescription': instance.ruleDescription,
      'ruleDescriptionAr': instance.ruleDescriptionAr,
      'actualValue': instance.actualValue,
      'requiredValue': instance.requiredValue,
      'unit': instance.unit,
      'severity': _$LegalitySeverityEnumMap[instance.severity]!,
      'affectedLegIds': instance.affectedLegIds,
    };

const _$LegalitySeverityEnumMap = {
  LegalitySeverity.blocking: 'blocking',
  LegalitySeverity.warning: 'warning',
};

_$RankedLineImpl _$$RankedLineImplFromJson(Map<String, dynamic> json) =>
    _$RankedLineImpl(
      line: FlightLine.fromJson(json['line'] as Map<String, dynamic>),
      compositeScore: (json['compositeScore'] as num?)?.toDouble() ?? 0,
      salaryScore: (json['salaryScore'] as num?)?.toDouble() ?? 0,
      restScore: (json['restScore'] as num?)?.toDouble() ?? 0,
      destPrefScore: (json['destPrefScore'] as num?)?.toDouble() ?? 0,
      regularityScore: (json['regularityScore'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String,
      explanationAr: json['explanationAr'] as String,
    );

Map<String, dynamic> _$$RankedLineImplToJson(_$RankedLineImpl instance) =>
    <String, dynamic>{
      'line': instance.line,
      'compositeScore': instance.compositeScore,
      'salaryScore': instance.salaryScore,
      'restScore': instance.restScore,
      'destPrefScore': instance.destPrefScore,
      'regularityScore': instance.regularityScore,
      'rank': instance.rank,
      'explanation': instance.explanation,
      'explanationAr': instance.explanationAr,
    };

_$AIMessageImpl _$$AIMessageImplFromJson(Map<String, dynamic> json) =>
    _$AIMessageImpl(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      intentType: json['intentType'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      responseTimeMs: (json['responseTimeMs'] as num?)?.toInt() ?? 0,
      lineCard: json['lineCard'] == null
          ? null
          : FlightLine.fromJson(json['lineCard'] as Map<String, dynamic>),
      tradeCard: json['tradeCard'] == null
          ? null
          : Trade.fromJson(json['tradeCard'] as Map<String, dynamic>),
      legalityCard: json['legalityCard'] == null
          ? null
          : LegalityResult.fromJson(
              json['legalityCard'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$AIMessageImplToJson(_$AIMessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'role': instance.role,
      'content': instance.content,
      'intentType': instance.intentType,
      'timestamp': instance.timestamp.toIso8601String(),
      'responseTimeMs': instance.responseTimeMs,
      'lineCard': instance.lineCard,
      'tradeCard': instance.tradeCard,
      'legalityCard': instance.legalityCard,
    };

_$CIPNotificationImpl _$$CIPNotificationImplFromJson(
        Map<String, dynamic> json) =>
    _$CIPNotificationImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      titleAr: json['titleAr'] as String,
      body: json['body'] as String,
      bodyAr: json['bodyAr'] as String,
      deepLink: json['deepLink'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      sentAt: DateTime.parse(json['sentAt'] as String),
    );

Map<String, dynamic> _$$CIPNotificationImplToJson(
        _$CIPNotificationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'type': instance.type,
      'title': instance.title,
      'titleAr': instance.titleAr,
      'body': instance.body,
      'bodyAr': instance.bodyAr,
      'deepLink': instance.deepLink,
      'read': instance.read,
      'sentAt': instance.sentAt.toIso8601String(),
    };
