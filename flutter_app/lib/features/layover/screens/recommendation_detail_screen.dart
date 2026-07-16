import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_theme.dart';
import '../models/recommendation.dart';
import '../models/city.dart';
import '../services/layover_service.dart';
import '../services/auth_service.dart';
import '../widgets/recommendation_card.dart';

class RecommendationDetailScreen extends StatefulWidget {
  final String recId;
  const RecommendationDetailScreen({super.key, required this.recId});

  @override
  State<RecommendationDetailScreen> createState() =>
      _RecommendationDetailScreenState();
}

class _RecommendationDetailScreenState
    extends State<RecommendationDetailScreen> {
  final _service = LayoverService();
  final _auth = AuthService();
  final _commentCtrl = TextEditingController();
  bool _isLiked = false;
  bool _isSaved = false;
  double? _myRating;
  bool _submittingComment = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    if (widget.recId.isEmpty) return;
    final liked = await _service.isLiked(widget.recId);
    final saved = await _service.isSaved(widget.recId);
    if (mounted) setState(() { _isLiked = liked; _isSaved = saved; });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Recommendation?>(
      future: _service.getRecommendation(widget.recId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: NajmTheme.navy,
            body: Center(
                child: CircularProgressIndicator(color: NajmTheme.gold)),
          );
        }
        final rec = snap.data;
        if (rec == null) {
          return Scaffold(
            backgroundColor: NajmTheme.navy,
            appBar: AppBar(backgroundColor: NajmTheme.navyMid),
            body: const Center(
              child: Text('Recommendation not found',
                  style: TextStyle(color: NajmTheme.textSecondary)),
            ),
          );
        }
        return _buildDetail(context, rec);
      },
    );
  }

  Widget _buildDetail(BuildContext context, Recommendation rec) {
    final user = _auth.currentUser;
    final isAdmin = user != null && _auth.isAdmin(user.email ?? '');

    return Scaffold(
      backgroundColor: NajmTheme.navy,
      body: CustomScrollView(
        slivers: [
          // ── Photo gallery app bar ─────────────────────────
          SliverAppBar(
            expandedHeight: rec.photoUrls.isNotEmpty ? 280 : 160,
            pinned: true,
            backgroundColor: NajmTheme.navyMid,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: NajmTheme.textPrimary),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Admin delete
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: NajmTheme.error),
                  onPressed: () => _confirmAdminDelete(context, rec),
                  tooltip: 'Admin Delete',
                ),
              // Save
              IconButton(
                icon: Icon(
                  _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: _isSaved ? NajmTheme.gold : NajmTheme.textPrimary,
                ),
                onPressed: () async {
                  await _service.toggleSave(rec.id, _isSaved);
                  setState(() => _isSaved = !_isSaved);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: rec.photoUrls.isNotEmpty
                  ? _PhotoGallery(photoUrls: rec.photoUrls)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [NajmTheme.navyLight, NajmTheme.navy],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Badges ─────────────────────────────────
                  _BadgesRow(rec: rec),
                  const SizedBox(height: 12),

                  // ── Name ───────────────────────────────────
                  Text(rec.name,
                      style: const TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 6),

                  // ── Rating row ─────────────────────────────
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: rec.rating,
                        itemBuilder: (_, __) =>
                            const Icon(Icons.star, color: NajmTheme.gold),
                        itemCount: 5,
                        itemSize: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${rec.rating.toStringAsFixed(1)} · ${rec.ratingCount} reviews',
                        style: const TextStyle(
                            color: NajmTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Description ────────────────────────────
                  Text(rec.description,
                      style: const TextStyle(
                          color: NajmTheme.textSecondary,
                          fontSize: 15,
                          height: 1.6)),
                  const SizedBox(height: 16),

                  // ── Address + Maps ─────────────────────────
                  if (rec.address != null || rec.latitude != null)
                    _LocationCard(rec: rec),
                  const SizedBox(height: 16),

                  // ── Crew Notes ─────────────────────────────
                  if (rec.notes != null && rec.notes!.isNotEmpty)
                    _CrewNotesCard(notes: rec.notes!),
                  const SizedBox(height: 20),

                  // ── Like / Actions ─────────────────────────
                  _ActionsRow(
                    rec: rec,
                    isLiked: _isLiked,
                    isSaved: _isSaved,
                    onLike: () async {
                      await _service.toggleLike(rec.id, _isLiked);
                      setState(() => _isLiked = !_isLiked);
                    },
                    onSave: () async {
                      await _service.toggleSave(rec.id, _isSaved);
                      setState(() => _isSaved = !_isSaved);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Rate this place ────────────────────────
                  _RatingSection(
                    myRating: _myRating,
                    onRate: (r) async {
                      setState(() => _myRating = r);
                      await _service.rateRecommendation(rec.id, r);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Submitted by ───────────────────────────
                  _SubmittedBy(rec: rec),
                  const SizedBox(height: 24),

                  // ── Comments ───────────────────────────────
                  const Text('Comments',
                      style: TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 12),
                  _CommentInput(
                    controller: _commentCtrl,
                    submitting: _submittingComment,
                    onSubmit: () => _submitComment(rec),
                  ),
                  const SizedBox(height: 16),
                  _CommentsList(
                    recId: rec.id,
                    service: _service,
                    isAdmin: isAdmin,
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComment(Recommendation rec) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submittingComment = true);
    try {
      await _service.addComment(
        recId: rec.id,
        text: text,
        userName: 'Crew Member',
        userRank: 'CA',
      );
      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: NajmTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  Future<void> _confirmAdminDelete(
      BuildContext context, Recommendation rec) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: NajmTheme.navyMid,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Recommendation',
            style: TextStyle(color: NajmTheme.textPrimary)),
        content: Text(
          'Are you sure you want to delete "${rec.name}"? This action cannot be undone.',
          style: const TextStyle(color: NajmTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: NajmTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: NajmTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.adminDeleteRecommendation(rec.id);
      if (mounted) context.pop();
    }
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _PhotoGallery extends StatefulWidget {
  final List<String> photoUrls;
  const _PhotoGallery({required this.photoUrls});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          itemCount: widget.photoUrls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openFullScreen(context, i),
            child: CachedNetworkImage(
              imageUrl: widget.photoUrls[i],
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (widget.photoUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.photoUrls.length,
                (i) => Container(
                  width: i == _current ? 20 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _current
                        ? NajmTheme.gold
                        : NajmTheme.textMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: PhotoViewGallery.builder(
            itemCount: widget.photoUrls.length,
            pageController:
                PageController(initialPage: initialIndex),
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider:
                  CachedNetworkImageProvider(widget.photoUrls[i]),
              minScale: PhotoViewComputedScale.contained,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Recommendation rec;
  const _LocationCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NajmTheme.navyLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rec.address != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.place, color: NajmTheme.gold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(rec.address!,
                      style: const TextStyle(
                          color: NajmTheme.textPrimary, fontSize: 14)),
                ),
              ],
            ),
          if (rec.latitude != null && rec.longitude != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMaps(rec),
                    icon: const Icon(Icons.map_outlined, size: 16),
                    label: const Text('Open in Maps'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _getDirections(rec),
                    icon: const Icon(Icons.directions, size: 16),
                    label: const Text('Directions'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openMaps(Recommendation rec) {
    final url =
        'https://www.google.com/maps/search/?api=1&query=${rec.latitude},${rec.longitude}';
    launchUrl(Uri.parse(url));
  }

  void _getDirections(Recommendation rec) {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${rec.latitude},${rec.longitude}';
    launchUrl(Uri.parse(url));
  }
}

class _CrewNotesCard extends StatelessWidget {
  final String notes;
  const _CrewNotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NajmTheme.gold.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NajmTheme.gold.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📝', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Crew Notes',
                    style: TextStyle(
                      color: NajmTheme.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    )),
                const SizedBox(height: 4),
                Text(notes,
                    style: const TextStyle(
                        color: NajmTheme.textPrimary,
                        fontSize: 14,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  final Recommendation rec;
  final bool isLiked, isSaved;
  final VoidCallback onLike, onSave;

  const _ActionsRow({
    required this.rec,
    required this.isLiked,
    required this.isSaved,
    required this.onLike,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: NajmTheme.navyLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NajmTheme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionBtn(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: '${rec.likeCount}',
            color: isLiked ? NajmTheme.error : NajmTheme.textMuted,
            onTap: onLike,
          ),
          _ActionBtn(
            icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
            label: '${rec.saveCount}',
            color: isSaved ? NajmTheme.gold : NajmTheme.textMuted,
            onTap: onSave,
          ),
          _ActionBtn(
            icon: Icons.chat_bubble_outline,
            label: '${rec.commentCount}',
            color: NajmTheme.textMuted,
            onTap: () {},
          ),
          _ActionBtn(
            icon: Icons.share_outlined,
            label: 'Share',
            color: NajmTheme.textMuted,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RatingSection extends StatelessWidget {
  final double? myRating;
  final ValueChanged<double> onRate;
  const _RatingSection({required this.myRating, required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rate This Place',
            style: TextStyle(
                color: NajmTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        RatingBar.builder(
          initialRating: myRating ?? 0,
          minRating: 1,
          itemCount: 5,
          itemSize: 36,
          itemBuilder: (_, __) =>
              const Icon(Icons.star, color: NajmTheme.gold),
          onRatingUpdate: onRate,
        ),
      ],
    );
  }
}

class _SubmittedBy extends StatelessWidget {
  final Recommendation rec;
  const _SubmittedBy({required this.rec});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: NajmTheme.saudiGreen.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: NajmTheme.saudiGreen.withOpacity(0.4)),
          ),
          child: Center(
            child: Text(
              rec.submittedByRank,
              style: const TextStyle(
                  color: NajmTheme.saudiGreenLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rec.submittedByName,
                style: const TextStyle(
                    color: NajmTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Text(
              'Submitted ${timeago.format(rec.createdAt)}',
              style: const TextStyle(
                  color: NajmTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _CommentInput(
      {required this.controller,
      required this.submitting,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(
                color: NajmTheme.textPrimary, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Add a comment…',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: submitting ? null : onSubmit,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: NajmTheme.goldGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: NajmTheme.navy))
                : const Icon(Icons.send,
                    color: NajmTheme.navy, size: 18),
          ),
        ),
      ],
    );
  }
}

class _CommentsList extends StatelessWidget {
  final String recId;
  final LayoverService service;
  final bool isAdmin;

  const _CommentsList(
      {required this.recId,
      required this.service,
      required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RecommendationComment>>(
      stream: service.commentsStream(recId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child:
                CircularProgressIndicator(color: NajmTheme.gold),
          ));
        }
        final comments = snap.data ?? [];
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No comments yet. Be the first!',
                  style: TextStyle(
                      color: NajmTheme.textMuted, fontSize: 13)),
            ),
          );
        }
        return Column(
          children: comments.map((c) => _CommentTile(
                comment: c,
                isAdmin: isAdmin,
                onDelete: isAdmin
                    ? () => service.adminDeleteComment(c.id)
                    : null,
              )).toList(),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final RecommendationComment comment;
  final bool isAdmin;
  final VoidCallback? onDelete;

  const _CommentTile(
      {required this.comment,
      required this.isAdmin,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: NajmTheme.navyLight,
              shape: BoxShape.circle,
              border: Border.all(color: NajmTheme.cardBorder),
            ),
            child: Center(
              child: Text(
                comment.userRank,
                style: const TextStyle(
                    color: NajmTheme.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: NajmTheme.navyLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NajmTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(comment.userName,
                          style: const TextStyle(
                              color: NajmTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(timeago.format(comment.createdAt),
                          style: const TextStyle(
                              color: NajmTheme.textMuted, fontSize: 11)),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(Icons.delete_outline,
                              color: NajmTheme.error, size: 16),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment.text,
                      style: const TextStyle(
                          color: NajmTheme.textSecondary,
                          fontSize: 13,
                          height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _BadgesRow extends StatelessWidget {
  final dynamic rec;
  const _BadgesRow({required this.rec});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if ((rec.category ?? '').toString().isNotEmpty) rec.category.toString(),
      if ((rec.priceRange ?? '').toString().isNotEmpty) rec.priceRange.toString(),
      if (rec.isVerified == true) 'Verified',
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips.map((label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: NajmTheme.navyLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: NajmTheme.cardBorder),
        ),
        child: Text(label, style: const TextStyle(
          color: NajmTheme.gold,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        )),
      )).toList(),
    );
  }
}
