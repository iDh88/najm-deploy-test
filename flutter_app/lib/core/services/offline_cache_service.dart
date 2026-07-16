import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

// ─── Cache Box Names ──────────────────────────────────────────────────────────
const _kLinesBox    = 'cached_lines';
const _kBidsBox     = 'cached_bids';
const _kTradesBox   = 'cached_trades';
const _kProfileBox  = 'cached_profile';
const _kQueueBox    = 'offline_queue';
const _kMetaBox     = 'cache_meta';

// ─── Cache Provider ───────────────────────────────────────────────────────────
final offlineCacheProvider = Provider<OfflineCacheService>(
  (_) => OfflineCacheService(),
);

// ─── Offline Action Queue ─────────────────────────────────────────────────────
enum QueuedActionType {
  submitBid,
  withdrawBid,
  reorderBids,
  createTrade,
  acceptTrade,
  cancelTrade,
  updatePreferences,
}

class QueuedAction {
  final String id;
  final QueuedActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;

  QueuedAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id':         id,
    'type':       type.name,
    'payload':    payload,
    'createdAt':  createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
    id:          json['id'] as String,
    type:        QueuedActionType.values.firstWhere(
                   (e) => e.name == json['type']),
    payload:     Map<String, dynamic>.from(json['payload'] as Map),
    createdAt:   DateTime.parse(json['createdAt'] as String),
    retryCount:  json['retryCount'] as int? ?? 0,
  );
}

// ─── Cache Metadata ───────────────────────────────────────────────────────────
class CacheMeta {
  final DateTime? linesCachedAt;
  final DateTime? bidsCachedAt;
  final DateTime? tradesCachedAt;
  final DateTime? profileCachedAt;
  final String?   cachedMonth;
  final String?   cachedRank;

