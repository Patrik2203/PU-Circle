import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create a post
  Future<String> createPost({
    required String caption,
    required String mediaUrl,
    required String userId,
    required bool isVideo,
  }) async {
    try {
      // Create post document
      DocumentReference doc = await _firestore.collection('posts').add({
        'userId': userId,
        'caption': caption,
        'mediaUrl': mediaUrl,
        'isVideo': isVideo,
        'likes': [],
        'timestamp': FieldValue.serverTimestamp(),
      });

      return doc.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get posts for home feed (posts from users you follow)
  Future<List<PostModel>> getHomeFeedPosts(String userId) async {
    try {
      // Get current user's following list
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      List<dynamic> following = (userDoc.data() as Map<String, dynamic>)['following'] ?? [];

      // If user isn't following anyone, return empty list
      if (following.isEmpty) {
        return [];
      }

      // Get posts from users the current user follows
      QuerySnapshot postSnapshot = await _firestore
          .collection('posts')
          .where('userId', whereIn: following)
          .orderBy('timestamp', descending: true)
          .get();

      return postSnapshot.docs
          .map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id; // Add post ID to the data
        return PostModel.fromMap(data);
      })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get all posts for a specific user
  Future<List<PostModel>> getUserPosts(String userId) async {
    try {
      QuerySnapshot postSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return postSnapshot.docs
          .map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['postId'] = doc.id; // Add post ID to the data
        return PostModel.fromMap(data);
      })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Like a post
  Future<void> likePost(String postId, String userId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayUnion([userId]),
      });

      // Get post data to identify post owner
      DocumentSnapshot postSnapshot = await _firestore.collection('posts').doc(postId).get();
      String postOwnerId = (postSnapshot.data() as Map<String, dynamic>)['userId'];

      // Create notification if the user liking is not the post owner
      if (userId != postOwnerId) {
        await _firestore.collection('notifications').add({
          'type': 'like',
          'senderId': userId,
          'receiverId': postOwnerId,
          'postId': postId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // Unlike a post
  Future<void> unlikePost(String postId, String userId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'likes': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get a specific user's data
  Future<UserModel?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id; // Add UID to the data
        return UserModel.fromMap(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

//The getPost method fetches a specific post from Firestore using its postId.
  Future<PostModel?> getPost(String postId) async {
    try {
      // Fetch the post document from Firestore
      final doc = await _firestore.collection('posts').doc(postId).get();

      // Check if the document exists
      if (!doc.exists) return null;

      // Convert Firestore data to a PostModel
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['postId'] = doc.id; // Ensure postId is included in the data

      return PostModel.fromMap(data);
    } catch (e) {
      print('Error fetching post: $e');
      return null;
    }
  }


  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? username,
    String? bio,
    String? profileImageUrl,
  }) async {
    try {
      Map<String, dynamic> updates = {};

      if (username != null && username.isNotEmpty) {
        updates['username'] = username;
      }

      if (bio != null) {
        updates['bio'] = bio;
      }

      if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
        updates['profileImageUrl'] = profileImageUrl;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(userId).update(updates);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get followers list
  Future<List<UserModel>> getFollowers(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      List<dynamic> followerIds = (doc.data() as Map<String, dynamic>)['followers'] ?? [];

      List<UserModel> followers = [];
      for (String followerId in followerIds) {
        UserModel? user = await getUserData(followerId);
        if (user != null) {
          followers.add(user);
        }
      }

      return followers;
    } catch (e) {
      rethrow;
    }
  }

  // Get following list
  Future<List<UserModel>> getFollowing(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      List<dynamic> followingIds = (doc.data() as Map<String, dynamic>)['following'] ?? [];

      List<UserModel> following = [];
      for (String followingId in followingIds) {
        UserModel? user = await getUserData(followingId);
        if (user != null) {
          following.add(user);
        }
      }

      return following;
    } catch (e) {
      rethrow;
    }
  }

  // Search for users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return UserModel.fromMap(data);
      })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> createDefaultUserProfile(String uid) async {
    try {
      print("DEBUG: Starting default user profile creation for uid: $uid");
      
      // Check if user already exists
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      if (docSnapshot.exists) {
        print("DEBUG: User document already exists");
        return;
      }

      // Create a default profile for the user
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      print("DEBUG: Creating user document with email: ${user.email}");

      // Create user data with explicit typing and null safety
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': user.email ?? '',
        'username': 'User_${uid.substring(0, 5)}',
        'profileImageUrl': '',
        'bio': '',
        'gender': 'Prefer not to say',
        'isSingle': true,
        'isAdmin': false,
        'followers': [],
        'following': [],
        'interests': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Verify document creation
      final verifyDoc = await _firestore.collection('users').doc(uid).get();
      if (!verifyDoc.exists) {
        print("DEBUG: Document creation verification failed");
        throw Exception('Failed to verify user document creation');
      }

      print("DEBUG: Default user profile created successfully");
    } catch (e) {
      print("DEBUG: Error creating default user profile: $e");
      print("DEBUG: Error type: ${e.runtimeType}");
      rethrow;
    }
  }
}