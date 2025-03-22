import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../firebase/cloudinary_service.dart';
import '../../firebase/messaging_service.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';

class ChatController {
  final String chatId;
  final UserModel otherUser;
  final TextEditingController messageController = TextEditingController();
  final MessagingService messagingService = MessagingService();
  final CloudinaryService cloudinaryService = CloudinaryService();
  final FirebaseAuth auth = FirebaseAuth.instance;
  final ScrollController scrollController = ScrollController();
  final ImagePicker imagePicker = ImagePicker();
  late StreamSubscription<QuerySnapshot> messagesSubscription;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final int pageSize = 20; // Number of messages to load at once
  DocumentSnapshot? lastDocument; // To keep track of the last document for pagination
  bool isLoadingMore = false; // Flag to prevent multiple loading calls
  bool hasMoreMessages = true; // Flag to check if there are more messages to load

  List<MessageModel> messages = [];
  bool isLoading = true;
  bool isSending = false;
  File? imageFile;

  // Stream controller to notify UI of state changes
  final StreamController<ChatControllerState> _stateController = StreamController<ChatControllerState>.broadcast();
  Stream<ChatControllerState> get stateStream => _stateController.stream;

  ChatController({
    required this.chatId,
    required this.otherUser,
  }) {
    _setupScrollListener();
  }

  void _setupScrollListener() {
    scrollController.addListener(() {
      // Only attempt to load more if:
      // 1. We're near the top of the list (remember it's reversed)
      // 2. We're not already loading
      // 3. We believe there are more messages
      // 4. The list is actually scrollable (has more content than viewport)
      if (scrollController.hasClients &&
          scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200 &&
          !isLoadingMore &&
          hasMoreMessages &&
          scrollController.position.maxScrollExtent > scrollController.position.viewportDimension) {
        loadMoreMessages();
      }
    });
  }

  void init() {
    loadMessages();
    markMessagesAsRead();
  }

  Future<void> loadMessages() async {
    isLoading = true;
    _notifyStateChange();

    try {
      // Initial query to get the first batch of messages
      Query query = firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(pageSize);

      // Set up a stream listener for real-time updates of the latest messages
      messagesSubscription = query.snapshots().listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final loadedMessages = snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['messageId'] = doc.id;
            return MessageModel.fromMap(data);
          }).toList();

          // If this is the first load, set the last document for pagination
          if (lastDocument == null && snapshot.docs.isNotEmpty) {
            lastDocument = snapshot.docs.last;

            // Check if we might have more messages
            hasMoreMessages = snapshot.docs.length >= pageSize;
          }

          messages = loadedMessages;
          isLoading = false;
          _notifyStateChange();

          // Mark messages as read
          markMessagesAsRead();

          // Scroll to bottom on new messages if near bottom
          if (scrollController.hasClients &&
              (scrollController.position.pixels < 100 || scrollController.position.atEdge)) {
            scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        } else {
          messages = [];
          isLoading = false;
          hasMoreMessages = false;
          _notifyStateChange();
        }
      });
    } catch (e) {
      isLoading = false;
      hasMoreMessages = false;
      _notifyStateChange();
      throw Exception('Failed to load messages');
    }
  }

  Future<void> loadMoreMessages() async {
    if (!hasMoreMessages || isLoadingMore || lastDocument == null) {
      isLoadingMore = false;
      hasMoreMessages = false; // Make sure to set this to false
      _notifyStateChange();
      return;
    }

    isLoadingMore = true;
    _notifyStateChange();

    try {
      // Add a small delay to prevent rapid consecutive calls
      await Future.delayed(Duration(milliseconds: 300));

      // Query for the next batch of messages
      final query = firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(lastDocument!)
          .limit(pageSize);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        hasMoreMessages = false;
        isLoadingMore = false;
        _notifyStateChange();
        return;
      }

      final newMessages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['messageId'] = doc.id;
        return MessageModel.fromMap(data);
      }).toList();

      messages.addAll(newMessages);
      lastDocument = snapshot.docs.last;
      isLoadingMore = false;
      _notifyStateChange();
    } catch (e) {
      isLoadingMore = false;
      hasMoreMessages = false; // Set to false on error too
      _notifyStateChange();
      throw Exception('Failed to load more messages');
    }
  }

  Future<void> markMessagesAsRead() async {
    try {
      final userId = auth.currentUser!.uid;
      await messagingService.markMessagesAsRead(chatId, userId);
    } catch (e) {
      //TODO
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();

    if (text.isEmpty && imageFile == null) return;

    isSending = true;
    _notifyStateChange();

    try {
      final userId = auth.currentUser!.uid;

      if (imageFile != null) {
        // Upload image using CloudinaryService
        final imageUrl = await cloudinaryService.uploadChatImage(imageFile!);

        // Send message with image
        await messagingService.sendMessage(
          chatId: chatId,
          senderId: userId,
          content: text.isNotEmpty ? text : 'Sent an image',
          mediaUrl: imageUrl,
          isImage: true,
        );

        imageFile = null;
      } else {
        // Send text message
        await messagingService.sendMessage(
          chatId: chatId,
          senderId: userId,
          content: text,
        );
      }

      messageController.clear();
    } catch (e) {
      throw Exception('Failed to send message');
    } finally {
      isSending = false;
      _notifyStateChange();
    }
  }

  Future<void> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final pickedFile = await imagePicker.pickImage(source: source);

      if (pickedFile != null) {
        imageFile = File(pickedFile.path);
        _notifyStateChange();
      }
    } catch (e) {
      throw Exception('Failed to pick image');
    }
  }

  void clearSelectedImage() {
    imageFile = null;
    _notifyStateChange();
  }

  Future<void> sendPredefinedMessage() async {
    try {
      final userId = auth.currentUser!.uid;
      await messagingService.sendPredefinedMessage(
        chatId: chatId,
        senderId: userId,
      );
    } catch (e) {
      throw Exception('Failed to send message');
    }
  }

  Future<void> deleteChat() async {
    try {
      await messagingService.deleteChat(chatId);
    } catch (e) {
      throw Exception('Failed to delete conversation');
    }
  }

  bool isCurrentUser(String senderId) {
    return senderId == auth.currentUser!.uid;
  }

  void _notifyStateChange() {
    _stateController.add(
      ChatControllerState(
        messages: messages,
        isLoading: isLoading,
        isSending: isSending,
        imageFile: imageFile,
        isLoadingMore: isLoadingMore,
        hasMoreMessages: hasMoreMessages,
      ),
    );
  }

  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    messagesSubscription.cancel();
    _stateController.close();
  }
}

class ChatControllerState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isSending;
  final File? imageFile;
  final bool isLoadingMore;
  final bool hasMoreMessages;

  ChatControllerState({
    required this.messages,
    required this.isLoading,
    required this.isSending,
    required this.imageFile,
    required this.isLoadingMore,
    required this.hasMoreMessages,
  });
}