  const CacheMeta({
    this.linesCachedAt,
    this.bidsCachedAt,
    this.tradesCachedAt,
    this.profileCachedAt,
    this.cachedMonth,
    this.cachedRank,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────
class OfflineCacheService {
  Box? _linesBox;
  Box? _bidsBox;
  Box? _tradesBox;
  Box? _profileBox;
  Box? _queueBox;
  Box? _metaBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _linesBox   = await Hive.openBox(_kLinesBox);
    _bidsBox    = await Hive.openBox(_kBidsBox);
    _tradesBox  = await Hive.openBox(_kTradesBox);
    _profileBox = await Hive.openBox(_kProfileBox);
    _queueBox   = await Hive.openBox(_kQueueBox);
    _metaBox    = await Hive.openBox(_kMetaBox);
    _initialized = true;
  }

  // ── Lines Cache ─────────────────────────────────────────────────────────
  Future<void> cacheLines(List<FlightLine> lines, String month, String rank) async {
    await init();
    final data = lines.map((l) => jsonEncode(l.toJson())).toList();
    await _linesBox!.put('lines_${rank}_$month', data);
    await _metaBox!.put('lines_month', month);
    await _metaBox!.put('lines_rank',  rank);
    await _metaBox!.put('lines_cached_at', DateTime.now().toIso8601String());
  }

  List<FlightLine> getCachedLines(String month, String rank) {
    if (_linesBox == null) return [];
    final data = _linesBox!.get('lines_${rank}_$month');
    if (data == null) return [];
    try {
      return (data as List)
          .map((e) => FlightLine.fromJson(jsonDecode(e as String)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Also cache all months available for this rank
  List<FlightLine> getCachedLinesLatest(String rank) {
    if (_linesBox == null) return [];
    final month = _metaBox?.get('lines_month') as String?;
    if (month == null) return [];
    return getCachedLines(month, rank);
  }

  // ── Bids Cache ──────────────────────────────────────────────────────────
  Future<void> cacheBids(List<Bid> bids) async {
    await init();
    final data = bids.map((b) => jsonEncode(b.toJson())).toList();
    await _bidsBox!.put('my_bids', data);
    await _metaBox!.put('bids_cached_at', DateTime.now().toIso8601String());
  }

  List<Bid> getCachedBids() {
    if (_bidsBox == null) return [];
    final data = _bidsBox!.get('my_bids');
    if (data == null) return [];
    try {
      return (data as List)
          .map((e) => Bid.fromJson(jsonDecode(e as String)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Trades Cache ────────────────────────────────────────────────────────
  Future<void> cacheTrades(List<Trade> trades) async {
    await init();
    final data = trades.map((t) => jsonEncode(t.toJson())).toList();
    await _tradesBox!.put('open_trades', data);
    await _metaBox!.put('trades_cached_at', DateTime.now().toIso8601String());
  }

  List<Trade> getCachedTrades() {
    if (_tradesBox == null) return [];
    final data = _tradesBox!.get('open_trades');
    if (data == null) return [];
    try {
      return (data as List)
          .map((e) => Trade.fromJson(jsonDecode(e as String)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Profile Cache ───────────────────────────────────────────────────────
  Future<void> cacheProfile(CIPUser user) async {
    await init();
    await _profileBox!.put('user', jsonEncode(user.toJson()));
    await _metaBox!.put('profile_cached_at', DateTime.now().toIso8601String());
  }

  CIPUser? getCachedProfile() {
    if (_profileBox == null) return null;
    final data = _profileBox!.get('user');
    if (data == null) return null;
    try {
      return CIPUser.fromJson(jsonDecode(data as String));
    } catch (_) {
      return null;
    }
  }

  // ── Offline Action Queue ────────────────────────────────────────────────
  Future<void> enqueueAction(QueuedAction action) async {
    await init();
    final existing = getPendingActions();
    existing.add(action);
    await _queueBox!.put(
      'queue',
      existing.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  List<QueuedAction> getPendingActions() {
    if (_queueBox == null) return [];
    final data = _queueBox!.get('queue');
    if (data == null) return [];
    try {
      return (data as List)
          .map((e) => QueuedAction.fromJson(jsonDecode(e as String)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> removeAction(String actionId) async {
    await init();
    final actions = getPendingActions()
        .where((a) => a.id != actionId)
        .toList();
    await _queueBox!.put(
      'queue',
      actions.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  Future<void> clearQueue() async {
    await init();
    await _queueBox!.put('queue', []);
  }

  // ── Metadata ────────────────────────────────────────────────────────────
  CacheMeta getMeta() {
    if (_metaBox == null) return const CacheMeta();
    String? _dt(String key) => _metaBox!.get(key) as String?;
    DateTime? _parse(String key) {
      final s = _dt(key);
      return s != null ? DateTime.tryParse(s) : null;
    }
    return CacheMeta(
      linesCachedAt:   _parse('lines_cached_at'),
      bidsCachedAt:    _parse('bids_cached_at'),
      tradesCachedAt:  _parse('trades_cached_at'),
      profileCachedAt: _parse('profile_cached_at'),
      cachedMonth:     _dt('lines_month'),
      cachedRank:      _dt('lines_rank'),
    );
  }

  bool get hasAnyCache {
    final meta = getMeta();
    return meta.linesCachedAt != null ||
           meta.bidsCachedAt  != null ||
           meta.profileCachedAt != null;
  }

  String cacheAgeString(DateTime? cachedAt) {
    if (cachedAt == null) return 'Never cached';
    final diff = DateTime.now().difference(cachedAt);
    if (diff.inMinutes  < 60)  return 'Cached ${diff.inMinutes}m ago';
    if (diff.inHours    < 24)  return 'Cached ${diff.inHours}h ago';
    return 'Cached ${diff.inDays}d ago';
  }

  Future<void> clearAll() async {
    await init();
    await _linesBox!.clear();
    await _bidsBox!.clear();
    await _tradesBox!.clear();
    await _metaBox!.clear();
    // Keep queue — user's pending actions should not be deleted
  }
}
