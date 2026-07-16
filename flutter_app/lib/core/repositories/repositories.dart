import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../models/models.dart';
import '../services/connectivity_service.dart';
import '../services/offline_cache_service.dart';

// ─── Flight Lines Repository ──────────────────────────────────────────────────

final flightLinesRepositoryProvider = Provider<FlightLinesRepository>((ref) {
  return FlightLinesRepository(firestore: ref.watch(firestoreProvider));
});

final flightLinesProvider = StreamProvider.family<List<FlightLine>, String>((ref, month) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(flightLinesRepositoryProvider).watchLines(userId: auth.uid, month: month);
});

final singleLineProvider = StreamProvider.family<FlightLine?, String>((ref, lineId) {
  return ref.watch(flightLinesRepositoryProvider).watchLine(lineId);
});

class FlightLinesRepository {
  final FirebaseFirestore _firestore;
  FlightLinesRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  // Watch all lines for a user in a month
  Stream<List<FlightLine>> watchLines({
    required String userId,
    required String month,
    String? rank,
    OfflineCacheService? cache,
    bool isOnline = true,
  }) {
    // Offline: return cached data as single-event stream
    if (!isOnline && cache != null) {
      final cached = rank != null
          ? cache.getCachedLines(month, rank)
          : cache.getCachedLinesLatest(rank ?? '');
      return Stream.value(cached);
    }
    var query = _firestore
        .collection('flightLines')
        .where('month', isEqualTo: month);
    if (rank != null && rank.isNotEmpty) {
      query = query.where('rank', isEqualTo: rank);
    }
    return query.orderBy('lineNumber')
        .snapshots()
        .asyncMap((snapshot) async {
      final lines = <FlightLine>[];
      for (final doc in snapshot.docs) {
        final line = FlightLine.fromFirestore(doc);
        final legs = await fetchLegs(line.id);
        lines.add(line.copyWith(legs: legs));
      }
      return lines;
    });
  }

  // Watch a single line with legs
  Stream<FlightLine?> watchLine(String lineId) {
    return _firestore
        .collection('flightLines')
        .doc(lineId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) return null;
      final line = FlightLine.fromFirestore(doc);
      final legs = await fetchLegs(lineId);
      return line.copyWith(legs: legs);
    });
  }

  // Fetch legs subcollection
  Future<List<FlightLeg>> fetchLegs(String lineId) async {
    final snapshot = await _firestore
        .collection('flightLines')
        .doc(lineId)
        .collection('legs')
        .orderBy('sequence')
        .get();
    return snapshot.docs.map((d) => FlightLeg.fromFirestore(d)).toList();
  }

  // Save parsed line from upload
  Future<void> saveLine(FlightLine line, List<FlightLeg> legs, {String rank = ''}) async {
    final batch = _firestore.batch();

    final lineRef = _firestore.collection('flightLines').doc(line.id);
    batch.set(lineRef, _lineToFirestore(line));

    for (final leg in legs) {
      final legRef = lineRef.collection('legs').doc(leg.id);
      batch.set(legRef, _legToFirestore(leg));
    }

    await batch.commit();
  }

  // Delete a line (user-initiated)
  Future<void> deleteLine(String lineId) async {
    // Delete legs subcollection first
    final legsSnapshot = await _firestore
        .collection('flightLines')
        .doc(lineId)
        .collection('legs')
        .get();

    final batch = _firestore.batch();
    for (final doc in legsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_firestore.collection('flightLines').doc(lineId));
    await batch.commit();
  }

  Map<String, dynamic> _lineToFirestore(FlightLine line) => {
    'lineNumber': line.lineNumber,
    'month': line.month,
    'userId': line.userId,
    'uploadedAt': Timestamp.fromDate(line.uploadedAt),
    'validationStatus': line.validationStatus,
    'summary': {
      'totalLegs': line.summary.totalLegs,
      'totalBlockHours': line.summary.totalBlockHours,
      'totalDutyHours': line.summary.totalDutyHours,
      'totalDutyDays': line.summary.totalDutyDays,
      'internationalLegs': line.summary.internationalLegs,
      'domesticLegs': line.summary.domesticLegs,
      'layoverCount': line.summary.layoverCount,
      'estimatedSalaryMin': line.summary.estimatedSalaryMin,
      'estimatedSalaryMax': line.summary.estimatedSalaryMax,
      'salaryScore': line.summary.salaryScore,
      'restQualityScore': line.summary.restQualityScore,
      'compositeScore': line.summary.compositeScore,
    },
    'destinations': line.destinations,
    'daysOff': line.daysOff,
    'isActive': line.isActive,
      'rank': line.rank,
  };

  Map<String, dynamic> _legToFirestore(FlightLeg leg) => {
    'lineId': leg.lineId,
    'flightNumber': leg.flightNumber,
    'origin': leg.origin,
    'destination': leg.destination,
    'legType': leg.legType.name,
    'departureLT': Timestamp.fromDate(leg.departureLT),
    'arrivalLT': Timestamp.fromDate(leg.arrivalLT),
    'departureUTC': Timestamp.fromDate(leg.departureUTC),
    'arrivalUTC': Timestamp.fromDate(leg.arrivalUTC),
    'dutyStart': Timestamp.fromDate(leg.dutyStart),
    'dutyEnd': Timestamp.fromDate(leg.dutyEnd),
    'releaseTime': Timestamp.fromDate(leg.releaseTime),
    'blockHours': leg.blockHours,
    'fdpHours': leg.fdpHours,
    'aircraftType': leg.aircraftType,
    'layover': leg.layover,
    'layoverHours': leg.layoverHours,
    'payRate': leg.payRate,
    'estimatedPay': leg.estimatedPay,
    'perDiem': leg.perDiem,
    'legalityStatus': leg.legalityStatus.name,
    'legalityFlags': leg.legalityFlags,
    'restAfterHours': leg.restAfterHours,
    'restBeforeHours': leg.restBeforeHours,
    'sequence': leg.sequence,
  };
}

