// Profile — widget tests.
//
// These cover the presentational layer where NAJM's honesty and security
// guarantees are actually *rendered*. The view-model rules (sync badge
// matrix, days-remaining, mailto construction) are unit-tested in
// test/unit/profile_test.dart; what can only be proven by pumping a widget is
// asserted here:
//
//   · an unavailable provider (Email Import) cannot be tapped into a flow
//     that does not exist — "not available yet" has to be inert, not just
//     grey;
//   · the Security card reinforces the Zero-Knowledge model and is
//     structurally incapable of showing a credential;
//   · a value the backend did not send renders as "—", never as an invented
//     default;
//   · a degraded subsystem is *visible* (error note) rather than hidden
//     behind a fake-healthy UI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crew_intelligence_platform/core/theme/app_theme.dart';
import 'package:crew_intelligence_platform/features/profile/widgets/profile_widgets.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: NajmTheme.navy,
        body: SingleChildScrollView(child: child),
      ),
    ),
  );
}

void main() {
  group('ProfileTile — an unavailable source must be inert', () {
    testWidgets('a disabled tile cannot be tapped (Email Import)',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ProfileTile(
          icon: Icons.mail_outline,
          title: 'Email Import',
          subtitle: 'Not available yet',
          enabled: false,
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.text('Email Import'));
      await tester.pumpAndSettle();

      // The honesty rule: we render the provider so crew know it exists and
      // is not yet built — but it must not open anything. A grey tile that
      // still fires onTap would be a lie with extra steps.
      expect(taps, 0);
      expect(find.text('Not available yet'), findsOneWidget);
    });

    testWidgets('an available tile does fire, and shows an affordance',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ProfileTile(
          icon: Icons.calendar_month,
          title: 'ICS Calendar',
          subtitle: 'Connected',
          onTap: () => taps++,
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('ICS Calendar'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('a tile with no action shows no chevron', (tester) async {
      await _pump(
        tester,
        const ProfileTile(icon: Icons.info_outline, title: 'Build 1042'),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('SecurityCard — Zero-Knowledge, by construction', () {
    testWidgets('states where credentials live and that NAJM never gets them',
        (tester) async {
      await _pump(tester, const SecurityCard());

      expect(find.text('Zero-Knowledge Credentials'), findsOneWidget);
      expect(find.text('Protected'), findsOneWidget);
      expect(
        find.textContaining('Apple Keychain / Android Keystore'),
        findsOneWidget,
      );
      expect(find.textContaining('Never uploaded to NAJM servers'),
          findsOneWidget);
      expect(find.textContaining('normalized on-device'), findsOneWidget);
    });

    testWidgets('renders no credential-shaped value', (tester) async {
      await _pump(tester, const SecurityCard());

      // The card takes no arguments and holds no CredentialManager, so it
      // *cannot* obtain a secret. This test pins that: if someone ever wires
      // a stored PRN or token into it "just to show the user", it fails.
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase())
          .join(' ');

      for (final leak in ['password', 'prn:', 'token', 'secret', 'bearer']) {
        expect(rendered.contains(leak), isFalse,
            reason: 'SecurityCard rendered "$leak"');
      }
    });
  });

  group('ProfileKeyValue — absent data is shown, never invented', () {
    testWidgets('renders exactly the value it is given, em-dash included',
        (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            // What the AI card shows when the knowledge base is genuinely
            // empty: no documents, so no "last updated" timestamp exists.
            // "Today" would be a fabrication.
            ProfileKeyValue(label: 'Knowledge Updated', value: '—'),
            ProfileKeyValue(label: 'Renewal', value: '22 Jul 2026'),
          ],
        ),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.text('22 Jul 2026'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
    });
  });

  group('Status surfaces', () {
    testWidgets('a degraded subsystem stays visible', (tester) async {
      await _pump(
        tester,
        const ProfileErrorNote('AI status unavailable — showing cached state'),
      );
      expect(find.textContaining('AI status unavailable'), findsOneWidget);
    });

    testWidgets('badge and health dot render for each sync state',
        (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            StatusBadge(label: 'Healthy', color: NajmTheme.success),
            HealthDot(color: NajmTheme.success),
            StatusBadge(label: 'Waiting', color: NajmTheme.warning),
            StatusBadge(label: 'Failed', color: NajmTheme.error),
          ],
        ),
      );

      expect(find.text('Healthy'), findsOneWidget);
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.byType(HealthDot), findsOneWidget);
    });

    testWidgets('engine chips render every trigger mode without crashing',
        (tester) async {
      await _pump(
        tester,
        const Wrap(
          children: [
            EngineChip(label: 'Legality', trigger: 'triggered'),
            EngineChip(label: 'Salary', trigger: 'queued'),
            EngineChip(label: 'Trade Finder', trigger: 'on_demand'),
          ],
        ),
      );

      expect(find.byType(EngineChip), findsNWidgets(3));
      expect(find.text('Legality'), findsOneWidget);
      expect(find.text('Trade Finder'), findsOneWidget);
    });

    testWidgets('skeleton animates while loading and disposes cleanly',
        (tester) async {
      await _pump(tester, const ProfileSkeleton(height: 80));
      expect(find.byType(ProfileSkeleton), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      // Replace it — the shimmer's AnimationController must tear down without
      // throwing (a leaked ticker would fail the test).
      await _pump(tester, const SizedBox.shrink());
      expect(find.byType(ProfileSkeleton), findsNothing);
    });
  });
}
