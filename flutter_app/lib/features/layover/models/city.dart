import 'package:cloud_firestore/cloud_firestore.dart';

class LayoverCity {
  final String id;
  final String name;
  final String country;
  final String airportCode;
  final String? heroImageUrl;
  final String? timezone;
  final int recommendationCount;
  final bool isActive;

  const LayoverCity({
    required this.id,
    required this.name,
    required this.country,
    required this.airportCode,
    this.heroImageUrl,
    this.timezone,
    required this.recommendationCount,
    required this.isActive,
  });

  factory LayoverCity.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LayoverCity(
      id: doc.id,
      name: d['name'] as String? ?? '',
      country: d['country'] as String? ?? '',
      airportCode: d['airportCode'] as String? ?? '',
      heroImageUrl: d['heroImageUrl'] as String?,
      timezone: d['timezone'] as String?,
      recommendationCount: d['recommendationCount'] as int? ?? 0,
      isActive: d['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'country': country,
    'airportCode': airportCode,
    'heroImageUrl': heroImageUrl,
    'timezone': timezone,
    'recommendationCount': recommendationCount,
    'isActive': isActive,
  };
}

class RecommendationComment {
  final String id;
  final String recommendationId;
  final String userId;
  final String userName;
  final String userRank;
  final String text;
  final DateTime createdAt;
  final bool isDeleted;

  const RecommendationComment({
    required this.id,
    required this.recommendationId,
    required this.userId,
    required this.userName,
    required this.userRank,
    required this.text,
    required this.createdAt,
    required this.isDeleted,
  });

  factory RecommendationComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecommendationComment(
      id: doc.id,
      recommendationId: d['recommendationId'] as String? ?? '',
      userId: d['userId'] as String? ?? '',
      userName: d['userName'] as String? ?? '',
      userRank: d['userRank'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: d['isDeleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'recommendationId': recommendationId,
    'userId': userId,
    'userName': userName,
    'userRank': userRank,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
    'isDeleted': isDeleted,
  };
}
