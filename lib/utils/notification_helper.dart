import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../firebase/messaging_service.dart';
import '../models/notification_model.dart';
import '../firebase/notification_service.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/home/post_detail_screen.dart';
import '../screens/match/match_detail_screen.dart';
import '../screens/messaging/chat_screen.dart';

class NotificationHelper {
  static final NotificationService _notificationService = NotificationService();

  // Handle notification tap based on notification type
  static Future<void> handleNotificationTap(
      BuildContext context,
      NotificationModel notification,
      ) async {
    // Mark notification as read
    await _notificationService.markNotificationAsRead(notification.id);

    // Navigate based on notification type
    switch (notification.type) {
      case 'follow':
      // Navigate to profile screen
        _navigateToProfile(context, notification.senderId);
        break;

      case 'like':
      // Navigate to post detail
        if (notification.postId != null) {
          _navigateToPost(context, notification.postId!);
        }
        break;

      case 'match':
      case 'algorithmMatch':
      // Navigate to match detail
        if (notification.matchId != null) {
          _navigateToMatch(context, notification.matchId!);
        }
        break;

      case 'message':
      // Navigate to chat
        _navigateToChat(context, notification.senderId);
        break;

      default:
        break;
    }
  }

  // Helper navigation methods
  static void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  static Future<void> _navigateToPost(BuildContext context, String postId) async {
    // First fetch the post data
    final post = await FirestoreService().getPost(postId);
    if (post != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(post: post),
        ),
      );
    }
  }

  static Future<void> _navigateToMatch(BuildContext context, String matchId) async {
    // First fetch the matched user
    final matchedUser = await AuthService().getUserData(matchId);
    if (matchedUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchDetailScreen(matchedUser: matchedUser),
        ),
      );
    }
  }

  static Future<void> _navigateToChat(BuildContext context, String userId) async {
    // First fetch the user and find/create chatId
    final otherUser = await AuthService().getUserData(userId);
    final chatId = await MessagingService().getChatIdForUsers(
        FirebaseAuth.instance.currentUser!.uid,
        userId
    );

    if (otherUser != null && chatId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: chatId,
            otherUser: otherUser,
          ),
        ),
      );
    }
  }
}