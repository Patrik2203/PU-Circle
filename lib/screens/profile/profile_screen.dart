import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../utils/colors.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const ProfileScreen({
    Key? key,
    required this.userId,
    this.isCurrentUser = false,
  }) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;
  late Future<UserModel?> _userFuture;
  late Future<List<PostModel>> _postsFuture;

  bool _isFollowing = false;
  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  void _loadUserData() {
    _userFuture = _authService.getUserData(widget.userId);
    _postsFuture = _firestoreService.getUserPosts(widget.userId);

    _userFuture.then((user) {
      if (user != null && mounted) {
        setState(() {
          _followersCount = user.followers.length;
          _followingCount = user.following.length;
        });

        // Check if current user is following this profile
        if (!widget.isCurrentUser && _authService.currentUser != null) {
          setState(() {
            _isFollowing = user.followers.contains(
              _authService.currentUser!.uid,
            );
          });
        }
      }
    });

    _postsFuture.then((posts) {
      if (mounted) {
        setState(() {
          _postsCount = posts.length;
        });
      }
    });
  }

  Future<void> _handleFollow() async {
    if (_authService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to login to follow users')),
      );
      return;
    }

    try {
      if (_isFollowing) {
        // Unfollow the user
        await _authService.unfollowUser(
          _authService.currentUser!.uid,
          widget.userId,
        );
      } else {
        // Follow the user
        await _authService.followUser(
          _authService.currentUser!.uid,
          widget.userId,
        );
      }

      // Reload the user data
      setState(() {
        _isFollowing = !_isFollowing;
        if (_isFollowing) {
          _followersCount++;
        } else {
          _followersCount--;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _showReportDialog() {
    final TextEditingController _reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Report User'),
            content: TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for reporting',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (_reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please provide a reason')),
                    );
                    return;
                  }

                  try {
                    await _authService.reportUser(
                      _authService.currentUser!.uid,
                      widget.userId,
                      _reasonController.text.trim(),
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User reported successfully'),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Report'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (widget.isCurrentUser)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () async {
                await _authService.logout();
                // Navigate to login screen or home screen
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.flag),
              onPressed: _showReportDialog,
            ),
        ],
      ),
      body: FutureBuilder<UserModel?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile header with image and stats
                        Row(
                          children: [
                            // Profile image
                            Hero(
                              tag: 'profile_${user.uid}',
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage:
                                    user.profileImageUrl.isNotEmpty
                                        ? NetworkImage(user.profileImageUrl)
                                        : null,
                                child:
                                    user.profileImageUrl.isEmpty
                                        ? const Icon(Icons.person, size: 50)
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Stats
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Posts count
                                  _buildStatColumn('Posts', _postsCount),

                                  // Followers count
                                  GestureDetector(
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => FollowersScreen(
                                                  userId: user.uid,
                                                  isFollowers: true,
                                                ),
                                          ),
                                        ),
                                    child: _buildStatColumn(
                                      'Followers',
                                      _followersCount,
                                    ),
                                  ),

                                  // Following count
                                  GestureDetector(
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => FollowersScreen(
                                                  userId: user.uid,
                                                  isFollowers: false,
                                                ),
                                          ),
                                        ),
                                    child: _buildStatColumn(
                                      'Following',
                                      _followingCount,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Username and bio
                        Text(
                          user.username,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),

                        if (user.bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(user.bio),
                          ),

                        // Relationship status / gender
                        Row(
                          children: [
                            Icon(
                              user.gender == 'male' ? Icons.male : Icons.female,
                              color: Theme.of(context).primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user.gender.toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              user.isSingle
                                  ? Icons.favorite_border
                                  : Icons.favorite,
                              color: user.isSingle ? Colors.grey : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user.isSingle ? 'Single' : 'In Relationship',
                              style: TextStyle(
                                color: user.isSingle ? Colors.grey : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Edit profile / follow button
                        SizedBox(
                          width: double.infinity,
                          child:
                              widget.isCurrentUser
                                  ? OutlinedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  EditProfileScreen(user: user),
                                        ),
                                      ).then((_) => _loadUserData());
                                    },
                                    child: const Text('Edit Profile'),
                                  )
                                  : ElevatedButton(
                                    onPressed: _handleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          _isFollowing
                                              ? Colors.grey
                                              : Theme.of(context).primaryColor,
                                    ),
                                    child: Text(
                                      _isFollowing ? 'Unfollow' : 'Follow',
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on)),
                        Tab(icon: Icon(Icons.favorite)),
                      ],
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                // Posts grid
                FutureBuilder<List<PostModel>>(
                  future: _postsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final posts = snapshot.data ?? [];
                    if (posts.isEmpty) {
                      return const Center(child: Text('No posts yet'));
                    }

                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return GestureDetector(
                          onTap: () {
                            // Navigate to post detail screen
                            // TODO: Implement post detail screen navigation
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: post.mediaUrl,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color: Colors.grey.shade300,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.error),
                                    ),
                              ),

                              if (post.isVideo)
                                const Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),

                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.favorite,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      post.likes.length.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),

                // Liked posts (to be implemented)
                Center(
                  child: Text(
                    'Liked posts feature coming soon',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
