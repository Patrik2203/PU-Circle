import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/match_model.dart';
import 'notification_service.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get potential matches for a user

  Future<List<UserModel>> getPotentialMatches(
      String userId, {
        DocumentSnapshot? lastDocument,
        int limit = 10,
      }) async {
    try {
      // Get current user data to check gender preference
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      UserModel currentUser = UserModel.fromMap(userDoc.data() as Map<String, dynamic>);

      // Get rejected users that are still within the 5-day period
      QuerySnapshot rejectedSnapshot = await _firestore
          .collection('rejections')
          .where('rejectorId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(DateTime.now()))
          .get();

      List<String> rejectedUserIds = rejectedSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['rejectedId'] as String)
          .toList();

      // Get users the current user has already liked or matched with
      QuerySnapshot likedSnapshot = await _firestore
          .collection('likes')
          .where('likerId', isEqualTo: userId)
          .get();

      List<String> likedUserIds = likedSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['likedId'] as String)
          .toList();

      // Get matches
      QuerySnapshot matchesSnapshot1 = await _firestore
          .collection('matches')
          .where('userId1', isEqualTo: userId)
          .get();

      QuerySnapshot matchesSnapshot2 = await _firestore
          .collection('matches')
          .where('userId2', isEqualTo: userId)
          .get();

      List<String> matchedUserIds = [];
      for (var doc in matchesSnapshot1.docs) {
        matchedUserIds.add((doc.data() as Map<String, dynamic>)['userId2'] as String);
      }
      for (var doc in matchesSnapshot2.docs) {
        matchedUserIds.add((doc.data() as Map<String, dynamic>)['userId1'] as String);
      }

      // Combine all IDs to exclude
      List<String> excludedUserIds = [
        userId,
        ...likedUserIds,
        ...matchedUserIds,
        ...rejectedUserIds,
      ];

      // Base query
      Query usersQuery = _firestore
          .collection('users')
          .where('gender', isNotEqualTo: currentUser.gender)
          .orderBy('gender')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // Apply pagination if last document provided
      if (lastDocument != null) {
        usersQuery = usersQuery.startAfterDocument(lastDocument);
      }

      // Execute query
      QuerySnapshot usersSnapshot = await usersQuery.get();

      // Filter out excluded users
      List<UserModel> potentialMatches = [];

      for (var doc in usersSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;

        // Add to results only if not in excluded list
        if (!excludedUserIds.contains(doc.id)) {
          potentialMatches.add(UserModel.fromMap(data));
        }
      }

      return potentialMatches;
    } catch (e) {
      rethrow;
    }
  }

  // Like a user
  Future<bool> likeUser(String likerId, String likedId) async {
    try {
      // Record the like
      await _firestore.collection('likes').add({
        'likerId': likerId,
        'likedId': likedId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Check if the other user also liked this user (mutual like)
      QuerySnapshot mutualLikeSnapshot = await _firestore
          .collection('likes')
          .where('likerId', isEqualTo: likedId)
          .where('likedId', isEqualTo: likerId)
          .get();

      // If mutual like found, create a match
      if (mutualLikeSnapshot.docs.isNotEmpty) {
        await createMatch(likerId, likedId);
        return true; // It's a match
      }

      return false; // No match yet
    } catch (e) {
      rethrow;
    }
  }

  // Create a match between two users
  Future<void> createMatch(String userId1, String userId2, {bool matchedByAdmin = false}) async {
    try {
      // Create match document
      await _firestore.collection('matches').add({
        'userId1': userId1,
        'userId2': userId2,
        'matchedByAdmin': matchedByAdmin,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create a chat room for the matched users
      // DocumentReference chatRef = await _firestore.collection('chats').add({
      //   'participants': [userId1, userId2],
      //   'lastMessage': 'You are now matched! Say hello!',
      //   'lastMessageTimestamp': FieldValue.serverTimestamp(),
      //   'lastMessageSenderId': 'system',
      //   'createdAt': FieldValue.serverTimestamp(),
      // });

      // Send notifications to both users
      await _notificationService.sendMatchNotification(
        userId1,
        userId2,
        'You have a new match! Start chatting now.',
      );

      await _notificationService.sendMatchNotification(
        userId2,
        userId1,
        'You have a new match! Start chatting now.',
      );
    } catch (e) {
      rethrow;
    }
  }

  // Get user's matches
  Future<List<MatchModel>> getUserMatches(String userId) async {
    try {
      // Get matches where user is userId1
      QuerySnapshot matches1 = await _firestore
          .collection('matches')
          .where('userId1', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      // Get matches where user is userId2
      QuerySnapshot matches2 = await _firestore
          .collection('matches')
          .where('userId2', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      // Combine both lists
      List<MatchModel> allMatches = [];

      // Add matches where user is userId1
      for (var doc in matches1.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['matchId'] = doc.id;
        allMatches.add(MatchModel.fromMap(data));
      }

      // Add matches where user is userId2
      for (var doc in matches2.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['matchId'] = doc.id;

        // Swap userId1 and userId2 for consistent processing
        String temp = data['userId1'];
        data['userId1'] = data['userId2'];
        data['userId2'] = temp;

        allMatches.add(MatchModel.fromMap(data));
      }

      return allMatches;
    } catch (e) {
      rethrow;
    }
  }

  // Unmatch users
  Future<void> unmatchUsers(String matchId) async {
    try {
      // Get match data
      DocumentSnapshot matchDoc = await _firestore.collection('matches').doc(matchId).get();
      String userId1 = (matchDoc.data() as Map<String, dynamic>)['userId1'];
      String userId2 = (matchDoc.data() as Map<String, dynamic>)['userId2'];

      // Delete match document
      await _firestore.collection('matches').doc(matchId).delete();

      // Find and delete chat room
      QuerySnapshot chatSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId1)
          .get();

      for (var doc in chatSnapshot.docs) {
        List<dynamic> participants = (doc.data() as Map<String, dynamic>)['participants'];
        if (participants.contains(userId2)) {
          await _firestore.collection('chats').doc(doc.id).delete();
          break;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Add this method to get users who have liked the current user
  Future<List<String>> getPendingMatchRequests(String userId) async {
    // print('nnnnnkhvjbkvvvvv bvvjbvhjbvjkvbkj');
    try {
      // Get all users who have liked the current user
      QuerySnapshot likedBySnapshot = await _firestore
          .collection('likes')
          .where('likedId', isEqualTo: userId)
          .get();

      // Extract userIds who have liked this user - THIS IS THE FIX
      List<String> likedByUserIds = likedBySnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['likerId'] as String)
          .toList();

      // Filter out users who are already matched
      List<String> pendingUserIds = [];
      for (String likedByUserId in likedByUserIds) {
        // Check if this user has already matched with the liked user
        QuerySnapshot matchCheck = await _firestore
            .collection('matches')
            .where('userId1', whereIn: [userId, likedByUserId])
            .where('userId2', whereIn: [userId, likedByUserId])
            .get();

        // If no match exists, add to pending list
        if (matchCheck.docs.isEmpty) {
          pendingUserIds.add(likedByUserId);
        }
      }

      // print('nnnnnkhvjbkvvvvv bvvjbvhjbvjkvbkj');

      return pendingUserIds;
    } catch (e) {
      // print('nnnnnkhvjbkvvvvv bvvjbvhjbvjkvbkj');
      rethrow;
    }
  }

  // Add these functions to your MatchService class

// For tracking rejected profiles
  Future<void> rejectUser(String rejectorId, String rejectedId) async {
    try {
      await _firestore.collection('rejections').add({
        'rejectorId': rejectorId,
        'rejectedId': rejectedId,
        'rejectedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 5)),
        ),
      });
    } catch (e) {
      rethrow;
    }
  }

// For tracking daily swipes
  Future<int> getRemainingDailySwipes(String userId) async {
    try {
      // Get the start of the current day
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      // Query swipes for today
      QuerySnapshot swipesSnapshot = await _firestore
          .collection('swipes')
          .where('userId', isEqualTo: userId)
          .where('swipedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      // Calculate remaining swipes (100 max per day)
      return 100 - swipesSnapshot.docs.length;
    } catch (e) {
      rethrow;
    }
  }

// Record a swipe (left or right)
  Future<void> recordSwipe(String userId, String swipedUserId, bool isLike) async {
    try {
      await _firestore.collection('swipes').add({
        'userId': userId,
        'swipedUserId': swipedUserId,
        'isLike': isLike,
        'swipedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
}