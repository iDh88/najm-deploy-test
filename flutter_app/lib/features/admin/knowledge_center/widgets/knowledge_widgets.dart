import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme.dart';
import '../models/knowledge_models.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DOCUMENT CARD
// ══════════════════════════════════════════════════════════════════════════════

class DocumentCard extends StatelessWidget {
  final KnowledgeDocument document;
  final int index;
  final VoidCallback onTap;

  const DocumentCard({
    super.key, required this.document, required this.index, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CIPTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: document.isDisabled
                ? CIPTheme.textMuted.withOpacity(0.3)
                : CIPTheme.divider,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: CIPTheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(document.category.icon,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(document.name,
                        style: const TextStyle(
                            color: CIPTheme.textPrimary,
                            fontSize: 14, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  if (document.isDisabled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CIPTheme.textMuted.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('DISABLED',
                          style: TextStyle(
                              color: CIPTheme.textMuted,
                              fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 2),
                Text(document.category.label,
                    style: const TextStyle(
                        color: CIPTheme.primary, fontSize: 11,
                        fontWeight: FontWeight.w600)),
                if (document.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(document.description,
                      style: const TextStyle(
                          color: CIPTheme.textMuted, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: CIPTheme.textMuted, size: 18),
        ]),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 250.ms)
        .slideY(begin: 0.05, end: 0);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CATEGORY FILTER BAR
// ══════════════════════════════════════════════════════════════════════════════

class CategoryFilterBar extends StatelessWidget {
  final DocumentCategory? selected;
  final ValueChanged<DocumentCategory?> onChanged;

  const CategoryFilterBar({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _Chip(label: 'All', icon: '📚', active: selected == null,
              onTap: () => onChanged(null)),
          ...DocumentCategory.values.map((c) => _Chip(
            label: c.label, icon: c.icon, active: selected == c,
            onTap: () => onChanged(c),
          )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, icon;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.icon,
    required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: active ? CIPTheme.primary.withOpacity(0.15) : CIPTheme.navLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? CIPTheme.primary : CIPTheme.divider),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: active ? CIPTheme.primary : CIPTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// STATUS BADGE
// ══════════════════════════════════════════════════════════════════════════════

class StatusBadge extends StatelessWidget {
  final DocumentStatus status;
  const StatusBadge({super.key, required this.status});

  Color get _color {
    switch (status) {
      case DocumentStatus.active:     return CIPTheme.success;
      case DocumentStatus.processing: return CIPTheme.warning;
      case DocumentStatus.failed:     return CIPTheme.error;
      case DocumentStatus.archived:   return CIPTheme.textMuted;
      case DocumentStatus.disabled:   return CIPTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(status.emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        Text(status.label,
            style: TextStyle(
                color: _color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// VERSION TILE
// ══════════════════════════════════════════════════════════════════════════════

class VersionTile extends StatelessWidget {
  final DocumentVersion version;
  final bool isActive;
  final VoidCallback? onDownload;

  const VersionTile({
    super.key, required this.version, required this.isActive, this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? CIPTheme.primary.withOpacity(0.06) : CIPTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isActive
                ? CIPTheme.primary.withOpacity(0.35)
                : CIPTheme.divider),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? CIPTheme.primary.withOpacity(0.15)
                : CIPTheme.navLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('v${version.versionNumber}',
                style: TextStyle(
                    color: isActive ? CIPTheme.primary : CIPTheme.textMuted,
                    fontSize: 10, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(version.versionLabel,
                    style: const TextStyle(
                        color: CIPTheme.textPrimary,
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                StatusBadge(status: version.status),
              ]),
              const SizedBox(height: 2),
              Text(
                'Effective ${_fmt(version.effectiveDate)}'
                '${version.pageCount != null ? " · ${version.pageCount} pages" : ""}',
                style: const TextStyle(
                    color: CIPTheme.textMuted, fontSize: 11),
              ),
              if (version.processingError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Error: ${version.processingError}',
                      style: const TextStyle(
                          color: CIPTheme.error, fontSize: 10)),
                ),
            ],
          ),
        ),
        if (onDownload != null)
          IconButton(
            icon: const Icon(Icons.download_outlined,
                color: CIPTheme.textMuted, size: 18),
            onPressed: onDownload,
          ),
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ══════════════════════════════════════════════════════════════════════════════
// CHANGE SUMMARY CARD
// ══════════════════════════════════════════════════════════════════════════════

class ChangeSummaryCard extends StatelessWidget {
  final DocumentChangeSummary summary;
  const ChangeSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CIPTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Rev ${summary.oldVersionNumber} → Rev ${summary.newVersionNumber}',
                style: const TextStyle(
                    color: CIPTheme.primary,
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (summary.hasLegalityChanges) const _FlagTag('⚖️ Legality'),
            if (summary.hasFatigueChanges) const _FlagTag('🔋 Fatigue'),
            if (summary.hasRuleChanges) const _FlagTag('📏 Rule'),
          ]),
          const SizedBox(height: 8),
          Text(summary.overallSummary,
              style: const TextStyle(
                  color: CIPTheme.textSecondary, fontSize: 12, height: 1.5)),
          if (summary.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: CIPTheme.divider),
            const SizedBox(height: 10),
            ...summary.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.categoryEmoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.categoryLabel,
                            style: const TextStyle(
                                color: CIPTheme.textPrimary,
                                fontSize: 11, fontWeight: FontWeight.w700)),
                        Text(item.description,
                            style: const TextStyle(
                                color: CIPTheme.textSecondary,
                                fontSize: 11, height: 1.4)),
                        if (item.section != null)
                          Text('Section ${item.section}',
                              style: const TextStyle(
                                  color: CIPTheme.textMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _FlagTag extends StatelessWidget {
  final String label;
  const _FlagTag(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CIPTheme.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label,
          style: const TextStyle(
              color: CIPTheme.warning, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CITATION CARD (used in Ask Operations AI)
// ══════════════════════════════════════════════════════════════════════════════

class CitationCard extends StatelessWidget {
  final Citation citation;
  const CitationCard({super.key, required this.citation});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CIPTheme.navLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CIPTheme.divider),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.menu_book_outlined, color: CIPTheme.primary, size: 12),
        const SizedBox(width: 5),
        Text(citation.label,
            style: const TextStyle(
                color: CIPTheme.textSecondary, fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
