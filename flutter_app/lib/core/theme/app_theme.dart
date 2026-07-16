import 'package:flutter/material.dart';

/// Najm dark theme palette — navy surfaces with gold accents.
///
/// Used by the Layover Hub and Intelligence features, which render on dark
/// navy surfaces (vs. the light CIPTheme used elsewhere). Brand anchors are
/// derived from CIPTheme (lib/app/theme.dart): saudiNavy 0xFF1B4F8A and
/// saudiGold 0xFFC8A84B.
///
/// F23: this file was referenced by 12 widgets/screens but absent from the
/// repository, breaking compilation of both features.
class NajmTheme {
  NajmTheme._();

  // ── Surfaces (navy scale, darkest → lightest) ─────────────────────────────
  /// Deepest background (scaffold).
  static const Color navy = Color(0xFF0D1B2E);

  /// Mid-depth surface (sheets, nav bars).
  static const Color navyMid = Color(0xFF12233B);

  /// Card surface.
  static const Color navyCard = Color(0xFF162944);

  /// Elevated / interactive surface (chips, hovered cards). Brand navy.
  static const Color navyLight = Color(0xFF1B4F8A);

  // ── Strokes ────────────────────────────────────────────────────────────────
  static const Color cardBorder = Color(0xFF27406B);
  static const Color divider = Color(0xFF1E3355);

  // ── Accent ─────────────────────────────────────────────────────────────────
  /// Brand gold (matches CIPTheme.saudiGold).
  static const Color gold = Color(0xFFC8A84B);

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8C86B), Color(0xFFC8A84B)],
  );

  // ── Text on navy ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F5FA);
  static const Color textSecondary = Color(0xFFB7C4D8);
  static const Color textMuted = Color(0xFF7C8BA3);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // ── Saudi green (crew-favourite / halal-verified accents) ─────────────────
  static const Color saudiGreen = Color(0xFF1E8449);
  static const Color saudiGreenLight = Color(0xFF2ECC71);
}
