import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String type; // 'follow', 'like', 'match', 'algorithmMatch'
  final String senderId;
  final String receiverId;
  final String? postId;
  final String? matchId;
  final DateTime timestamp;
  final bool isRead;

  NotificationModel({
    required this.id,
    required this.type,
    required this.senderId,
    required this.receiverId,
    this.postId,
    this.matchId,
    required this.timestamp,
    this.isRead = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      type: map['type'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      postId: map['postId'],
      matchId: map['matchId'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'senderId': senderId,
      'receiverId': receiverId,
      'postId': postId,
      'matchId': matchId,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }
}