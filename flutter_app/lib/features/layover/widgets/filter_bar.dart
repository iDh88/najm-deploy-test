import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class FilterBar extends StatelessWidget {
  final String sortBy;
  final bool halalOnly;
  final bool openNow;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onHalalChanged;
  final ValueChanged<bool> onOpenNowChanged;

  const FilterBar({
    super.key,
    required this.sortBy,
    required this.halalOnly,
    required this.openNow,
    required this.onSortChanged,
    required this.onHalalChanged,
    required this.onOpenNowChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Sort dropdown
          _SortChip(current: sortBy, onChanged: onSortChanged),
          const SizedBox(width: 8),

          // Halal filter
          _ToggleChip(
            label: '🟢 Halal',
            active: halalOnly,
            onToggle: () => onHalalChanged(!halalOnly),
          ),
          const SizedBox(width: 8),

          // Open Now filter
          _ToggleChip(
            label: '🕐 Open Now',
            active: openNow,
            onToggle: () => onOpenNowChanged(!openNow),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _SortChip({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: NajmTheme.navyMid,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _SortSheet(current: current),
        );
        if (selected != null) onChanged(selected);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: NajmTheme.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: NajmTheme.gold.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort, color: NajmTheme.gold, size: 14),
            const SizedBox(width: 5),
            Text(
              current,
              style: const TextStyle(
                color: NajmTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                color: NajmTheme.gold, size: 14),
          ],
        ),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final String current;
  const _SortSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sort by',
              style: TextStyle(
                  color: NajmTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...AppConstants.sortOptions.map((opt) {
            final isActive = opt == current;
            return ListTile(
              onTap: () => Navigator.pop(context, opt),
              title: Text(opt,
                  style: TextStyle(
                    color: isActive ? NajmTheme.gold : NajmTheme.textPrimary,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w400,
                  )),
              trailing: isActive
                  ? const Icon(Icons.check, color: NajmTheme.gold)
                  : null,
              contentPadding: EdgeInsets.zero,
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onToggle;

  const _ToggleChip(
      {required this.label, required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: active ? NajmTheme.gold.withOpacity(0.15) : NajmTheme.navyLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? NajmTheme.gold : NajmTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? NajmTheme.gold : NajmTheme.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
