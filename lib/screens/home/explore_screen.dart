import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase/firestore_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../widgets/post_widget.dart';

class ExploreScreen extends StatefulWidget {
  final ScrollController? scrollController;

  const ExploreScreen({Key? key, this.scrollController}) : super(key: key);

  @override
  _ExploreScreenState createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ScrollController _scrollController = ScrollController();

  List<PostModel> _posts = [];
  Map<String, UserModel> _postOwners = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    // _scrollController.addListener(_scrollListener);
    // Only add listener if we created our own controller
    if (widget.scrollController == null) {
      _scrollController.addListener(_scrollListener);
    }
  }

  @override
  void dispose() {
    // _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    if (widget.scrollController == null) {
      _scrollController.removeListener(_scrollListener);
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMorePosts) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitialPosts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get random posts for explore feed
      final posts = await _firestoreService.getRandomPosts(limit: 15);

      if (posts.isNotEmpty) {
        // Update last document for pagination
        final lastDoc = await _firestoreService.getLastDocument(posts.last.postId);
        if (lastDoc != null) {
          _lastDocument = lastDoc;
        }

        // Check if we might have more posts
        _hasMorePosts = posts.length >= 15;

        // Collect post owners data
        final Map<String, UserModel> tempPostOwners = {};
        for (var post in posts) {
          if (!tempPostOwners.containsKey(post.userId)) {
            final userData = await _firestoreService.getUserData(post.userId);
            if (userData != null) {
              tempPostOwners[post.userId] = userData;
            }
          }
        }

        setState(() {
          _posts = posts;
          _postOwners = tempPostOwners;
        });
      }
    } catch (e) {
      print("Error loading explore posts: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Load more random posts with pagination
      List<PostModel> newPosts = await _firestoreService.getRandomPosts(
        lastDocument: _lastDocument,
        limit: 15,
      );

      if (newPosts.isEmpty) {
        _hasMorePosts = false;
      } else {
        // Update last document for next pagination
        final lastDoc = await _firestoreService.getLastDocument(newPosts.last.postId);
        if (lastDoc != null) {
          _lastDocument = lastDoc;
        }

        // Get user data for new posts
        Map<String, UserModel> newPostOwners = {};
        for (var post in newPosts) {
          if (!_postOwners.containsKey(post.userId)) {
            final userData = await _firestoreService.getUserData(post.userId);
            if (userData != null) {
              newPostOwners[post.userId] = userData;
            }
          }
        }

        setState(() {
          _posts.addAll(newPosts);
          _postOwners.addAll(newPostOwners);
        });
      }
    } catch (e) {
      print("Error loading more explore posts: $e");
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  Future<void> _refreshExplore() async {
    setState(() {
      _posts = [];
      _lastDocument = null;
      _hasMorePosts = true;
    });

    await _loadInitialPosts();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts to explore right now',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refreshExplore,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshExplore,
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _posts.length + 1, // +1 for loading indicator
        itemBuilder: (context, index) {
          if (index < _posts.length) {
            final post = _posts[index];
            final postOwner = _postOwners[post.userId];

            if (postOwner == null) {
              // Skip if we don't have user data
              return const SizedBox.shrink();
            }

            return PostWidget(
              key: ValueKey(post.postId),
              post: post,
              postOwner: postOwner,
              onRefresh: () async {
                // Reload this post if needed (for likes, etc.)
                final updatedPost = await _firestoreService.getPost(post.postId);
                if (updatedPost != null) {
                  setState(() {
                    _posts[index] = updatedPost;
                  });
                }
              },
            );
          } else {
            // Footer widget for loading indicator
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    strokeWidth: 2.0,
                  ),
                ),
              );
            } else if (!_hasMorePosts) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    "You've seen all the posts!",
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox(height: 50);
          }
        },
      ),
    );
  }
}