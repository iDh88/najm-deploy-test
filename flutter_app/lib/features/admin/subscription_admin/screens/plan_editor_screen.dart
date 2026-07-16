import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../subscription/models/subscription_models.dart';
import '../../../subscription/services/subscription_service.dart';

/// Editable plan name/description/benefits/price. Saves directly to
/// subscriptionConfig.plans — no deploy needed.
class PlanEditorScreen extends StatefulWidget {
  final String tier;   // "FREE" | "PRO"
  const PlanEditorScreen({super.key, required this.tier});

  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> {
  final _svc = SubscriptionService();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final List<TextEditingController> _benefitCtrls = [];
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;

  PlanTier get _tier => widget.tier == 'PRO' ? PlanTier.pro : PlanTier.free;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final plans = await _svc.getPlans();
      final plan = plans.where((p) => p.tier == _tier).firstOrNull;
      if (plan != null) {
        _nameCtrl.text = plan.displayName;
        _descCtrl.text = plan.description;
        _priceCtrl.text = plan.priceLabel ?? '';
        _isActive = plan.isActive;
        for (final b in plan.benefits) {
          _benefitCtrls.add(TextEditingController(text: b));
        }
      }
      if (_benefitCtrls.isEmpty) _benefitCtrls.add(TextEditingController());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    for (final c in _benefitCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addBenefit() => setState(() => _benefitCtrls.add(TextEditingController()));

  void _removeBenefit(int i) => setState(() {
    _benefitCtrls[i].dispose();
    _benefitCtrls.removeAt(i);
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final benefits = _benefitCtrls
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await _svc.adminUpdatePlan(
        tier: _tier,
        displayName: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        benefits: benefits,
        priceLabel: _priceCtrl.text.trim().isEmpty ? null : _priceCtrl.text.trim(),
        isActive: _isActive,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan updated'), backgroundColor: CIPTheme.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: Text('Edit ${widget.tier == 'PRO' ? 'Pro' : 'Free'} Plan',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CIPTheme.primary))
                : const Text('Save', style: TextStyle(color: CIPTheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CIPTheme.primary))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const _Label('Plan Name'),
                const SizedBox(height: 6),
                TextField(controller: _nameCtrl,
                    style: const TextStyle(color: CIPTheme.textPrimary)),
                const SizedBox(height: 16),

                const _Label('Description'),
                const SizedBox(height: 6),
                TextField(controller: _descCtrl, maxLines: 2,
                    style: const TextStyle(color: CIPTheme.textPrimary)),
                const SizedBox(height: 16),

                const _Label('Price Label (display only)'),
                const SizedBox(height: 6),
                TextField(controller: _priceCtrl,
                    style: const TextStyle(color: CIPTheme.textPrimary),
                    decoration: const InputDecoration(hintText: 'e.g. \$4.99/mo')),
                const SizedBox(height: 4),
                const Text(
                  'For display only — actual pricing comes from the App Store / '
                  'Google Play once subscriptions go live.',
                  style: TextStyle(color: CIPTheme.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 20),

                Row(children: [
                  const Expanded(child: _Label('Benefits')),
                  TextButton.icon(
                    onPressed: _addBenefit,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
                ]),
                const SizedBox(height: 6),
                ...List.generate(_benefitCtrls.length, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _benefitCtrls[i],
                        style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: CIPTheme.error, size: 18),
                      onPressed: () => _removeBenefit(i),
                    ),
                  ]),
                )),
                const SizedBox(height: 20),

                Row(children: [
                  const Expanded(child: _Label('Plan active')),
                  Switch(
                    value: _isActive,
                    activeColor: CIPTheme.primary,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ]),
              ],
            ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: CIPTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600));
}
