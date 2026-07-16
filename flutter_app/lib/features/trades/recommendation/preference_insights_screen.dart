import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import 'models.dart';
import 'recommendation_provider.dart';

/// Shows the crew member their own learned schedule preferences.
/// All data is derived from their own trade history — nothing hidden from them.
class PreferenceInsightsScreen extends ConsumerWidget {
  final String userId;
  const PreferenceInsightsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefAsync = ref.watch(preferenceSummaryProvider(userId));

    return Scaffold(
      backgroundColor: CIPTheme.surface,
      appBar: AppBar(
        backgroundColor: CIPTheme.surface,
        elevation: 0,
        title: const Text('My Trade Preferences',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: prefAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: CIPTheme.primary)),
        error: (e, _) => Center(
            child: Text(e.toString(),
                style: const TextStyle(color: CIPTheme.error))),
        data: (pref) {
          if (pref == null) {
            return _NoDataState();
          }
          return _PreferenceBody(pref: pref);
        },
      ),
    );
  }
}

class _PreferenceBody extends StatelessWidget {
  final UserPreferenceSummary pref;
  const _PreferenceBody({required this.pref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Cold start notice
        if (pref.isColdStart)
          _InfoCard(
            icon: '📊',
            color: CIPTheme.primary,
            title: 'Building your profile',
            body: 'Interact with more trades to build a stronger preference profile. '
                'The system learns from your own accept and reject history.',
          ).animate().fadeIn(),

        if (!pref.isColdStart) ...[
          _SectionHeader('What the system has learned from your trades'),
          const SizedBox(height: 12),

          _StatRow('Total trade interactions', '${pref.totalEvents}'),
          _StatRow('Preferred timing', _timingLabel(pref.preferredTiming)),
          _StatRow('Fatigue tolerance', _fatigueLabel(pref.fatigueTolerance)),

          const SizedBox(height: 20),
          _SectionHeader('Preferred routes'),
          const SizedBox(height: 10),
          if (pref.topRoutes.isEmpty)
            const Text('No route data yet',
                style: TextStyle(color: CIPTheme.textMuted, fontSize: 13))
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: pref.topRoutes
                  .map((r) => _RouteChip(route: r))
                  .toList(),
            ),

          const SizedBox(height: 20),
          _SectionHeader('Preferred destinations'),
          const SizedBox(height: 10),
          if (pref.topDestinations.isEmpty)
            const Text('No destination data yet',
                style: TextStyle(color: CIPTheme.textMuted, fontSize: 13))
          else
            Wrap(
              spacing: 8, runSpacing: 8,
              children: pref.topDestinations
                  .map((d) => _DestChip(iata: d))
                  .toList(),
            ),

          const SizedBox(height: 20),
          _SectionHeader('Schedule preferences'),
          const SizedBox(height: 10),

          _PrefToggle('Prefers international routes', pref.prefersInternational),
          _PrefToggle('Prefers long layovers (24h+)',  pref.prefersLongLayovers),
          _PrefToggle('Avoids early sign-in (<06:00)', pref.avoidsEarlySignin),
        ],

        const SizedBox(height: 28),
        // Privacy note
        _InfoCard(
          icon: '🔒',
          color: CIPTheme.textMuted,
          title: 'How this data is used',
          body: 'This information is built entirely from your own trade history. '
              'It is used to improve trade match suggestions for you. '
              'No personal, demographic, or identity information is inferred or stored.',
        ),
      ],
    );
  }

  String _timingLabel(String t) {
    switch (t) {
      case 'early':     return 'Early morning (before 06:00)';
      case 'morning':   return 'Morning (06:00–12:00)';
      case 'afternoon': return 'Afternoon (12:00–18:00)';
      case 'evening':   return 'Evening (after 18:00)';
      default:          return t;
    }
  }

  String _fatigueLabel(String t) {
    switch (t) {
      case 'low':    return 'Low — prefers lighter duties';
      case 'high':   return 'High — accepts demanding schedules';
      default:       return 'Medium — balanced preference';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: CIPTheme.textPrimary,
          fontSize: 15, fontWeight: FontWeight.w700));
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(child: Text(label,
            style: const TextStyle(
                color: CIPTheme.textSecondary, fontSize: 13))),
        Text(value,
            style: const TextStyle(
                color: CIPTheme.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _RouteChip extends StatelessWidget {
  final String route;
  const _RouteChip({required this.route});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CIPTheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CIPTheme.primary.withOpacity(0.3)),
      ),
      child: Text(route,
          style: const TextStyle(
              color: CIPTheme.primary,
              fontSize: 12, fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
    );
  }
}

class _DestChip extends StatelessWidget {
  final String iata;
  const _DestChip({required this.iata});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CIPTheme.navLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Text('✈ $iata',
          style: const TextStyle(
              color: CIPTheme.textPrimary,
              fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _PrefToggle extends StatelessWidget {
  final String label;
  final bool value;
  const _PrefToggle(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(
          value ? Icons.check_circle : Icons.radio_button_unchecked,
          color: value ? CIPTheme.success : CIPTheme.textMuted,
          size: 18,
        ),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                color: value ? CIPTheme.textPrimary : CIPTheme.textSecondary,
                fontSize: 13)),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon, title, body;
  final Color color;
  const _InfoCard({required this.icon, required this.title,
    required this.body, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(
                color: CIPTheme.textSecondary, fontSize: 12, height: 1.5)),
          ],
        )),
      ]),
    );
  }
}

class _NoDataState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📊', style: TextStyle(fontSize: 52)),
            SizedBox(height: 16),
            Text('No preference data yet',
                style: TextStyle(
                    color: CIPTheme.textPrimary,
                    fontSize: 17, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'Start interacting with trades to build\nyour personal preference profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
