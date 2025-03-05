import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/firestore_service.dart';
import '../../firebase/notification_service.dart';
import '../../models/notification_model.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../widgets/common_widgets.dart';
import '../profile/profile_screen.dart';
import '../home/post_detail_screen.dart';
import '../match/match_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  bool _isMarkingAllAsRead = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      // Mark as loading
      setState(() {
        _isLoading = true;
      });

      // Get current user ID
      String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception("User not authenticated");
      }

      // Data has been loaded
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Handle errors
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: ${e.toString()}')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      setState(() {
        _isMarkingAllAsRead = true;
      });

      String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception("User not authenticated");
      }

      await _notificationService.markAllNotificationsAsRead(userId);

      setState(() {
        _isMarkingAllAsRead = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (e) {
      setState(() {
        _isMarkingAllAsRead = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking notifications as read: ${e.toString()}')),
      );
    }
  }

  Future<void> _onNotificationTap(NotificationModel notification) async {
    // Mark notification as read
    await _notificationService.markNotificationAsRead(notification.id);

    // Navigate based on notification type
    switch (notification.type) {
      case 'follow':
      // Navigate to profile screen
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: notification.senderId),
          ),
        );
        break;
      case 'like':
      // Navigate to post detail
        if (notification.postId != null && mounted) {
          // Fetch full post data first
          final post = await FirestoreService().getPost(notification.postId!);
          if (post != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(post: post), // Pass PostModel
              ),
            );
          }
        }
        break;
      case 'match':
      case 'algorithmMatch':
      // Navigate to match detail
      if (notification.matchId != null && mounted) {
        // Fetch user data first
        final user = await AuthService().getUserData(notification.matchId!);
        if (user != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailScreen(matchedUser: user), // Pass UserModel
            ),
          );
        }
      }
      break;
      case 'message':
      // Already handled by navigation to chat from message notification
        break;
      default:
        break;
    }
  }

  Future<Widget> _buildNotificationItem(NotificationModel notification) async {
    // Get sender user info
    DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(notification.senderId).get();
    Map<String, dynamic>? userData = userSnapshot.data() as Map<String, dynamic>?;

    String username = userData?['username'] ?? 'User';
    String profileImageUrl = userData?['profileImageUrl'] ?? '';

    // Format timestamp
    String timeAgo = _getTimeAgo(notification.timestamp);

    // Build notification content based on type
    String content = '';
    IconData iconData = Icons.notifications;
    Color iconColor = AppColors.primary;

    switch (notification.type) {
      case 'follow':
        content = '$username started following you';
        iconData = Icons.person_add;
        iconColor = AppColors.follow;
        break;
      case 'like':
        content = '$username liked your post';
        iconData = Icons.favorite;
        iconColor = AppColors.like;
        break;
      case 'match':
        content = 'You matched with $username!';
        iconData = Icons.favorite;
        iconColor = AppColors.match;
        break;
      case 'algorithmMatch':
        content = 'The algorithm matched you with $username!';
        iconData = Icons.favorite;
        iconColor = AppColors.match;
        break;
      case 'message':
        content = '$username sent you a message';
        iconData = Icons.message;
        iconColor = AppColors.primary;
        break;
      default:
        content = 'New notification from $username';
        break;
    }

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: profileImageUrl.isNotEmpty
                ? NetworkImage(profileImageUrl)
                : const AssetImage('assets/images/default_profile.png') as ImageProvider,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ],
      ),
      title: Text(
        content,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        timeAgo,
        style: TextStyle(
          color: Colors.grey,
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      trailing: !notification.isRead
          ? Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      )
          : null,
      onTap: () => _onNotificationTap(notification),
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    String? userId = _auth.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (!_isMarkingAllAsRead)
            IconButton(
              icon: const Icon(Icons.done_all),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            )
          else
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : userId == null
          ? const Center(child: Text('Please login to view notifications'))
          : StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.streamUserNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You\'ll see notifications for likes, follows and matches here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          List<NotificationModel> notifications = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _fetchInitialData,
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                return FutureBuilder<Widget>(
                  future: _buildNotificationItem(notifications[index]),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const ListTile(
                        leading: CircleAvatar(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        title: Text('Loading...'),
                      );
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return const ListTile(
                        title: Text('Error loading notification'),
                      );
                    }

                    return snapshot.data!;
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}