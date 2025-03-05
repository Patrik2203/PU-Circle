import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../firebase/messaging_service.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../firebase/firestore_service.dart';
import '../../utils/colors.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final MessagingService _messagingService = MessagingService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<ChatModel> _chats = [];
  Map<String, UserModel?> _chatUsers = {};
  Map<String, int> _unreadCounts = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser!.uid;

      // Get all chats for current user
      _chats = await _messagingService.getUserChats(userId);

      // Get unread message counts
      _unreadCounts = await _messagingService.getUnreadMessageCounts(userId);

      // Load user data for each chat
      for (ChatModel chat in _chats) {
        // Find the other user's ID (not the current user)
        final otherUserId = chat.participants
            .firstWhere((id) => id != userId, orElse: () => '');

        if (otherUserId.isNotEmpty) {
          final userData = await _firestoreService.getUserData(otherUserId);
          _chatUsers[otherUserId] = userData;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading chats: $e');
      setState(() {
        _isLoading = false;
      });

      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load conversations'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _navigateToChat(ChatModel chat, UserModel otherUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chat.chatId,
          otherUser: otherUser,
        ),
      ),
    ).then((_) {
      // Refresh the chat list when returning from chat screen
      _loadChats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _chats.isEmpty
          ? _buildEmptyState()
          : _buildChatList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No Messages Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with your matches',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    final currentUserId = _auth.currentUser!.uid;

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.separated(
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final chat = _chats[index];

          // Find the other user's ID (not the current user)
          final otherUserId = chat.participants
              .firstWhere((id) => id != currentUserId, orElse: () => '');

          final otherUser = _chatUsers[otherUserId];
          final unreadCount = _unreadCounts[chat.chatId] ?? 0;

          if (otherUser == null) {
            return const SizedBox.shrink(); // Skip if user data not available
          }

          return _buildChatTile(chat, otherUser, unreadCount);
        },
      ),
    );
  }

  Widget _buildChatTile(ChatModel chat, UserModel otherUser, int unreadCount) {
    final currentUserId = _auth.currentUser!.uid;
    final isLastMessageFromMe = chat.lastMessageTimestamp != null &&
        chat.lastMessage.isNotEmpty &&
        chat.participants.contains(currentUserId);

    return ListTile(
      onTap: () => _navigateToChat(chat, otherUser),
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: otherUser.profileImageUrl != null &&
            otherUser.profileImageUrl!.isNotEmpty
            ? NetworkImage(otherUser.profileImageUrl!)
            : null,
        child: otherUser.profileImageUrl == null ||
            otherUser.profileImageUrl!.isEmpty
            ? Text(
          otherUser.username?.substring(0, 1).toUpperCase() ?? '?',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        )
            : null,
      ),
      title: Text(
        otherUser.username ?? 'User',
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        chat.lastMessage,
        style: TextStyle(
          color: unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatChatTime(chat.lastMessageTimestamp),
            style: TextStyle(
              fontSize: 12,
              color: unreadCount > 0 ? AppColors.primary : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatChatTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day
    );

    if (messageDate == today) {
      return DateFormat('h:mm a').format(timestamp);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(timestamp).inDays < 7) {
      return DateFormat('EEEE').format(timestamp); // Day name
    } else {
      return DateFormat('MMM d').format(timestamp); // Month and day
    }
  }
}