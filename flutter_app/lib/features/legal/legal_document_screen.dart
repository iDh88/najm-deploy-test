import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/theme/app_theme.dart';

/// Renders a bundled document (Terms, Privacy Policy, Release Notes).
///
/// The documents are the REAL ones the project maintains
/// (docs/terms-of-service.md, docs/privacy-policy.md, VERSION.md), copied
/// into assets/legal/ at build time. Two consequences worth having:
///   * they work offline — a crew member on a layover with no signal can
///     still read the privacy policy they agreed to;
///   * they cannot drift into a dead link. Settings previously pointed at
///     `https://cip.app/privacy`, a leftover placeholder domain from the
///     pre-NAJM naming; both entry points now render this.
///
/// Rendering is a small, dependency-free markdown subset (headings, bullets,
/// rules, bold-ish emphasis stripped) — enough for policy prose, and it
/// avoids pulling in a markdown package for three documents.
class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NajmTheme.navy,
      appBar: AppBar(
        backgroundColor: NajmTheme.navy,
        title: Text(title),
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || (snap.data ?? '').isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'This document could not be loaded on this device.',
                  style: const TextStyle(color: NajmTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return Scrollbar(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: _render(snap.data!),
            ),
          );
        },
      ),
    );
  }

  /// Public so a widget test can pump the parser's output directly.
  /// The policy documents are markdown TABLES, and a renderer that only knew
  /// headings and bullets showed crew 58 rows of raw `| pipes |`.
  static List<Widget> renderMarkdown(String markdown) => _render(markdown);

  static final _tableSeparator = RegExp(r'^:?-{2,}:?$');

  static List<Widget> _render(String markdown) {
    final widgets = <Widget>[];
    for (final rawLine in markdown.split('\n')) {
      final line = rawLine.trimRight();

      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 10));
        continue;
      }
      if (line.startsWith('---')) {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: NajmTheme.cardBorder, height: 1),
        ));
        continue;
      }

      // Markdown table row: `| Contact Email | someone@example.com |`
      if (line.trimLeft().startsWith('|')) {
        final cells = line
            .trim()
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();

        // `|---|---|` separators carry no content.
        if (cells.isEmpty ||
            cells.every((c) => _tableSeparator.hasMatch(c))) {
          continue;
        }

        if (cells.length == 1) {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: SelectableText(
              _plain(cells.first),
              style: const TextStyle(
                  color: NajmTheme.textSecondary, fontSize: 14, height: 1.55),
            ),
          ));
          continue;
        }

        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 132,
                child: Text(
                  _plain(cells.first),
                  style: const TextStyle(
                      color: NajmTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: SelectableText(
                  _plain(cells.skip(1).join(' · ')),
                  style: const TextStyle(
                      color: NajmTheme.textPrimary,
                      fontSize: 13.5,
                      height: 1.45),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final text = _plain(heading.group(2)!);
        widgets.add(Padding(
          padding: EdgeInsets.only(top: level == 1 ? 8 : 16, bottom: 6),
          child: Text(
            text,
            style: TextStyle(
              color: level <= 2 ? NajmTheme.gold : NajmTheme.textPrimary,
              fontSize: level == 1
                  ? 22
                  : level == 2
                      ? 18
                      : 15,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ));
        continue;
      }

      final bullet = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 3, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 10),
                child: Icon(Icons.circle, size: 5, color: NajmTheme.gold),
              ),
              Expanded(
                child: SelectableText(
                  _plain(bullet.group(1)!),
                  style: const TextStyle(
                      color: NajmTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ));
        continue;
      }

      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: SelectableText(
          _plain(line),
          style: const TextStyle(
              color: NajmTheme.textSecondary, fontSize: 14, height: 1.55),
        ),
      ));
    }
    return widgets;
  }

  static final _inlineLink = RegExp(r'\[([^\]]+)\]\((https?://[^)]+)\)');

  /// Strip the markdown markers we don't render. Inline links become
  /// "text (url)" — never the raw `[text](url)` syntax, which is what a
  /// legal document looked like before this existed.
  static String _plain(String s) => s
      .replaceAllMapped(_inlineLink, (m) => '${m[1]} (${m[2]})')
      .replaceAll('**', '')
      .replaceAll('`', '')
      .replaceAll('> ', '')
      .trim();
}
