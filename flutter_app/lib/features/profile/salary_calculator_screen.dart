import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';

// ─── Hive Storage Keys ────────────────────────────────────────────────────────
const _kBox          = 'salaryCalc';
const _kFlying       = 'flyingHours';
const _kCredit       = 'creditHours';
const _kDaysOff      = 'daysOffHours';
const _kIntlLayover  = 'intlLayoverHours';
const _kDomLayover   = 'domLayoverHours';
const _kBasic        = 'basicSalary';
const _kHousing      = 'housingSalary';
const _kTransport    = 'transportSalary';
const _kHousingAuto  = 'housingAuto';
const _kGosi         = 'gosiEnabled';
const _kSanid        = 'sanidEnabled';
const _kHistory      = 'salaryHistory';
const _kSavedMonth   = 'savedMonth';
const _kCustomIncome = 'customIncome';
const _kCustomDeduct = 'customDeductions';

// ─── Models ───────────────────────────────────────────────────────────────────
class HoursInput {
  double hours;
  int    minutes;
  HoursInput({this.hours = 0, this.minutes = 0});
  double get decimal => hours + minutes / 60.0;
  String get formatted =>
      '${hours.toInt().toString().padLeft(2,'0')}:${minutes.toString().padLeft(2,'0')}';
}

class CustomItem {
  String label;
  double amount;
  CustomItem({required this.label, required this.amount});
  Map<String, dynamic> toMap() => {'label': label, 'amount': amount};
  factory CustomItem.fromMap(Map m) =>
      CustomItem(label: m['label'] as String? ?? '', amount: ((m['amount'] ?? 0) as num).toDouble());
}

class MonthHistory {
  final String month;
  final double gross;
  final double net;
  MonthHistory({required this.month, required this.gross, required this.net});
  Map<String, dynamic> toMap() =>
      {'month': month, 'gross': gross, 'net': net};
  factory MonthHistory.fromMap(Map m) => MonthHistory(
      month: m['month'] as String? ?? '',
      gross: ((m['gross'] ?? 0) as num).toDouble(),
      net:   ((m['net']   ?? 0) as num).toDouble());
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final salaryCalcProvider =
    ChangeNotifierProvider<SalaryCalcNotifier>((_) => SalaryCalcNotifier());

class SalaryCalcNotifier extends ChangeNotifier {
  late Box _box;
  bool _ready = false;

  // ── Hours inputs ──────────────────────────────────────────────────────────
  HoursInput flying       = HoursInput();
  HoursInput credit       = HoursInput();
  HoursInput daysOff      = HoursInput();
  HoursInput intlLayover  = HoursInput();
  HoursInput domLayover   = HoursInput();

  // ── Salary inputs ─────────────────────────────────────────────────────────
  double basic     = 0;
  double housing   = 0;
  double transport = 400;
  bool   housingAuto = true;

  // ── Deductions ────────────────────────────────────────────────────────────
  bool   gosiEnabled  = true;
  bool   sanidEnabled = true;
  double gosiRate     = 9.0;
  double sanidRate    = 0.75;

  // ── Rates (editable in advanced) ─────────────────────────────────────────
  double domLayoverRate   = 11.0;
  double intlLayoverRate  = 14.5;
  double prod1Rate        = 75.0;   // 50–65h
  double prod2Rate        = 90.0;   // 65–80h
  double prod3Rate        = 110.0;  // 80h+
  double bonus1Pct        = 3.5;    // 65–75h
  double bonus1Min        = 150.0;
  double bonus2Pct        = 6.0;    // 75–85h
  double bonus2Min        = 250.0;
  double bonus3Pct        = 8.0;    // 85h+
  double bonus3Min        = 350.0;
  double overtimeDivisor  = 70.0;
  double daysOffRate      = 60.0;
  double daysOffMinPer    = 150.0;

  // ── Custom items ──────────────────────────────────────────────────────────
  List<CustomItem> customIncome      = [];
  List<CustomItem> customDeductions  = [];

  // ── History ───────────────────────────────────────────────────────────────
  List<MonthHistory> history = [];

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    _box = await Hive.openBox(_kBox);
    _checkMonthReset();
    _load();
    _ready = true;
    notifyListeners();
  }

  bool get ready => _ready;

  void _checkMonthReset() {
    final savedMonth = _box.get(_kSavedMonth, defaultValue: '') as String;
    final thisMonth  = DateFormat('yyyy-MM').format(DateTime.now());
    if (savedMonth != thisMonth) {
      // New month — save last month to history if there's data
      final lastBasic = (_box.get(_kBasic, defaultValue: 0) as num).toDouble();
      if (lastBasic > 0 && savedMonth.isNotEmpty) {
        final hist = _loadHistory();
        if (hist.length >= 6) hist.removeLast();
        // We'll add after calc — just clear hours
        _box.put(_kFlying,      {'h': 0, 'm': 0});
        _box.put(_kCredit,      {'h': 0, 'm': 0});
        _box.put(_kDaysOff,     {'h': 0, 'm': 0});
        _box.put(_kIntlLayover, {'h': 0, 'm': 0});
        _box.put(_kDomLayover,  {'h': 0, 'm': 0});
      }
      _box.put(_kSavedMonth, thisMonth);
    }
  }

