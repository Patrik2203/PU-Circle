import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/retry_helper.dart';

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

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Create a default user profile if it doesn't exist
  // Future<void> createDefaultUserProfile(String uid) async {
  //   try {
  //     // Check if user already exists
  //     final docSnapshot = await _firestore.collection('users').doc(uid).get();
  //     if (docSnapshot.exists) return;
  //
  //     // Create a default profile for the user
  //     final user = _auth.currentUser;
  //     await _firestore.collection('users').doc(uid).set({
  //       'uid': uid,
  //       'email': user?.email ?? '',
  //       'username': 'User_${uid.substring(0, 5)}',
  //       'profileImageUrl': '',
  //       'bio': '',
  //       'gender': 'Prefer not to say',
  //       'isSingle': true,
  //       'isAdmin': false,
  //       'followers': [],
  //       'following': [],
  //       'interests': [],
  //       'createdAt': FieldValue.serverTimestamp(),
  //     });
  //   } catch (e) {
  //     throw _handleException(e);
  //   }
  // }

  // Signup with email and password
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
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print("User created in Authentication: ${userCredential.user!.uid}");

      // Create user document in Firestore with explicit types
      try {
        Map<String, dynamic> userData = {
          'uid': userCredential.user!.uid,
          'email': email,
          'username': username,
          'profileImageUrl': profileImageUrl ?? '',
          'bio': bio ?? '',
          'gender': gender,
          'isSingle': isSingle,
          'isAdmin': false,
          'followers': <String>[],  // Empty array with proper type
          'following': <String>[],  // Empty array with proper type
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('users').doc(userCredential.user!.uid).set(userData);
        print("User document created in Firestore");
      } catch (firestoreError) {
        print("Error creating user document in Firestore: $firestoreError");
        throw AuthException('firestore-error', 'Account created but profile setup failed: $firestoreError');
      }

      return userCredential;
    } catch (e) {
      print("Error in signUp function: $e");
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

  // Modern email verification compatible with 2025 changes
  // Future<void> sendEmailVerification(User user) async {
  //   try {
  //     await user.sendEmailVerification(
  //       ActionCodeSettings(
  //         url: 'https://your-app-domain.com/finishSignUp?email=${user.email}',
  //         handleCodeInApp: true,
  //         androidPackageName: 'com.example.pucircle',
  //         androidInstallApp: true,
  //         androidMinimumVersion: '12',
  //         iOSBundleId: 'com.example.pucircle',
  //       ),
  //     );
  //   } catch (e) {
  //     throw _handleException(e);
  //   }
  // }

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

      // Check if user has a profile in Firestore, create if not
      // await createDefaultUserProfile(credential.user!.uid);

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
// Get user data with retry logic
  Future<UserModel?> getUserData(String uid) async {
    return retry(() async {
      try {
        DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        }
        return null;
      } catch (e) {
        print("Error getting user data: $e");
        return null;
      }
    }, maxRetries: 3);
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