import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/roster_sync/roster_connector.dart';
import '../../core/roster_sync/roster_sync_providers.dart';
import '../../core/roster_sync/sync_models.dart';
import '../../core/roster_sync/sync_service.dart';
import '../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Settings → Roster Sources
// ═══════════════════════════════════════════════════════════════════════════

class RosterSourcesScreen extends ConsumerWidget {
  const RosterSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navy,
        title: const Text('Roster Sources'),
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: 'Could not load roster sources.',
          onRetry: () => ref.invalidate(syncStatusProvider),
        ),
        data: (status) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(syncStatusProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Connect a source once — NAJM keeps your roster in sync and '
                'feeds every intelligence engine automatically. Credentials '
                'stay only in your device\'s secure storage.',
                style: TextStyle(color: NajmTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              for (final p in status.providers)
                _ProviderCard(info: p, status: status),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderCard extends ConsumerWidget {
  final ProviderInfo info;
  final SyncStatus status;
  const _ProviderCard({required this.info, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conn = status.connection(info.providerId);
    final health = ref.read(healthMonitorProvider).healthOf(conn);
    final isManual = info.providerId == 'manual_pdf';
    final preferred = status.preferredSource == info.providerId;

    return Card(
      color: NajmTheme.navyCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: preferred ? NajmTheme.gold : NajmTheme.cardBorder),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Flexible(
              child: Text(info.displayName,
                  style: const TextStyle(
                      color: NajmTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
            ),
            if (info.recommended) ...[
              const SizedBox(width: 8),
              _Badge(text: 'Recommended', color: NajmTheme.gold),
            ],
            if (preferred) ...[
              const SizedBox(width: 8),
              _Badge(text: 'Active source', color: NajmTheme.success),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _HealthLine(health: health, conn: conn, info: info),
        ),
        trailing: const Icon(Icons.chevron_right, color: NajmTheme.textMuted),
        onTap: () {
          if (isManual) {
            context.push('/intelligence/upload');
          } else if (conn != null && conn.status == 'connected') {
            context.push(
                '/settings/roster-sources/${info.providerId}/status');
          } else {
            context
                .push('/settings/roster-sources/${info.providerId}/connect');
          }
        },
      ),
    );
  }
}

class _HealthLine extends StatelessWidget {
  final SyncHealth health;
  final RosterConnection? conn;
  final ProviderInfo info;
  const _HealthLine(
      {required this.health, required this.conn, required this.info});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (health) {
      SyncHealth.healthy => ('Connected · synced', NajmTheme.success),
      SyncHealth.stale => ('Connected · sync overdue', NajmTheme.warning),
      SyncHealth.error => ('Connected · last sync failed', NajmTheme.error),
      SyncHealth.pending => (
          'Awaiting official integration',
          NajmTheme.info
        ),
      SyncHealth.disconnected => ('Not connected', NajmTheme.textMuted),
    };
    return Row(children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(label,
            style: const TextStyle(
                color: NajmTheme.textSecondary, fontSize: 13)),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Connect screen — dynamic auth fields from the connector
// ═══════════════════════════════════════════════════════════════════════════

class RosterSourceConnectScreen extends ConsumerStatefulWidget {
  final String providerId;
  const RosterSourceConnectScreen({super.key, required this.providerId});

  @override
  ConsumerState<RosterSourceConnectScreen> createState() =>
      _RosterSourceConnectScreenState();
}

class _RosterSourceConnectScreenState
    extends ConsumerState<RosterSourceConnectScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _busy = false;
  String? _note;
  String? _noteStatus;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connect(List<AuthField> fields) async {
    setState(() {
      _busy = true;
      _note = null;
    });
    final creds = {
      for (final f in fields) f.key: _controllers[f.key]?.text ?? ''
    };
    try {
      final outcome = await ref
          .read(rosterSyncServiceProvider)
          .connect(widget.providerId, creds);
      if (!mounted) return;
      setState(() {
        _note = outcome.note;
        _noteStatus = outcome.status;
      });
      if (outcome.ok) {
        ref.invalidate(syncStatusProvider);
        context.pushReplacement(
            '/settings/roster-sources/${widget.providerId}/status');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _note = e.toString();
        _noteStatus = 'error';
      });
    } finally {
      creds.clear(); // drop the credential map reference immediately
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(syncStatusProvider);
    final registry = ref.read(connectorRegistryProvider);
    final connector = registry.byId(widget.providerId);

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(backgroundColor: NajmTheme.navy, title: const Text('Connect source')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: 'Could not load this source.',
          onRetry: () => ref.invalidate(syncStatusProvider),
        ),
        data: (status) {
          final info = status.providers
              .where((p) => p.providerId == widget.providerId)
              .toList();
          if (info.isEmpty || connector == null) {
            return const Center(
              child: Text('This source has no device connector yet.',
                  style: TextStyle(color: NajmTheme.textSecondary)),
            );
          }
          final provider = info.first;
          final fields = connector.authFields;
          for (final f in fields) {
            _controllers.putIfAbsent(f.key, TextEditingController.new);
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(provider.displayName,
                  style: const TextStyle(
                      color: NajmTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'You connect once. Credentials are stored only in this '
                'device\'s secure storage (iOS Keychain / Android Keystore) '
                '— never on NAJM servers.',
                style: TextStyle(color: NajmTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (!provider.isAvailable)
                _NoteBox(
                    text: provider.availabilityNote,
                    color: NajmTheme.info),
              for (final f in fields) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _controllers[f.key],
                  obscureText: f.obscure,
                  enableSuggestions: !f.obscure,
                  autocorrect: false,
                  style: const TextStyle(color: NajmTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: f.label,
                    labelStyle:
                        const TextStyle(color: NajmTheme.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: NajmTheme.cardBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: NajmTheme.gold),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_note != null)
                _NoteBox(
                  text: _note!,
                  color: _noteStatus == 'connected'
                      ? NajmTheme.success
                      : _noteStatus == 'awaiting_official_integration'
                          ? NajmTheme.info
                          : NajmTheme.error,
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NajmTheme.gold,
                    foregroundColor: NajmTheme.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _busy ? null : () => _connect(fields),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Connect',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sync Status screen — spec fields + Sync Now + Disconnect
// ═══════════════════════════════════════════════════════════════════════════

class SyncStatusScreen extends ConsumerStatefulWidget {
  final String providerId;
  const SyncStatusScreen({super.key, required this.providerId});

  @override
  ConsumerState<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends ConsumerState<SyncStatusScreen> {
  bool _syncing = false;
  String? _lastMessage;

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _lastMessage = null;
    });
    final report = await ref
        .read(rosterSyncServiceProvider)
        .syncProvider(widget.providerId);
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _lastMessage = report.ok
          ? (report.importResult?.isDuplicate == true
              ? 'Already up to date — no changes since the last import.'
              : 'Synced ${report.importResult?.importedFlights ?? 0} '
                  'flights.')
          : report.error;
    });
    ref.invalidate(syncStatusProvider);
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NajmTheme.navyCard,
        title: const Text('Disconnect source?',
            style: TextStyle(color: NajmTheme.textPrimary)),
        content: const Text(
            'Every credential stored on this device for this source will be '
            'securely erased. Your already-imported rosters are kept.',
            style: TextStyle(color: NajmTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Disconnect',
                  style: TextStyle(color: NajmTheme.error))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(rosterSyncServiceProvider).disconnect(widget.providerId);
    ref.invalidate(syncStatusProvider);
    if (mounted) context.pop();
  }

  String _fmt(DateTime? t) {
    if (t == null) return '—';
    final local = t.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (sameDay) return 'Today $hh:$mm';
    return '${local.day}/${local.month}/${local.year} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(syncStatusProvider);
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
          backgroundColor: NajmTheme.navy, title: const Text('Sync Status')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: 'Could not load sync status.',
          onRetry: () => ref.invalidate(syncStatusProvider),
        ),
        data: (status) {
          final infoList = status.providers
              .where((p) => p.providerId == widget.providerId)
              .toList();
          final conn = status.connection(widget.providerId);
          final version = status.versionsLatest[widget.providerId];
          final name = infoList.isEmpty
              ? widget.providerId
              : infoList.first.displayName;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _StatusRow(label: 'Roster Source', value: name),
              _StatusRow(
                  label: 'Status',
                  value: switch (conn?.status) {
                    'connected' => 'Connected',
                    'awaiting_official_integration' =>
                      'Awaiting official integration',
                    'error' => 'Error',
                    _ => 'Not connected',
                  }),
              _StatusRow(label: 'Last Sync', value: _fmt(conn?.lastSyncAt)),
              _StatusRow(
                  label: 'Last Successful Import',
                  value: _fmt(conn?.lastSuccessAt)),
              _StatusRow(
                  label: 'Imported Flights',
                  value: '${conn?.importedFlightsLast ?? 0}'),
              _StatusRow(
                  label: 'Next Sync',
                  value: (conn?.autoSync ?? true)
                      ? 'Automatic'
                      : 'Manual only'),
              if (version != null)
                _StatusRow(
                    label: 'Roster Version',
                    value:
                        'v${version.version} · +${version.added} / −${version.removed} / ~${version.changed}'),
              if (conn?.lastError != null && conn!.lastError!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _NoteBox(
                      text: conn.lastError!, color: NajmTheme.warning),
                ),
              if (_lastMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _NoteBox(
                      text: _lastMessage!,
                      color: NajmTheme.info),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NajmTheme.gold,
                    foregroundColor: NajmTheme.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _syncing ? null : _syncNow,
                  icon: _syncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.sync),
                  label: const Text('Sync Now',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _disconnect,
                child: const Text('Disconnect',
                    style: TextStyle(color: NajmTheme.error)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared bits
// ═══════════════════════════════════════════════════════════════════════════

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatusRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label,
                style: const TextStyle(color: NajmTheme.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: NajmTheme.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final String text;
  final Color color;
  const _NoteBox({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(text,
          style: TextStyle(color: color, height: 1.4, fontSize: 13)),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message,
              style: const TextStyle(color: NajmTheme.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
