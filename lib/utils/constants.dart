import 'package:flutter/material.dart';

class AppConstants {
  // App info
  static const String appName = "PU Circle";
  static const String appVersion = "1.0.0";
  static const String appDescription = "Connect with students at PU";

  // Firebase collections
  static const String usersCollection = "users";
  static const String postsCollection = "posts";
  static const String matchesCollection = "matches";
  static const String chatsCollection = "chats";
  static const String messagesCollection = "messages";
  static const String notificationsCollection = "notifications";
  static const String reportsCollection = "reports";

  // Firebase storage paths
  static const String profileImagesPath = "profiles";
  static const String postImagesPath = "posts/images";
  static const String postVideosPath = "posts/videos";
  static const String chatImagesPath = "chats/images";

  // Admin constants
  static const String adminPasskey = "79770051419136567648";

  // Default values
  static const String defaultProfileImage = "assets/images/default_profile.png";
  static const String defaultPostPlaceholder =
      "assets/images/post_placeholder.png";

  // Message constants
  static const String predefinedMessage =
      "Wanna meet at PU Circle or on a tea post?";

  // Regular expressions for validation
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$', // At least 8 chars, 1 letter, 1 number
  );
  static final RegExp usernameRegex = RegExp(
    r'^[a-zA-Z0-9_]{3,20}$', // 3-20 characters, alphanumeric and underscore
  );

  // UI constants
  static const double defaultBorderRadius = 12.0;
  static const double smallBorderRadius = 8.0;
  static const double largeBorderRadius = 16.0;

  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  static const double defaultElevation = 2.0;
  static const double cardElevation = 4.0;

  static const double profileImageSize = 120.0;
  static const double avatarSize = 40.0;
  static const double smallAvatarSize = 32.0;

  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Gender options
  static const List<String> genderOptions = ["Male", "Female"];

  // Relationship status options
  static const List<String> relationshipOptions = ["Single", "Not Single"];

  // Report reasons
  static const List<String> reportReasons = [
    "Inappropriate content",
    "Fake profile",
    "Harassment",
    "Spam",
    "Other"
  ];

  // Max length constants
  static const int maxBioLength = 150;
  static const int maxCaptionLength = 500;
  static const int maxPostsPerPage = 10;
  static const int maxProfilesPerSearch = 20;
  static const int maxChatsPerPage = 30;

  // API timeout
  static const Duration apiTimeout = Duration(seconds: 15);
}
