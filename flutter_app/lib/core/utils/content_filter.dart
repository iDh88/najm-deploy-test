/// Client-side content filter for layover recommendations.
///
/// Mirrors the server-side keyword list in python_services/layover/router.py
/// (BLOCKED_KEYWORDS) — the server remains authoritative; this exists to give
/// crew members immediate feedback before an upload round-trip.
///
/// F25: matching is WORD-BOUNDARY based, not substring. Substring matching
/// falsely blocked legitimate content ("Barcelona" contains "bar", "Clube de
/// Regatas" contains "club", "winery" tour ≠ "wine" — though winery itself is
/// blocked as its own keyword). Keep this list and the Python list in sync.
///
/// NOTE: ContentBlockedException is defined in layover_service.dart; this
/// file intentionally defines only the filter.
class ContentFilter {
  ContentFilter._();

  /// Keep in sync with python_services/layover/router.py BLOCKED_KEYWORDS.
  static const List<String> blockedKeywords = [
    'bar', 'bars', 'club', 'clubs', 'nightclub', 'nightclubs',
    'pub', 'pubs', 'alcohol', 'alcoholic', 'beer', 'wine', 'liquor',
    'cocktail', 'cocktails', 'whiskey', 'vodka', 'spirits', 'brewery',
    'winery', 'casino', 'gambling', 'hookah bar', 'shisha bar',
  ];

  static final List<RegExp> _patterns = blockedKeywords
      .map((kw) => RegExp(
            '\\b${RegExp.escape(kw)}\\b',
            caseSensitive: false,
          ))
      .toList(growable: false);

  /// Returns a human-readable, comma-joined list of the blocked terms found
  /// across all provided fields, or null when the content is clean.
  static String? blockedReason({
    required String name,
    required String description,
    required String category,
    String? notes,
  }) {
    final combined = '$name\n$description\n$category\n${notes ?? ''}';
    final hits = <String>{};
    for (var i = 0; i < _patterns.length; i++) {
      if (_patterns[i].hasMatch(combined)) {
        hits.add(blockedKeywords[i]);
      }
    }
    if (hits.isEmpty) return null;
    return hits.join(', ');
  }

  /// True when [text] contains none of the blocked keywords.
  static bool isAllowed(String text) =>
      !_patterns.any((p) => p.hasMatch(text));
}