  void _load() {
    flying      = _loadHours(_kFlying);
    credit      = _loadHours(_kCredit);
    daysOff     = _loadHours(_kDaysOff);
    intlLayover = _loadHours(_kIntlLayover);
    domLayover  = _loadHours(_kDomLayover);
    basic       = (_box.get(_kBasic,     defaultValue: 0)   as num).toDouble();
    housing     = (_box.get(_kHousing,   defaultValue: 0)   as num).toDouble();
    transport   = (_box.get(_kTransport, defaultValue: 400) as num).toDouble();
    housingAuto = _box.get(_kHousingAuto, defaultValue: true) as bool;
    gosiEnabled = _box.get(_kGosi,  defaultValue: true) as bool;
    sanidEnabled= _box.get(_kSanid, defaultValue: true) as bool;
    if (housingAuto && basic > 0) housing = (basic * 0.25).roundToDouble();
    history      = _loadHistory();
    customIncome = _loadCustom(_kCustomIncome);
    customDeductions = _loadCustom(_kCustomDeduct);
  }

  HoursInput _loadHours(String key) {
    final m = _box.get(key, defaultValue: <String, dynamic>{'h': 0, 'm': 0});
    return HoursInput(
      hours:   ((m['h'] ?? 0) as num).toDouble(),
      minutes: ((m['m'] ?? 0) as num).toInt(),
    );
  }

  List<MonthHistory> _loadHistory() {
    final raw = _box.get(_kHistory, defaultValue: []);
    return (raw as List).map((e) => MonthHistory.fromMap(Map.from(e as Map))).toList();
  }

  List<CustomItem> _loadCustom(String key) {
    final raw = _box.get(key, defaultValue: []);
    return (raw as List).map((e) => CustomItem.fromMap(Map.from(e as Map))).toList();
  }

  void _save() {
    _box.put(_kFlying,      {'h': flying.hours,      'm': flying.minutes});
    _box.put(_kCredit,      {'h': credit.hours,      'm': credit.minutes});
    _box.put(_kDaysOff,     {'h': daysOff.hours,     'm': daysOff.minutes});
    _box.put(_kIntlLayover, {'h': intlLayover.hours,  'm': intlLayover.minutes});
    _box.put(_kDomLayover,  {'h': domLayover.hours,   'm': domLayover.minutes});
    _box.put(_kBasic,       basic);
    _box.put(_kHousing,     housing);
    _box.put(_kTransport,   transport);
    _box.put(_kHousingAuto, housingAuto);
    _box.put(_kGosi,        gosiEnabled);
    _box.put(_kSanid,       sanidEnabled);
    _box.put(_kCustomIncome, customIncome.map((e) => e.toMap()).toList());
    _box.put(_kCustomDeduct, customDeductions.map((e) => e.toMap()).toList());
  }

  // ── Setters ───────────────────────────────────────────────────────────────
  void setFlying(double h, int m)      { flying = HoursInput(hours: h, minutes: m); _saveNotify(); }
  void setCredit(double h, int m)      { credit = HoursInput(hours: h, minutes: m); _saveNotify(); }
  void setDaysOff(double h, int m)     { daysOff = HoursInput(hours: h, minutes: m); _saveNotify(); }
  void setIntlLayover(double h, int m) { intlLayover = HoursInput(hours: h, minutes: m); _saveNotify(); }
  void setDomLayover(double h, int m)  { domLayover = HoursInput(hours: h, minutes: m); _saveNotify(); }

  void setBasic(double v) {
    basic = v;
    if (housingAuto) housing = (v * 0.25).roundToDouble();
    _saveNotify();
  }

  void setHousing(double v)    { housing = v; housingAuto = false; _saveNotify(); }
  void setTransport(double v)  { transport = v; _saveNotify(); }
  void toggleHousingAuto() {
    housingAuto = !housingAuto;
    if (housingAuto) housing = (basic * 0.25).roundToDouble();
    _saveNotify();
  }
  void toggleGosi()  { gosiEnabled  = !gosiEnabled;  _saveNotify(); }
  void toggleSanid() { sanidEnabled = !sanidEnabled; _saveNotify(); }

  void addCustomIncome(String label, double amount) {
    customIncome.add(CustomItem(label: label, amount: amount));
    _saveNotify();
  }
  void removeCustomIncome(int i) { customIncome.removeAt(i); _saveNotify(); }
  void addCustomDeduction(String label, double amount) {
    customDeductions.add(CustomItem(label: label, amount: amount));
    _saveNotify();
  }
  void removeCustomDeduction(int i) { customDeductions.removeAt(i); _saveNotify(); }

  void resetToDefaults() {
    domLayoverRate = 11.0; intlLayoverRate = 14.5;
    prod1Rate = 75.0; prod2Rate = 90.0; prod3Rate = 110.0;
    bonus1Pct = 3.5; bonus1Min = 150.0;
    bonus2Pct = 6.0; bonus2Min = 250.0;
    bonus3Pct = 8.0; bonus3Min = 350.0;
    overtimeDivisor = 70.0; daysOffRate = 60.0; daysOffMinPer = 150.0;
    gosiRate = 9.0; sanidRate = 0.75;
    _saveNotify();
  }

