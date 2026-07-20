import 'package:cloud_firestore/cloud_firestore.dart';

class Recommendation {
  final String id;
  final String cityId;
  final String category;
  final String name;
  final String description;
  final String? notes;
  final List<String> photoUrls;
  final double? latitude;
  final double? longitude;
  final String? address;
  final bool isHalal;
  final double rating;
  final int ratingCount;
  final int likeCount;
  final int saveCount;
  final int commentCount;
  final String submittedBy;       // userId
  final String submittedByRank;
  final String submittedByName;
  final DateTime createdAt;
  final bool isApproved;
  final bool isDeleted;           // soft-delete by admin

  const Recommendation({
    required this.id,
    required this.cityId,
    required this.category,
    required this.name,
    required this.description,
    this.notes,
    required this.photoUrls,
    this.latitude,
    this.longitude,
    this.address,
    required this.isHalal,
    required this.rating,
    required this.ratingCount,
    required this.likeCount,
    required this.saveCount,
    required this.commentCount,
    required this.submittedBy,
    required this.submittedByRank,
    required this.submittedByName,
    required this.createdAt,
    required this.isApproved,
    required this.isDeleted,
  });

  factory Recommendation.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Recommendation(
      id: doc.id,
      cityId: d['cityId'] as String? ?? '',
      category: d['category'] as String? ?? '',
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      notes: d['notes'] as String?,
      photoUrls: List<String>.from(d['photoUrls'] as List? ?? []),
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      address: d['address'] as String?,
      isHalal: d['isHalal'] as bool? ?? false,
      rating: (d['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: d['ratingCount'] as int? ?? 0,
      likeCount: d['likeCount'] as int? ?? 0,
      saveCount: d['saveCount'] as int? ?? 0,
      commentCount: d['commentCount'] as int? ?? 0,
      submittedBy: d['submittedBy'] as String? ?? '',
      submittedByRank: d['submittedByRank'] as String? ?? '',
      submittedByName: d['submittedByName'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isApproved: d['isApproved'] as bool? ?? false,
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'cityId': cityId,
    'category': category,
    'name': name,
    'description': description,
    'notes': notes,
    'photoUrls': photoUrls,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'isHalal': isHalal,
    'rating': rating,
    'ratingCount': ratingCount,
    'likeCount': likeCount,
    'saveCount': saveCount,
    'commentCount': commentCount,
    'submittedBy': submittedBy,
    'submittedByRank': submittedByRank,
    'submittedByName': submittedByName,
    'createdAt': Timestamp.fromDate(createdAt),
    'isApproved': isApproved,
    'isDeleted': isDeleted,
  };

  Recommendation copyWith({
    bool? isDeleted,
    bool? isApproved,
    double? rating,
    int? ratingCount,
    int? likeCount,
    int? saveCount,
    int? commentCount,
  }) {
    return Recommendation(
      id: id,
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
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      likeCount: likeCount ?? this.likeCount,
      saveCount: saveCount ?? this.saveCount,
      commentCount: commentCount ?? this.commentCount,
      submittedBy: submittedBy,
      submittedByRank: submittedByRank,
      submittedByName: submittedByName,
      createdAt: createdAt,
      isApproved: isApproved ?? this.isApproved,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
