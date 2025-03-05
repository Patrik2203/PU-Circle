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

  const PostDetailScreen({
    Key? key,
    required this.post,
    this.onPostUpdated,
  }) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late PostModel _post;
  UserModel? _postUser;
  bool _isLoading = true;
  bool _isLiked = false;
  String _currentUserId = '';
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadData();
  }

  @override
  void dispose() {
    _videoController?.dispose();
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
      if (_post.isVideo) {
        _videoController = VideoPlayerController.network(_post.mediaUrl)
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
        AppHelpers.showSnackBar(context, 'Error updating like: ${e.toString()}');
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
        AppHelpers.showSnackBar(context, 'Error deleting post: ${e.toString()}');
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
        );
      } else {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
    } else {
      return Image.network(
        _post.mediaUrl,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Post'),
        ),
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
        appBar: AppBar(
          title: const Text('Post'),
        ),
        body: const Center(
          child: Text('Error loading post data'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (_post.userId == _currentUserId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post header with user info
            ListTile(
              leading: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: _postUser!.uid,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  backgroundImage: _postUser!.profileImageUrl != null
                      ? NetworkImage(_postUser!.profileImageUrl!)
                      : null,
                  child: _postUser!.profileImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
              ),
              title: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: _postUser!.uid,
                      ),
                    ),
                  );
                },
                child: Text(
                  _postUser!.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              subtitle: Text(
                timeago.format(_post.createdAt),
              ),
            ),

            // Post media content
            _buildMediaContent(),

            // Post actions (like button)
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? AppColors.like : null,
                  ),
                  onPressed: _toggleLike,
                ),
                Text(
                  '${_post.likes.length} likes',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // Post caption
            if (_post.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: '${_postUser!.username} ',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: _post.caption,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}