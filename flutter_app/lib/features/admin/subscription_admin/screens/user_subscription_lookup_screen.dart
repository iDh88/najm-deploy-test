import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme.dart';
import '../../../subscription/models/subscription_models.dart';
import '../../../subscription/services/subscription_service.dart';

/// Manual subscription control per user — "manually activate," "manually
/// deactivate," "grant free days/months" all live here.
class UserSubscriptionLookupScreen extends StatefulWidget {
  const UserSubscriptionLookupScreen({super.key});

  @override
  State<UserSubscriptionLookupScreen> createState() =>
      _UserSubscriptionLookupScreenState();
}

class _UserSubscriptionLookupScreenState
    extends State<UserSubscriptionLookupScreen> {
  final _svc = SubscriptionService();
  final _userIdCtrl = TextEditingController();
  Map<String, dynamic>? _subscription;
  List<AccountHistoryEvent>? _history;
  bool _loading = false;
  String? _error;

  Future<void> _lookup() async {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) return;

    setState(() { _loading = true; _error = null; _subscription = null; _history = null; });
    try {
      final sub = await _svc.adminGetUserSubscription(userId);
      final history = await _svc.adminGetUserHistory(userId);
      setState(() { _subscription = sub; _history = history; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _activate({int? days}) async {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) return;
    await _svc.adminActivateUser(userId, durationDays: days);
    await _lookup();
    _showSnack('Pro access activated${days != null ? " ($days days)" : " (indefinite)"}');
  }

  Future<void> _revoke() async {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) return;
    final confirmed = await _confirmDialog(
      'Revoke Pro Access?',
      'This immediately removes Pro access for this user, regardless of remaining time.',
    );
    if (confirmed != true) return;
    await _svc.adminRevokeUser(userId);
    await _lookup();
    _showSnack('Pro access revoked');
  }

  Future<void> _grantDays(int days) async {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) return;
    await _svc.adminGrantDays(userId, days, reason: 'Manual admin grant');
    await _lookup();
    _showSnack('+$days days granted');
  }

  Future<void> _extendTrial(int days) async {
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty) return;
    await _svc.adminExtendTrial(userId, days, reason: 'Manual admin extension');
    await _lookup();
    _showSnack('Trial extended by $days days');
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: CIPTheme.success),
    );
  }

  Future<bool?> _confirmDialog(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CIPTheme.card,
        title: Text(title, style: const TextStyle(color: CIPTheme.textPrimary)),
        content: Text(body, style: const TextStyle(color: CIPTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm', style: TextStyle(color: CIPTheme.error))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Manage Users', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _userIdCtrl,
                style: const TextStyle(color: CIPTheme.textPrimary, fontSize: 13),
                decoration: const InputDecoration(hintText: 'Enter user ID (UID)'),
                onSubmitted: (_) => _lookup(),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _loading ? null : _lookup,
              style: ElevatedButton.styleFrom(
                backgroundColor: CIPTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lookup'),
            ),
          ]),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: CIPTheme.error, fontSize: 12)),
          ],

          if (_subscription != null) ...[
            const SizedBox(height: 20),
            _SubscriptionSummaryCard(sub: _subscription!),
            const SizedBox(height: 20),

            const Text('Quick Actions',
                style: TextStyle(color: CIPTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ActionChip(label: '+3 days', onTap: () => _grantDays(3)),
              _ActionChip(label: '+7 days', onTap: () => _grantDays(7)),
              _ActionChip(label: '+30 days', onTap: () => _grantDays(30)),
              _ActionChip(label: 'Activate (indefinite)', onTap: () => _activate(),
                  color: CIPTheme.success),
              _ActionChip(label: 'Revoke Pro', onTap: _revoke, color: CIPTheme.error),
            ]),
            const SizedBox(height: 16),

            const Text('Extend Trial',
                style: TextStyle(color: CIPTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _ActionChip(label: '+3 days', onTap: () => _extendTrial(3)),
              _ActionChip(label: '+7 days', onTap: () => _extendTrial(7)),
              _ActionChip(label: '+30 days', onTap: () => _extendTrial(30)),
            ]),

            if (_history != null && _history!.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('History',
                  style: TextStyle(color: CIPTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ..._history!.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Text(e.eventType.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.description,
                      style: const TextStyle(color: CIPTheme.textSecondary, fontSize: 12))),
                ]),
              )),
            ],
          ],
        ],
      ),
    );
  }
}

class _SubscriptionSummaryCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  const _SubscriptionSummaryCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final isPro = sub['isProActive'] == true;
    final color = isPro ? CIPTheme.success : CIPTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isPro ? Icons.verified : Icons.person_outline, color: color, size: 20),
            const SizedBox(width: 8),
            Text('${sub['status']} · ${sub['tier']}',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          if (sub['expirationDate'] != null) ...[
            const SizedBox(height: 6),
            Text('Expires: ${sub['expirationDate']}',
                style: const TextStyle(color: CIPTheme.textMuted, fontSize: 11)),
          ],
          if (sub['bonusDaysGranted'] != null && sub['bonusDaysGranted'] > 0) ...[
            const SizedBox(height: 4),
            Text('Total bonus days granted: ${sub['bonusDaysGranted']}',
                style: const TextStyle(color: CIPTheme.textMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _ActionChip({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? CIPTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.35)),
        ),
        child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