// ─── Bids Repository ──────────────────────────────────────────────────────────

final bidsRepositoryProvider = Provider<BidsRepository>((ref) {
  return BidsRepository(firestore: ref.watch(firestoreProvider));
});

final userBidsProvider = StreamProvider.family<List<Bid>, String>((ref, month) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(bidsRepositoryProvider).watchUserBids(userId: auth.uid, month: month);
});

class BidsRepository {
  final FirebaseFirestore _firestore;
  BidsRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  Stream<List<Bid>> watchUserBids({required String userId, required String month, String? rank}) {
    var query = _firestore
        .collection('bids')
        .where('userId', isEqualTo: userId)
        .where('month', isEqualTo: month);
    if (rank != null && rank.isNotEmpty) {
      query = query.where('rank', isEqualTo: rank);
    }
    return query.orderBy('priority')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Bid.fromFirestore(d)).toList());
  }

  Future<void> submitBid(Bid bid) async {
    await _firestore.collection('bids').doc(bid.id).set({
      'userId': bid.userId,
      'lineId': bid.lineId,
      'lineNumber': bid.lineNumber,
      'month': bid.month,
      'priority': bid.priority,
      'status': bid.status.name,
      'userMode': bid.userMode.name,
      'isAutoBid': bid.isAutoBid,
      'autoReasons': bid.autoReasons,
      'scoreAtBid': {
        'salaryScore': bid.scoreAtBid.salaryScore,
        'restScore': bid.scoreAtBid.restScore,
        'prefScore': bid.scoreAtBid.prefScore,
        'composite': bid.scoreAtBid.composite,
      },
      'estimatedSalary': bid.estimatedSalary,
      'submittedAt': Timestamp.fromDate(bid.submittedAt),
      'rank': bid.rank,
    });
  }

  Future<void> updateBidPriorities(List<Bid> bids) async {
    final batch = _firestore.batch();
    for (int i = 0; i < bids.length; i++) {
      batch.update(
        _firestore.collection('bids').doc(bids[i].id),
        {'priority': i + 1},
      );
    }
    await batch.commit();
  }

  Future<void> withdrawBid(String bidId) async {
    await _firestore.collection('bids').doc(bidId).update({
      'status': BidStatus.withdrawn.name,
      'withdrawnAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> hasExistingBid(String userId, String lineId, String month) async {
    final snap = await _firestore
        .collection('bids')
        .where('userId', isEqualTo: userId)
        .where('lineId', isEqualTo: lineId)
        .where('month', isEqualTo: month)
        .where('status', whereNotIn: ['withdrawn', 'rejected'])
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }
}

// ─── Trades Repository ────────────────────────────────────────────────────────

final tradesRepositoryProvider = Provider<TradesRepository>((ref) {
  return TradesRepository(firestore: ref.watch(firestoreProvider));
});

final openTradesProvider = StreamProvider<List<Trade>>((ref) {
  return ref.watch(tradesRepositoryProvider).watchOpenTrades();
});

final userTradesProvider = StreamProvider<List<Trade>>((ref) {
  final auth = ref.watch(authStateProvider).valueOrNull;
  if (auth == null) return Stream.value([]);
  return ref.watch(tradesRepositoryProvider).watchUserTrades(auth.uid);
});

class TradesRepository {
  final FirebaseFirestore _firestore;
  TradesRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  Stream<List<Trade>> watchOpenTrades({String? rank}) {
    var query = _firestore
        .collection('trades')
        .where('status', isEqualTo: TradeStatus.open.name)
        .where('expiresAt', isGreaterThan: Timestamp.now());
    if (rank != null && rank.isNotEmpty) {
      query = query.where('initiatorRank', isEqualTo: rank);
    }
    return query.orderBy('expiresAt')
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Trade.fromFirestore(d)).toList());
  }

  Stream<List<Trade>> watchUserTrades(String userId) {
    return _firestore
        .collection('trades')
        .where('initiatorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Trade.fromFirestore(d)).toList());
  }

  Future<String> createTrade(Trade trade) async {
    final ref = _firestore.collection('trades').doc();
    await ref.set(_tradeToFirestore(trade.copyWith(id: ref.id)));
    return ref.id;
  }

  Future<void> acceptTrade({
    required String tradeId,
    required String receiverId,
    required LegalityResult receiverLegalityResult,
  }) async {
    await _firestore.collection('trades').doc(tradeId).update({
      'receiverId': receiverId,
      'status': TradeStatus.pendingConfirm.name,
      'legality.receiverResult': _legalityResultToMap(receiverLegalityResult),
      'legality.checked': true,
      'legality.checkedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> confirmTrade(String tradeId) async {
    await _firestore.collection('trades').doc(tradeId).update({
      'status': TradeStatus.confirmed.name,
      'confirmedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelTrade(String tradeId) async {
    await _firestore.collection('trades').doc(tradeId).update({
      'status': TradeStatus.cancelled.name,
    });
  }

  Map<String, dynamic> _tradeToFirestore(Trade trade) => {
    'type': trade.type.name,
    'initiatorId': trade.initiatorId,
    'receiverId': trade.receiverId,
    'status': trade.status.name,
    'offeredLeg': _tradeLegToMap(trade.offeredLeg),
    'requestedLeg': trade.requestedLeg != null ? _tradeLegToMap(trade.requestedLeg!) : null,
    'legality': {
      'checked': trade.legality.checked,
      'initiatorResult': _legalityResultToMap(trade.legality.initiatorResult),
      'receiverResult': _legalityResultToMap(trade.legality.receiverResult),
    },
    'isAnonymous': trade.isAnonymous,
    'note': trade.note,
    'expiresAt': Timestamp.fromDate(trade.expiresAt),
    'createdAt': FieldValue.serverTimestamp(),
      'initiatorRank': trade.initiatorRank,
  };

  Map<String, dynamic> _tradeLegToMap(TradeLeg leg) => {
    'legId': leg.legId,
    'lineId': leg.lineId,
    'flightNumber': leg.flightNumber,
    'origin': leg.origin,
    'destination': leg.destination,
    'departureUTC': Timestamp.fromDate(leg.departureUTC),
  };

  Map<String, dynamic> _legalityResultToMap(LegalityResult result) => {
    'passed': result.passed,
    'violations': result.violations.map((v) => {
      'ruleId': v.ruleId,
      'ruleDescription': v.ruleDescription,
      'ruleDescriptionAr': v.ruleDescriptionAr,
      'actualValue': v.actualValue,
      'requiredValue': v.requiredValue,
      'unit': v.unit,
      'severity': v.severity.name,
      'affectedLegIds': v.affectedLegIds,
    }).toList(),
    'warnings': result.warnings.map((v) => {
      'ruleId': v.ruleId,
      'ruleDescription': v.ruleDescription,
      'ruleDescriptionAr': v.ruleDescriptionAr,
      'actualValue': v.actualValue,
      'requiredValue': v.requiredValue,
      'unit': v.unit,
      'severity': v.severity.name,
      'affectedLegIds': v.affectedLegIds,
    }).toList(),
  };
}
