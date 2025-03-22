import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pu_circle/firebase/match_service.dart';
import 'package:pu_circle/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchController with ChangeNotifier {
  final MatchService _matchService = MatchService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<UserModel> _potentialMatches = [];
  bool _isLoading = false;
  bool _showMatchAnimation = false;
  UserModel? _matchedUser;
  bool _hasMoreMatches = true;
  DocumentSnapshot? _lastDocument;
  int _remainingSwipes = 100;

  // Getters
  List<UserModel> get potentialMatches => _potentialMatches;
  bool get isLoading => _isLoading;
  bool get showMatchAnimation => _showMatchAnimation;
  UserModel? get matchedUser => _matchedUser;
  bool get hasMoreMatches => _hasMoreMatches;
  int get remainingSwipes => _remainingSwipes;

  // Initialize
  Future<void> init() async {
    await loadPotentialMatches(refresh: true);
    await checkRemainingSwipes();
  }

  // Check remaining swipes
  Future<void> checkRemainingSwipes() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        int remaining = await _matchService.getRemainingDailySwipes(userId);
        _remainingSwipes = remaining;
        notifyListeners();
      }
    } catch (e) {
      print('Error checking remaining swipes: $e');
    }
  }

  // Load potential matches
  Future<void> loadPotentialMatches({bool refresh = false}) async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // If refreshing, clear existing data
      if (refresh) {
        _potentialMatches = [];
        _lastDocument = null;
        _hasMoreMatches = true;
      }

      // Don't fetch if we already know there are no more matches
      if (!_hasMoreMatches && !refresh) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Fetch matches with pagination
      final matches = await _matchService.getPotentialMatches(
        userId,
        lastDocument: _lastDocument,
        limit: 10,
      );

      // Update pagination status
      if (matches.isEmpty) {
        _hasMoreMatches = false;
      } else {
        // Get the last document for pagination
        final lastUserId = matches.last.uid;
        final lastUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(lastUserId)
            .get();
        _lastDocument = lastUserDoc;

        // Add new matches to the list
        _potentialMatches.addAll(matches);
      }
    } catch (e) {
      print('Error loading matches: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Handle swipe action
  Future<void> handleSwipe(UserModel user, bool isLiked) async {
    // Check if user has remaining swipes for today
    if (_remainingSwipes <= 0) {
      return;
    }

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Record the swipe regardless of like/dislike
      await _matchService.recordSwipe(userId, user.uid, isLiked);

      // Decrement remaining swipes
      _remainingSwipes--;

      // If liked, check for match
      if (isLiked) {
        final bool isMatch = await _matchService.likeUser(userId, user.uid);

        if (isMatch) {
          _showMatchAnimation = true;
          _matchedUser = user;
          notifyListeners();
        }
      } else {
        // If disliked (rejected), record rejection
        await _matchService.rejectUser(userId, user.uid);
      }

      // Remove the user from the list in the UI
      _potentialMatches.remove(user);

      // If running low on potential matches, load more
      if (_potentialMatches.length < 3 && _hasMoreMatches) {
        loadPotentialMatches();
      }

      notifyListeners();
    } catch (e) {
      print('Error handling swipe: $e');
    }
  }

  // Toggle match animation
  void setShowMatchAnimation(bool show) {
    _showMatchAnimation = show;
    notifyListeners();
  }

  // Reset match state
  void resetMatchState() {
    _matchedUser = null;
    _showMatchAnimation = false;
    notifyListeners();
  }
}