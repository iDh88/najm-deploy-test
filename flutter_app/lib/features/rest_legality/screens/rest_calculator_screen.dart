import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../models/rest_models.dart';
import '../providers/rest_providers.dart';
import '../widgets/legality_card.dart';
import '../widgets/timeline_widget.dart';

class RestCalculatorScreen extends ConsumerStatefulWidget {
  // Optional prefill from trade/line screens
  final DateTime? prefillDutyStart;
  final DateTime? prefillDutyEnd;
  final int?      prefillLegs;
  final bool?     prefillIsIntl;
  final DateTime? prefillNextDuty;
  final double?   prefillCarryOver;

  const RestCalculatorScreen({
    super.key,
    this.prefillDutyStart,
    this.prefillDutyEnd,
    this.prefillLegs,
    this.prefillIsIntl,
    this.prefillNextDuty,
    this.prefillCarryOver,
  });

  @override
  ConsumerState<RestCalculatorScreen> createState() =>
      _RestCalculatorScreenState();
}

class _RestCalculatorScreenState
    extends ConsumerState<RestCalculatorScreen> {

  // Form state
  DateTime? _dutyStart;
  DateTime? _dutyEnd;
  DateTime? _nextDuty;
  int       _reportHour   = 8;
  int       _operLegs     = 2;
  int       _dhLegs       = 0;
  int       _blockMins    = 0;
  bool      _isIntl       = true;
  bool      _isAugmented  = false;
  double    _carryOver    = 0.0;
  String    _crewType     = 'cabin_standard';
  String    _localTz      = 'Asia/Riyadh';

  @override
  void initState() {
    super.initState();
    _dutyStart = widget.prefillDutyStart;
    _dutyEnd   = widget.prefillDutyEnd;
    _nextDuty  = widget.prefillNextDuty;
    _operLegs  = widget.prefillLegs  ?? 2;
    _isIntl    = widget.prefillIsIntl ?? true;
    _carryOver = widget.prefillCarryOver ?? 0.0;
  }

  Future<void> _calculate() async {
    if (_dutyStart == null || _dutyEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set duty start and end times first')),
      );
      return;
    }
    await ref.read(restCalcProvider.notifier).calculate(
      dutyStartUtc:     _dutyStart!.toUtc(),
      dutyEndUtc:       _dutyEnd!.toUtc(),
      reportLocalHour:  _reportHour,
      numOperatingLegs: _operLegs,
      numDeadheadLegs:  _dhLegs,
      blockMinutes:     _blockMins,
      isInternational:  _isIntl,
      isAugmented:      _isAugmented,
      localTz:          _localTz,
      carryOverHours:   _carryOver,
      nextDutyStartUtc: _nextDuty?.toUtc(),
      crewType:         _crewType,
    );
  }

  @override
  Widget build(BuildContext context) {
    final calcState = ref.watch(restCalcProvider);

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Rest Calculator',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (calcState.hasResult)
            TextButton(
              onPressed: ref.read(restCalcProvider.notifier).reset,
              child: const Text('Reset',
                  style: TextStyle(color: CIPTheme.primary)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Input Form ──────────────────────────────────────────────────
          _InputCard(
            dutyStart:    _dutyStart,
            dutyEnd:      _dutyEnd,
            nextDuty:     _nextDuty,
            reportHour:   _reportHour,
            operLegs:     _operLegs,
            dhLegs:       _dhLegs,
            blockMins:    _blockMins,
            isIntl:       _isIntl,
            isAugmented:  _isAugmented,
            carryOver:    _carryOver,
            crewType:     _crewType,
            onDutyStartChanged:  (v) => setState(() => _dutyStart  = v),
            onDutyEndChanged:    (v) => setState(() => _dutyEnd    = v),
            onNextDutyChanged:   (v) => setState(() => _nextDuty   = v),
            onReportHourChanged: (v) => setState(() => _reportHour = v),
            onOperLegsChanged:   (v) => setState(() => _operLegs   = v),
            onDhLegsChanged:     (v) => setState(() => _dhLegs     = v),
            onBlockMinsChanged:  (v) => setState(() => _blockMins  = v),
            onIsIntlChanged:     (v) => setState(() => _isIntl     = v),
            onIsAugmentedChanged:(v) => setState(() => _isAugmented = v),
            onCarryOverChanged:  (v) => setState(() => _carryOver  = v),
            onCrewTypeChanged:   (v) => setState(() => _crewType   = v),
          ),
          const SizedBox(height: 14),

          // ── Calculate button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: calcState.isLoading ? null : _calculate,
              style: ElevatedButton.styleFrom(
                backgroundColor: CIPTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: calcState.isLoading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.calculate_outlined, size: 18),
              label: Text(
                calcState.isLoading ? 'Calculating…' : 'Check Legality & Rest',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),

          // ── Error ───────────────────────────────────────────────────────
          if (calcState.status == RestCalcStatus.error &&
              calcState.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CIPTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: CIPTheme.error.withOpacity(0.3)),
              ),
              child: Text(calcState.error!,
                  style: const TextStyle(
                      color: CIPTheme.error, fontSize: 12)),
            ),
          ],

          // ── Results ─────────────────────────────────────────────────────
          if (calcState.hasResult) ...[
            const SizedBox(height: 20),

            // Legality status
            if (calcState.legality != null)
              LegalityCard(result: calcState.legality!),

            const SizedBox(height: 12),

            // Fatigue
            if (calcState.fatigue != null)
              FatigueBar(
                result:      calcState.fatigue!,
                showFactors: true,
              ),

            const SizedBox(height: 12),

            // Timeline
            if (calcState.legality != null)
              DutyTimelineWidget(legality: calcState.legality!),

            const SizedBox(height: 12),

            // FDP details
            if (calcState.legality?.fdp != null)
              FDPWidget(fdp: calcState.legality!.fdp!),

            // Rest details
            if (calcState.legality?.rest != null) ...[
              const SizedBox(height: 12),
              RestCountdownWidget(rest: calcState.legality!.rest!),
            ],

            // Carry-over
            if (calcState.safety?.legality?.carryOver != null) ...[
              const SizedBox(height: 12),
              _CarryOverCard(co: calcState.safety!.legality!.carryOver!),
            ],

            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }
}

