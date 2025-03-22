import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String profileImageUrl;
  final String bio;
  final String gender;
  final bool isSingle;
  final bool isAdmin;
  final List<String> followers;
  final List<String> following;
  final List<String> interests;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.profileImageUrl,
    required this.bio,
    required this.gender,
    required this.isSingle,
    required this.isAdmin,
    required this.followers,
    required this.following,
    required this.interests,
    this.createdAt,
  });

  // Much simpler and more defensive fromMap constructor
  factory UserModel.fromMap(Map<String, dynamic> map) {
    try {
      // Convert Timestamp to DateTime if present
      DateTime? createdAt;
      if (map['createdAt'] != null) {
        if (map['createdAt'] is Timestamp) {
          createdAt = (map['createdAt'] as Timestamp).toDate();
        }
      }

      // Handle lists safely
      List<String> followers = [];
      List<String> following = [];
      List<String> interests = [];

      if (map['followers'] is List) {
        followers = (map['followers'] as List).map((e) => e.toString()).toList();
      }

      if (map['following'] is List) {
        following = (map['following'] as List).map((e) => e.toString()).toList();
      }

      if (map['interests'] is List) {
        interests = (map['interests'] as List).map((e) => e.toString()).toList();
      }

      return UserModel(
        uid: map['uid'] ?? '',
        email: map['email'] ?? '',
        username: map['username'] ?? '',
        profileImageUrl: map['profileImageUrl'] ?? '',
        bio: map['bio'] ?? '',
        gender: map['gender'] ?? '',
        isSingle: map['isSingle'] ?? false,
        isAdmin: map['isAdmin'] ?? false,
        followers: followers,
        following: following,
        interests: interests,
        createdAt: createdAt,
      );
    } catch (e) {
      // Return a default user model in case of error
      return UserModel(
        uid: map['uid'] ?? '',
        email: map['email'] ?? '',
        username: map['username'] ?? '',
        profileImageUrl: '',
        bio: '',
        gender: '',
        isSingle: false,
        isAdmin: false,
        followers: [],
        following: [],
        interests: [],
        createdAt: null,
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'gender': gender,
      'isSingle': isSingle,
      'isAdmin': isAdmin,
      'followers': followers,
      'following': following,
      'interests': interests,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }
}