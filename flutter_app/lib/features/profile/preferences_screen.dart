import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';

/// Line Preferences — Optimization Mode + ranking preferences.
///
/// These widgets are the SHIPPED, working implementation lifted verbatim out
/// of the previous Profile screen when Profile was rebuilt. They keep calling
/// the same AuthService methods (`updateUserMode`, `updatePreferences`) — no
/// business logic was duplicated or reimplemented, and no feature was lost in
/// the redesign.
///
/// Styling note (honest): this editor still uses CIPTheme. Porting its
/// sliders and chips to the NajmTheme navy/gold palette is a cosmetic
/// follow-up; it was deliberately NOT attempted in the same pass as the
/// Profile rebuild, because rewriting a working stateful editor that cannot
/// be executed here is exactly how a regression gets shipped.
class PreferencesScreen extends ConsumerStatefulWidget {
  const PreferencesScreen({super.key});

  @override
  ConsumerState<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends ConsumerState<PreferencesScreen> {
  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Line Preferences')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ModeCard(user: user),
              const SizedBox(height: 16),
              _PreferencesCard(user: user, onSave: _savePreferences),
              const SizedBox(height: 16),
              _PrivacyCard(user: user),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _savePreferences(CIPUser user, UserPreferences prefs) async {
    await ref.read(authServiceProvider).updatePreferences(user.id, prefs);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preferences saved ✓'),
          backgroundColor: CIPTheme.legalGreen,
        ),
      );
    }
  }
}

// ─── Mode Card ────────────────────────────────────────────────────────────────
class _ModeCard extends ConsumerWidget {
  final CIPUser user;
  const _ModeCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Optimization Mode',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Controls how Najm ranks and suggests lines for you.',
            style: TextStyle(color: CIPTheme.grey500, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: UserMode.values.map((mode) {
              final isSelected = user.userMode == mode;
              final (emoji, label, desc, color) = switch (mode) {
                UserMode.money => ('💰', 'Money', 'Max salary', CIPTheme.moneyGreen),
                UserMode.rest => ('😴', 'Rest', 'Max rest', CIPTheme.restBlue),
                UserMode.balanced => ('⚖️', 'Balanced', 'Both', CIPTheme.balancedPurple),
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => ref.read(authServiceProvider).updateUserMode(user.id, mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withOpacity(0.1) : CIPTheme.grey50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? color : CIPTheme.grey200, width: isSelected ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
                        Text(desc, style: const TextStyle(color: CIPTheme.grey500, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Preferences Card ─────────────────────────────────────────────────────────
class _PreferencesCard extends StatefulWidget {
  final CIPUser user;
  final Function(CIPUser, UserPreferences) onSave;
  const _PreferencesCard({required this.user, required this.onSave});

  @override
  State<_PreferencesCard> createState() => _PreferencesCardState();
}

class _PreferencesCardState extends State<_PreferencesCard> {
  late List<String> _preferredDest;
  late List<int> _preferredOff;
  final _destController = TextEditingController();

  static const _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _preferredDest = List.from(widget.user.preferences.preferredDest);
    _preferredOff = List.from(widget.user.preferences.preferredOff);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preferences',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          const Text('Preferred Destinations', style: TextStyle(fontSize: 13, color: CIPTheme.grey700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: [
              ..._preferredDest.map((d) => Chip(
                label: Text(d),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () => setState(() => _preferredDest.remove(d)),
              )),
              ActionChip(
                label: const Text('+ Add'),
                onPressed: _addDestDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Preferred Days Off', style: TextStyle(fontSize: 13, color: CIPTheme.grey700)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (i) {
              final selected = _preferredOff.contains(i);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    if (selected) _preferredOff.remove(i);
                    else _preferredOff.add(i);
                  }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? CIPTheme.saudiNavy : CIPTheme.grey100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(_weekdays[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : CIPTheme.grey500,
                        )),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final updated = widget.user.preferences.copyWith(
                  preferredDest: _preferredDest,
                  preferredOff: _preferredOff,
                );
                widget.onSave(widget.user, updated);
              },
              child: const Text('Save Preferences'),
            ),
          ),
        ],
      ),
    );
  }

  void _addDestDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Destination'),
        content: TextField(
          controller: _destController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 3,
          decoration: const InputDecoration(hintText: 'IATA code (e.g. LHR)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final code = _destController.text.trim().toUpperCase();
              if (code.length == 3 && !_preferredDest.contains(code)) {
                setState(() => _preferredDest.add(code));
              }
              _destController.clear();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─── Privacy Card ─────────────────────────────────────────────────────────────
class _PrivacyCard extends ConsumerWidget {
  final CIPUser user;
  const _PrivacyCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Privacy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Behavior Tracking', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Let Najm learn from your choices to improve suggestions',
              style: TextStyle(fontSize: 12)),
            value: user.privacyConsents.behaviorTracking,
            onChanged: (_) {},
            activeColor: CIPTheme.saudiNavy,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('Anonymous Comparisons', style: TextStyle(fontSize: 14)),
            subtitle: const Text('Allow anonymized data to improve group recommendations',
              style: TextStyle(fontSize: 12)),
            value: user.privacyConsents.collaborativeFiltering,
            onChanged: (_) {},
            activeColor: CIPTheme.saudiNavy,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Export My Data', style: TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.download_outlined, size: 18),
            onTap: () {},
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Delete Account', style: TextStyle(fontSize: 14, color: CIPTheme.violationRed)),
            trailing: const Icon(Icons.delete_outline, color: CIPTheme.violationRed, size: 18),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
