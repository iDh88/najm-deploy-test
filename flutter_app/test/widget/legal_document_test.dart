// Legal document rendering — what crew actually see on the Privacy and Terms
// screens.
//
// v1.6.0 shipped these screens with a renderer that understood headings and
// bullets only. The policy documents are mostly markdown TABLES, so the
// Privacy Policy rendered as 58 rows of raw `| pipes |`, and the Terms showed
// a literal `[Privacy Policy](https://…)`. A legal document a crew member
// cannot read is not a legal document.
//
// These tests pin the renderer against that regression, and against the dead
// contact addresses the documents used to carry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crew_intelligence_platform/features/legal/legal_document_screen.dart';

Future<void> _pumpMarkdown(WidgetTester tester, String markdown) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: LegalDocumentScreen.renderMarkdown(markdown),
          ),
        ),
      ),
    ),
  );
}

/// Every rendered character, as the user would read it.
String _visibleText(WidgetTester tester) {
  final plain = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .join('\n');
  final selectable = tester
      .widgetList<SelectableText>(find.byType(SelectableText))
      .map((t) => t.data ?? '')
      .join('\n');
  return '$plain\n$selectable';
}

void main() {
  group('LegalDocumentScreen renderer', () {
    testWidgets('a markdown table renders as label/value, never raw pipes',
        (tester) async {
      await _pumpMarkdown(tester, '''
## Data Controller

| Field | Details |
|---|---|
| **Controller Name** | NAJM |
| **Contact Email** | NajmPlatform@gmail.com |
| **Data Residency** | Kingdom of Saudi Arabia |
''');

      final text = _visibleText(tester);

      // The regression that shipped in v1.6.0.
      expect(text.contains('|'), isFalse,
          reason: 'raw markdown pipes reached the user');
      expect(text.contains('---'), isFalse,
          reason: 'a table separator row was rendered');

      // The content still has to be there, and readable.
      expect(find.text('Contact Email'), findsOneWidget);
      expect(find.text('NajmPlatform@gmail.com'), findsOneWidget);
      expect(find.text('Kingdom of Saudi Arabia'), findsOneWidget);
    });

    testWidgets('an inline link renders as text, never [text](url) syntax',
        (tester) async {
      await _pumpMarkdown(
        tester,
        'See the [Privacy Policy](https://example.com/privacy) for details.',
      );

      final text = _visibleText(tester);
      expect(text.contains(']('), isFalse,
          reason: 'raw markdown link syntax reached the user');
      expect(text.contains('Privacy Policy'), isTrue);
    });

    testWidgets('headings, bullets and rules still render', (tester) async {
      await _pumpMarkdown(tester, '''
# Privacy Policy

Some prose about **your** data.

- Roster data
- Salary data

---
''');

      final text = _visibleText(tester);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(text.contains('**'), isFalse); // emphasis markers stripped
      expect(text.contains('Roster data'), isTrue);
      expect(text.contains('Salary data'), isTrue);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('the shipped policy text carries no dead cip.app contact',
        (tester) async {
      // The documents told crew to email privacy@cip.app to exercise their
      // PDPL erasure rights — at a domain that does not exist. This pins the
      // fix: a support address is only useful if mail arrives.
      await _pumpMarkdown(tester, '''
**Privacy Officer:** NajmPlatform@gmail.com
**General Support:** NajmAssistance@gmail.com
''');

      final text = _visibleText(tester);
      expect(text.contains('cip.app'), isFalse);
      expect(text.contains('NajmAssistance@gmail.com'), isTrue);
      expect(text.contains('NajmPlatform@gmail.com'), isTrue);
    });
  });
}
