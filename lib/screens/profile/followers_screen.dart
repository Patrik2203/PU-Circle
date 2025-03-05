import 'package:flutter/material.dart';
import '../../firebase/firestore_service.dart';
import '../../firebase/auth_service.dart';
import '../../models/user_model.dart';
import 'profile_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final bool isFollowers; // true for followers, false for following

  const FollowersScreen({
    Key? key,
    required this.userId,
    required this.isFollowers,
  }) : super(key: key);

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() {
    if (widget.isFollowers) {
      _usersFuture = _firestoreService.getFollowers(widget.userId);
    } else {
      _usersFuture = _firestoreService.getFollowing(widget.userId);
    }
  }

  Future<void> _handleFollowToggle(UserModel user) async {
    if (_authService.currentUser == null) return;

    final currentUserId = _authService.currentUser!.uid;
    final isFollowing = user.followers.contains(currentUserId);

    try {
      if (isFollowing) {
        await _authService.unfollowUser(currentUserId, user.uid);
      } else {
        await _authService.followUser(currentUserId, user.uid);
      }
      // Reload the users list
      setState(() {
        _loadUsers();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFollowers ? 'Followers' : 'Following'),
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(
              child: Text(
                widget.isFollowers ? 'No followers yet' : 'Not following anyone',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final bool isCurrentUser = user.uid == _authService.currentUser?.uid;
              final bool isFollowing = user.followers.contains(_authService.currentUser?.uid);

              return ListTile(
                leading: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                          userId: user.uid,
                          isCurrentUser: isCurrentUser,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: user.profileImageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(user.profileImageUrl)
                        : null,
                    child: user.profileImageUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                title: Text(user.username),
                subtitle: Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: isCurrentUser
                    ? null
                    : TextButton(
                  onPressed: () => _handleFollowToggle(user),
                  style: TextButton.styleFrom(
                    backgroundColor: isFollowing
                        ? Colors.grey.shade200
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isFollowing
                            ? Colors.grey
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  child: Text(
                    isFollowing ? 'Unfollow' : 'Follow',
                    style: TextStyle(
                      color: isFollowing
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: user.uid,
                        isCurrentUser: isCurrentUser,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}