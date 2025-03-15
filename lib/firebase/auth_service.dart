import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/retry_helper.dart';
import './firestore_service.dart';

class AuthException implements Exception {
  final String message;
  final String code;

  AuthException(this.code, this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String username,
    required String gender,
    required bool isSingle,
    String? profileImageUrl,
    String? bio,
  }) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw AuthException('no-internet', 'No internet connection. Please check your network settings.');
    }

    try {
      print("DEBUG: Starting user creation in Firebase Auth");
      
      // Create user with email and password first
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw AuthException('auth-error', 'Failed to create user account.');
      }

      print("DEBUG: User created in Authentication: ${userCredential.user!.uid}");

      try {
        // First create the default profile
        print("DEBUG: Creating default user profile");
        await _firestoreService.createDefaultUserProfile(userCredential.user!.uid);
        
        print("DEBUG: Updating user profile with provided information");
        // Then update with user-provided information
        Map<String, dynamic> updateData = {
          'email': email,
          'username': username,
          'gender': gender,
          'isSingle': isSingle,
        };
        
        // Only add optional fields if they are provided
        if (bio != null && bio.isNotEmpty) {
          updateData['bio'] = bio;
        }
        if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
          updateData['profileImageUrl'] = profileImageUrl;
        }

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update(updateData);

        print("DEBUG: User profile updated successfully");
        return userCredential;
      } catch (firestoreError) {
        print("DEBUG: Firestore Error: $firestoreError");
        print("DEBUG: Firestore Error Type: ${firestoreError.runtimeType}");
        
        // Clean up: delete the auth user since document creation failed
        try {
          await userCredential.user!.delete();
          print("DEBUG: Auth user deleted after Firestore error");
        } catch (deleteError) {
          print("DEBUG: Error deleting auth user: $deleteError");
        }
        
        throw AuthException('firestore-error', 'Failed to create user profile: ${firestoreError.toString()}');
      }
    } catch (e) {
      print("DEBUG: Error in signUp function: $e");
      print("DEBUG: Error type: ${e.runtimeType}");
      
      if (e is FirebaseAuthException) {
        print("DEBUG: Firebase Auth Error Code: ${e.code}");
        print("DEBUG: Firebase Auth Error Message: ${e.message}");
      }
      
      throw _handleException(e);
    }
  }

  // Check if user exists in Firestore
  Future<bool> userExistsInFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print("Error checking if user exists: $e");
      return false;
    }
  }

  // Login with email and password
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    // Check connectivity first
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw AuthException('no-internet', 'No internet connection. Please check your network settings.');
    }

    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return credential;
    } catch (e) {
      throw _handleException(e);
    }
  }

  // Admin login with passkey
  Future<bool> adminLogin({
    required String email,
    required String password,
    required String passkey,
  }) async {
    // Check if passkey is correct
    if (passkey != "79770051419136567648") {
      throw AuthException('invalid-passkey', 'The admin passkey is invalid.');
    }

    try {
      // First login with email and password
      UserCredential userCredential = await login(
        email: email,
        password: password,
      );

      // Update user as admin
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'isAdmin': true,
      });

      return true;
    } catch (e) {
      throw _handleException(e);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw _handleException(e);
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    try {
      print("DEBUG: Attempting to get user data for $uid");
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        print("DEBUG: Raw user data: $userData"); // Debug print

        // Create a UserModel with safe type casting
        UserModel user = UserModel(
          uid: userData['uid']?.toString() ?? '',
          email: userData['email']?.toString() ?? '',
          username: userData['username']?.toString() ?? '',
          profileImageUrl: userData['profileImageUrl']?.toString() ?? '',
          bio: userData['bio']?.toString() ?? '',
          gender: userData['gender']?.toString() ?? '',
          isSingle: userData['isSingle'] as bool? ?? false,
          isAdmin: userData['isAdmin'] as bool? ?? false,
          followers: List<String>.from(userData['followers'] ?? []),
          following: List<String>.from(userData['following'] ?? []),
          interests: List<String>.from(userData['interests'] ?? []),
          createdAt: userData['createdAt'] != null ?
            (userData['createdAt'] as Timestamp).toDate() : DateTime.now(),
        );

        print("DEBUG: User data found for $uid");
        return user;
      }

      print("DEBUG: No user data found for $uid");
      return null;
    } catch (e) {
      print("DEBUG: Error getting user data: $e");
      print("DEBUG: Error type: ${e.runtimeType}");
      return null;
    }
  }

  // Helper method to safely convert any list to List<String>
  List<String> _convertToStringList(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];

    return value.map((item) => item?.toString() ?? '').toList().cast<String>();
  }

  // Follow user
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      // Add targetUserId to current user's following list
      await _firestore.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayUnion([targetUserId]),
      });

      // Add currentUserId to target user's followers list
      await _firestore.collection('users').doc(targetUserId).update({
        'followers': FieldValue.arrayUnion([currentUserId]),
      });

      // Create notification
      await _firestore.collection('notifications').add({
        'type': 'follow',
        'senderId': currentUserId,
        'receiverId': targetUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw _handleException(e);
    }
  }

  // Unfollow user
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // Remove targetUserId from current user's following list
      await _firestore.collection('users').doc(currentUserId).update({
        'following': FieldValue.arrayRemove([targetUserId]),
      });

      // Remove currentUserId from target user's followers list
      await _firestore.collection('users').doc(targetUserId).update({
        'followers': FieldValue.arrayRemove([currentUserId]),
      });
    } catch (e) {
      throw _handleException(e);
    }
  }

  // Report user
  Future<void> reportUser(String reporterId, String reportedUserId, String reason) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': reporterId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      throw _handleException(e);
    }
  }

  // Handle exceptions with user-friendly messages
  Exception _handleException(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return AuthException(e.code, 'No account found with this email.');
        case 'wrong-password':
          return AuthException(e.code, 'Incorrect password. Please try again.');
        case 'email-already-in-use':
          return AuthException(e.code, 'This email is already registered.');
        case 'weak-password':
          return AuthException(e.code, 'Password is too weak. Use at least 6 characters.');
        case 'invalid-email':
          return AuthException(e.code, 'Please enter a valid email address.');
        case 'user-disabled':
          return AuthException(e.code, 'This account has been disabled.');
        case 'too-many-requests':
          return AuthException(e.code, 'Too many unsuccessful login attempts. Please try again later.');
        case 'operation-not-allowed':
          return AuthException(e.code, 'This operation is not allowed.');
        case 'account-exists-with-different-credential':
          return AuthException(e.code, 'An account already exists with the same email address.');
        case 'network-request-failed':
          return AuthException(e.code, 'Network error. Please check your internet connection.');
        default:
          return AuthException(e.code, 'Authentication error: ${e.message}');
      }
    } else if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return AuthException(e.code, 'You do not have permission to perform this action.');
      }
      return AuthException(e.code, 'Firebase error: ${e.message}');
    }
    return AuthException('unknown', 'An unexpected error occurred. Please try again.');
  }
}