  void saveToHistory() {
    final result = calculate();
    final month = DateFormat('MMM yyyy').format(DateTime.now());
    history.removeWhere((h) => h.month == month);
    history.insert(0, MonthHistory(month: month, gross: result.grossTotal, net: result.netPay));
    if (history.length > 6) history = history.sublist(0, 6);
    _box.put(_kHistory, history.map((e) => e.toMap()).toList());
    notifyListeners();
  }

  void _saveNotify() { _save(); notifyListeners(); }

  // ─────────────────────────────────────────────────────────────────────────
  // CALCULATION ENGINE
  // ─────────────────────────────────────────────────────────────────────────
  SalaryResult calculate() {
    if (basic <= 0) {
      return SalaryResult.empty();
    }

    final blk = flying.decimal;
    final crd = credit.decimal;

    // 1 — Productivity Allowance (TIERED — each band at its own rate)
    // 50:01–65:00h → SAR 75/hr  |  65:01–80:00h → SAR 90/hr  |  80:01h+ → SAR 110/hr
    double prodRate = 0;
    double prodAllowance = 0;
    String prodNote = '';
    if (blk <= 50) {
      prodNote = 'Below 50h threshold — no allowance';
    } else {
      final tier1 = (min(blk, 65) - 50).clamp(0.0, 15.0);   // 50:01–65:00
      final tier2 = (min(blk, 80) - 65).clamp(0.0, 15.0);   // 65:01–80:00
      final tier3 = (blk - 80).clamp(0.0, double.infinity);  // 80:01+
      prodAllowance = (tier1 * prod1Rate) + (tier2 * prod2Rate) + (tier3 * prod3Rate);
      // Use highest tier reached as display rate
      prodRate = blk > 80 ? prod3Rate : blk > 65 ? prod2Rate : prod1Rate;
      prodNote = 'Tiered: ${tier1.toStringAsFixed(2)}h×${prod1Rate.toStringAsFixed(0)}'
          ' + ${tier2.toStringAsFixed(2)}h×${prod2Rate.toStringAsFixed(0)}'
          ' + ${tier3.toStringAsFixed(2)}h×${prod3Rate.toStringAsFixed(0)}';
    }

    // 2 — Flying Bonus (based on block hours)
    double bonusPct = 0; double bonusFixed = 0;
    double bonusFromSalary = 0; double bonusTotal = 0;
    String bonusNote = '';
    if (blk > 85) {
      bonusPct = bonus3Pct; bonusFixed = bonus3Min;
    } else if (blk > 75) {
      bonusPct = bonus2Pct; bonusFixed = bonus2Min;
    } else if (blk > 65) {
      bonusPct = bonus1Pct; bonusFixed = bonus1Min;
    }
    if (bonusPct > 0) {
      bonusFromSalary = basic * (bonusPct / 100);
      // Formula: MAX(% × basic, minimum) — minimum is a floor, not an addition
      bonusTotal  = bonusFromSalary < bonusFixed ? bonusFixed : bonusFromSalary;
      final applied = bonusFromSalary < bonusFixed ? 'minimum applied' : '${bonusPct.toStringAsFixed(1)}% of basic';
      bonusNote = 'MAX(${bonusPct.toStringAsFixed(1)}% × SAR ${_f(basic)}, SAR ${bonusFixed.toStringAsFixed(0)}) = SAR ${_f(bonusTotal)} [$applied]';
    } else {
      bonusNote = 'Below 65h threshold — no bonus';
    }

    // 3 — Layover Expenses
    final intlAmt = intlLayover.decimal * intlLayoverRate;
    final domAmt  = domLayover.decimal  * domLayoverRate;
    final layoverTotal = intlAmt + domAmt;

    // 4 — Overtime (credit hours vs guarantee)
    final otHours  = (crd - overtimeDivisor).clamp(0.0, double.infinity);
    final otRate   = basic / overtimeDivisor;
    // GOM 1.25.5: first 20h at 1:1, beyond 20h at 1.5:1
    double otAmount = 0.0;
    if (otHours <= 0) {
      otAmount = 0.0;
    } else if (otHours <= 20) {
      otAmount = otHours * otRate;
    } else {
      otAmount = (20 * otRate) + ((otHours - 20) * otRate * 1.5);
    }

    // 5 — Days Off Flying
    double daysOffAmount = 0;
    if (daysOff.decimal > 0) {
      final raw = daysOff.decimal * daysOffRate;
      final min = daysOffMinPer;
      daysOffAmount = raw < min ? min : raw;
    }

    // Custom income
    final customIncomeTotal = customIncome.fold(0.0, (s, e) => s + e.amount);

    // Gross
    final grossTotal = basic + housing + transport +
        prodAllowance + bonusTotal + layoverTotal +
        otAmount + daysOffAmount + customIncomeTotal;

    // Deductions
    final gosiBase  = basic + housing;
    final gosiAmt   = gosiEnabled  ? gosiBase * (gosiRate  / 100) : 0.0;
    final sanidAmt  = sanidEnabled ? gosiBase * (sanidRate / 100) : 0.0;
    final customDeductTotal = customDeductions.fold(0.0, (s, e) => s + e.amount);
    final totalDeductions = gosiAmt + sanidAmt + customDeductTotal;

    final netPay = grossTotal - totalDeductions;

    return SalaryResult(
      flyingHours:      blk,
      creditHours:      crd,
      daysOffHours:     daysOff.decimal,
      intlLayoverHours: intlLayover.decimal,
      domLayoverHours:  domLayover.decimal,
      basicSalary:      basic,
      housing:          housing,
      transport:        transport,
      productivityRate: prodRate,
      productivityAllowance: prodAllowance,
      productivityNote: prodNote,
      flyingBonusPct:   bonusPct,
      flyingBonusAmount:bonusTotal,
      flyingBonusNote:  bonusNote,
      intlLayoverAmount:intlAmt,
      domLayoverAmount: domAmt,
      layoverTotal:     layoverTotal,
      overtimeHours:    otHours,
      overtimeRate:     otRate,
      overtimeAmount:   otAmount,
      daysOffAmount:    daysOffAmount,
      customIncomeItems:customIncome,
      customIncomeTotal:customIncomeTotal,
      grossTotal:       grossTotal,
      gosiAmount:       gosiAmt,
      sanidAmount:      sanidAmt,
      customDeductItems:customDeductions,
      totalDeductions:  totalDeductions,
      netPay:           netPay,
    );
  }

