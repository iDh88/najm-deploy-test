import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../core/services/ai_service.dart';
import '../../shared/widgets/legality_badge.dart';
import '../../shared/widgets/skeleton_loader.dart';

// ─── Step enum ────────────────────────────────────────────────────────────────
enum TradeStep { selectOffer, selectRequest, confirmLegality }

// ─── Trade Initiate Screen ────────────────────────────────────────────────────
class TradeInitiateScreen extends ConsumerStatefulWidget {
  const TradeInitiateScreen({super.key});

  @override
  ConsumerState<TradeInitiateScreen> createState() =>
      _TradeInitiateScreenState();
}

class _TradeInitiateScreenState extends ConsumerState<TradeInitiateScreen> {
  TradeStep _step = TradeStep.selectOffer;
  FlightLeg? _offeredLeg;
  FlightLeg? _requestedLeg;
  LegalityResult? _legalityResult;
  bool _isOpenDrop = false;
  bool _isAnonymous = false;
  bool _checkingLegality = false;
  bool _submitting = false;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: const Text('New Trade'),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: _step),
          Expanded(
            child: switch (_step) {
              TradeStep.selectOffer   => _SelectOfferStep(
                  onLegSelected: (leg) => setState(() {
                    _offeredLeg = leg;
                    _step = TradeStep.selectRequest;
                  }),
                ),
              TradeStep.selectRequest => _SelectRequestStep(
                  offeredLeg: _offeredLeg!,
                  onOpenDrop: () => setState(() {
                    _isOpenDrop = true;
                    _step = TradeStep.confirmLegality;
                    _runLegalityCheck();
                  }),
                  onLegSelected: (leg) => setState(() {
                    _requestedLeg = leg;
                    _step = TradeStep.confirmLegality;
                    _runLegalityCheck();
                  }),
                ),
              TradeStep.confirmLegality => _ConfirmStep(
                  offeredLeg: _offeredLeg!,
                  requestedLeg: _requestedLeg,
                  isOpenDrop: _isOpenDrop,
                  isAnonymous: _isAnonymous,
                  legalityResult: _legalityResult,
                  checkingLegality: _checkingLegality,
                  submitting: _submitting,
                  noteController: _noteController,
                  onAnonymousToggle: (v) => setState(() => _isAnonymous = v),
                  onBack: () => setState(() {
                    _step = TradeStep.selectRequest;
                    _legalityResult = null;
                  }),
                  onSubmit: _submitTrade,
                ),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runLegalityCheck() async {
    if (_offeredLeg == null) return;
    setState(() => _checkingLegality = true);

    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      if (_isOpenDrop) {
        // Open drop — only check initiator's schedule after removing the leg
        setState(() {
          _legalityResult = const LegalityResult(passed: true);
          _checkingLegality = false;
        });
        return;
      }

      if (_requestedLeg == null) return;

      final result = await ref.read(aiServiceProvider).checkTradeLegality(
        initiatorId: user.id,
        receiverId: '',
        offeredLegId: _offeredLeg!.id,
        requestedLegId: _requestedLeg!.id,
      );

      setState(() {
        _legalityResult = result.initiatorResult;
        _checkingLegality = false;
      });
    } catch (e) {
      setState(() {
        _legalityResult = LegalityResult(
          passed: false,
          violations: [
            LegalityViolation(
              ruleId: 'CHECK_FAILED',
              ruleDescription: 'Legality check could not be completed: $e',
              ruleDescriptionAr: 'Legality check failed',
              actualValue: 0,
              requiredValue: 0,
              unit: '',
            ),
          ],
        );
        _checkingLegality = false;
      });
    }
  }

  Future<void> _submitTrade() async {
    if (_offeredLeg == null) return;
    if (_legalityResult != null && !_legalityResult!.passed) return;

    setState(() => _submitting = true);
    HapticFeedback.mediumImpact();

    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      final trade = Trade(
        id: const Uuid().v4(),
        type: _isOpenDrop ? TradeType.openDrop : TradeType.direct,
        initiatorId: user.id,
        status: TradeStatus.open,
        offeredLeg: TradeLeg(
          legId: _offeredLeg!.id,
          lineId: _offeredLeg!.lineId,
          flightNumber: _offeredLeg!.flightNumber,
          origin: _offeredLeg!.origin,
          destination: _offeredLeg!.destination,
          departureUTC: _offeredLeg!.departureUTC,
        ),
        requestedLeg: _requestedLeg != null
            ? TradeLeg(
                legId: _requestedLeg!.id,
                lineId: _requestedLeg!.lineId,
                flightNumber: _requestedLeg!.flightNumber,
                origin: _requestedLeg!.origin,
                destination: _requestedLeg!.destination,
                departureUTC: _requestedLeg!.departureUTC,
              )
            : null,
        legality: TradeLegality(
          checked: _legalityResult != null,
          checkedAt: _legalityResult != null ? DateTime.now() : null,
          initiatorResult: _legalityResult ?? const LegalityResult(passed: true),
        ),
        isAnonymous: _isAnonymous,
        note: _noteController.text.trim(),
        expiresAt: DateTime.now().add(const Duration(hours: 72)),
        createdAt: DateTime.now(),
      );

      await ref.read(tradesRepositoryProvider).createTrade(trade);
      HapticFeedback.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trade posted successfully ✓'),
            backgroundColor: CIPTheme.legalGreen,
          ),
        );
        context.go('/trades');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post trade: $e'),
            backgroundColor: CIPTheme.violationRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ─── Step Indicator ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final TradeStep currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final steps = ['Select Offer', 'Select Request', 'Confirm'];
    final current = currentStep.index;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 2,
                color: i ~/ 2 < current ? CIPTheme.saudiNavy : CIPTheme.grey200,
              ),
            );
          }
          final stepIdx = i ~/ 2;
          final isDone = stepIdx < current;
          final isCurrent = stepIdx == current;
          return Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone || isCurrent
                      ? CIPTheme.saudiNavy
                      : CIPTheme.grey100,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone || isCurrent
                        ? CIPTheme.saudiNavy
                        : CIPTheme.grey300,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : Text(
                          '${stepIdx + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.white : CIPTheme.grey500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIdx],
                style: TextStyle(
                  fontSize: 10,
                  color: isCurrent ? CIPTheme.saudiNavy : CIPTheme.grey500,
                  fontWeight:
                      isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Step 1: Select Offered Leg ───────────────────────────────────────────────
class _SelectOfferStep extends ConsumerWidget {
  final ValueChanged<FlightLeg> onLegSelected;
  const _SelectOfferStep({required this.onLegSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final month = DateFormat('yyyy-MM').format(DateTime.now());
    final linesAsync = ref.watch(flightLinesProvider(month));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Offered Leg', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15,
                fontFamily: 'Inter',
              )),
              Text('Select the leg you want to give away',
                  style: TextStyle(color: CIPTheme.grey500, fontSize: 13)),
            ],
          ),
        ),
        Expanded(
          child: linesAsync.when(
            loading: () => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SkeletonLoader(height: 72),
              ),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (lines) {
              final allLegs = lines.expand((l) => l.legs).toList();
              if (allLegs.isEmpty) {
                return const Center(
                  child: Text(
                    'No legs found.\nUpload your roster first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: CIPTheme.grey500),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: allLegs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) => _LegSelectTile(
                  leg: allLegs[i],
                  onTap: () => onLegSelected(allLegs[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: Select Requested Leg ─────────────────────────────────────────────
class _SelectRequestStep extends StatelessWidget {
  final FlightLeg offeredLeg;
  final VoidCallback onOpenDrop;
  final ValueChanged<FlightLeg> onLegSelected;

  const _SelectRequestStep({
    required this.offeredLeg,
    required this.onOpenDrop,
    required this.onLegSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trade Type', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15,
                fontFamily: 'Inter',
              )),
              const Text('Choose trade type',
                  style: TextStyle(color: CIPTheme.grey500, fontSize: 13)),
              const SizedBox(height: 12),
              _TradeTypeCard(
                emoji: '🌐',
                title: 'Open Drop',
                titleAr: 'Open Drop',
                subtitle: 'Post your leg — anyone can pick it up',
                subtitleAr: 'Post your leg - anyone can pick it up',
                onTap: onOpenDrop,
              ),
              const SizedBox(height: 8),
              _TradeTypeCard(
                emoji: '🔄',
                title: 'Direct Swap',
                titleAr: 'Direct Swap',
                subtitle: 'Choose a specific leg from the board to swap with',
                subtitleAr: 'Choose a specific leg from the board to swap with',
                onTap: () {},
                isDisabled: true,
                disabledNote: 'Browse the trade board to find a specific swap',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TradeTypeCard extends StatelessWidget {
  final String emoji, title, titleAr, subtitle, subtitleAr;
  final VoidCallback onTap;
  final bool isDisabled;
  final String? disabledNote;

  const _TradeTypeCard({
    required this.emoji,
    required this.title,
    required this.titleAr,
    required this.subtitle,
    required this.subtitleAr,
    required this.onTap,
    this.isDisabled = false,
    this.disabledNote,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CIPTheme.grey200),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleAr, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontFamily: 'Inter',
                    )),
                    Text(title, style: const TextStyle(
                      fontWeight: FontWeight.w600, color: CIPTheme.saudiNavy,
                    )),
                    Text(subtitleAr, style: const TextStyle(
                      fontSize: 12, color: CIPTheme.grey500,
                      fontFamily: 'Inter',
                    )),
                    if (disabledNote != null)
                      Text(disabledNote!, style: const TextStyle(
                        fontSize: 11, color: CIPTheme.warningAmber,
                      )),
                  ],
                ),
              ),
              if (!isDisabled)
                const Icon(Icons.chevron_right, color: CIPTheme.grey500),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 3: Confirm ──────────────────────────────────────────────────────────
class _ConfirmStep extends StatelessWidget {
  final FlightLeg offeredLeg;
  final FlightLeg? requestedLeg;
  final bool isOpenDrop, isAnonymous, checkingLegality, submitting;
  final LegalityResult? legalityResult;
  final TextEditingController noteController;
  final ValueChanged<bool> onAnonymousToggle;
  final VoidCallback onBack, onSubmit;

  const _ConfirmStep({
    required this.offeredLeg,
    this.requestedLeg,
    required this.isOpenDrop,
    required this.isAnonymous,
    required this.checkingLegality,
    required this.submitting,
    this.legalityResult,
    required this.noteController,
    required this.onAnonymousToggle,
    required this.onBack,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final canSubmit = !checkingLegality &&
        !submitting &&
        (legalityResult == null || legalityResult!.passed);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CIPTheme.grey200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trade Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _SummaryRow('Offering', offeredLeg.flightNumber,
                    '${offeredLeg.origin} → ${offeredLeg.destination}'),
                if (!isOpenDrop && requestedLeg != null)
                  _SummaryRow('Requesting', requestedLeg!.flightNumber,
                      '${requestedLeg!.origin} → ${requestedLeg!.destination}'),
                if (isOpenDrop)
                  const _SummaryRow('Type', 'Open Drop', 'Anyone can pick this up'),
                const SizedBox(height: 8),
                const Text('Expires in 72 hours',
                    style: TextStyle(fontSize: 12, color: CIPTheme.grey500)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Legality status
          if (checkingLegality)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CIPTheme.grey200),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: CIPTheme.saudiNavy)),
                  SizedBox(width: 10),
                  Text('Checking legality...'),
                ],
              ),
            )
          else if (legalityResult != null)
            LegalityPanel(result: legalityResult!),

          const SizedBox(height: 12),

          // Options
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CIPTheme.grey200),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Post anonymously', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Hide your name; show rank + base only',
                      style: TextStyle(fontSize: 12)),
                  value: isAnonymous,
                  onChanged: onAnonymousToggle,
                  activeColor: CIPTheme.saudiNavy,
                  contentPadding: EdgeInsets.zero,
                ),
                TextField(
                  controller: noteController,
                  maxLength: 200,
                  maxLines: 2,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'Optional note',
                    hintStyle: const TextStyle(color: CIPTheme.grey500, fontSize: 13),
                    filled: true,
                    fillColor: CIPTheme.grey50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: CIPTheme.grey200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: CIPTheme.grey200),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, 52),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: canSubmit ? onSubmit : null,
                  child: submitting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Post Trade Request'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value, subtitle;
  const _SummaryRow(this.label, this.value, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: CIPTheme.grey500)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: CIPTheme.grey700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leg select tile ──────────────────────────────────────────────────────────
class _LegSelectTile extends StatelessWidget {
  final FlightLeg leg;
  final VoidCallback onTap;
  const _LegSelectTile({required this.leg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final depTime = DateFormat('dd MMM HH:mm').format(leg.departureLT);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CIPTheme.grey200),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: leg.legType == LegType.international
                    ? CIPTheme.legalGreen.withOpacity(0.1)
                    : CIPTheme.restBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.flight_takeoff,
                  size: 18,
                  color: leg.legType == LegType.international
                      ? CIPTheme.legalGreen
                      : CIPTheme.restBlue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(leg.flightNumber,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${leg.origin} → ${leg.destination}  ·  $depTime',
                      style: const TextStyle(
                          fontSize: 12, color: CIPTheme.grey500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: CIPTheme.grey300),
          ],
        ),
      ),
    );
  }
}
