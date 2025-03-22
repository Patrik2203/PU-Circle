import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import 'notification_service.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Get all chat rooms for a user
  Future<List<ChatModel>> getUserChats(String userId) async {
    try {
      QuerySnapshot chatSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTimestamp', descending: true)
          .get();

      return chatSnapshot.docs
          .map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['chatId'] = doc.id;
        return ChatModel.fromMap(data);
      })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get messages for a specific chat
  Future<List<MessageModel>> getChatMessages(String chatId) async {
    try {
      QuerySnapshot messageSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();

      return messageSnapshot.docs
          .map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['messageId'] = doc.id;
        return MessageModel.fromMap(data);
      })
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String content,
    String? mediaUrl,
    bool isImage = false,
  }) async {
    try {
      // Get chat to identify the receiver
      DocumentSnapshot chatDoc = await _firestore.collection('chats').doc(chatId).get();
      List<dynamic> participants = (chatDoc.data() as Map<String, dynamic>)['participants'];

      // Find the receiver (the other participant)
      String receiverId = participants.firstWhere((id) => id != senderId, orElse: () => '');

      if (receiverId.isEmpty) {
        throw Exception('Receiver not found');
      }

      // Create message
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': senderId,
        'content': content,
        'mediaUrl': mediaUrl,
        'isImage': isImage,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update chat with last message info
      await _firestore.collection('chats').doc(chatId).update({
        'lastMessage': isImage ? 'Sent an image' : content,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
      });

      // Send notification to receiver
      await _notificationService.sendMessageNotification(
        receiverId,
        senderId,
        isImage ? 'Sent you an image' : content,
        chatId,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Send a predefined message
  Future<void> sendPredefinedMessage({
    required String chatId,
    required String senderId,
  }) async {
    try {
      const String predefinedMessage = "Wanna meet at PU Circle or on a tea post?";
      await sendMessage(
        chatId: chatId,
        senderId: senderId,
        content: predefinedMessage,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Get all unread messages sent by the other user
      QuerySnapshot unreadMessages = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      // Update each message to read=true
      WriteBatch batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Get unread message counts for a user
  Future<Map<String, int>> getUnreadMessageCounts(String userId) async {
    try {
      Map<String, int> unreadCounts = {};

      // Get all chats for the user
      List<ChatModel> userChats = await getUserChats(userId);

      for (var chat in userChats) {
        // Get unread messages from other participants
        QuerySnapshot unreadMessages = await _firestore
            .collection('chats')
            .doc(chat.chatId)
            .collection('messages')
            .where('senderId', isNotEqualTo: userId)
            .where('read', isEqualTo: false)
            .get();

        unreadCounts[chat.chatId] = unreadMessages.docs.length;
      }

      return unreadCounts;
    } catch (e) {
      rethrow;
    }
  }

  // Delete a chat
  Future<void> deleteChat(String chatId) async {
    try {
      // Delete all messages in the chat
      QuerySnapshot messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      WriteBatch batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the chat document
      batch.delete(_firestore.collection('chats').doc(chatId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Add this method to generate or retrieve a chat ID for two users
  Future<String?> getChatIdForUsers(String userId1, String userId2) async {
    try {
      // Sort the user IDs to ensure consistency
      final List<String> userIds = [userId1, userId2]..sort();

      // Create a unique chat ID based on the sorted user IDs
      final String chatId = 'chat_${userIds[0]}_${userIds[1]}';

      // Check if the chat already exists in Firestore
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        // If the chat doesn't exist, create a new chat document
        await _firestore.collection('chats').doc(chatId).set({
          'participants': userIds,
          'lastMessage': 'Say hello!',
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
        });
      }

      return chatId;
    } catch (e) {
      rethrow;
    }
  }
}