// ── Input card ────────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  final DateTime? dutyStart, dutyEnd, nextDuty;
  final int reportHour, operLegs, dhLegs, blockMins;
  final bool isIntl, isAugmented;
  final double carryOver;
  final String crewType;
  final ValueChanged<DateTime?> onDutyStartChanged, onDutyEndChanged, onNextDutyChanged;
  final ValueChanged<int>    onReportHourChanged, onOperLegsChanged,
                              onDhLegsChanged, onBlockMinsChanged;
  final ValueChanged<bool>   onIsIntlChanged, onIsAugmentedChanged;
  final ValueChanged<double> onCarryOverChanged;
  final ValueChanged<String> onCrewTypeChanged;

  const _InputCard({
    required this.dutyStart, required this.dutyEnd, required this.nextDuty,
    required this.reportHour, required this.operLegs, required this.dhLegs,
    required this.blockMins, required this.isIntl, required this.isAugmented,
    required this.carryOver, required this.crewType,
    required this.onDutyStartChanged, required this.onDutyEndChanged,
    required this.onNextDutyChanged, required this.onReportHourChanged,
    required this.onOperLegsChanged, required this.onDhLegsChanged,
    required this.onBlockMinsChanged, required this.onIsIntlChanged,
    required this.onIsAugmentedChanged, required this.onCarryOverChanged,
    required this.onCrewTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Duty Details',
              style: TextStyle(
                  color: CIPTheme.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),

          // Date/time pickers
          _DateTimePicker('Duty Start (UTC)', dutyStart, onDutyStartChanged, context),
          const SizedBox(height: 10),
          _DateTimePicker('Duty End / Release (UTC)', dutyEnd, onDutyEndChanged, context),
          const SizedBox(height: 10),
          _DateTimePicker('Next Duty Start (optional)', nextDuty, onNextDutyChanged, context),
          const SizedBox(height: 16),

          // Numeric inputs row
          Row(children: [
            Expanded(child: _IntStepper('Operating Legs', operLegs,
                onOperLegsChanged, 0, 12)),
            const SizedBox(width: 10),
            Expanded(child: _IntStepper('Deadhead Legs', dhLegs,
                onDhLegsChanged, 0, 8)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _IntStepper('Report Hour (local)', reportHour,
                onReportHourChanged, 0, 23)),
            const SizedBox(width: 10),
            Expanded(child: _IntStepper('Block Mins', blockMins,
                (v) => onBlockMinsChanged(v * 30), 0, 30,
                displayValue: (blockMins / 30).round())),
          ]),
          const SizedBox(height: 14),

          // Toggles
          _Toggle('International route', isIntl, onIsIntlChanged),
          _Toggle('Augmented crew',      isAugmented, onIsAugmentedChanged),
          const SizedBox(height: 10),

          // Crew type
          _Dropdown('Crew Type', crewType, const {
            'cabin_standard':  'Cabin — Standard',
            'cabin_long_haul': 'Cabin — Long Haul',
            'cockpit':         'Cockpit',
            'augmented':       'Augmented',
          }, onCrewTypeChanged),
        ],
      ),
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final BuildContext parentContext;

  const _DateTimePicker(this.label, this.value, this.onChanged,
      this.parentContext);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: parentContext,
          initialDate: value ?? DateTime.now().toUtc(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: CIPTheme.primary)),
            child: child!,
          ),
        );
        if (date == null) return;
        final time = await showTimePicker(
          context: parentContext,
          initialTime: TimeOfDay.fromDateTime(value ?? DateTime.now().toUtc()),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: CIPTheme.primary)),
            child: child!,
          ),
        );
        if (time == null) return;
        onChanged(DateTime.utc(
            date.year, date.month, date.day, time.hour, time.minute));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CIPTheme.navLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: value != null
                  ? CIPTheme.primary.withOpacity(0.5)
                  : CIPTheme.divider),
        ),
        child: Row(children: [
          Icon(Icons.access_time,
              color: value != null ? CIPTheme.primary : CIPTheme.textMuted,
              size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: CIPTheme.textMuted, fontSize: 10)),
                Text(
                  value != null
                      ? '${value!.toUtc().toIso8601String().substring(0, 16)}Z'
                      : 'Tap to set',
                  style: TextStyle(
                      color: value != null
                          ? CIPTheme.textPrimary
                          : CIPTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: () => onChanged(null),
              child: const Icon(Icons.clear,
                  color: CIPTheme.textMuted, size: 14),
            ),
        ]),
      ),
    );
  }
}

