// notification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase/notification_service.dart';
import '../../models/notification_model.dart';
import '../../utils/colors.dart';
import '../../widgets/notification_item_widget.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  bool _isMarkingAllAsRead = false;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      setState(() => _isLoading = true);

      // Initialize FCM notifications
      await _notificationService.initNotifications();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing notifications: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      setState(() => _isMarkingAllAsRead = true);

      String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception("User not authenticated");
      }

      await _notificationService.markAllNotificationsAsRead(userId);

      setState(() => _isMarkingAllAsRead = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      setState(() => _isMarkingAllAsRead = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking notifications as read: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? userId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
            onRefresh: _initializeNotifications,
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                return NotificationItemWidget(
                  notification: notifications[index],
                );
              },
            ),
          );
        },
      ),
    );
  }
}