import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../shared/constants/constants.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifBidAward = true;
  bool _notifTradeMatch = true;
  bool _notifAutoBid = true;
  bool _notifLegality = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  void _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _appVersion = '${info.version} (${info.buildNumber})');
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: CIPTheme.grey50,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language
          _SettingsSection(title: 'Roster', children: [
            _SettingsTile(
              icon: Icons.sync,
              title: 'Roster Sources',
              subtitle: 'Connect CAE Crew Access, calendar feed, or upload',
              onTap: () => context.push('/settings/roster-sources'),
            ),
          ]),
          const SizedBox(height: 16),
          _SettingsSection(title: 'Language', children: [
            _SettingsTile(
              icon: Icons.language,
              title: 'App Language',
              subtitle: 'English',
              onTap: () => _showLanguageSheet(context),
            ),
          ]),
          const SizedBox(height: 16),

          // Notifications
          _SettingsSection(title: 'Notifications', children: [
            SwitchListTile(
              title: const Text('Bid Awarded / Rejected', style: TextStyle(fontSize: 14)),
              value: _notifBidAward,
              onChanged: (v) => setState(() => _notifBidAward = v),
              activeColor: CIPTheme.saudiNavy,
              dense: true,
            ),
            SwitchListTile(
              title: const Text('Trade Matched', style: TextStyle(fontSize: 14)),
              value: _notifTradeMatch,
              onChanged: (v) => setState(() => _notifTradeMatch = v),
              activeColor: CIPTheme.saudiNavy,
              dense: true,
            ),
            SwitchListTile(
              title: const Text('Auto-Bid Ready', style: TextStyle(fontSize: 14)),
              value: _notifAutoBid,
              onChanged: (v) => setState(() => _notifAutoBid = v),
              activeColor: CIPTheme.saudiNavy,
              dense: true,
            ),
            SwitchListTile(
              title: const Text('Legality Alerts', style: TextStyle(fontSize: 14)),
              value: _notifLegality,
              onChanged: (v) => setState(() => _notifLegality = v),
              activeColor: CIPTheme.saudiNavy,
              dense: true,
            ),
          ]),
          const SizedBox(height: 16),

          // Calendar
          _SettingsSection(title: 'Calendar', children: [
            _SettingsTile(
              icon: Icons.calendar_today_outlined,
              title: 'Export to Calendar',
              subtitle: 'Add your schedule to device calendar',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.download_outlined,
              title: 'Download PDF Schedule',
              subtitle: 'Export monthly schedule as PDF',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),

          // Support
          _SettingsSection(title: 'Support', children: [
            _SettingsTile(
              icon: Icons.help_outline,
              title: 'Help & FAQ',
              onTap: () => _launchUrl('https://cip.app/help'),
            ),
            _SettingsTile(
              icon: Icons.chat_bubble_outline,
              title: 'Contact Support',
              onTap: () => _launchUrl('mailto:${AppConstants.supportEmail}'),
            ),
            _SettingsTile(
              icon: Icons.star_outline,
              title: 'Rate the App',
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 16),

          // Legal
          _SettingsSection(title: 'Legal', children: [
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => _launchUrl('https://cip.app/privacy'),
            ),
            _SettingsTile(
              icon: Icons.gavel_outlined,
              title: 'Terms of Service',
              onTap: () => _launchUrl('https://cip.app/terms'),
            ),
            _SettingsTile(
              icon: Icons.warning_amber_outlined,
              title: 'Disclaimer',
              subtitle: 'CIP is an unofficial tool, not affiliated with Saudi Airlines',
              onTap: () => _showDisclaimer(context),
            ),
          ]),
          const SizedBox(height: 16),

          // About
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CIPTheme.grey200),
            ),
            child: Column(
              children: [
                const Text('⭐ Najm', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: CIPTheme.saudiNavy, fontFamily: 'Inter',
                )),
                const Text('Crew Intelligence Platform', style: TextStyle(color: CIPTheme.grey500)),
                const SizedBox(height: 8),
                Text('Version $_appVersion', style: const TextStyle(color: CIPTheme.grey500, fontSize: 12)),
                const SizedBox(height: 4),
                const Text('© 2026 CIP. All rights reserved.',
                  style: TextStyle(color: CIPTheme.grey500, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Select Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            title: const Text('English'),
            trailing: ref.read(localeProvider).languageCode == 'ar'
                ? const Icon(Icons.check, color: CIPTheme.saudiNavy) : null,
            onTap: () {
              ref.read(localeProvider.notifier).state = const Locale('ar');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('English'),
            trailing: ref.read(localeProvider).languageCode == 'en'
                ? const Icon(Icons.check, color: CIPTheme.saudiNavy) : null,
            onTap: () {
              ref.read(localeProvider.notifier).state = const Locale('en');
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showDisclaimer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('⚠️ Disclaimer'),
        content: const Text(
          'Crew Intelligence Platform (CIP / Najm) is an UNOFFICIAL, independent tool '
          'created to assist Saudi Airlines cabin crew with scheduling decisions.\n\n'
          'CIP is NOT affiliated with, endorsed by, or connected to Saudi Arabian Airlines '
          'Corporation (Saudia) or any of its systems.\n\n'
          'All data entered into this app is user-provided and user-owned. '
          'CIP does not access any airline internal systems.\n\n'
          'Always verify schedules and legality through official airline channels. '
          'CIP is provided as-is with no warranty.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Understood')),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(title, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: CIPTheme.grey500, letterSpacing: 0.5,
          )),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CIPTheme.grey200),
          ),
          child: Column(
            children: children.map((child) {
              final idx = children.indexOf(child);
              return Column(
                children: [
                  child,
                  if (idx < children.length - 1) const Divider(height: 1, indent: 52),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, required this.title, this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: CIPTheme.saudiNavy, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12, color: CIPTheme.grey500))
          : null,
      trailing: const Icon(Icons.chevron_right, color: CIPTheme.grey300, size: 18),
      onTap: onTap,
      dense: subtitle == null,
    );
  }
}
