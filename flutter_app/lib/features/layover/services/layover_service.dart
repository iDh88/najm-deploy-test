import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/recommendation.dart';
import '../models/city.dart';
import '../../../core/utils/content_filter.dart';

class LayoverService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  // ── Cities ────────────────────────────────────────────────
  Stream<List<LayoverCity>> citiesStream() {
    return _db
        .collection('cities')
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map(LayoverCity.fromFirestore).toList());
  }

  Future<LayoverCity?> getCity(String cityId) async {
    final doc = await _db.collection('cities').doc(cityId).get();
    if (!doc.exists) return null;
    return LayoverCity.fromFirestore(doc);
  }

  // ── Recommendations ───────────────────────────────────────
  Stream<List<Recommendation>> recommendationsStream({
    required String cityId,
    String? category,
    bool halalOnly = false,
    String sortBy = 'Trending',
  }) {
    Query query = _db
        .collection('recommendations')
        .where('cityId', isEqualTo: cityId)
        .where('isDeleted', isEqualTo: false)
        .where('isApproved', isEqualTo: true);

    if (category != null && category != 'all') {
      query = query.where('category', isEqualTo: category);
    }
    if (halalOnly) {
      query = query.where('isHalal', isEqualTo: true);
    }

    switch (sortBy) {
      case 'Top Rated':
        query = query.orderBy('rating', descending: true);
        break;
      case 'Newest':
        query = query.orderBy('createdAt', descending: true);
        break;
      case 'Most Saved':
        query = query.orderBy('saveCount', descending: true);
        break;
      default: // Trending = weighted score
        query = query.orderBy('likeCount', descending: true);
    }

    return query.snapshots().map(
      (s) => s.docs.map(Recommendation.fromFirestore).toList(),
    );
  }

  Future<Recommendation?> getRecommendation(String id) async {
    final doc = await _db.collection('recommendations').doc(id).get();
    if (!doc.exists) return null;
    return Recommendation.fromFirestore(doc);
  }

  /// Submit a new recommendation — runs content filter before saving.
  Future<String> submitRecommendation({
    required String cityId,
    required String category,
    required String name,
    required String description,
    String? notes,
    List<File> photos = const [],
    double? latitude,
    double? longitude,
    String? address,
    required bool isHalal,
    required String submitterRank,
    required String submitterName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Content filter
    final blocked = ContentFilter.blockedReason(
      name: name,
      description: description,
      category: category,
      notes: notes,
    );
    if (blocked != null) {
      throw ContentBlockedException(
        'This recommendation contains content that is not permitted on Najm. '
        'Please remove references to: $blocked',
      );
    }

    // Upload photos
    final photoUrls = <String>[];
    for (final file in photos) {
      final ref = _storage
          .ref()
          .child('recommendations/${_uuid.v4()}.jpg');
      await ref.putFile(file);
      photoUrls.add(await ref.getDownloadURL());
    }

    final docRef = _db.collection('recommendations').doc();
    final rec = Recommendation(
      id: docRef.id,
      cityId: cityId,
      category: category,
      name: name,
      description: description,
      notes: notes,
      photoUrls: photoUrls,
      latitude: latitude,
      longitude: longitude,
      address: address,
      isHalal: isHalal,
      rating: 0,
      ratingCount: 0,
      likeCount: 0,
      saveCount: 0,
      commentCount: 0,
      submittedBy: user.uid,
      submittedByRank: submitterRank,
      submittedByName: submitterName,
      createdAt: DateTime.now(),
      isApproved: true, // auto-approve; admin can delete
      isDeleted: false,
    );

    await docRef.set(rec.toMap());
    // Increment city counter
    await _db.collection('cities').doc(cityId).update({
      'recommendationCount': FieldValue.increment(1),
    });

    return docRef.id;
  }

  // ── Like / Save ────────────────────────────────────────────
  Future<void> toggleLike(String recId, bool currentlyLiked) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _db.batch();
    final recRef = _db.collection('recommendations').doc(recId);
    final likeRef = _db
        .collection('userLikes')
        .doc('${user.uid}_$recId');

    if (currentlyLiked) {
      batch.delete(likeRef);
      batch.update(recRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {
        'userId': user.uid,
        'recId': recId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(recRef, {'likeCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<void> toggleSave(String recId, bool currentlySaved) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _db.batch();
    final recRef = _db.collection('recommendations').doc(recId);
    final saveRef = _db
        .collection('userSaves')
        .doc('${user.uid}_$recId');

    if (currentlySaved) {
      batch.delete(saveRef);
      batch.update(recRef, {'saveCount': FieldValue.increment(-1)});
    } else {
      batch.set(saveRef, {
        'userId': user.uid,
        'recId': recId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(recRef, {'saveCount': FieldValue.increment(1)});
    }
    await batch.commit();
  }

  Future<bool> isLiked(String recId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db
        .collection('userLikes')
        .doc('${user.uid}_$recId')
        .get();
    return doc.exists;
  }

  Future<bool> isSaved(String recId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _db
        .collection('userSaves')
        .doc('${user.uid}_$recId')
        .get();
    return doc.exists;
  }

  /// F30 — all recommendations the current user has bookmarked, newest
  /// save first. Backs the Saved Places screen.
  ///
  /// Reads `userSaves` (owner-listable via the `resource.data.userId`
  /// rules clause + composite index userId ASC / createdAt DESC), then
  /// resolves each referenced recommendation. Saves pointing at deleted
  /// or since-unapproved recommendations are silently dropped rather
  /// than surfaced as errors.
  Future<List<Recommendation>> getSavedRecommendations() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final saves = await _db
        .collection('userSaves')
        .where('userId', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true)
        .get();
    if (saves.docs.isEmpty) return [];

    final recIds = saves.docs
        .map((d) => (d.data()['recId'] ?? '') as String)
        .where((id) => id.isNotEmpty)
        .toList();

    final snaps = await Future.wait(
      recIds.map((id) => _db.collection('recommendations').doc(id).get()),
    );

    return snaps
        .where((s) =>
            s.exists &&
            (s.data()?['isDeleted'] ?? false) == false &&
            (s.data()?['isApproved'] ?? true) == true)
        .map(Recommendation.fromFirestore)
        .toList();
  }

  // ── Rating ─────────────────────────────────────────────────
  Future<void> rateRecommendation(String recId, double newRating) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ratingRef = _db
        .collection('userRatings')
        .doc('${user.uid}_$recId');
    final recRef = _db.collection('recommendations').doc(recId);

    await _db.runTransaction((tx) async {
      final recDoc = await tx.get(recRef);
      final ratingDoc = await tx.get(ratingRef);
      final rec = Recommendation.fromFirestore(recDoc);

      double totalRating = rec.rating * rec.ratingCount;
      int count = rec.ratingCount;

      if (ratingDoc.exists) {
        final oldRating = (ratingDoc.data()!['rating'] as num).toDouble();
        totalRating = totalRating - oldRating + newRating;
      } else {
        totalRating += newRating;
        count++;
      }

      final avgRating = count > 0 ? totalRating / count : 0.0;

      tx.set(ratingRef, {
        'userId': user.uid,
        'recId': recId,
        'rating': newRating,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(recRef, {
        'rating': avgRating,
        'ratingCount': count,
      });
    });
  }

  // ── Comments ───────────────────────────────────────────────
  Stream<List<RecommendationComment>> commentsStream(String recId) {
    return _db
        .collection('comments')
        .where('recommendationId', isEqualTo: recId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(RecommendationComment.fromFirestore).toList());
  }

  Future<void> addComment({
    required String recId,
    required String text,
    required String userName,
    required String userRank,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (!ContentFilter.isAllowed(text)) {
      throw ContentBlockedException(
          'Comment contains content that is not permitted.');
    }

    final batch = _db.batch();
    final commentRef = _db.collection('comments').doc();
    batch.set(commentRef, RecommendationComment(
      id: commentRef.id,
      recommendationId: recId,
      userId: user.uid,
      userName: userName,
      userRank: userRank,
      text: text,
      createdAt: DateTime.now(),
      isDeleted: false,
    ).toMap());
    batch.update(
      _db.collection('recommendations').doc(recId),
      {'commentCount': FieldValue.increment(1)},
    );
    await batch.commit();
  }

  // ── Admin: soft-delete ─────────────────────────────────────
  Future<void> adminDeleteRecommendation(String recId) async {
    await _db.collection('recommendations').doc(recId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> adminDeleteComment(String commentId) async {
    await _db.collection('comments').doc(commentId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Pending (admin review queue) ───────────────────────────
  Stream<List<Recommendation>> pendingRecommendationsStream() {
    return _db
        .collection('recommendations')
        .where('isApproved', isEqualTo: false)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Recommendation.fromFirestore).toList());
  }
}

class ContentBlockedException implements Exception {
  final String message;
  ContentBlockedException(this.message);
  @override
  String toString() => message;
}
