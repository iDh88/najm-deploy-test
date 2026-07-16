import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/models.dart';

/// Compact 3-button mode switcher shown below the AppBar on the Lines screen.
/// Tapping a mode updates the user's global optimization preference immediately.
class ModeSwitcher extends ConsumerWidget {
  final UserMode currentMode;

  const ModeSwitcher({super.key, required this.currentMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Mode:',
            style: TextStyle(fontSize: 12, color: CIPTheme.grey700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: UserMode.values.map((mode) {
                final isSelected = mode == currentMode;
                final (emoji, label, desc, color) = switch (mode) {
                  UserMode.money => (
                      '💰',
                      'Money',
                      'Max salary',
                      CIPTheme.moneyGreen
                    ),
                  UserMode.rest => (
                      '😴',
                      'Rest',
                      'Max rest',
                      CIPTheme.restBlue
                    ),
                  UserMode.balanced => (
                      '⚖️',
                      'Balanced',
                      'Both',
                      CIPTheme.balancedPurple
                    ),
                };

                return Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final user =
                          ref.read(currentUserProvider).valueOrNull;
                      if (user == null) return;
                      await ref
                          .read(authServiceProvider)
                          .updateUserMode(user.id, mode);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? color : CIPTheme.grey200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 14)),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected ? color : CIPTheme.grey500,
                            ),
                          ),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 9,
                              color: CIPTheme.grey500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