class _IntStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min, max;
  final int? displayValue;

  const _IntStepper(this.label, this.value, this.onChanged, this.min, this.max,
      {this.displayValue});

  @override
  Widget build(BuildContext context) {
    final disp = displayValue ?? value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CIPTheme.navLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(children: [
        Text(label,
            style: const TextStyle(
                color: CIPTheme.textMuted, fontSize: 10),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: value > min ? () => onChanged(value - 1) : null,
            child: Icon(Icons.remove_circle_outline,
                color: value > min ? CIPTheme.primary : CIPTheme.textMuted,
                size: 20),
          ),
          const SizedBox(width: 10),
          Text('$disp',
              style: const TextStyle(
                  color: CIPTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: value < max ? () => onChanged(value + 1) : null,
            child: Icon(Icons.add_circle_outline,
                color: value < max ? CIPTheme.primary : CIPTheme.textMuted,
                size: 20),
          ),
        ]),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(label,
            style: const TextStyle(
                color: CIPTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Switch(
          value:          value,
          onChanged:      onChanged,
          activeColor:    CIPTheme.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  const _Dropdown(this.label, this.value, this.options, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: CIPTheme.textMuted, fontSize: 10)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value:           value,
          dropdownColor:   CIPTheme.navLight,
          style:           const TextStyle(
              color: CIPTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CIPTheme.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: CIPTheme.divider),
            ),
            filled:      true,
            fillColor:   CIPTheme.navLight,
          ),
          items: options.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

// ── Carry-over card ───────────────────────────────────────────────────────────

class _CarryOverCard extends StatelessWidget {
  final CarryOverResult co;
  const _CarryOverCard({required this.co});

  @override
  Widget build(BuildContext context) {
    final color = co.isWithinLimit ? CIPTheme.success : CIPTheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('📊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text('Carry-Over Status',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${co.percentageUsed.toStringAsFixed(0)}% used',
                style: TextStyle(
                    color: color, fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value:           (co.percentageUsed / 100).clamp(0.0, 1.0),
              backgroundColor: CIPTheme.navLight,
              valueColor:      AlwaysStoppedAnimation(color),
              minHeight:       6,
            ),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Text('${co.carryOverHours.toStringAsFixed(1)}h used',
                style: const TextStyle(
                    color: CIPTheme.textMuted, fontSize: 11)),
            const Spacer(),
            Text('${co.remainingHours.toStringAsFixed(1)}h remaining',
                style: const TextStyle(
                    color: CIPTheme.textMuted, fontSize: 11)),
          ]),
        ],
      ),
    );
  }
}
