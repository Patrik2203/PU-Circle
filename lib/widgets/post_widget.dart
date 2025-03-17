import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../utils/colors.dart';
import '../firebase/firestore_service.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/home/post_detail_screen.dart';

class PostWidget extends StatefulWidget {
  final PostModel post;
  final UserModel postOwner;
  final bool isDetailView;
  final Function()? onRefresh;

  const PostWidget({
    Key? key,
    required this.post,
    required this.postOwner,
    this.isDetailView = false,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLiked = false;
  int _likeCount = 0;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likes.length;
    _checkIfLiked();

    // Setup like animation
    _likeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _likeAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    final currentUserId = await _firestoreService.currentUserId!;
    if (mounted) {
      setState(() {
        _isLiked = widget.post.likes.contains(currentUserId);
      });
    }
  }

  Future<void> _toggleLike() async {
    try {
      final currentUserId = await _firestoreService.currentUserId!;

      // Update UI immediately for better UX
      setState(() {
        if (!_isLiked) {
          _likeCount++;
          _likeAnimationController
              .forward()
              .then((_) => _likeAnimationController.reverse());
        } else {
          _likeCount--;
        }
        _isLiked = !_isLiked;
      });

      // Call service method to update in Firestore
      await _firestoreService.togglePostLike(widget.post, currentUserId);

      // Call callback to refresh parent screen if needed
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating like: ${e.toString()}')),
        );
      }
    }
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: widget.postOwner.uid),
      ),
    );
  }

  void _navigateToPostDetail(BuildContext context) {
    if (!widget.isDetailView) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailScreen(
            post: widget.post,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      elevation: 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post header with user info
          ListTile(
            leading: GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: CircleAvatar(
                backgroundImage: widget.postOwner.profileImageUrl != null
                    ? NetworkImage(widget.postOwner.profileImageUrl!)
                    : const AssetImage('assets/images/default_profile.png')
                        as ImageProvider,
              ),
            ),
            title: GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: Text(
                widget.postOwner.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            subtitle: Text(
              DateFormat.yMMMd().format(widget.post.createdAt),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.0,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // Show options menu (report, etc.)
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.report),
                        title: const Text('Report Post'),
                        onTap: () {
                          // Implement report functionality
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Post reported. We\'ll review it soon.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Caption/Text content
          if (widget.post.caption != null && widget.post.caption!.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                widget.post.caption!,
                style: const TextStyle(fontSize: 14.0),
              ),
            ),

          // Media content (image/video)
          GestureDetector(
            onTap: () => _navigateToPostDetail(context),
            onDoubleTap: _toggleLike,
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 400,
              ),
              width: double.infinity,
              child: widget.post.mediaUrl != null
                  ? Hero(
                      tag: 'post_image_${widget.post.postId}',
                      child: Image.network(
                        widget.post.mediaUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 50,
                            ),
                          );
                        },
                      ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: AppColors.textLight,
                        size: 50,
                      ),
                    ),
            ),
          ),

          // Post actions (like, comment, etc.)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _likeAnimation,
                  child: IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? AppColors.like : null,
                    ),
                    onPressed: _toggleLike,
                  ),
                ),
                const SizedBox(width: 4.0),
                Text(
                  _likeCount.toString(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16.0),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () => _navigateToPostDetail(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Optional: Post List Widget for reusability
class PostListWidget extends StatelessWidget {
  final List<PostModel> posts;
  final Map<String, UserModel> userMap;
  final Function()? onRefresh;
  final bool showEmptyMessage;

  const PostListWidget({
    Key? key,
    required this.posts,
    required this.userMap,
    this.onRefresh,
    this.showEmptyMessage = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty && showEmptyMessage) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_album_outlined,
              size: 80,
              color: AppColors.textLight,
            ),
            SizedBox(height: 16),
            Text(
              'No posts to show',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postOwner = userMap[post.userId]!;

        return PostWidget(
          post: post,
          postOwner: postOwner,
          onRefresh: onRefresh,
        );
      },
    );
  }
}
