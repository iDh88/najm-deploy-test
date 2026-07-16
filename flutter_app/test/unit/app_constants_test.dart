// AppConstants + period_utils unit tests (F37).
//
// The category ids here are STORED VALUES on `recommendations` documents and
// are duplicated in recommendation_card.dart's emoji map — these tests pin
// the contract so a rename in one place fails fast instead of silently
// rendering wrong icons / filtering nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:crew_intelligence_platform/core/constants/app_constants.dart';
import 'package:crew_intelligence_platform/core/utils/period_utils.dart';

void main() {
  group('AppConstants.layoverCategories', () {
    test('ids are the persisted vocabulary — exact set, no synthetic "all"',
        () {
      final ids = AppConstants.layoverCategories.map((c) => c.id).toList();
      expect(ids, [
        'restaurants', 'coffee', 'gyms', 'prayer', 'transport',
        'shopping', 'attractions', 'essentials', 'crew_fav',
      ]);
      expect(ids, isNot(contains('all')),
          reason: "'all' is a UI-only tab, never a stored category");
    });

    test('ids are unique and every entry has a label and an icon', () {
      final ids = AppConstants.layoverCategories.map((c) => c.id).toSet();
      expect(ids.length, AppConstants.layoverCategories.length);
      for (final c in AppConstants.layoverCategories) {
        expect(c.label, isNotEmpty);
        expect(c.icon, isNotEmpty);
      }
    });
  });

  group('AppConstants.sortOptions', () {
    test('exactly the options layover_service switches on, Trending first',
        () {
      // layover_service.recommendationsStream switch-cases these literals;
      // its `default` branch is Trending, which must therefore be first (the
      // UI's initial selection).
      expect(AppConstants.sortOptions,
          ['Trending', 'Top Rated', 'Newest', 'Most Saved']);
    });
  });

  group('yearFromPeriod', () {
    test('extracts the year from canonical period strings', () {
      expect(yearFromPeriod('JUN-2026'), 2026);
      expect(yearFromPeriod('DEC-1999'), 1999);
      expect(yearFromPeriod('2027-JAN'), 2027);
      expect(yearFromPeriod('sv schedule 2030 final'), 2030);
    });

    test('falls back when no 19xx/20xx year is present', () {
      expect(yearFromPeriod('JUN', fallbackYear: 2026), 2026);
      expect(yearFromPeriod('', fallbackYear: 2031), 2031);
      // 3-digit and 21xx runs are not years we accept
      expect(yearFromPeriod('room 210', fallbackYear: 2026), 2026);
      expect(yearFromPeriod('flight 2101', fallbackYear: 2026), 2026);
      // 5-digit runs are rejected outright (digit lookarounds)
      expect(yearFromPeriod('ref 20261', fallbackYear: 2026), 2026);
      expect(yearFromPeriod('id 12026', fallbackYear: 2031), 2031);
    });

    test('first plausible year wins when several appear', () {
      expect(yearFromPeriod('2025 vs 2026 comparison'), 2025);
    });

    test('default fallback is the current year (no hardcoding)', () {
      expect(yearFromPeriod('no year here'), DateTime.now().year);
    });
  });
}
