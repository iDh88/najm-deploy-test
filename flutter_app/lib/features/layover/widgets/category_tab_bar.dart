import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class CategoryTabBar extends StatelessWidget {
  final List<LayoverCategory> tabs;
  final TabController controller;
  final ValueChanged<int>? onTabChanged;

  const CategoryTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 12),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        onTap: onTabChanged,
        indicatorColor: NajmTheme.gold,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: NajmTheme.gold,
        unselectedLabelColor: NajmTheme.textMuted,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        tabs: tabs.map((tab) {
          return Tab(
            height: 48,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tab.icon, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 5),
                Text(tab.label),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
