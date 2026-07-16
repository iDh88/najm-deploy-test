import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'offline_widgets.dart';

/// Bottom navigation shell wrapping all main tab screens.
/// Uses GoRouter's ShellRoute — child is the active tab's screen.
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _locationToIndex(location),
        onDestinationSelected: (index) => _onTap(context, index),
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.flight_outlined),
            selectedIcon: Icon(Icons.flight),
            label: 'Lines',
          ),
          NavigationDestination(
            icon:         Icon(Icons.how_to_vote_outlined),
            selectedIcon: Icon(Icons.how_to_vote),
            label: 'Bids',
          ),
          NavigationDestination(
            icon:         Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Trades',
          ),
          NavigationDestination(
            icon:         Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Najm AI',
          ),
          // Phase 2 — PDF Intelligence
          NavigationDestination(
            icon:         Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Intel',
          ),
          // Phase 3 — Layover
          NavigationDestination(
            icon:         Icon(Icons.hotel_outlined),
            selectedIcon: Icon(Icons.hotel),
            label: 'Layover',
          ),
        ],
      ),
    );
  }

  int _locationToIndex(String location) {
    if (location.startsWith('/lines'))        return 1;
    if (location.startsWith('/bids'))         return 2;
    if (location.startsWith('/trades'))       return 3;
    if (location.startsWith('/assistant'))    return 4;
    if (location.startsWith('/intelligence')) return 5;
    if (location.startsWith('/layover'))      return 6;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');         break;
      case 1: context.go('/lines');        break;
      case 2: context.go('/bids');         break;
      case 3: context.go('/trades');       break;
      case 4: context.go('/assistant');    break;
      case 5: context.go('/intelligence'); break;
      case 6: context.go('/layover');      break;
    }
  }
}
