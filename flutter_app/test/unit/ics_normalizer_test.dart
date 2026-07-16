// ICS golden-parity (device side).
//
// Twin of python_services/tests/unit/test_ics_parity.py. Both assert against
// the SAME fixture files at test_fixtures/roster_sync/, so the Dart device
// normalizer and the canonical Python parser cannot silently diverge.
//
// Why this matters: the Zero-Knowledge directive requires the DEVICE to
// normalize the roster ("Normalized roster ONLY is uploaded"). That put a
// second ICS implementation on the phone. Without this test, a drift between
// the two would ship a wrong roster to real crew with every suite still
// green.
//
// `flutter test` runs with the package root as cwd, so the fixture lives one
// level up.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:crew_intelligence_platform/core/roster_sync/providers/ics_normalizer.dart';

const _deviceFields = [
  'flightNumber',
  'origin',
  'destination',
  'legType',
  'departureLT',
  'arrivalLT',
  'blockHours',
  'aircraftType',
];

void main() {
  final fixtures = Directory('../test_fixtures/roster_sync');

  late String icsText;
  late Map<String, dynamic> golden;

  setUpAll(() {
    icsText = File('${fixtures.path}/ics_golden.ics').readAsStringSync();
    golden = jsonDecode(
        File('${fixtures.path}/ics_golden.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  group('IcsNormalizer golden parity', () {
    test('device normalizer matches the canonical parser exactly', () {
      final roster = IcsNormalizer.normalize(
          icsText, golden['period'] as String, golden['year'] as int);

      final produced = roster.legs
          .map((leg) => {
                for (final k in _deviceFields) k: leg[k],
              })
          .toList();

      expect(produced, equals(golden['legs']));
    });

    test('private, non-flight events never leave the device', () {
      final roster = IcsNormalizer.normalize(
          icsText, golden['period'] as String, golden['year'] as int);
      final blob = jsonEncode(roster.legs).toUpperCase();

      // The fixture feed contains a dentist appointment, annual leave and a
      // standby block. The uploaded payload must contain none of them.
      for (final private in ['DENTIST', 'ANNUAL LEAVE', 'STBY']) {
        expect(blob.contains(private), isFalse,
            reason: '$private leaked into the uploaded roster');
      }
      expect(roster.legs.length, golden['legs'].length);
    });

    test('legs are sorted chronologically even though the feed is not', () {
      final roster = IcsNormalizer.normalize(
          icsText, golden['period'] as String, golden['year'] as int);
      final departures =
          roster.legs.map((l) => l['departureLT'] as String).toList();
      final sorted = [...departures]..sort();

      expect(departures, equals(sorted));
      // The feed lists the 05-Jul long-haul first; the 03-Jul domestic leg
      // must still come out first.
      expect(roster.legs.first['flightNumber'], 'SV1023');
    });

    test('a feed with no flight events fails loudly, uploads nothing', () {
      expect(
        () => IcsNormalizer.normalize(
            'BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Dentist\n'
            'DTSTART:20260703T060000Z\nDTEND:20260703T070000Z\n'
            'END:VEVENT\nEND:VCALENDAR\n',
            'JUL-2026',
            2026),
        throwsA(isA<IcsNormalizeException>()),
      );
    });

    test('non-calendar text is rejected', () {
      expect(
        () => IcsNormalizer.normalize('<html>login</html>', 'JUL-2026', 2026),
        throwsA(isA<IcsNormalizeException>()),
      );
    });
  });
}