  String _f(double v) => NumberFormat('#,##0').format(v);
}

class SalaryResult {
  final double flyingHours, creditHours, daysOffHours;
  final double intlLayoverHours, domLayoverHours;
  final double basicSalary, housing, transport;
  final double productivityRate, productivityAllowance;
  final String productivityNote;
  final double flyingBonusPct, flyingBonusAmount;
  final String flyingBonusNote;
  final double intlLayoverAmount, domLayoverAmount, layoverTotal;
  final double overtimeHours, overtimeRate, overtimeAmount;
  final double daysOffAmount;
  final List<CustomItem> customIncomeItems;
  final double customIncomeTotal;
  final double grossTotal;
  final double gosiAmount, sanidAmount;
  final List<CustomItem> customDeductItems;
  final double totalDeductions;
  final double netPay;
  final bool isEmpty;

  const SalaryResult({
    required this.flyingHours, required this.creditHours,
    required this.daysOffHours, required this.intlLayoverHours,
    required this.domLayoverHours, required this.basicSalary,
    required this.housing, required this.transport,
    required this.productivityRate, required this.productivityAllowance,
    required this.productivityNote, required this.flyingBonusPct,
    required this.flyingBonusAmount, required this.flyingBonusNote,
    required this.intlLayoverAmount, required this.domLayoverAmount,
    required this.layoverTotal, required this.overtimeHours,
    required this.overtimeRate, required this.overtimeAmount,
    required this.daysOffAmount, required this.customIncomeItems,
    required this.customIncomeTotal, required this.grossTotal,
    required this.gosiAmount, required this.sanidAmount,
    required this.customDeductItems, required this.totalDeductions,
    required this.netPay, this.isEmpty = false,
  });

  factory SalaryResult.empty() => const SalaryResult(
    flyingHours: 0, creditHours: 0, daysOffHours: 0,
    intlLayoverHours: 0, domLayoverHours: 0, basicSalary: 0,
    housing: 0, transport: 0, productivityRate: 0,
    productivityAllowance: 0, productivityNote: '',
    flyingBonusPct: 0, flyingBonusAmount: 0, flyingBonusNote: '',
    intlLayoverAmount: 0, domLayoverAmount: 0, layoverTotal: 0,
    overtimeHours: 0, overtimeRate: 0, overtimeAmount: 0,
    daysOffAmount: 0, customIncomeItems: [], customIncomeTotal: 0,
    grossTotal: 0, gosiAmount: 0, sanidAmount: 0, customDeductItems: [],
    totalDeductions: 0, netPay: 0, isEmpty: true,
  );
}

// ─── SCREEN ───────────────────────────────────────────────────────────────────
class SalaryCalculatorScreen extends ConsumerStatefulWidget {
  const SalaryCalculatorScreen({super.key});

  @override
  ConsumerState<SalaryCalculatorScreen> createState() => _SalaryCalcState();
}

