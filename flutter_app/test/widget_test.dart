// App smoke test.
//
// The full CIPApp cannot be pumped here: its router watches
// FirebaseAuth.instance, which needs a live/mocked Firebase app (covered by
// the e2e suite instead). This test keeps a fast, dependency-free smoke
// check that both shipped themes construct and render a frame.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crew_intelligence_platform/app/theme.dart';

void main() {
  testWidgets('light and dark CIP themes build and render', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(MaterialApp(
        theme: CIPTheme.lightTheme,
        darkTheme: CIPTheme.darkTheme,
        themeMode: mode,
        home: const Scaffold(body: Center(child: Text('NAJM'))),
      ));
      expect(find.text('NAJM'), findsOneWidget);
    }
  });
}
