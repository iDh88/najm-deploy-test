import '../sync_models.dart';

/// Device-side ICS → NormalizedRoster.
///
/// ZERO-KNOWLEDGE DIRECTIVE: "Roster is downloaded locally → Roster is
/// normalized → Normalized roster ONLY is uploaded to NAJM backend."
///
/// So the phone — not the server — turns the calendar into flight legs. Two
/// consequences, both deliberate:
///   1. The raw calendar never leaves the device. A crew member's feed also
///      carries personal, non-flight events (doctor's appointments, family
///      birthdays); those are dropped here and NAJM never sees them.
///   2. The feed URL — which can embed a personal token — is used only on
///      the device, so it is never transmitted to NAJM either.
///
/// PARITY: this is a faithful port of the canonical server parser
/// (python_services/roster_sync/ics_parser.py). The two implementations are
/// locked to identical behaviour by a SHARED golden fixture, asserted on
/// both sides:
///   · python_services/tests/unit/test_roster_sync.py  (golden parity test)
///   · flutter_app/test/unit/ics_normalizer_test.dart  (same fixture)
/// If you change extraction rules, change BOTH and update the fixture.
class IcsNormalizer {
  /// RFC 5545 §3.1 — a CRLF followed by space/tab continues the previous line.
  static List<String> _unfold(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final out = <String>[];
    for (final raw in normalized.split('\n')) {
      if (raw.isNotEmpty &&
          (raw.startsWith(' ') || raw.startsWith('\t')) &&
          out.isNotEmpty) {
        out[out.length - 1] += raw.substring(1);
      } else {
        out.add(raw);
      }
    }
    return out.where((l) => l.trim().isNotEmpty).toList();
  }

  /// 'DTSTART;TZID=Asia/Riyadh:20260610T083000' → (name, params, value)
  static _Prop _prop(String line) {
    final i = line.indexOf(':');
    final head = i == -1 ? line : line.substring(0, i);
    final value = i == -1 ? '' : line.substring(i + 1);
    final parts = head.split(';');
    final params = <String, String>{};
    for (final p in parts.skip(1)) {
      final j = p.indexOf('=');
      if (j == -1) {
        params[p.toUpperCase()] = '';
      } else {
        params[p.substring(0, j).toUpperCase()] = p.substring(j + 1);
      }
    }
    return _Prop(parts.first.toUpperCase(), params, value);
  }

  static final _dateOnly = RegExp(r'^\d{8}$');

  /// Mirrors the server: every branch yields the LITERAL wall-clock time as a
  /// naive DateTime (roster times are consumed as local times downstream), so
  /// a TZID or trailing Z shifts nothing.
  static DateTime? _parseDt(String raw, Map<String, String> params) {
    final v = raw.trim();
    try {
      if (params['VALUE'] == 'DATE' || _dateOnly.hasMatch(v)) {
        return DateTime(int.parse(v.substring(0, 4)),
            int.parse(v.substring(4, 6)), int.parse(v.substring(6, 8)));
      }
      final body = v.endsWith('Z') ? v.substring(0, v.length - 1) : v;
      if (body.length < 15 || body[8] != 'T') return null;
      return DateTime(
        int.parse(body.substring(0, 4)),
        int.parse(body.substring(4, 6)),
        int.parse(body.substring(6, 8)),
        int.parse(body.substring(9, 11)),
        int.parse(body.substring(11, 13)),
        int.parse(body.substring(13, 15)),
      );
    } catch (_) {
      return null;
    }
  }

  // Extraction patterns — identical to the server's DEFAULT_PROFILE.
  static final _flightRe = RegExp(r'\b([A-Z]{2}\s?\d{2,4})\b');
  static final _routeRe = RegExp(r'\b([A-Z]{3})\s*[-–>/]\s*([A-Z]{3})\b');
  static final _aircraftRe = RegExp(r'\b(A3\d{2}|B7\d{2}|77\dW?|78\d)\b');
  static const _domestic = {
    'JED', 'RUH', 'DMM', 'MED', 'AHB', 'TUU', 'GIZ', 'ELQ', 'HAS',
    'TIF', 'YNB', 'AJF', 'EAM', 'URY', 'RAE', 'BHH', 'WAE', 'DWD',
  };

