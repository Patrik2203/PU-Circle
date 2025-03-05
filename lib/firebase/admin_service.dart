import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';
import '../models/report_model.dart';
import 'notification_service.dart';

class AdminService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Check if current user is an admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      DocumentSnapshot doc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!doc.exists) {
        return false;
      }

      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      return userData['isAdmin'] == true;
    } catch (e) {
      return false;
    }
  }

  // Get all users
  Future<List<UserModel>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      // Delete user's posts
      QuerySnapshot postSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      for (var doc in postSnapshot.docs) {
        await _firestore.collection('posts').doc(doc.id).delete();
      }

      // Delete user's matches
      QuerySnapshot matchesSnapshot = await _firestore
          .collection('matches')
          .where('userId1', isEqualTo: userId)
          .get();

      for (var doc in matchesSnapshot.docs) {
        await _firestore.collection('matches').doc(doc.id).delete();
      }

      matchesSnapshot = await _firestore
          .collection('matches')
          .where('userId2', isEqualTo: userId)
          .get();

      for (var doc in matchesSnapshot.docs) {
        await _firestore.collection('matches').doc(doc.id).delete();
      }

      // Delete user's chats
      QuerySnapshot chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .get();

      for (var doc in chatsSnapshot.docs) {
        await _firestore.collection('chats').doc(doc.id).delete();
      }

      // Finally delete the user document
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get all posts
  Future<List<PostModel>> getAllPosts() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('posts').get();
      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get all reports
  Future<List<ReportModel>> getAllReports() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('reports').get();
      return snapshot.docs
          .map((doc) => ReportModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Handle report (approve or reject)
  Future<void> handleReport(String reportId, String status) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': status,
        'handledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Manual match two users
  Future<void> manuallyMatchUsers(String userId1, String userId2) async {
    try {
      // Create a match document
      await _firestore.collection('matches').add({
        'userId1': userId1,
        'userId2': userId2,
        'matchedByAdmin': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Notify both users
      await _notificationService.sendMatchNotification(
        userId1,
        userId2,
        'You have a new match! Our algorithm matched you with someone special.',
      );

      await _notificationService.sendMatchNotification(
        userId2,
        userId1,
        'You have a new match! Our algorithm matched you with someone special.',
      );
    } catch (e) {
      rethrow;
    }
  }

  // Get admin statistics
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      int userCount = 0;
      int postCount = 0;
      int matchCount = 0;
      int reportCount = 0;

      // Get user count
      QuerySnapshot userSnapshot = await _firestore.collection('users').get();
      userCount = userSnapshot.docs.length;

      // Get post count
      QuerySnapshot postSnapshot = await _firestore.collection('posts').get();
      postCount = postSnapshot.docs.length;

      // Get match count
      QuerySnapshot matchSnapshot = await _firestore.collection('matches').get();
      matchCount = matchSnapshot.docs.length;

      // Get report count
      QuerySnapshot reportSnapshot = await _firestore.collection('reports').get();
      reportCount = reportSnapshot.docs.length;

      return {
        'userCount': userCount,
        'postCount': postCount,
        'matchCount': matchCount,
        'reportCount': reportCount,
      };
    } catch (e) {
      rethrow;
    }
  }
}