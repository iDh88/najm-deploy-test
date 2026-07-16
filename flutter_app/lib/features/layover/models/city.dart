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
      name: d['name'] ?? '',
      country: d['country'] ?? '',
      airportCode: d['airportCode'] ?? '',
      heroImageUrl: d['heroImageUrl'],
      timezone: d['timezone'],
      recommendationCount: d['recommendationCount'] ?? 0,
      isActive: d['isActive'] ?? true,
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
      recommendationId: d['recommendationId'] ?? '',
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userRank: d['userRank'] ?? '',
      text: d['text'] ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDeleted: d['isDeleted'] ?? false,
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
