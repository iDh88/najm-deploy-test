import 'package:flutter/material.dart';
import '../../../../app/theme.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SEARCH HEADER
// ══════════════════════════════════════════════════════════════════════════════

class SearchHeader extends StatelessWidget {
  final TextEditingController routeController;
  final String selectedMonth;
  final ValueChanged<String> onMonthChanged;
  final VoidCallback onSearch;
  final bool isLoading;
  final bool isPrefilled;

  const SearchHeader({
    super.key,
    required this.routeController,
    required this.selectedMonth,
    required this.onMonthChanged,
    required this.onSearch,
    required this.isLoading,
    required this.isPrefilled,
  });

  static const _months = [
    'JAN','FEB','MAR','APR','MAY','JUN',
    'JUL','AUG','SEP','OCT','NOV','DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final year = int.parse(selectedMonth.split('-').last);

    return Container(
      color: CIPTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: routeController,
                  style: const TextStyle(
                      color: CIPTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.5),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Route  e.g.  JED-DEL-JED',
                    prefixIcon: const Icon(Icons.flight,
                        color: CIPTheme.primary, size: 18),
                    suffixIcon: isPrefilled
                        ? const Tooltip(
                            message: 'Pre-filled from your line',
                            child: Icon(Icons.auto_awesome,
                                color: CIPTheme.primary, size: 16))
                        : null,
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Month picker
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _months.length,
              itemBuilder: (_, i) {
                final key = '${_months[i]}-$year';
                final active = key == selectedMonth;
                return GestureDetector(
                  onTap: () => onMonthChanged(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: active
                          ? CIPTheme.primary
                          : CIPTheme.navLight,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: active
                              ? CIPTheme.primary
                              : CIPTheme.divider),
                    ),
                    child: Center(
                      child: Text(
                        _months[i],
                        style: TextStyle(
                            color: active
                                ? Colors.white
                                : CIPTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Search button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: CIPTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search, size: 18),
              label: Text(
                isLoading ? 'Scanning…' : 'Find Trade Matches',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// COLD START BANNER
// ══════════════════════════════════════════════════════════════════════════════

class ColdStartBanner extends StatelessWidget {
  const ColdStartBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CIPTheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome,
              color: CIPTheme.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Building your preference profile',
                    style: TextStyle(
                        color: CIPTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 4),
                const Text(
                  'Results are sorted by operational compatibility. '
                  'As you interact with more trades, the system will '
                  'learn your preferred route patterns and improve suggestions.',
                  style: TextStyle(
                      color: CIPTheme.textSecondary,
                      fontSize: 12,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
