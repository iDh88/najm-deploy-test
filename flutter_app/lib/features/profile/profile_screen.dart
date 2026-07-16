import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';
import '../../core/roster_sync/roster_sync_providers.dart';
import '../../core/roster_sync/sync_models.dart';
import '../../core/theme/app_theme.dart';
import '../subscription/models/subscription_models.dart';
import '../subscription/providers/subscription_providers.dart';
import 'providers/profile_providers.dart';
import 'widgets/profile_widgets.dart';

/// NAJM Profile — aviation-grade, and honest.
///
/// Every value on this screen comes from a service that really exists:
///   Subscription  → entitlementProvider / usageStatusProvider
///   Roster        → syncStatusProvider (the live provider catalog)
///   Sync          → the same SyncStatus + SyncService the scheduler uses
///   AI            → aiStatusProvider  → GET /v1/ai/status
///   Version       → packageInfoProvider (real build number)
///   Security      → nothing. By construction: this screen never reads a
///                   credential, because it cannot. See SecurityCard.
///
/// Where a capability does not exist yet (email import), the UI says so
/// plainly instead of rendering a convincing lie.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _refresh() async {
    HapticFeedback.lightImpact();
    ref.invalidate(entitlementProvider);
    ref.invalidate(syncStatusProvider);
    ref.invalidate(aiStatusProvider);
    // Settle each independently: one failing service (e.g. offline sync)
    // must not abort the refresh of the others, and every card already
    // renders its own error/offline state.
    await Future.wait<void>([
      _settle(ref.read(entitlementProvider.future)),
      _settle(ref.read(syncStatusProvider.future)),
      _settle(ref.read(aiStatusProvider.future)),
    ]);
  }

  static Future<void> _settle(Future<Object?> future) async {
    try {
      await future;
    } catch (_) {
      // Swallowed on purpose — the card shows the error, not the gesture.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navy,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(
                color: NajmTheme.textPrimary, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: NajmTheme.textSecondary),
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: NajmTheme.gold,
        backgroundColor: NajmTheme.navyCard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _Identity(user: user),
            const SizedBox(height: 24),

            const ProfileSectionLabel('Subscription'),
            const _SubscriptionSection(),
            const SizedBox(height: 24),

            const ProfileSectionLabel('Roster Sources'),
            const _RosterSourcesSection(),
            const SizedBox(height: 24),

            const ProfileSectionLabel('Synchronization'),
            const _SyncSection(),
            const SizedBox(height: 24),

            const ProfileSectionLabel('NAJM AI'),
            const _AiSection(),
            const SizedBox(height: 24),

            const ProfileSectionLabel('Security'),
            const SecurityCard(),
            const SizedBox(height: 24),

            const ProfileSectionLabel('Preferences'),
            ProfileTile(
              icon: Icons.tune,
              title: 'Line Preferences',
              subtitle: 'Optimization mode, rest, layovers, weekends',
              onTap: () => context.push(Routes.linePreferences),
            ),
            const SizedBox(height: 24),

            const ProfileSectionLabel('Support'),
            ProfileTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'Need help using NAJM?',
              onTap: () => _mail(context, supportEmail, 'NAJM — Support request'),
            ),
            const SizedBox(height: 10),
            ProfileTile(
              icon: Icons.business_center_outlined,
              title: 'Administrator',
              subtitle:
                  'Business inquiries, enterprise integration, partnerships',
              onTap: () =>
                  _mail(context, administratorEmail, 'NAJM — Administrator'),
            ),
            const SizedBox(height: 24),

            const ProfileSectionLabel('About'),
            const _AboutSection(),
            const SizedBox(height: 10),
            ProfileTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Rules, policies, and prohibited conduct',
              onTap: () => context.push(Routes.legalTerms),
            ),
            const SizedBox(height: 10),
            ProfileTile(
              icon: Icons.shield_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              onTap: () => context.push(Routes.legalPrivacy),
            ),
            const SizedBox(height: 28),

            const ProfileSectionLabel('Danger Zone', danger: true),
            const _DangerZone(),
          ],
        ),
      ),
    );
  }

  static Future<void> _mail(
      BuildContext context, String address, String subject) async {
    HapticFeedback.selectionClick();
    final uri = supportMailto(address, subject: subject);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: NajmTheme.navyCard,
          content: Text('No email app found. Write to $address',
              style: const TextStyle(color: NajmTheme.textPrimary)),
        ));
      }
    }
  }
}

// ── Identity ────────────────────────────────────────────────────────────────