  /// Returns the normalized roster, or throws [IcsNormalizeException] with a
  /// message safe to show the user (never echoes the feed URL or a token).
  static NormalizedRoster normalize(String text, String period, int year) {
    if (!text.contains('BEGIN:VCALENDAR')) {
      throw IcsNormalizeException(
          'That link is not a calendar feed (no calendar data found).');
    }

    final legs = <Map<String, dynamic>>[];
    var eventsTotal = 0;
    var inEvent = false;
    var ev = <String, dynamic>{};

    for (final line in _unfold(text)) {
      final p = _prop(line);
      if (p.name == 'BEGIN' && p.value.toUpperCase() == 'VEVENT') {
        inEvent = true;
        ev = <String, dynamic>{};
        continue;
      }
      if (p.name == 'END' && p.value.toUpperCase() == 'VEVENT') {
        inEvent = false;
        eventsTotal++;
        final leg = _eventToLeg(ev);
        if (leg != null) legs.add(leg);
        continue;
      }
      if (!inEvent) continue;
      if (p.name == 'DTSTART' || p.name == 'DTEND') {
        ev[p.name] = _parseDt(p.value, p.params);
      } else if (p.name == 'SUMMARY' ||
          p.name == 'DESCRIPTION' ||
          p.name == 'LOCATION') {
        ev[p.name] = p.value.replaceAll('\\,', ',').replaceAll('\\n', ' ');
      }
    }

    legs.sort((a, b) =>
        (a['departureLT'] as String).compareTo(b['departureLT'] as String));

    if (legs.isEmpty) {
      throw IcsNormalizeException(
          'No flights found in that calendar ($eventsTotal events read).');
    }

    return NormalizedRoster(
      period: period,
      year: year,
      legs: legs,
      providerNote: 'ics: ${legs.length} legs from $eventsTotal events '
          '(normalized on device)',
    );
  }

  static Map<String, dynamic>? _eventToLeg(Map<String, dynamic> ev) {
    final start = ev['DTSTART'];
    final end = ev['DTEND'];
    if (start is! DateTime || end is! DateTime) return null;

    final text = ['SUMMARY', 'DESCRIPTION', 'LOCATION']
        .map((k) => (ev[k] ?? '').toString())
        .join(' ')
        .toUpperCase();

    final fn = _flightRe.firstMatch(text);
    final rt = _routeRe.firstMatch(text);
    // Not a flight event (a personal appointment, a standby block, …) —
    // skipped honestly, and therefore never uploaded.
    if (fn == null || rt == null) return null;

    final origin = rt.group(1)!;
    final dest = rt.group(2)!;
    final intl = !(_domestic.contains(origin) && _domestic.contains(dest));
    final rawBlock = end.difference(start).inSeconds / 3600.0;
    final block = (rawBlock * 100).round() / 100.0;
    final ac = _aircraftRe.firstMatch(text);

    return {
      'flightNumber': fn.group(1)!.replaceAll(' ', ''),
      'origin': origin,
      'destination': dest,
      'legType': intl ? 'international' : 'domestic',
      'departureLT': _iso(start),
      'arrivalLT': _iso(end),
      'blockHours': block < 0 ? 0.0 : block,
      'aircraftType': ac?.group(1) ?? '',
    };
  }

  /// Naive local wall-clock, no offset — matches the server's datetime model.
  static String _iso(DateTime d) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${p2(d.month)}-${p2(d.day)}'
        'T${p2(d.hour)}:${p2(d.minute)}:${p2(d.second)}';
  }
}

class _Prop {
  final String name;
  final Map<String, String> params;
  final String value;
  const _Prop(this.name, this.params, this.value);
}

class IcsNormalizeException implements Exception {
  final String message;
  IcsNormalizeException(this.message);
  @override
  String toString() => message;
}
