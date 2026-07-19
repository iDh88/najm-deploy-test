import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'offline_widgets.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const double _desktopBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _locationToIndex(location);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= _desktopBreakpoint;
    final isWideDesktop = width >= 1180;

    final body = Column(
      children: [
        const OfflineBanner(),
        Expanded(child: child),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onTap(context, index),
              extended: isWideDesktop,
              minWidth: 72,
              minExtendedWidth: 176,
              groupAlignment: -0.86,
              labelType:
                  isWideDesktop ? null : NavigationRailLabelType.selected,
              destinations: _railDestinations,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          height: 62,
          labelTextStyle: MaterialStatePropertyAll(
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          iconTheme: MaterialStatePropertyAll(IconThemeData(size: 22)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) => _onTap(context, index),
          destinations: _barDestinations,
        ),
      ),
    );
  }

  static const List<NavigationRailDestination> _railDestinations = [
    NavigationRailDestination(
        icon: Icon(Icons.home_outlined, size: 22),
        selectedIcon: Icon(Icons.home, size: 22),
        label: Text('Home')),
    NavigationRailDestination(
        icon: Icon(Icons.flight_outlined, size: 22),
        selectedIcon: Icon(Icons.flight, size: 22),
        label: Text('Lines')),
    NavigationRailDestination(
        icon: Icon(Icons.how_to_vote_outlined, size: 22),
        selectedIcon: Icon(Icons.how_to_vote, size: 22),
        label: Text('Bids')),
    NavigationRailDestination(
        icon: Icon(Icons.swap_horiz_outlined, size: 22),
        selectedIcon: Icon(Icons.swap_horiz, size: 22),
        label: Text('Trades')),
    NavigationRailDestination(
        icon: Icon(Icons.auto_awesome_outlined, size: 22),
        selectedIcon: Icon(Icons.auto_awesome, size: 22),
        label: Text('Najm AI')),
    NavigationRailDestination(
        icon: Icon(Icons.analytics_outlined, size: 22),
        selectedIcon: Icon(Icons.analytics, size: 22),
        label: Text('Intel')),
    NavigationRailDestination(
        icon: Icon(Icons.hotel_outlined, size: 22),
        selectedIcon: Icon(Icons.hotel, size: 22),
        label: Text('Layover')),
  ];

  static const List<NavigationDestination> _barDestinations = [
    NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home'),
    NavigationDestination(
        icon: Icon(Icons.flight_outlined),
        selectedIcon: Icon(Icons.flight),
        label: 'Lines'),
    NavigationDestination(
        icon: Icon(Icons.how_to_vote_outlined),
        selectedIcon: Icon(Icons.how_to_vote),
        label: 'Bids'),
    NavigationDestination(
        icon: Icon(Icons.swap_horiz_outlined),
        selectedIcon: Icon(Icons.swap_horiz),
        label: 'Trades'),
    NavigationDestination(
        icon: Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome),
        label: 'Najm AI'),
    NavigationDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics),
        label: 'Intel'),
    NavigationDestination(
        icon: Icon(Icons.hotel_outlined),
        selectedIcon: Icon(Icons.hotel),
        label: 'Layover'),
  ];

  int _locationToIndex(String location) {
    if (location.startsWith('/lines')) return 1;
    if (location.startsWith('/bids')) return 2;
    if (location.startsWith('/trades')) return 3;
    if (location.startsWith('/assistant')) return 4;
    if (location.startsWith('/intelligence')) return 5;
    if (location.startsWith('/layover')) return 6;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/lines');
        break;
      case 2:
        context.go('/bids');
        break;
      case 3:
        context.go('/trades');
        break;
      case 4:
        context.go('/assistant');
        break;
      case 5:
        context.go('/intelligence');
        break;
      case 6:
        context.go('/layover');
        break;
    }
  }
}
