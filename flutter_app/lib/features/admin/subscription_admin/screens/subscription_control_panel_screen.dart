import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../subscription/models/subscription_models.dart';
import '../../../subscription/services/subscription_service.dart';
import '../widgets/feature_access_toggle_grid.dart';

/// The Subscription Management section inside Admin Panel.
/// Every control here writes directly to subscriptionConfig in Firestore —
/// no app rebuild or deploy is needed for any of these changes to take effect.
class SubscriptionControlPanelScreen extends ConsumerStatefulWidget {
  const SubscriptionControlPanelScreen({super.key});

  @override
  ConsumerState<SubscriptionControlPanelScreen> createState() =>
      _SubscriptionControlPanelScreenState();
}

class _SubscriptionControlPanelScreenState
    extends ConsumerState<SubscriptionControlPanelScreen> {
  final _svc = SubscriptionService();
  Map<String, dynamic>? _config;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final config = await _svc.adminGetFullConfig();
      setState(() { _config = config; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load config: $e')),
        );
      }
    }
  }

  Future<void> _toggleMasterSwitch(bool enabled) async {
    setState(() => _saving = true);
    try {
      await _svc.adminSetMasterSwitch(enabled);
      setState(() => _config!['subscriptionsEnabled'] = enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(enabled
              ? 'Subscriptions are now ENABLED platform-wide'
              : 'Subscriptions are now DISABLED — everything is free'),
          backgroundColor: enabled ? CIPTheme.warning : CIPTheme.success,
        ));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _updateFeatureAccess(String key, FeatureAccessLevel level) async {
    setState(() => _saving = true);
    try {
      await _svc.adminSetFeatureAccess(key, level);
      setState(() {
        (_config!['featureAccess'] as Map)[key]['accessLevel'] =
            level == FeatureAccessLevel.proOnly ? 'PRO_ONLY' : 'PUBLIC';
      });
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
        title: const Text('Subscription Management',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: CIPTheme.primary),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: CIPTheme.primary))
          : _config == null
              ? const Center(child: Text('Failed to load configuration',
                  style: TextStyle(color: CIPTheme.error)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _MasterSwitchCard(
                      enabled: _config!['subscriptionsEnabled'] as bool? ?? false,
                      onChanged: _toggleMasterSwitch,
                    ),
                    const SizedBox(height: 24),

                    _SectionHeader('Feature Access',
                        subtitle: 'Decide which tools require Pro — takes effect instantly'),
                    const SizedBox(height: 12),
                    FeatureAccessToggleGrid(
                      featureAccess: Map<String, Map<String, dynamic>>.from(
                          (_config!['featureAccess'] as Map).map(
                              (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))),
                      onChanged: _updateFeatureAccess,
                    ),
                    const SizedBox(height: 24),

                    _SectionHeader('Usage Limits',
                        subtitle: 'Monthly caps for Free plan — 0 means unlimited'),
                    const SizedBox(height: 12),
                    _UsageLimitsSection(
                      usageLimits: Map<String, Map<String, dynamic>>.from(
                          (_config!['usageLimits'] as Map).map(
                              (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)))),
                      onChanged: (key, limit) async {
                        setState(() => _saving = true);
                        await _svc.adminSetUsageLimit(key, limit);
                        setState(() {
                          (_config!['usageLimits'] as Map)[key]['monthlyLimit'] = limit;
                          _saving = false;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    _SectionHeader('Plans', subtitle: 'Names, descriptions, and benefits'),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/admin/subscription/plans/FREE'),
                          icon: const Icon(Icons.card_membership_outlined, size: 16),
                          label: const Text('Edit Free Plan'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/admin/subscription/plans/PRO'),
                          icon: const Icon(Icons.workspace_premium_outlined, size: 16),
                          label: const Text('Edit Pro Plan'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    _SectionHeader('Free Trial', subtitle: 'Configure trial length and eligibility'),
                    const SizedBox(height: 12),
                    _TrialConfigSection(
                      trial: Map<String, dynamic>.from(_config!['trial'] as Map? ?? {}),
                      onChanged: (enabled, days, requireNoPrior) async {
                        setState(() => _saving = true);
                        await _svc.adminUpdateTrialConfig(
                          enabled: enabled, durationDays: days,
                          requiresNoPriorTrial: requireNoPrior,
                        );
                        setState(() {
                          _config!['trial'] = {
                            'enabled': enabled, 'durationDays': days,
                            'requiresNoPriorTrial': requireNoPrior,
                          };
                          _saving = false;
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    _SectionHeader('More tools', subtitle: null),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/admin/subscription/users'),
                          icon: const Icon(Icons.person_search_outlined, size: 16),
                          label: const Text('Manage Users'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/admin/subscription/referral'),
                          icon: const Icon(Icons.card_giftcard_outlined, size: 16),
                          label: const Text('Referral Campaign'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }
}

class _MasterSwitchCard extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _MasterSwitchCard({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? CIPTheme.warning : CIPTheme.success;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.10), color.withOpacity(0.02)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(enabled ? Icons.toggle_on : Icons.toggle_off, color: color, size: 32),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                enabled ? 'Subscriptions: ENABLED' : 'Subscriptions: DISABLED (Free Launch)',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                enabled
                    ? 'Pro-only features and usage limits are now enforced for all users.'
                    : 'Everything is free for everyone, regardless of feature settings below.',
                style: const TextStyle(color: CIPTheme.textSecondary, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        Switch(value: enabled, onChanged: onChanged, activeColor: CIPTheme.warning),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: CIPTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(subtitle!,
                style: const TextStyle(color: CIPTheme.textMuted, fontSize: 11)),
          ),
      ],
    );
  }
}

class _UsageLimitsSection extends StatelessWidget {
  final Map<String, Map<String, dynamic>> usageLimits;
  final void Function(String key, int limit) onChanged;

  const _UsageLimitsSection({required this.usageLimits, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final entries = usageLimits.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      children: entries.map((e) => _LimitRow(
        featureKey: e.key,
        limit: e.value['monthlyLimit'] as int? ?? 0,
        onChanged: (v) => onChanged(e.key, v),
      )).toList(),
    );
  }
}

class _LimitRow extends StatefulWidget {
  final String featureKey;
  final int limit;
  final ValueChanged<int> onChanged;
  const _LimitRow({required this.featureKey, required this.limit, required this.onChanged});

  @override
  State<_LimitRow> createState() => _LimitRowState();
}

class _LimitRowState extends State<_LimitRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.limit.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Row(children: [
        Expanded(
          child: Text(widget.featureKey.replaceAll('_', ' '),
              style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13)),
        ),
        SizedBox(
          width: 70,
          child: TextField(
            controller: _ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onSubmitted: (v) {
              final parsed = int.tryParse(v) ?? 0;
              widget.onChanged(parsed);
            },
          ),
        ),
        const SizedBox(width: 6),
        const Text('/ month', style: TextStyle(color: CIPTheme.textMuted, fontSize: 11)),
      ]),
    );
  }
}

class _TrialConfigSection extends StatefulWidget {
  final Map<String, dynamic> trial;
  final void Function(bool enabled, int days, bool requireNoPrior) onChanged;
  const _TrialConfigSection({required this.trial, required this.onChanged});

  @override
  State<_TrialConfigSection> createState() => _TrialConfigSectionState();
}

class _TrialConfigSectionState extends State<_TrialConfigSection> {
  late bool _enabled;
  late int _days;
  late bool _requireNoPrior;

  @override
  void initState() {
    super.initState();
    _enabled = widget.trial['enabled'] as bool? ?? true;
    _days = widget.trial['durationDays'] as int? ?? 14;
    _requireNoPrior = widget.trial['requiresNoPriorTrial'] as bool? ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(
        children: [
          Row(children: [
            const Expanded(child: Text('Trials enabled',
                style: TextStyle(color: CIPTheme.textPrimary, fontSize: 13))),
            Switch(
              value: _enabled,
              activeColor: CIPTheme.primary,
              onChanged: (v) {
                setState(() => _enabled = v);
                widget.onChanged(_enabled, _days, _requireNoPrior);
              },
            ),
          ]),
          const Divider(height: 1, color: CIPTheme.divider),
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Text('Duration (days)',
                style: TextStyle(color: CIPTheme.textPrimary, fontSize: 13))),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                onPressed: () {
                  setState(() => _days = (_days - 1).clamp(1, 365));
                  widget.onChanged(_enabled, _days, _requireNoPrior);
                },
              ),
              Text('$_days', style: const TextStyle(
                  color: CIPTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                onPressed: () {
                  setState(() => _days = (_days + 1).clamp(1, 365));
                  widget.onChanged(_enabled, _days, _requireNoPrior);
                },
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(child: Text('One trial per account',
                style: TextStyle(color: CIPTheme.textPrimary, fontSize: 13))),
            Switch(
              value: _requireNoPrior,
              activeColor: CIPTheme.primary,
              onChanged: (v) {
                setState(() => _requireNoPrior = v);
                widget.onChanged(_enabled, _days, _requireNoPrior);
              },
            ),
          ]),
        ],
      ),
    );
  }
}
