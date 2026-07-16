// ContentFilter unit tests (F37).
//
// The pre-remediation filter used SUBSTRING matching, which blocked
// legitimate crew content ("Barcelona" ⊃ "bar", "public" ⊃ "pub",
// "clubhouse sandwich" ⊃ "club"). These tests pin the word-boundary
// behavior on both directions: real blocked terms are still caught, and the
// documented false positives can never regress. Keep in lockstep with
// python_services/tests/unit/test_layover_content.py — the two suites
// assert the same fixture strings.

import 'package:flutter_test/flutter_test.dart';
import 'package:crew_intelligence_platform/core/utils/content_filter.dart';

void main() {
  group('ContentFilter — blocks real matches', () {
    test('standalone keywords are blocked case-insensitively', () {
      expect(ContentFilter.isAllowed('great sports BAR downtown'), isFalse);
      expect(ContentFilter.isAllowed('Wine tasting tour'), isFalse);
      expect(ContentFilter.isAllowed('the casino floor'), isFalse);
      expect(ContentFilter.isAllowed('best Nightclub in town'), isFalse);
    });

    test('multi-word keywords match as phrases', () {
      expect(ContentFilter.isAllowed('a hookah bar near the hotel'), isFalse);
      expect(ContentFilter.isAllowed('shisha bar rooftop'), isFalse);
    });

    test('keyword at string edges still matches', () {
      expect(ContentFilter.isAllowed('bar'), isFalse);
      expect(ContentFilter.isAllowed('beer.'), isFalse);
      expect(ContentFilter.isAllowed('Vodka'), isFalse);
    });

    test('blockedReason names every distinct hit once', () {
      final reason = ContentFilter.blockedReason(
        name: 'Beer garden',
        description: 'craft beer and wine',
        category: 'restaurants',
        notes: null,
      );
      expect(reason, isNotNull);
      expect(reason, contains('beer'));
      expect(reason, contains('wine'));
      // 'beer' appears in two fields but is reported once
      expect('beer'.allMatches(reason!).length, 1);
    });
  });

  group('ContentFilter — word-boundary false-positive regression', () {
    test('substring-only occurrences are allowed', () {
      expect(ContentFilter.isAllowed('Barcelona tapas walk'), isTrue);
      expect(ContentFilter.isAllowed('Public transport tips'), isTrue);
      expect(ContentFilter.isAllowed('clubhouse sandwich cafe'), isTrue);
      expect(ContentFilter.isAllowed('rebar art installation'), isTrue);
      expect(ContentFilter.isAllowed('scuba diving trip'), isTrue);
      expect(ContentFilter.isAllowed('barbershop quartet'), isTrue);
      expect(ContentFilter.isAllowed('winesap apple orchard'), isTrue);
    });

    test('hyphen/punctuation form a boundary — full word still blocks', () {
      // regex \b treats '-' as a boundary; a full blocked word adjacent to
      // punctuation must still be caught.
      expect(ContentFilter.isAllowed('wine-tasting evening'), isFalse);
      expect(ContentFilter.isAllowed('(bar)'), isFalse);
    });

    test('clean content returns null reason', () {
      expect(
        ContentFilter.blockedReason(
          name: 'Al Baik',
          description: 'Legendary fried chicken, halal, near the corniche',
          category: 'restaurants',
          notes: 'crew favourite after Barcelona layovers',
        ),
        isNull,
      );
    });
  });

  group('ContentFilter — keyword list contract', () {
    test('list is non-empty and lowercase (matching is case-insensitive)', () {
      expect(ContentFilter.blockedKeywords, isNotEmpty);
      for (final kw in ContentFilter.blockedKeywords) {
        expect(kw, equals(kw.toLowerCase()),
            reason: 'keywords are canonically lowercase: $kw');
      }
    });
  });
}
