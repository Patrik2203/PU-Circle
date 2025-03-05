import 'package:cloud_firestore/cloud_firestore.dart';

class MatchModel {
  final String matchId;
  final String user1Id;
  final String user2Id;
  final DateTime matchedAt;
  final bool isAlgorithmMatched;

  MatchModel({
    required this.matchId,
    required this.user1Id,
    required this.user2Id,
    required this.matchedAt,
    required this.isAlgorithmMatched,
  });

  factory MatchModel.fromMap(Map<String, dynamic> map) {
    return MatchModel(
      matchId: map['matchId'] ?? '',
      user1Id: map['user1Id'] ?? '',
      user2Id: map['user2Id'] ?? '',
      matchedAt: (map['matchedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isAlgorithmMatched: map['isAlgorithmMatched'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'user1Id': user1Id,
      'user2Id': user2Id,
      'matchedAt': matchedAt,
      'isAlgorithmMatched': isAlgorithmMatched,
    };
  }
}