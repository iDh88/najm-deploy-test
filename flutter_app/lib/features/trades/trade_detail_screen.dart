import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/ai_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class TradeDetailScreen extends ConsumerStatefulWidget {
  final String tradeId;
  const TradeDetailScreen({super.key, required this.tradeId});

  @override
  ConsumerState<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends ConsumerState<TradeDetailScreen> {
  bool _checkingLegality = false;
  bool _accepting = false;
  bool _confirming = false;
  LegalityCheckResponse? _legalityResult;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    // Watch live trade document
    final tradeAsync = ref.watch(
      StreamProvider<Trade?>((ref) => ref
          .watch(tradesRepositoryProvider)
          .watchUserTrades(user?.id ?? '')
          .map((list) => list.firstWhere(
                (t) => t.id == widget.tradeId,
                orElse: () => throw Exception('Trade not found'),
              )))
          .select((v) => v),
    );

    return tradeAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Trade')),
        body: const Center(child: Text('Trade not found or expired')),
      ),
      data: (trade) {
        if (trade == null) return const SizedBox.shrink();
        return _buildScaffold(trade, user);
      },
    );
  }

  Widget _buildScaffold(Trade trade, CIPUser? user) {
    final isInitiator = user?.id == trade.initiatorId;
    final isReceiver = user?.id == trade.receiverId;
    final canAccept = !isInitiator &&
        trade.status == TradeStatus.open &&
        user != null;
    final canConfirm = (isInitiator || isReceiver) &&
        trade.status == TradeStatus.pendingConfirm;

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: Text('Trade #${widget.tradeId.substring(0, 8)}'),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          _TradeStatusBanner(trade: trade),
          const SizedBox(height: 16),

          // Leg comparison card
          _LegComparisonCard(trade: trade),
          const SizedBox(height: 16),

          // Legality result (if checked)
          if (_legalityResult != null) ...[
            LegalityPanel(result: _legalityResult!.initiatorResult),
            const SizedBox(height: 8),
            if (_legalityResult!.receiverResult.violations.isNotEmpty ||
                _legalityResult!.receiverResult.warnings.isNotEmpty)
              LegalityPanel(result: _legalityResult!.receiverResult),
            const SizedBox(height: 16),
          ],

          // Trade note
          if (trade.note.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CIPTheme.grey200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.note_outlined, color: CIPTheme.grey500, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(trade.note,
                        style: const TextStyle(color: CIPTheme.grey700, fontSize: 13)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Expiry info
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: CIPTheme.grey500),
              const SizedBox(width: 6),
              Text(
                'Expires: ${DateFormat('dd MMM HH:mm').format(trade.expiresAt)}',
                style: const TextStyle(color: CIPTheme.grey500, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Action buttons
          if (canAccept) ...[
            if (_legalityResult == null)
              OutlinedButton.icon(
                onPressed: _checkingLegality ? null : () => _checkLegality(trade, user!),
                icon: _checkingLegality
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.shield_outlined, size: 18),
                label: Text(_checkingLegality ? 'Checking...' : 'Check Legality First'),
              ),
            if (_legalityResult != null) ...[
              if (_legalityResult!.passed)
                ElevatedButton.icon(
                  onPressed: _accepting ? null : () => _acceptTrade(trade, user!),
                  icon: _accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(_accepting ? 'Accepting...' : 'Accept Trade ✓'),
                  style: ElevatedButton.styleFrom(backgroundColor: CIPTheme.legalGreen),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CIPTheme.violationRedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CIPTheme.violationRed.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.block, color: CIPTheme.violationRed, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Cannot accept — legal violations detected for your schedule',
                          style: TextStyle(color: CIPTheme.violationRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],

          if (canConfirm)
            ElevatedButton.icon(
              onPressed: _confirming ? null : () => _confirmTrade(trade),
              icon: const Icon(Icons.handshake_outlined, size: 18),
              label: Text(_confirming ? 'Confirming...' : 'Confirm Trade'),
            ),

          if (isInitiator && trade.status == TradeStatus.open) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _cancelTrade(trade),
              style: OutlinedButton.styleFrom(
                foregroundColor: CIPTheme.violationRed,
                side: const BorderSide(color: CIPTheme.violationRed),
              ),
              child: const Text('Cancel Trade'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _checkLegality(Trade trade, CIPUser user) async {
    setState(() => _checkingLegality = true);
    try {
      final result = await ref.read(aiServiceProvider).checkTradeLegality(
        initiatorId: trade.initiatorId,
        receiverId: user.id,
        offeredLegId: trade.offeredLeg.legId,
        requestedLegId: trade.requestedLeg?.legId ?? '',
      );
      setState(() => _legalityResult = result);
    } catch (e) {
      _showSnack('Legality check failed: $e', isError: true);
    } finally {
      setState(() => _checkingLegality = false);
    }
  }

  Future<void> _acceptTrade(Trade trade, CIPUser user) async {
    setState(() => _accepting = true);
    HapticFeedback.mediumImpact();
    try {
      await ref.read(tradesRepositoryProvider).acceptTrade(
        tradeId: trade.id,
        receiverId: user.id,
        receiverLegalityResult: _legalityResult!.receiverResult,
      );
      _showSnack('Trade accepted — waiting for initiator confirmation');
    } catch (e) {
      _showSnack('Failed to accept trade: $e', isError: true);
    } finally {
      setState(() => _accepting = false);
    }
  }

  Future<void> _confirmTrade(Trade trade) async {
    setState(() => _confirming = true);
    HapticFeedback.heavyImpact();
    try {
      await ref.read(tradesRepositoryProvider).confirmTrade(trade.id);
      _showSnack('Trade confirmed ✓');
      if (mounted) context.pop();
    } catch (e) {
      _showSnack('Failed to confirm trade: $e', isError: true);
    } finally {
      setState(() => _confirming = false);
    }
  }

  Future<void> _cancelTrade(Trade trade) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Trade'),
        content: const Text('Are you sure you want to cancel this trade post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Trade', style: TextStyle(color: CIPTheme.violationRed)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(tradesRepositoryProvider).cancelTrade(trade.id);
      if (mounted) context.pop();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? CIPTheme.violationRed : CIPTheme.legalGreen,
    ));
  }
}

// ─── Status Banner ────────────────────────────────────────────────────────────
class _TradeStatusBanner extends StatelessWidget {
  final Trade trade;
  const _TradeStatusBanner({required this.trade});

  @override
  Widget build(BuildContext context) {
    final (label, labelAr, color, icon) = switch (trade.status) {
      TradeStatus.open => ('Open for Matching', 'Open', CIPTheme.saudiNavy, Icons.search),
      TradeStatus.matched => ('Match Found!', 'Match Found!', CIPTheme.warningAmber, Icons.handshake_outlined),
      TradeStatus.pendingConfirm => ('Pending Confirmation', 'Pending', CIPTheme.warningAmber, Icons.pending_outlined),
      TradeStatus.confirmed => ('Confirmed ✓', 'Confirmed ✓', CIPTheme.legalGreen, Icons.check_circle),
      TradeStatus.rejected => ('Rejected', 'Rejected', CIPTheme.violationRed, Icons.cancel),
      TradeStatus.expired => ('Expired', 'Expired', CIPTheme.grey500, Icons.timer_off),
      TradeStatus.cancelled => ('Cancelled', 'Cancelled', CIPTheme.grey500, Icons.block),
      _ => ('Draft', 'Draft', CIPTheme.grey500, Icons.edit_outlined),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(labelAr,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Leg Comparison Card ──────────────────────────────────────────────────────
class _LegComparisonCard extends StatelessWidget {
  final Trade trade;
  const _LegComparisonCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trade Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _LegSide(
                label: 'Offering',
                labelAr: 'Offered',
                leg: trade.offeredLeg,
                color: CIPTheme.violationRed,
              )),
              Container(
                width: 1,
                height: 80,
                color: CIPTheme.grey200,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(child: _LegSide(
                label: 'Requesting',
                labelAr: 'Requested',
                leg: trade.requestedLeg,
                color: CIPTheme.legalGreen,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegSide extends StatelessWidget {
  final String label, labelAr;
  final TradeLeg? leg;
  final Color color;
  const _LegSide({required this.label, required this.labelAr, this.leg, required this.color});

  @override
  Widget build(BuildContext context) {
    if (leg == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(labelAr, style: TextStyle(
              fontSize: 11, color: color, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CIPTheme.grey100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Any leg\n(Open Drop)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: CIPTheme.grey500)),
          ),
        ],
      );
    }

    final depTime = DateFormat('dd MMM HH:mm').format(leg!.departureUTC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(labelAr, style: TextStyle(
            fontSize: 11, color: color, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(leg!.flightNumber,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
              Text('${leg!.origin} → ${leg!.destination}',
                  style: const TextStyle(fontSize: 12, color: CIPTheme.grey700)),
              Text(depTime, style: const TextStyle(fontSize: 11, color: CIPTheme.grey500)),
            ],
          ),
        ),
      ],
    );
  }
}
