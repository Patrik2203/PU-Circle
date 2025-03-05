import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase/notification_service.dart';
import '../utils/colors.dart';

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final double top;
  final double right;
  final double badgeSize;

  const NotificationBadge({
    Key? key,
    required this.child,
    this.top = -5,
    this.right = -5,
    this.badgeSize = 18,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final NotificationService _notificationService = NotificationService();
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        StreamBuilder<int>(
          stream: _notificationService
              .streamUserNotifications(userId)
              .map((notifications) => notifications
              .where((notification) => !notification.isRead)
              .length),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == 0) {
              return const SizedBox.shrink();
            }

            final count = snapshot.data ?? 0;

            return Positioned(
              top: top,
              right: right,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                decoration: const BoxDecoration(
                  color: AppColors.like,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}