class _SalaryCalcState extends ConsumerState<SalaryCalculatorScreen> {
  bool _showBreakdown  = false;
  bool _showAdvanced   = false;
  bool _showHistory    = false;
  bool _decimalMode    = false; // H+M vs DEC
  bool _initialized    = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(salaryCalcProvider).init();
      setState(() => _initialized = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final calc   = ref.watch(salaryCalcProvider);
    final result = calc.ready ? calc.calculate() : SalaryResult.empty();
    final fmt    = NumberFormat('#,##0.00');
    final fmtInt = NumberFormat('#,##0');

    return Scaffold(
      backgroundColor: const Color(0xFF0C111D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C111D),
        foregroundColor: Colors.white,
        title: const Text(
          'PAY COMPUTER',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              calc.saveToHistory();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Saved to history'),
                backgroundColor: CIPTheme.legalGreen,
              ));
            },
            child: const Text('SAVE', style: TextStyle(
              color: CIPTheme.saudiGold, fontSize: 11, letterSpacing: 1.5)),
          ),
        ],
      ),
      body: !_initialized
          ? const Center(child: CircularProgressIndicator(color: CIPTheme.saudiGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ── Input Mode Toggle ──────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ModeToggle(
                        isDecimal: _decimalMode,
                        onToggle: () => setState(() => _decimalMode = !_decimalMode),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── BLOCK HOURS ───────────────────────────────────────
                  _Section(
                    tag: 'INST-A3',
                    title: 'BLOCK HOURS',
                    child: Column(
                      children: [
                        _autosaveBanner(),
                        const SizedBox(height: 12),
                        _HoursRow(
                          label: 'Flying Hours',
                          value: calc.flying,
                          decimalMode: _decimalMode,
                          color: CIPTheme.saudiGold,
                          onChanged: (h, m) => calc.setFlying(h, m),
                        ),
                        _HoursRow(
                          label: 'Credit Hours',
                          value: calc.credit,
                          decimalMode: _decimalMode,
                          color: CIPTheme.restBlue,
                          onChanged: (h, m) => calc.setCredit(h, m),
                        ),
                        _HoursRow(
                          label: 'Flying in Days-Off',
                          value: calc.daysOff,
                          decimalMode: _decimalMode,
                          color: CIPTheme.warningAmber,
                          onChanged: (h, m) => calc.setDaysOff(h, m),
                        ),
                        _HoursRow(
                          label: 'Layover · International',
                          value: calc.intlLayover,
                          decimalMode: _decimalMode,
                          color: CIPTheme.legalGreen,
                          onChanged: (h, m) => calc.setIntlLayover(h, m),
                        ),
                        _HoursRow(
                          label: 'Layover · Domestic',
                          value: calc.domLayover,
                          decimalMode: _decimalMode,
                          color: const Color(0xFF64B6F7),
                          onChanged: (h, m) => calc.setDomLayover(h, m),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: CIPTheme.grey500, size: 14),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Layover values must include the whole pairing — flying time plus the stay.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: CIPTheme.grey500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── SALARY ────────────────────────────────────────────
                  _Section(
                    tag: 'INST-A1',
                    title: 'SALARY',
                    child: Column(
                      children: [
                        _AmountRow(
                          label: 'Basic Salary',
                          value: calc.basic,
                          color: CIPTheme.saudiGold,
                          onChanged: calc.setBasic,
                        ),
                        const SizedBox(height: 8),
                        _AmountRow(
                          label: 'Housing',
                          value: calc.housing,
                          color: CIPTheme.restBlue,
                          subtitle: calc.housingAuto
                              ? 'AUTO: Basic × 0.25'
                              : 'Manual',
                          onChanged: calc.setHousing,
                          trailing: GestureDetector(
                            onTap: calc.toggleHousingAuto,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: calc.housingAuto
                                    ? CIPTheme.restBlue.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: calc.housingAuto
                                      ? CIPTheme.restBlue.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.1)),
                              ),
                              child: Text(
                                'AUTO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: calc.housingAuto
                                      ? CIPTheme.restBlue
                                      : CIPTheme.grey500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AmountRow(
                          label: 'Transportation',
                          value: calc.transport,
                          color: CIPTheme.legalGreen,
                          onChanged: calc.setTransport,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── DEDUCTIONS ────────────────────────────────────────
                  _Section(
                    tag: 'INST-A2',
                    title: 'DEDUCTIONS',
                    child: Column(
                      children: [
                        _DeductionRow(
                          label: 'GOSI',
                          rate: calc.gosiRate,
                          amount: calc.basic > 0
                              ? (calc.basic + calc.housing) * (calc.gosiRate / 100)
                              : 0,
                          enabled: calc.gosiEnabled,
                          onToggle: calc.toggleGosi,
                        ),
                        const SizedBox(height: 8),
                        _DeductionRow(
                          label: 'SANID',
                          rate: calc.sanidRate,
                          amount: calc.basic > 0
                              ? (calc.basic + calc.housing) * (calc.sanidRate / 100)
                              : 0,
                          enabled: calc.sanidEnabled,
                          onToggle: calc.toggleSanid,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DEDUCTIONS APPLY TO BASIC + HOUSING ONLY.',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1,
                              color: CIPTheme.grey500,
                            ),
                          ),
                        ),
                        // Custom deductions
                        if (calc.customDeductions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...calc.customDeductions.asMap().entries.map(
                            (e) => _CustomItemRow(
                              item: e.value,
                              isDeduction: true,
                              onDelete: () => calc.removeCustomDeduction(e.key),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _AddItemButton(
                          label: '+ Add Custom Deduction',
                          onAdd: (label, amount) =>
                              calc.addCustomDeduction(label, amount),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── CUSTOM INCOME ─────────────────────────────────────
                  _Section(
                    tag: 'INST-A4',
                    title: 'CUSTOM INCOME',
                    child: Column(
                      children: [
                        if (calc.customIncome.isNotEmpty)
                          ...calc.customIncome.asMap().entries.map(
                            (e) => _CustomItemRow(
                              item: e.value,
                              isDeduction: false,
                              onDelete: () => calc.removeCustomIncome(e.key),
                            ),
                          ),
                        _AddItemButton(
                          label: '+ Add Custom Income',
                          onAdd: (label, amount) =>
                              calc.addCustomIncome(label, amount),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── RESULT ────────────────────────────────────────────
                  _ResultCard(
                    result: result,
                    showBreakdown: _showBreakdown,
                    onToggleBreakdown: () =>
                        setState(() => _showBreakdown = !_showBreakdown),
                  ),

                  const SizedBox(height: 12),

                  // ── HISTORY ───────────────────────────────────────────
                  if (calc.history.isNotEmpty)
                    _HistoryCard(
                      history: calc.history,
                      showHistory: _showHistory,
                      onToggle: () =>
                          setState(() => _showHistory = !_showHistory),
                    ),

                  const SizedBox(height: 12),

                  // ── ADVANCED ──────────────────────────────────────────
                  _AdvancedSection(
                    calc: calc,
                    expanded: _showAdvanced,
                    onToggle: () =>
                        setState(() => _showAdvanced = !_showAdvanced),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _autosaveBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, color: CIPTheme.legalGreen, size: 8),
          SizedBox(width: 8),
          Text(
            'AUTO-SAVE  ·  persists until month end',
            style: TextStyle(
              fontSize: 11, letterSpacing: 1,
              color: CIPTheme.grey500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-components ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String tag, title;
  final Widget child;
  const _Section({required this.tag, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.5,
                    color: Colors.white.withOpacity(0.3),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(height: 1, width: 40,
                    color: Colors.white.withOpacity(0.1)),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: CIPTheme.saudiGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool isDecimal;
  final VoidCallback onToggle;
  const _ModeToggle({required this.isDecimal, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleTab(label: 'H+M', active: !isDecimal),
            _ToggleTab(label: 'DEC', active: isDecimal),
          ],
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool active;
  const _ToggleTab({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? CIPTheme.saudiNavy : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: active ? Colors.white : CIPTheme.grey500,
        ),
      ),
    );
  }
}

class _HoursRow extends StatelessWidget {
  final String label;
  final HoursInput value;
  final bool decimalMode;
  final Color color;
  final void Function(double h, int m) onChanged;
  const _HoursRow({
    required this.label, required this.value, required this.decimalMode,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9, letterSpacing: 1.5,
              color: color.withOpacity(0.8), fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (!decimalMode)
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    value: value.hours.toStringAsFixed(0),
                    suffix: 'HRS',
                    color: color,
                    onChanged: (v) => onChanged(
                      double.tryParse(v) ?? 0, value.minutes),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NumField(
                    value: value.minutes.toString(),
                    suffix: 'MIN',
                    color: color,
                    onChanged: (v) => onChanged(
                      value.hours, int.tryParse(v) ?? 0),
                  ),
                ),
              ],
            )
          else
            _NumField(
              value: value.decimal.toStringAsFixed(2),
              suffix: 'HRS',
              color: color,
              onChanged: (v) {
                final d = double.tryParse(v) ?? 0;
                onChanged(d.floorToDouble(), ((d % 1) * 60).round());
              },
            ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String? subtitle;
  final Widget? trailing;
  final void Function(double) onChanged;
  const _AmountRow({
    required this.label, required this.value, required this.color,
    this.subtitle, this.trailing, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9, letterSpacing: 1.5,
                color: color.withOpacity(0.8), fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 9, letterSpacing: 0.5,
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ],
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 6),
        _NumField(
          value: value == 0 ? '' : value.toStringAsFixed(0),
          suffix: 'SAR',
          color: color,
          onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
        ),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final String value, suffix;
  final Color color;
  final void Function(String) onChanged;
  const _NumField({
    required this.value, required this.suffix,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              style: const TextStyle(
                color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: '0',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.2), fontSize: 16),
              ),
              onChanged: onChanged,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              suffix,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeductionRow extends StatelessWidget {
  final String label;
  final double rate, amount;
  final bool enabled;
  final VoidCallback onToggle;
  const _DeductionRow({
    required this.label, required this.rate, required this.amount,
    required this.enabled, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label Deduction (${rate.toStringAsFixed(2)}%)',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : CIPTheme.grey500,
                ),
              ),
              Text(
                enabled
                    ? 'SAR ${fmt.format(amount)}/month'
                    : 'Disabled',
                style: const TextStyle(
                    fontSize: 11, color: CIPTheme.grey500),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: (_) => onToggle(),
          activeColor: CIPTheme.saudiNavy,
          activeTrackColor: CIPTheme.saudiNavy.withOpacity(0.4),
          inactiveThumbColor: CIPTheme.grey500,
          inactiveTrackColor: Colors.white.withOpacity(0.1),
        ),
      ],
    );
  }
}

class _CustomItemRow extends StatelessWidget {
  final CustomItem item;
  final bool isDeduction;
  final VoidCallback onDelete;
  const _CustomItemRow(
      {required this.item, required this.isDeduction, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          Text(
            '${isDeduction ? '-' : '+'}SAR ${NumberFormat('#,##0').format(item.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13,
              color: isDeduction ? CIPTheme.violationRed : CIPTheme.legalGreen,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, color: CIPTheme.grey500, size: 16),
          ),
        ],
      ),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  final String label;
  final void Function(String, double) onAdd;
  const _AddItemButton({required this.label, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAddDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: Colors.white.withOpacity(0.12), style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: CIPTheme.saudiGold, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: CIPTheme.saudiGold, fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final labelCtrl  = TextEditingController();
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        title: Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Label',
                labelStyle: TextStyle(color: CIPTheme.grey500),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Amount (SAR)',
                labelStyle: TextStyle(color: CIPTheme.grey500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: CIPTheme.grey500)),
          ),
          TextButton(
            onPressed: () {
              final a = double.tryParse(amountCtrl.text) ?? 0;
              if (labelCtrl.text.isNotEmpty && a > 0) {
                onAdd(labelCtrl.text, a);
              }
              Navigator.pop(context);
            },
            child: const Text('Add',
                style: TextStyle(color: CIPTheme.saudiGold)),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final SalaryResult result;
  final bool showBreakdown;
  final VoidCallback onToggleBreakdown;
  const _ResultCard({
    required this.result,
    required this.showBreakdown,
    required this.onToggleBreakdown,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CIPTheme.saudiNavy.withOpacity(0.8),
            const Color(0xFF0D3266),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CIPTheme.saudiGold.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'FINAL SALARY',
                  style: TextStyle(
                    fontSize: 10, letterSpacing: 3,
                    color: CIPTheme.saudiGold, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                result.isEmpty
                    ? const Text(
                        '— —',
                        style: TextStyle(
                          fontSize: 48, fontWeight: FontWeight.w900,
                          color: Colors.white54,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            fmt.format(result.netPay),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SAR',
                            style: TextStyle(
                              fontSize: 14, color: CIPTheme.saudiGold,
                              fontWeight: FontWeight.w600, letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                if (!result.isEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Gross: SAR ${fmt.format(result.grossTotal)}  ·  Deductions: -SAR ${fmt.format(result.totalDeductions)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
                if (result.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: CIPTheme.warningAmber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: CIPTheme.warningAmber.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'ENTER YOUR BASIC SALARY TO COMPUTE.\nEVERYTHING ELSE IS OPTIONAL.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: CIPTheme.warningAmber,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (!result.isEmpty)
            GestureDetector(
              onTap: onToggleBreakdown,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TAP TO ${showBreakdown ? 'HIDE' : 'EXPAND'}  ·  BREAKDOWN',
                      style: const TextStyle(
                        fontSize: 10, letterSpacing: 1.5,
                        color: CIPTheme.saudiGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      showBreakdown
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: CIPTheme.saudiGold, size: 16,
                    ),
                  ],
                ),
              ),
            ),

          if (showBreakdown && !result.isEmpty)
            _BreakdownTable(result: result),
        ],
      ),
    );
  }
}

class _BreakdownTable extends StatelessWidget {
  final SalaryResult result;
  const _BreakdownTable({required this.result});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');

    List<_BRow> incomeRows = [
      _BRow('Basic Salary',               result.basicSalary,   true),
      _BRow('Housing Allowance',           result.housing,       true),
      _BRow('Transportation',              result.transport,     true),
      if (result.productivityAllowance > 0)
        _BRow('Productivity (${result.productivityNote.split('×').first.trim()})',
            result.productivityAllowance, true),
      if (result.flyingBonusAmount > 0)
        _BRow('Flying Bonus (${result.flyingBonusPct.toStringAsFixed(1)}%)',
            result.flyingBonusAmount, true),
      if (result.intlLayoverAmount > 0)
        _BRow('Layover · International',   result.intlLayoverAmount, true),
      if (result.domLayoverAmount > 0)
        _BRow('Layover · Domestic',        result.domLayoverAmount, true),
      if (result.overtimeAmount > 0)
        _BRow('Overtime (${result.overtimeHours.toStringAsFixed(2)}h)',
            result.overtimeAmount, true),
      if (result.daysOffAmount > 0)
        _BRow('Days-Off Flying',           result.daysOffAmount, true),
      ...result.customIncomeItems.map((e) => _BRow(e.label, e.amount, true)),
    ];

    List<_BRow> deductRows = [
      if (result.gosiAmount > 0)
        _BRow('GOSI (9%)',                 result.gosiAmount,    false),
      if (result.sanidAmount > 0)
        _BRow('SANID (0.75%)',             result.sanidAmount,   false),
      ...result.customDeductItems.map((e) => _BRow(e.label, e.amount, false)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Income section
          const Text(
            'GROSS INCOME',
            style: TextStyle(
              fontSize: 9, letterSpacing: 2,
              color: CIPTheme.legalGreen, fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...incomeRows.map((r) => _buildRow(r, fmt)),
          _buildTotalRow('GROSS TOTAL', result.grossTotal, fmt, CIPTheme.legalGreen),

          const SizedBox(height: 16),

          // Deductions section
          const Text(
            'DEDUCTIONS',
            style: TextStyle(
              fontSize: 9, letterSpacing: 2,
              color: CIPTheme.violationRed, fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (deductRows.isEmpty)
            const Text(
              'No deductions enabled',
              style: TextStyle(color: CIPTheme.grey500, fontSize: 11),
            )
          else
            ...deductRows.map((r) => _buildRow(r, fmt)),
          if (deductRows.isNotEmpty)
            _buildTotalRow(
                'TOTAL DEDUCTIONS', result.totalDeductions, fmt,
                CIPTheme.violationRed,
                prefix: '-'),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: CIPTheme.saudiGold.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'NET PAY',
                  style: TextStyle(
                    fontSize: 12, letterSpacing: 2,
                    fontWeight: FontWeight.w800, color: CIPTheme.saudiGold,
                  ),
                ),
                Text(
                  'SAR ${fmt.format(result.netPay)}',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_BRow row, NumberFormat fmt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            row.label,
            style: const TextStyle(color: CIPTheme.grey500, fontSize: 12),
          ),
          Text(
            '${row.income ? '' : '-'}SAR ${fmt.format(row.amount)}',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: row.income
                  ? Colors.white.withOpacity(0.8)
                  : CIPTheme.violationRed.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, NumberFormat fmt,
      Color color, {String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11, letterSpacing: 1,
              fontWeight: FontWeight.w700, color: color,
            ),
          ),
          Text(
            '$prefix SAR ${fmt.format(amount)}',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800, color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BRow {
  final String label;
  final double amount;
  final bool income;
  const _BRow(this.label, this.amount, this.income);
}

class _HistoryCard extends StatelessWidget {
  final List<MonthHistory> history;
  final bool showHistory;
  final VoidCallback onToggle;
  const _HistoryCard({
    required this.history, required this.showHistory, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'HISTORY',
                    style: TextStyle(
                      fontSize: 11, letterSpacing: 2,
                      color: CIPTheme.saudiGold, fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    showHistory ? Icons.expand_less : Icons.expand_more,
                    color: CIPTheme.grey500, size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (showHistory)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: history.map((h) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        h.month,
                        style: const TextStyle(
                            color: CIPTheme.grey500, fontSize: 12),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'SAR ${fmt.format(h.net)} net',
                            style: const TextStyle(
                              color: Colors.white, fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Gross: SAR ${fmt.format(h.gross)}',
                            style: const TextStyle(
                                color: CIPTheme.grey500, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  final SalaryCalcNotifier calc;
  final bool expanded;
  final VoidCallback onToggle;
  const _AdvancedSection(
      {required this.calc, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.tune, color: CIPTheme.grey500, size: 16),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ADVANCED',
                        style: TextStyle(
                          fontSize: 11, letterSpacing: 2,
                          color: Colors.white, fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Edit calculation rates · Add custom items',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: CIPTheme.grey500, size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CALCULATION RATES',
                    style: TextStyle(
                      fontSize: 9, letterSpacing: 2,
                      color: CIPTheme.grey500, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _RateRow('Layover Domestic (SAR/hour)', calc.domLayoverRate,
                      (v) => calc.domLayoverRate = v),
                  _RateRow('Layover International (SAR/hour)', calc.intlLayoverRate,
                      (v) => calc.intlLayoverRate = v),
                  _RateRow('Productivity 50–65h (SAR/hour)', calc.prod1Rate,
                      (v) => calc.prod1Rate = v),
                  _RateRow('Productivity 66–80h (SAR/hour)', calc.prod2Rate,
                      (v) => calc.prod2Rate = v),
                  _RateRow('Productivity > 80h (SAR/hour)', calc.prod3Rate,
                      (v) => calc.prod3Rate = v),
                  _RateRow('Flying Bonus 65–75h (% of basic)', calc.bonus1Pct,
                      (v) => calc.bonus1Pct = v),
                  _RateRow('Flying Bonus 65–75h minimum (SAR)', calc.bonus1Min,
                      (v) => calc.bonus1Min = v),
                  _RateRow('Flying Bonus 76–85h (% of basic)', calc.bonus2Pct,
                      (v) => calc.bonus2Pct = v),
                  _RateRow('Flying Bonus 76–85h minimum (SAR)', calc.bonus2Min,
                      (v) => calc.bonus2Min = v),
                  _RateRow('Flying Bonus > 85h (% of basic)', calc.bonus3Pct,
                      (v) => calc.bonus3Pct = v),
                  _RateRow('Flying Bonus > 85h minimum (SAR)', calc.bonus3Min,
                      (v) => calc.bonus3Min = v),
                  _RateRow('Overtime divisor (basic ÷ X)', calc.overtimeDivisor,
                      (v) => calc.overtimeDivisor = v),
                  _RateRow('GOSI rate (%)', calc.gosiRate,
                      (v) => calc.gosiRate = v),
                  _RateRow('SANID rate (%)', calc.sanidRate,
                      (v) => calc.sanidRate = v),
                  _RateRow('Days-Off rate (SAR/hour)', calc.daysOffRate,
                      (v) => calc.daysOffRate = v),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: calc.resetToDefaults,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.refresh,
                            color: CIPTheme.saudiGold, size: 14),
                        const SizedBox(width: 4),
                        const Text(
                          'Reset to defaults',
                          style: TextStyle(
                            color: CIPTheme.saudiGold, fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final double value;
  final void Function(double) onChanged;
  const _RateRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: CIPTheme.grey500, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: value.toString(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              onChanged: (v) => onChanged(double.tryParse(v) ?? value),
            ),
          ),
        ],
      ),
    );
  }
}
