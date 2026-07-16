/// Pure helpers for roster period strings ("JUN-2026").
///
/// Extracted from upload_search_comparison_screens.dart (F27/F37) so the
/// parsing rules are unit-testable without a widget harness.
library period_utils;

/// Extracts the 4-digit year from a period string like "JUN-2026".
///
/// Accepts a 19xx/20xx run of EXACTLY four digits (digit-lookarounds reject
/// runs like "20261") anywhere in the string; falls back to [fallbackYear]
/// (defaults to the current year) so callers never receive a hardcoded value.
int yearFromPeriod(String period, {int? fallbackYear}) {
  final m = RegExp(r'(?<!\d)(?:19|20)\d{2}(?!\d)').firstMatch(period);
  if (m != null) return int.parse(m.group(0)!);
  return fallbackYear ?? DateTime.now().year;
}