class _Identity extends StatelessWidget {
  final CIPUser? user;
  const _Identity({required this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const ProfileSkeleton(height: 96);
    final u = user!;
    final initials = u.name.trim().isEmpty
        ? '—'
        : u.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();

    return Row(
      children: [
        Hero(
          tag: 'profile-avatar',
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: NajmTheme.goldGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initials.toUpperCase(),
                style: const TextStyle(
                    color: NajmTheme.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(u.name,
                    style: const TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  u.rank.name,
                  if (u.baseStation.isNotEmpty) u.baseStation,
                  if (u.fleetTypes.isNotEmpty) u.fleetTypes.join(' · '),
                ].where((s) => s.isNotEmpty).join('  •  '),
                style: const TextStyle(
                    color: NajmTheme.textSecondary, fontSize: 13),
              ),
              if (u.crewId.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Crew ID ${u.crewId}',
                    style: const TextStyle(
                        color: NajmTheme.textMuted, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── 1. Subscription ─────────────────────────────────────────────────────────

class _SubscriptionSection extends ConsumerWidget {
  const _SubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ent = ref.watch(entitlementProvider);

    return ent.when(
      loading: () => const ProfileSkeleton(height: 168),
      error: (e, _) =>
          const ProfileErrorNote('Subscription unavailable — pull to retry.'),
      data: (e) {
        final view = _viewOf(e, DateTime.now());
        return ProfileCard(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(view.planName,
                        style: const TextStyle(
                            color: NajmTheme.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w700)),
                  ),
                  StatusBadge(
                    label: view.statusLabel,
                    color: view.isActive ? NajmTheme.success : NajmTheme.warning,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProfileKeyValue(label: 'Start', value: _date(view.startDate)),
              ProfileKeyValue(label: 'Renewal', value: _date(view.renewalDate)),
              ProfileKeyValue(
                label: 'Remaining',
                value: view.remainingDays == null
                    ? '—'
                    : '${view.remainingDays} days',
                emphasise: true,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(Routes.subscription);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NajmTheme.gold,
                    side: const BorderSide(color: NajmTheme.gold),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Manage Subscription'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Trials expose a real start date; paid plans carry no start on the
  /// entitlement payload, so it renders "—" rather than a fabricated date.
  static SubscriptionCardView _viewOf(Entitlement e, DateTime now) {
    final plan = e.tier == PlanTier.pro ? 'NAJM Pro' : 'NAJM Free';
    final name = e.trialActive ? 'Trial Period' : plan;
    return SubscriptionCardView(
      planName: name,
      statusLabel: _statusLabel(e),
      isActive: e.isProActive || e.status == SubscriptionStatus.active,
      startDate: e.trialStartedAt,
      renewalDate: e.expirationDate,
      remainingDays: e.trialActive && e.trialDaysRemaining != null
          ? e.trialDaysRemaining
          : SubscriptionCardView.daysRemaining(e.expirationDate, now),
    );
  }

  static String _statusLabel(Entitlement e) {
    switch (e.status) {
      case SubscriptionStatus.trial:
        return 'Active';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.granted:
        return 'Granted';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.none:
        return 'Free';
    }
  }
}

// ── 2. Roster Sources (renders the LIVE catalog) ────────────────────────────

class _RosterSourcesSection extends ConsumerWidget {
  const _RosterSourcesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    return status.when(
      loading: () => const ProfileSkeleton(height: 190),
      error: (e, _) => const ProfileErrorNote(
          'Roster sources unavailable offline — cached roster is still in use.'),
      data: (s) => ProfileCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The catalog is whatever the backend really offers — priority
            // order included. Nothing here is hardcoded in the UI.
            for (var i = 0; i < s.providers.length; i++) ...[
              if (i > 0) const Divider(color: NajmTheme.divider, height: 20),
              _ProviderRow(
                info: s.providers[i],
                connection: s.connection(s.providers[i].providerId),
                priority: i + 1,
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push(Routes.rosterSources);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: NajmTheme.gold,
                  side: const BorderSide(color: NajmTheme.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Manage Sources'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  final ProviderInfo info;
  final RosterConnection? connection;
  final int priority;
  const _ProviderRow(
      {required this.info, required this.connection, required this.priority});

  @override
  Widget build(BuildContext context) {
    final available = info.availability == 'available';
    final connected = connection != null && connection!.status == 'connected';

    final (String label, Color color) = !available
        ? ('Not available yet', NajmTheme.textMuted)
        : connected
            ? ('Connected', NajmTheme.success)
            : ('Not connected', NajmTheme.textMuted);

    return Semantics(
      label: '${info.displayName}, $label, priority $priority',
      child: Row(
        children: [
          HealthDot(color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.displayName,
                    style: const TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  connected && connection!.lastSuccessAt != null
                      ? 'Last sync ${_ago(connection!.lastSuccessAt!)}'
                      // For a pending provider this is the backend's own
                      // honest note (e.g. "awaiting official CAE API").
                      : (available ? 'Priority $priority' : info.availabilityNote),
                  style: const TextStyle(
                      color: NajmTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          StatusBadge(label: label, color: color, dense: true),
        ],
      ),
    );
  }
}

// ── 3. Synchronization ──────────────────────────────────────────────────────

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);

    return status.when(
      loading: () => const ProfileSkeleton(height: 150),
      // Offline is NOT an error state: the cached roster is still valid and
      // the scheduler resyncs automatically when connectivity returns.
      error: (e, _) => const ProfileCard(
        child: Row(
          children: [
            HealthDot(color: NajmTheme.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Offline — showing your cached roster. NAJM will resync '
                'automatically when you are back online.',
                style:
                    TextStyle(color: NajmTheme.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      data: (s) {
        final badge = syncBadgeFor(s);
        final source = activeSourceOf(s);
        final conn = source == null ? null : s.connection(source);
        final latest = source == null ? null : s.versionsLatest[source];

        final (String text, Color color) = switch (badge) {
          ProfileSyncBadge.healthy => ('Healthy', NajmTheme.success),
          ProfileSyncBadge.waiting => ('Waiting', NajmTheme.warning),
          ProfileSyncBadge.failed => ('Failed', NajmTheme.error),
          ProfileSyncBadge.none => ('No source connected', NajmTheme.textMuted),
        };

        return ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HealthDot(color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Synchronization',
                        style: const TextStyle(
                            color: NajmTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  StatusBadge(label: text, color: color),
                ],
              ),
              const SizedBox(height: 12),
              ProfileKeyValue(
                label: 'Last successful sync',
                value: conn?.lastSuccessAt == null
                    ? '—'
                    : _ago(conn!.lastSuccessAt!),
              ),
              ProfileKeyValue(
                label: 'Provider used',
                value: source == null ? '—' : _providerName(s, source),
              ),
              ProfileKeyValue(
                label: 'Imported flights',
                value: latest == null
                    ? (conn == null ? '—' : '${conn.importedFlightsLast}')
                    : '${latest.importedFlights}',
              ),
              if (badge == ProfileSyncBadge.failed &&
                  conn?.lastError != null) ...[
                const SizedBox(height: 8),
                ProfileErrorNote(conn!.lastError!),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 4. AI status ────────────────────────────────────────────────────────────

class _AiSection extends ConsumerWidget {
  const _AiSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ai = ref.watch(aiStatusProvider);

    return ai.when(
      loading: () => const ProfileSkeleton(height: 180),
      error: (e, _) => const ProfileErrorNote('AI status unavailable.'),
      data: (a) {
        final online = a.status == 'online';
        return ProfileCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: NajmTheme.gold, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('NAJM AI',
                        style: TextStyle(
                            color: NajmTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  StatusBadge(
                    label: online ? 'Online' : 'Unconfigured',
                    color: online ? NajmTheme.success : NajmTheme.textMuted,
                  ),
                ],
              ),
              if (!online) ...[
                const SizedBox(height: 8),
                Text(a.statusDetail,
                    style: const TextStyle(
                        color: NajmTheme.textMuted, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              ProfileKeyValue(label: 'Model', value: a.model),
              ProfileKeyValue(label: 'AI version', value: a.serviceVersion),
              ProfileKeyValue(
                label: 'Knowledge base',
                value: a.knowledgeBase.available
                    ? '${a.knowledgeBase.documents} documents'
                    : '—',
              ),
              ProfileKeyValue(
                label: 'Knowledge updated',
                // Empty knowledge base ⇒ no timestamp. It shows "—", never
                // a reassuring "Today".
                value: a.knowledgeBase.lastUpdated == null
                    ? '—'
                    : _ago(a.knowledgeBase.lastUpdated!),
              ),
              if (a.engines.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Connected engines',
                    style: TextStyle(
                        color: NajmTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in a.engines)
                      EngineChip(label: e.displayName, trigger: e.trigger),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 7. About ────────────────────────────────────────────────────────────────

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(packageInfoProvider);

    return ProfileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          info.when(
            loading: () => const ProfileSkeleton(height: 40),
            error: (_, __) => const ProfileErrorNote('Version unavailable.'),
            data: (p) => Column(
              children: [
                ProfileKeyValue(label: 'Version', value: p.version),
                ProfileKeyValue(label: 'Build', value: p.buildNumber),
              ],
            ),
          ),
          const Divider(color: NajmTheme.divider, height: 24),
          _AboutLink(
            icon: Icons.new_releases_outlined,
            label: 'Release Notes',
            onTap: () => context.push(Routes.releaseNotes),
          ),
          const SizedBox(height: 12),
          _AboutLink(
            icon: Icons.balance_outlined,
            label: 'Open Source Licenses',
            onTap: () {
              HapticFeedback.selectionClick();
              showLicensePage(
                context: context,
                applicationName: 'NAJM',
                applicationVersion: info.value?.version ?? '',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AboutLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AboutLink(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: NajmTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: NajmTheme.textPrimary, fontSize: 14)),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: NajmTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── 10. Danger Zone ─────────────────────────────────────────────────────────

class _DangerZone extends ConsumerStatefulWidget {
  const _DangerZone();

  @override
  ConsumerState<_DangerZone> createState() => _DangerZoneState();
}

class _DangerZoneState extends ConsumerState<_DangerZone> {
  bool _busy = false;

  /// Disconnect every source: wipes Keychain/Keystore for each provider and
  /// tells the backend the connection is gone. Roster history is KEPT — the
  /// directive is explicit that disconnect erases credentials, not data.
  Future<void> _disconnectAll() async {
    final ok = await _confirm(
      title: 'Disconnect all roster sources?',
      body: 'Your saved provider credentials will be erased from this '
          "device's Keychain / Keystore.\n\n"
          'Your imported roster history is kept.',
      confirmLabel: 'Disconnect',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      final status = await ref.read(syncStatusProvider.future);
      final service = ref.read(rosterSyncServiceProvider);
      for (final c in status.connections) {
        if (c.status == 'disconnected') continue;
        await service.disconnect(c.providerId);
      }
      // Belt and braces: clear the whole secure namespace so no orphan key
      // can survive a partially-failed disconnect.
      await ref.read(credentialManagerProvider).wipeAll();
      ref.invalidate(syncStatusProvider);
      if (mounted) {
        HapticFeedback.mediumImpact();
        _toast('All roster sources disconnected. Credentials erased.');
      }
    } catch (e) {
      if (mounted) _toast('Could not disconnect: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final ok = await _confirm(
      title: 'Delete account?',
      body: 'This permanently deletes your NAJM account and all associated '
          'data. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      // Wipe the enclave BEFORE the account goes: never leave orphan
      // credentials behind on the device.
      await ref.read(credentialManagerProvider).wipeAll();
      await ref.read(authServiceProvider).deleteAccount(user.id);
      if (mounted) context.go(Routes.splash);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not delete account: $e');
      }
    }
  }

  /// Logout deliberately PRESERVES secure credentials — the directive says
  /// they are erased only when the user explicitly disconnects a provider.
  /// Signing back in resumes automatic sync with no re-entry.
  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).signOut();
      if (mounted) context.go(Routes.splash);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not sign out: $e');
      }
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    HapticFeedback.heavyImpact();
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NajmTheme.navyCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title,
            style: const TextStyle(
                color: NajmTheme.textPrimary, fontSize: 17)),
        content: Text(body,
            style: const TextStyle(
                color: NajmTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: NajmTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel,
                style: const TextStyle(
                    color: NajmTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: NajmTheme.navyCard,
      content: Text(message,
          style: const TextStyle(color: NajmTheme.textPrimary)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProfileTile(
          icon: Icons.link_off,
          title: 'Disconnect All Roster Sources',
          subtitle: 'Erases stored credentials — keeps your roster history',
          danger: true,
          enabled: !_busy,
          onTap: _disconnectAll,
        ),
        const SizedBox(height: 10),
        ProfileTile(
          icon: Icons.delete_outline,
          title: 'Delete Account',
          subtitle: 'Permanently delete your account and all data',
          danger: true,
          enabled: !_busy,
          onTap: _deleteAccount,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _logout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NajmTheme.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Signing out keeps your provider credentials in the device '
          'Keychain / Keystore. Disconnect a source to erase them.',
          textAlign: TextAlign.center,
          style: TextStyle(color: NajmTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Shared formatting ───────────────────────────────────────────────────────

/// Display name for a provider id, falling back to the id itself.
/// (Avoids `firstOrNull`, which lives in package:collection — not a declared
/// dependency of this app.)
String _providerName(SyncStatus s, String providerId) {
  for (final p in s.providers) {
    if (p.providerId == providerId) return p.displayName;
  }
  return providerId;
}

String _date(DateTime? d) {
  if (d == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _ago(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return _date(t);
}
