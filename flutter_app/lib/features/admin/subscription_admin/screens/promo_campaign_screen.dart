import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../subscription/models/subscription_models.dart';
import '../../../subscription/services/subscription_service.dart';

/// Admin editor for referral reward tiers — "Invite 1 → +7 days,
/// Invite 5 → +30 days" — fully configurable, no code deploy.
class PromoCampaignScreen extends StatefulWidget {
  const PromoCampaignScreen({super.key});

  @override
  State<PromoCampaignScreen> createState() => _PromoCampaignScreenState();
}

class _PromoCampaignScreenState extends State<PromoCampaignScreen> {
  final _svc = SubscriptionService();
  bool _isActive = true;
  List<_TierDraft> _tiers = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _svc.adminGetReferralCampaign();
      setState(() {
        _isActive = data['isActive'] ?? true;
        final rawTiers = (data['tiers'] as List? ?? []);
        _tiers = rawTiers.map((t) => _TierDraft(
          invitesRequired: t['invitesRequired'] ?? 1,
          rewardDays: t['rewardDays'] ?? 7,
          label: t['label'] ?? '',
        )).toList();
        if (_tiers.isEmpty) {
          _tiers = [
            _TierDraft(invitesRequired: 1, rewardDays: 7, label: 'Invite 1 crew member'),
            _TierDraft(invitesRequired: 5, rewardDays: 30, label: 'Invite 5 crew members'),
          ];
        }
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _addTier() => setState(() => _tiers.add(
      _TierDraft(invitesRequired: 1, rewardDays: 7, label: '')));

  void _removeTier(int i) => setState(() => _tiers.removeAt(i));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _svc.adminUpdateReferralCampaign(
        isActive: _isActive,
        tiers: _tiers.map((t) => ReferralTierInfo(
          invitesRequired: t.invitesRequired,
          rewardDays: t.rewardDays,
          label: t.label,
        )).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign updated'), backgroundColor: CIPTheme.success),
        );
        context.pop();
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
        title: const Text('Referral Campaign', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 16, height: 16,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: CIPTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CIPTheme.divider),
                  ),
                  child: Row(children: [
                    const Expanded(child: Text('Campaign active',
                        style: TextStyle(color: CIPTheme.textPrimary, fontSize: 14))),
                    Switch(
                      value: _isActive,
                      activeColor: CIPTheme.primary,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                Row(children: [
                  const Expanded(child: Text('Reward Tiers',
                      style: TextStyle(color: CIPTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
                  TextButton.icon(
                    onPressed: _addTier,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Tier'),
                  ),
                ]),
                const SizedBox(height: 10),

                ...List.generate(_tiers.length, (i) => _TierEditorCard(
                  tier: _tiers[i],
                  onChanged: (t) => setState(() => _tiers[i] = t),
                  onRemove: () => _removeTier(i),
                )),
              ],
            ),
    );
  }
}

class _TierDraft {
  int invitesRequired;
  int rewardDays;
  String label;
  _TierDraft({required this.invitesRequired, required this.rewardDays, required this.label});
}

class _TierEditorCard extends StatefulWidget {
  final _TierDraft tier;
  final ValueChanged<_TierDraft> onChanged;
  final VoidCallback onRemove;

  const _TierEditorCard({required this.tier, required this.onChanged, required this.onRemove});

  @override
  State<_TierEditorCard> createState() => _TierEditorCardState();
}

class _TierEditorCardState extends State<_TierEditorCard> {
  late TextEditingController _labelCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.tier.label);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            Expanded(
              child: TextField(
                controller: _labelCtrl,
                style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                    hintText: 'e.g. Invite 5 crew members', isDense: true),
                onChanged: (v) {
                  widget.tier.label = v;
                  widget.onChanged(widget.tier);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: CIPTheme.error, size: 18),
              onPressed: widget.onRemove,
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _NumberField(
                label: 'Invites required',
                value: widget.tier.invitesRequired,
                onChanged: (v) {
                  setState(() => widget.tier.invitesRequired = v);
                  widget.onChanged(widget.tier);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _NumberField(
                label: 'Reward (days)',
                value: widget.tier.rewardDays,
                onChanged: (v) {
                  setState(() => widget.tier.rewardDays = v);
                  widget.onChanged(widget.tier);
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _NumberField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CIPTheme.navLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: CIPTheme.textMuted, fontSize: 10)),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => onChanged((value - 1).clamp(1, 999)),
          ),
          Expanded(
            child: Text('$value', textAlign: TextAlign.center,
                style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => onChanged((value + 1).clamp(1, 999)),
          ),
        ]),
      ]),
    );
  }
}
