import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../models/recommendation.dart';
import '../services/layover_service.dart';

class RecommendationCard extends StatefulWidget {
  final Recommendation recommendation;
  final int index;
  final bool showAdminDelete;
  final VoidCallback? onAdminDelete;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.index = 0,
    this.showAdminDelete = false,
    this.onAdminDelete,
  });

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  final _service = LayoverService();
  bool? _isLiked;
  bool? _isSaved;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final liked = await _service.isLiked(widget.recommendation.id);
    final saved = await _service.isSaved(widget.recommendation.id);
    if (mounted) setState(() { _isLiked = liked; _isSaved = saved; });
  }

  Recommendation get rec => widget.recommendation;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/layover/rec/${rec.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: NajmTheme.navyCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo / Header ──────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: rec.photoUrls.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: rec.photoUrls.first,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 160,
                        color: NajmTheme.navyLight,
                        child: const Center(
                            child:
                                Icon(Icons.image, color: NajmTheme.textMuted)),
                      ),
                      errorWidget: (_, __, ___) => _NoPhotoHeader(rec: rec),
                    )
                  : _NoPhotoHeader(rec: rec),
            ),

            // ── Content ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges row
                  _BadgesRow(rec: rec),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    rec.name,
                    style: const TextStyle(
                      color: NajmTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    rec.description,
                    style: const TextStyle(
                      color: NajmTheme.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Rating
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: rec.rating,
                        itemBuilder: (_, __) =>
                            const Icon(Icons.star, color: NajmTheme.gold),
                        itemCount: 5,
                        itemSize: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        rec.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: NajmTheme.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' (${rec.ratingCount})',
                        style: const TextStyle(
                          color: NajmTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Address + time
                  if (rec.address != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            color: NajmTheme.textMuted, size: 13),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rec.address!,
                            style: const TextStyle(
                              color: NajmTheme.textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Actions row ─────────────────────────────
                  Row(
                    children: [
                      // Submitted by rank badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: NajmTheme.saudiGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: NajmTheme.saudiGreen.withOpacity(0.4)),
                        ),
                        child: Text(
                          rec.submittedByRank,
                          style: const TextStyle(
                            color: NajmTheme.saudiGreenLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeago.format(rec.createdAt),
                        style: const TextStyle(
                          color: NajmTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),

                      // Like
                      _ActionButton(
                        icon: _isLiked == true
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _isLiked == true
                            ? NajmTheme.error
                            : NajmTheme.textMuted,
                        count: rec.likeCount,
                        onTap: () async {
                          await _service.toggleLike(
                              rec.id, _isLiked ?? false);
                          setState(() => _isLiked = !(_isLiked ?? false));
                        },
                      ),
                      const SizedBox(width: 12),

                      // Save
                      _ActionButton(
                        icon: _isSaved == true
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: _isSaved == true
                            ? NajmTheme.gold
                            : NajmTheme.textMuted,
                        count: rec.saveCount,
                        onTap: () async {
                          await _service.toggleSave(
                              rec.id, _isSaved ?? false);
                          setState(() => _isSaved = !(_isSaved ?? false));
                        },
                      ),
                      const SizedBox(width: 12),

                      // Comment
                      _ActionButton(
                        icon: Icons.chat_bubble_outline,
                        color: NajmTheme.textMuted,
                        count: rec.commentCount,
                        onTap: () =>
                            context.push('/layover/rec/${rec.id}'),
                      ),

                      // Admin delete
                      if (widget.showAdminDelete) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: widget.onAdminDelete,
                          child: const Icon(Icons.delete_outline,
                              color: NajmTheme.error, size: 20),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _NoPhotoHeader extends StatelessWidget {
  final Recommendation rec;
  const _NoPhotoHeader({required this.rec});

  static const _catEmoji = {
    'restaurants': '🍽️',
    'coffee': '☕',
    'gyms': '💪',
    'prayer': '🕌',
    'transport': '🚕',
    'shopping': '🛍️',
    'attractions': '📸',
    'essentials': '🏥',
    'crew_fav': '⭐',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [NajmTheme.navyLight, NajmTheme.navyMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          _catEmoji[rec.category] ?? '📍',
          style: const TextStyle(fontSize: 48),
        ),
      ),
    );
  }
}

class _BadgesRow extends StatelessWidget {
  final Recommendation rec;
  const _BadgesRow({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (rec.isHalal)
          _Badge(label: '🟢 Halal',
              bg: NajmTheme.saudiGreen.withOpacity(0.15),
              border: NajmTheme.saudiGreen.withOpacity(0.4),
              text: NajmTheme.saudiGreenLight),
        if (rec.rating >= 4.5 && rec.ratingCount >= 5)
          _Badge(label: '⭐ Highly Rated',
              bg: NajmTheme.gold.withOpacity(0.12),
              border: NajmTheme.gold.withOpacity(0.4),
              text: NajmTheme.gold),
        if (rec.likeCount >= 10)
          _Badge(label: '🔥 Trending',
              bg: NajmTheme.warning.withOpacity(0.12),
              border: NajmTheme.warning.withOpacity(0.4),
              text: NajmTheme.warning),
        if (rec.ratingCount >= 10)
          _Badge(label: '✅ Crew Verified',
              bg: NajmTheme.info.withOpacity(0.12),
              border: NajmTheme.info.withOpacity(0.4),
              text: NajmTheme.info),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg, border, text;
  const _Badge({required this.label, required this.bg,
    required this.border, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(label,
          style: TextStyle(
              color: text, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 3),
          Text('$count',
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
