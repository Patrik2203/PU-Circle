import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../firebase/auth_service.dart';
import '../firebase/firestore_service.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../widgets/common_widgets.dart';

class HomeController with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final Map<String, UserModel> _postOwners = {};
  UserModel? _currentUser;
  bool _isLoading = true;
  List<PostModel> _posts = [];
  bool _isLoggingOut = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  final List<String> _loadedPostIds = [];
  bool _isShowingRandomPosts = false;
  bool _isEmptyFollowingFeed = false;
  String _transitionMessage = '';
  bool _showTransitionMessage = false;
  final ScrollController scrollController = ScrollController();

  // Getters
  Map<String, UserModel> get postOwners => _postOwners;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  List<PostModel> get posts => _posts;
  bool get isLoggingOut => _isLoggingOut;
  bool get hasMorePosts => _hasMorePosts;
  bool get isLoadingMore => _isLoadingMore;
  bool get isShowingRandomPosts => _isShowingRandomPosts;
  bool get isEmptyFollowingFeed => _isEmptyFollowingFeed;
  String get transitionMessage => _transitionMessage;
  bool get showTransitionMessage => _showTransitionMessage;

  HomeController() {
    _init();
  }

  void _init() {
    scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    // Load more posts when reaching near the bottom of the list
    if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMorePosts) {
      loadMorePosts();
    }
  }
  // Check if we need to navigate to login
  bool checkAuthStatus() {
    final currentUserId = _authService.currentUser?.uid;
    return currentUserId != null;
  }

  // Load user data and initial posts
  Future<void> loadUserData(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) {
        return;
      }

      final userData = await _authService.getUserData(currentUserId);

      if (userData == null) {
        final retryData = await _authService.getUserData(currentUserId);
        if (retryData == null) {
          throw Exception('Failed to load user profile');
        }
        _currentUser = retryData;
      } else {
        _currentUser = userData;
      }

      // Load initial posts
      await _loadInitialPosts(context);
    } catch (e) {
      print("Error in loadUserData: $e");
      if (context.mounted) {
        showCustomSnackBar(
          context,
          message: 'Error loading your profile data',
          isError: true,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load initial posts with optimizations
  Future<void> _loadInitialPosts(BuildContext? context) async {
    if (_currentUser == null) return;

    try {
      // Create temporary lists to avoid UI flicker
      final List<PostModel> tempPosts = [];
      final Map<String, UserModel> tempPostOwners = {};
      final List<String> tempLoadedPostIds = [];

      // Get initial posts from following
      final posts = await _firestoreService.getHomeFeedPosts(_currentUser!.uid);

      if (posts.isNotEmpty) {
        // Update last document for pagination
        _lastDocument = await _firestoreService.getLastDocument(posts.last.postId);

        // Check if we might have more posts
        _hasMorePosts = posts.length >= 15;
        _isEmptyFollowingFeed = false;

        // Collect post owners data
        for (var post in posts) {
          if (!tempPostOwners.containsKey(post.userId)) {
            final userData = await _firestoreService.getUserData(post.userId);
            if (userData != null) {
              tempPostOwners[post.userId] = userData;
            }
          }
          tempLoadedPostIds.add(post.postId);
        }

        tempPosts.addAll(posts);
      } else {
        _hasMorePosts = false;
        _isEmptyFollowingFeed = true;
      }

      // Update state
      _posts = tempPosts;
      _postOwners.addAll(tempPostOwners);
      _loadedPostIds.addAll(tempLoadedPostIds);
      notifyListeners();
    } catch (e) {
      print("Error loading initial posts: $e");
      if (context!.mounted) {
        showCustomSnackBar(
          context,
          message: 'Error loading posts',
          isError: true,
        );
      }
    }
  }

  // Load more posts (paginated)
  Future<void> loadMorePosts() async {
    if (_isLoadingMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // Only load posts from following users
      final newPosts = await _firestoreService.getHomeFeedPosts(
        _currentUser!.uid,
        lastDocument: _lastDocument,
      );

      if (newPosts.isEmpty || newPosts.length < 15) {
        _hasMorePosts = false;
      } else if (newPosts.isNotEmpty) {
        // Update last document for next pagination
        _lastDocument = await _firestoreService.getLastDocument(newPosts.last.postId);
      }

      // Filter out any posts that might already be loaded (prevent duplicates)
      final filteredPosts = newPosts.where((post) => !_loadedPostIds.contains(post.postId)).toList();

      // Get user data for new posts
      final Map<String, UserModel> newPostOwners = {};
      for (var post in filteredPosts) {
        if (!_postOwners.containsKey(post.userId)) {
          final userData = await _firestoreService.getUserData(post.userId);
          if (userData != null) {
            newPostOwners[post.userId] = userData;
          }
        }
        _loadedPostIds.add(post.postId);
      }

      _posts.addAll(filteredPosts);
      _postOwners.addAll(newPostOwners);
    } catch (e) {
      print("Error loading more posts: $e");
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Refresh data
  Future<void> refreshData() async {
    _isLoading = true;
    _posts = [];
    _loadedPostIds.clear();
    _lastDocument = null;
    _hasMorePosts = true;
    _showTransitionMessage = false;
    _isEmptyFollowingFeed = false;
    notifyListeners();

    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId != null) {
        final userData = await _authService.getUserData(currentUserId);
        _currentUser = userData;
        await _loadInitialPosts(null);
      }
    } catch (e) {
      print("Error refreshing data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update a single post (for likes without refreshing everything)
  void updatePost(PostModel updatedPost) {
    final index = _posts.indexWhere((post) => post.postId == updatedPost.postId);
    if (index != -1) {
      _posts[index] = updatedPost;
      notifyListeners();
    }
  }

  // Handle logout
  Future<void> logout(BuildContext context) async {
    if (_isLoggingOut) return;

    _isLoggingOut = true;
    notifyListeners();

    try {
      await _authService.logout();
      _isLoggingOut = false;
      return;
    } catch (e) {
      if (context.mounted) {
        showCustomSnackBar(
          context,
          message: 'Error logging out',
          isError: true,
        );
      }
    } finally {
      _isLoggingOut = false;
      notifyListeners();
    }
  }
}