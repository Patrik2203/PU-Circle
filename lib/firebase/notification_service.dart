import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Initialize notifications and request permissions// Update the initNotifications method to call setupNotificationHandling
  Future<void> initNotifications() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await _messaging.getToken();
        if (token != null && _auth.currentUser != null) {
          await _firestore.collection('users').doc(_auth.currentUser!.uid).update({
            'fcmToken': token,
          });
        }

        _messaging.onTokenRefresh.listen((newToken) {
          if (_auth.currentUser != null) {
            _firestore.collection('users').doc(_auth.currentUser!.uid).update({
              'fcmToken': newToken,
            });
          }
        });

        // Set up messaging handlers
        // await setupNotificationHandling();
      }
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  // Get all notifications for a user
  Future<List<NotificationModel>> getUserNotifications(String userId) async {
    try {
      QuerySnapshot notificationSnapshot = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return notificationSnapshot.docs.map((doc) {
        return NotificationModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      QuerySnapshot notifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        await doc.reference.update({'isRead': true});
      }
    } catch (e) {
      rethrow;
    }
  }

  // Send a notification
  Future<void> sendNotification(NotificationModel notification) async {
    try {
      await _firestore.collection('notifications').add(notification.toMap());

      // Get receiver's FCM token for push notification
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(notification.receiverId).get();
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        String? fcmToken = userData['fcmToken'];
        if (fcmToken != null && fcmToken.isNotEmpty) {
          // Here you would typically send a push notification using Firebase Cloud Functions
          // or a server endpoint. For client-side implementation, we'll just log it.
          print('Would send push notification to token: $fcmToken');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Stream notifications in real-time
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Send a match notification (called from MatchService)
  Future<void> sendMatchNotification(
      String receiverId,
      String senderId,
      String message,
      ) async {
    try {
      // Find or create match document ID
      QuerySnapshot matchSnapshot = await _firestore
          .collection('matches')
          .where('userId1', isEqualTo: senderId)
          .where('userId2', isEqualTo: receiverId)
          .get();

      String? matchId;
      if (matchSnapshot.docs.isNotEmpty) {
        matchId = matchSnapshot.docs.first.id;
      } else {
        // Check the other way around
        QuerySnapshot reverseMatchSnapshot = await _firestore
            .collection('matches')
            .where('userId1', isEqualTo: receiverId)
            .where('userId2', isEqualTo: senderId)
            .get();

        if (reverseMatchSnapshot.docs.isNotEmpty) {
          matchId = reverseMatchSnapshot.docs.first.id;
        }
      }

      // Create notification
      NotificationModel notification = NotificationModel(
        id: '',
        type: 'match',
        receiverId: receiverId,
        senderId: senderId,
        matchId: matchId,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await sendNotification(notification);
    } catch (e) {
      rethrow;
    }
  }

  // Send an algorithm match notification
  Future<void> sendAlgorithmMatchNotification(
      String receiverId,
      String senderId,
      String matchId,
      ) async {
    try {
      // Create notification
      NotificationModel notification = NotificationModel(
        id: '',
        type: 'algorithmMatch',
        receiverId: receiverId,
        senderId: senderId,
        matchId: matchId,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await sendNotification(notification);
    } catch (e) {
      rethrow;
    }
  }

  // Send a message notification (called from MessagingService)
  Future<void> sendMessageNotification(
      String receiverId,
      String senderId,
      String message,
      String chatId,
      ) async {
    try {
      // For messages, we don't need to set postId or matchId
      // But we could store the chatId in a custom field if needed in the future

      // Create notification
      NotificationModel notification = NotificationModel(
        id: '',
        type: 'message',
        receiverId: receiverId,
        senderId: senderId,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await sendNotification(notification);
    } catch (e) {
      rethrow;
    }
  }

  // Send a like notification
  Future<void> sendLikeNotification(
      String receiverId,
      String senderId,
      String postId,
      ) async {
    try {
      // Create notification
      NotificationModel notification = NotificationModel(
        id: '',
        type: 'like',
        receiverId: receiverId,
        senderId: senderId,
        postId: postId,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await sendNotification(notification);
    } catch (e) {
      rethrow;
    }
  }

  // Send a follow notification
  Future<void> sendFollowNotification(
      String receiverId,
      String senderId,
      ) async {
    try {
      // Create notification
      NotificationModel notification = NotificationModel(
        id: '',
        type: 'follow',
        receiverId: receiverId,
        senderId: senderId,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await sendNotification(notification);
    } catch (e) {
      rethrow;
    }
  }

  // Delete notifications related to a post
  Future<void> deletePostNotifications(String postId) async {
    try {
      QuerySnapshot notifications = await _firestore
          .collection('notifications')
          .where('postId', isEqualTo: postId)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Delete notifications related to a match
  Future<void> deleteMatchNotifications(String matchId) async {
    try {
      QuerySnapshot notifications = await _firestore
          .collection('notifications')
          .where('matchId', isEqualTo: matchId)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Delete all notifications from a specific sender
  Future<void> deleteSenderNotifications(String senderId) async {
    try {
      QuerySnapshot notifications = await _firestore
          .collection('notifications')
          .where('senderId', isEqualTo: senderId)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Get unread notification count
  Future<int> getUnreadNotificationCount(String userId) async {
    try {
      QuerySnapshot unreadNotifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return unreadNotifications.docs.length;
    } catch (e) {
      rethrow;
    }
  }


// Stream for unread notification count
  Stream<int> streamUnreadNotificationCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

// Stream grouped notifications
  Stream<Map<String, List<NotificationModel>>> streamGroupedNotifications(String userId) {
    return streamUserNotifications(userId).map((notifications) {
      Map<String, List<NotificationModel>> grouped = {
        'today': [],
        'earlier': [],
      };

      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      for (var notification in notifications) {
        DateTime notificationDate = DateTime(
          notification.timestamp.year,
          notification.timestamp.month,
          notification.timestamp.day,
        );

        if (notificationDate.isAtSameMomentAs(today)) {
          grouped['today']!.add(notification);
        } else {
          grouped['earlier']!.add(notification);
        }
      }

      return grouped;
    });
  }

// Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      QuerySnapshot receivedNotifications = await _firestore
          .collection('notifications')
          .where('receiverId', isEqualTo: userId)
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in receivedNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

//   // Setup for handling foreground and background messages
//   Future<void> setupNotificationHandling() async {
//     // Set up foreground notification presentation options
//     await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
//       alert: true,
//       badge: true,
//       sound: true,
//     );
//
//     // Initialize the local notifications plugin
//     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();
//
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const DarwinInitializationSettings initializationSettingsIOS =
//     DarwinInitializationSettings();
//
//     const InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );
//
//     await flutterLocalNotificationsPlugin.initialize(initializationSettings);
//
//     // Handle foreground messages
//     FirebaseMessaging.onMessage.listen((RemoteMessage message) {
//       print('Got a message whilst in the foreground!');
//       print('Message data: ${message.data}');
//
//       if (message.notification != null) {
//         print('Message also contained a notification: ${message.notification}');
//
//         // Show a local notification
//         _showLocalNotification(
//           flutterLocalNotificationsPlugin,
//           message.notification?.title ?? 'New Notification',
//           message.notification?.body ?? '',
//           message.data,
//         );
//       }
//     });
//
//     // Get initial message if app was opened from a terminated state
//     RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
//     if (initialMessage != null) {
//       _handleMessage(initialMessage);
//     }
//
//     // Handle background/terminated messages
//     FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
//   }
//
// // Handle notification data when user taps on notification
//   void _handleMessage(RemoteMessage message) {
//     // Process the message data based on the notification type
//     if (message.data.containsKey('type')) {
//       String type = message.data['type'];
//       String? notificationId = message.data['notificationId'];
//
//       if (notificationId != null) {
//         // Mark the notification as read since user tapped on it
//         markNotificationAsRead(notificationId);
//       }
//
//       // Navigation is handled by the NotificationHelper class
//       // The app automatically navigates to the correct screen based on the message data
//     }
//   }
//
// // Show a local notification when the app is in foreground
//   Future<void> _showLocalNotification(
//       FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin,
//       String title,
//       String body,
//       Map<String, dynamic> payload,
//       ) async {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//     AndroidNotificationDetails(
//       'your_channel_id',
//       'Your Channel Name',
//       channelDescription: 'Your channel description',
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//
//     const NotificationDetails platformChannelSpecifics =
//     NotificationDetails(android: androidPlatformChannelSpecifics);
//
//     await flutterLocalNotificationsPlugin.show(
//       0,
//       title,
//       body,
//       platformChannelSpecifics,
//       payload: payload.toString(),
//     );
//   }

}