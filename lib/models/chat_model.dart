import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final Map<String, int> unreadCount;

  ChatModel({
    required this.chatId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.unreadCount,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      chatId: map['chatId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTimestamp: (map['lastMessageTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp,
      'unreadCount': unreadCount,
    };
  }
}

class MessageModel {
  final String messageId;
  final String senderId;
  final String content;
  final String? mediaUrl;
  final DateTime timestamp;
  final bool isRead;
  final bool isPreDefined; // Add this line

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.content,
    this.mediaUrl,
    required this.timestamp,
    required this.isRead,
    this.isPreDefined = false, // Add this with a default value
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      mediaUrl: map['mediaUrl'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['isRead'] ?? false,
      isPreDefined: map['isPreDefined'] ?? false, // Add this
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'content': content,
      'mediaUrl': mediaUrl,
      'timestamp': timestamp,
      'isRead': isRead,
      'isPreDefined': isPreDefined, // Add this
    };
  }
}