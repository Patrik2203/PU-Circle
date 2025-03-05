import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../utils/colors.dart';
import '../utils/notification_helper.dart';

class NotificationItemWidget extends StatelessWidget {
  final NotificationModel notification;

  const NotificationItemWidget({
    Key? key,
    required this.notification,
  }) : super(key: key);

  // Get time ago display text
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
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(notification.senderId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return const ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text('Loading...'),
          );
        }

        Map<String, dynamic>? userData = snapshot.data?.data() as Map<String, dynamic>?;

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

        return Container(
          color: notification.isRead ? null : Colors.grey.withOpacity(0.1),
          child: ListTile(
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
            onTap: () => NotificationHelper.handleNotificationTap(context, notification),
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          ),
        );
      },
    );
  }
}