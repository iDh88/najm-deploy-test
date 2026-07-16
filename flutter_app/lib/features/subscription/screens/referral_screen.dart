import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/theme.dart';
import '../models/subscription_models.dart';
import '../providers/subscription_providers.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final referralAsync = ref.watch(referralStatusProvider);
    final applyState = ref.watch(applyReferralProvider);

    ref.listen<ApplyReferralState>(applyReferralProvider, (prev, next) {
      if (next.message != null && !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            backgroundColor: next.success == true ? CIPTheme.success : CIPTheme.error,
          ),
        );
        if (next.success == true) _codeCtrl.clear();
      }
    });

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('Refer Crew Members', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: referralAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: CIPTheme.primary)),
        error: (e, _) => Center(child: Text(e.toString(),
            style: const TextStyle(color: CIPTheme.error))),
        data: (referral) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _CodeCard(referral: referral),
            const SizedBox(height: 20),

            if (referral.tiers.isNotEmpty) ...[
              const Text('Rewards',
                  style: TextStyle(
                      color: CIPTheme.textPrimary,
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...(referral.tiers
                  .toList()
                ..sort((a, b) => a.invitesRequired.compareTo(b.invitesRequired)))
                  .map((t) => _RewardTierRow(
                        tier: t,
                        currentInvites: referral.successfulInvites,
                        claimed: referral.rewardsClaimed.contains(t.invitesRequired),
                      )),
              const SizedBox(height: 20),
            ],

            const Text('Have a code?',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                      color: CIPTheme.textPrimary,
                      fontWeight: FontWeight.w700, letterSpacing: 1),
                  decoration: const InputDecoration(hintText: 'Enter referral code'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: applyState.isLoading
                    ? null
                    : () {
                        if (_codeCtrl.text.trim().isNotEmpty) {
                          ref.read(applyReferralProvider.notifier)
                              .apply(_codeCtrl.text.trim());
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CIPTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: applyState.isLoading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Apply'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final ReferralStatus referral;
  const _CodeCard({required this.referral});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [CIPTheme.primary.withOpacity(0.12), CIPTheme.primary.withOpacity(0.02)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CIPTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Text('Your Referral Code',
              style: TextStyle(color: CIPTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 10),
          Text(referral.referralCode,
              style: const TextStyle(
                  color: CIPTheme.primary, fontSize: 32,
                  fontWeight: FontWeight.w900, letterSpacing: 3)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: referral.referralCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied')),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Share.share(
                  'Join me on Najm! Use my code ${referral.referralCode} when you sign up.',
                ),
                icon: const Icon(Icons.ios_share, size: 14),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CIPTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${referral.successfulInvites}',
                  style: const TextStyle(
                      color: CIPTheme.textPrimary,
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              const Text('successful invites',
                  style: TextStyle(color: CIPTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardTierRow extends StatelessWidget {
  final ReferralTierInfo tier;
  final int currentInvites;
  final bool claimed;

  const _RewardTierRow({
    required this.tier, required this.currentInvites, required this.claimed,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentInvites / tier.invitesRequired).clamp(0.0, 1.0);
    final color = claimed ? CIPTheme.success : CIPTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: claimed ? CIPTheme.success.withOpacity(0.3) : CIPTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(tier.label,
                  style: const TextStyle(
                      color: CIPTheme.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            if (claimed)
              const Icon(Icons.check_circle, color: CIPTheme.success, size: 18)
            else
              Text('+${tier.rewardDays} days',
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: CIPTheme.navLight,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text('$currentInvites of ${tier.invitesRequired} invites',
              style: const TextStyle(color: CIPTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }
}
