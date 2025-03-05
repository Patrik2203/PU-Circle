import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String userId;
  final String username;
  final String userProfileImageUrl;
  final String mediaUrl;
  final bool isVideo;
  final String caption;
  final List<String> likes;
  final DateTime createdAt;

  PostModel({
    required this.postId,
    required this.userId,
    required this.username,
    required this.userProfileImageUrl,
    required this.mediaUrl,
    required this.isVideo,
    required this.caption,
    required this.likes,
    required this.createdAt,
  });

  factory PostModel.fromMap(Map<String, dynamic> map) {
    return PostModel(
      postId: map['postId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      userProfileImageUrl: map['userProfileImageUrl'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      isVideo: map['isVideo'] ?? false,
      caption: map['caption'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'userId': userId,
      'username': username,
      'userProfileImageUrl': userProfileImageUrl,
      'mediaUrl': mediaUrl,
      'isVideo': isVideo,
      'caption': caption,
      'likes': likes,
      'createdAt': createdAt,
    };
  }
}