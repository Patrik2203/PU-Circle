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
  final List<String> interests; // ✅ Add this field
  final DateTime createdAt;

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
    required this.interests, // ✅ Add this field
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      bio: map['bio'] ?? '',
      gender: map['gender'] ?? 'male',
      isSingle: map['isSingle'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      interests: List<String>.from(map['interests'] ?? []), // ✅ Add this field
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
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
      'interests': interests, // ✅ Add this field
      'createdAt': createdAt,
    };
  }
}
