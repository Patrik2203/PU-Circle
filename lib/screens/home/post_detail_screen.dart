import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/firestore_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../utils/helpers.dart';
import '../profile/profile_screen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:timeago/timeago.dart' as timeago;

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  final Function? onPostUpdated;

  const PostDetailScreen({Key? key, required this.post, this.onPostUpdated})
    : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late PostModel _post;
  UserModel? _postUser;
  bool _isLoading = true;
  bool _isLiked = false;
  String _currentUserId = '';
  VideoPlayerController? _videoController;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _post = widget.post;

    // Setup like animation
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user ID
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      _currentUserId = currentUser.uid;

      // Get post creator data
      final userData = await _authService.getUserData(_post.userId);
      if (userData == null) {
        throw Exception('User data not found');
      }

      _postUser = userData;

      // Check if current user liked this post
      _isLiked = _post.likes.contains(_currentUserId);

      // Initialize video player if post is video
      if (_post.isVideo && _post.mediaUrl.isNotEmpty) {
        _videoController = VideoPlayerController.networkUrl(
            Uri.parse(_post.mediaUrl),
          )
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'Error loading data: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    try {
      final bool newLikeStatus = !_isLiked;

      // Animate like button
      if (newLikeStatus) {
        _likeAnimationController.forward().then(
          (_) => _likeAnimationController.reverse(),
        );
      }

      // Update UI immediately for better UX
      setState(() {
        if (newLikeStatus) {
          _post.likes.add(_currentUserId);
        } else {
          _post.likes.remove(_currentUserId);
        }
        _isLiked = newLikeStatus;
      });

      // Update like status in Firestore
      if (newLikeStatus) {
        await _firestoreService.likePost(_post.postId, _currentUserId);
      } else {
        await _firestoreService.unlikePost(_post.postId, _currentUserId);
      }

      // Fetch updated post data
      final updatedPost = await _firestoreService.getPost(_post.postId);

      if (updatedPost != null && mounted) {
        setState(() {
          _post = updatedPost;
        });
      }

      // Call callback to refresh parent screen
      widget.onPostUpdated?.call();
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Error updating like: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _deletePost() async {
    try {
      await _firestoreService.deletePost(_post.postId);

      // Call callback to refresh parent screen
      widget.onPostUpdated?.call();

      if (!mounted) return;

      // Show success message and pop screen
      AppHelpers.showSnackBar(context, 'Post deleted successfully!');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'Error deleting post: ${e.toString()}',
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text('Are you sure you want to delete this post?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deletePost();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildMediaContent() {
    if (_post.isVideo) {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return GestureDetector(
          onTap: () {
            setState(() {
              if (_videoController!.value.isPlaying) {
                _videoController!.pause();
              } else {
                _videoController!.play();
              }
            });
          },
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
                if (!_videoController!.value.isPlaying)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
              ],
            ),
          ),
        );
      } else {
        return const SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator()),
        );
      }
    } else {
      return _post.mediaUrl.isNotEmpty
          ? Container(
            constraints: const BoxConstraints(maxHeight: 500),
            width: double.infinity,
            child: Image.network(
              _post.mediaUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Image not available',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      value:
                          loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                    ),
                  ),
                );
              },
            ),
          )
          : const SizedBox();
    }
  }

  Widget _buildDoubleTapLikeOverlay() {
    return GestureDetector(
      onDoubleTap: () {
        if (!_isLiked) {
          _toggleLike();
        }
        // Show heart animation on double tap
        setState(() {
          _showHeartOverlay = true;
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _showHeartOverlay = false;
            });
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildMediaContent(),
          if (_showHeartOverlay)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value > 0.8 ? 2 - value * 2 : value,
                  child: Transform.scale(
                    scale: value,
                    child: Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 100,
                      shadows: const [
                        Shadow(
                          color: Colors.black38,
                          blurRadius: 20,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  bool _showHeartOverlay = false;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post'), elevation: 0),
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: AppColors.primary,
            size: 40,
          ),
        ),
      );
    }

    if (_postUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post'), elevation: 0),
        body: const Center(child: Text('Error loading post data')),
      );
    }

    return Scaffold(
      backgroundColor:
          Theme.of(context).brightness == Brightness.dark
              ? Colors.black
              : Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _postUser!.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          if (_post.userId == _currentUserId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header with user info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ProfileScreen(userId: _postUser!.uid),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      backgroundImage:
                          _postUser!.profileImageUrl != null &&
                                  _postUser!.profileImageUrl!.isNotEmpty
                              ? NetworkImage(_postUser!.profileImageUrl!)
                              : null,
                      child:
                          _postUser!.profileImageUrl == null ||
                                  _postUser!.profileImageUrl!.isEmpty
                              ? const Icon(Icons.person)
                              : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      ProfileScreen(userId: _postUser!.uid),
                            ),
                          );
                        },
                        child: Text(
                          _postUser!.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        timeago.format(_post.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Post media content
            if (_post.mediaUrl.isNotEmpty) _buildDoubleTapLikeOverlay(),

            // Post caption
            if (_post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  _post.caption,
                  style: const TextStyle(fontSize: 15),
                ),
              ),

            // Engagement buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _likeAnimation,
                    child: IconButton(
                      onPressed: _toggleLike,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        color: _isLiked ? Colors.red : null,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      AppHelpers.showSnackBar(context, 'Comment coming soon');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.chat_bubble_outline, size: 24),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      AppHelpers.showSnackBar(context, 'Share Post coming soon');
                      // Share post
                      // AppHelpers.shareContent(_post.caption, _post.mediaUrl);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.send, size: 24),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      // Save post
                      AppHelpers.showSnackBar(context, 'Save Post coming soon');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.bookmark_border, size: 26),
                  ),
                ],
              ),
            ),

            // Like count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${_post.likes.length} ${_post.likes.length == 1 ? 'like' : 'likes'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),

            // Comments section
            // _buildCommentSection(),

            // Bottom spacing
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
