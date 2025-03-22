import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pu_circle/widgets/common_widgets.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../screens/profile/profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final UserModel otherUser;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUser,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(
      chatId: widget.chatId,
      otherUser: widget.otherUser,
    );
    _controller.init();
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: widget.otherUser.uid,
          isCurrentUser: false,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: GestureDetector(
          onTap: _navigateToProfile,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[200],
                backgroundImage: widget.otherUser.profileImageUrl != null &&
                    widget.otherUser.profileImageUrl!.isNotEmpty
                    ? NetworkImage(widget.otherUser.profileImageUrl!)
                    : null,
                child: widget.otherUser.profileImageUrl == null ||
                    widget.otherUser.profileImageUrl!.isEmpty
                    ? Text(
                  widget.otherUser.username?.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                )
                    : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser.username ?? 'User',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Tap to view profile',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              showCustomSnackBar(context, message: "Video calling coming soon!", isError: false);
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showChatOptions();
            },
          ),
        ],
      ),
      body: StreamBuilder<ChatControllerState>(
        stream: _controller.stateStream,
        initialData: ChatControllerState(
          messages: [],
          isLoading: true,
          isSending: false,
          imageFile: null,
          isLoadingMore: false,
          hasMoreMessages: true,
        ),
        builder: (context, snapshot) {
          final state = snapshot.data!;

          return Column(
            children: [
              // Encryption banner
              _buildEncryptionBanner(),

              // Image preview if selected
              if (state.imageFile != null)
                _buildImagePreview(state.imageFile!),

              // Messages list
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.messages.isEmpty
                    ? _buildEmptyChat()
                    : _buildMessagesList(state),
              ),

              // Message input
              _buildMessageInput(state.isSending),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImagePreview(File imageFile) {
    return Container(
      height: 120,
      width: double.infinity,
      color: Colors.grey[200],
      child: Stack(
        children: [
          Center(
            child: Image.file(imageFile, height: 120, fit: BoxFit.cover),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                _controller.clearSelectedImage();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
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
            'No messages yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Start the conversation with a quick message!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              _controller.sendPredefinedMessage();
            },
            child: const Text('Send a greeting'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatControllerState state) {
    return ListView.builder(
      controller: _controller.scrollController,
      reverse: true, // Display messages from bottom to top
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.messages.length + (state.hasMoreMessages && state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Show loading indicator at the top
        if (state.hasMoreMessages && state.isLoadingMore && index == state.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final message = state.messages[index];
        final isMe = _controller.isCurrentUser(message.senderId);

        // Determine if we should show timestamp
        bool showTimestamp = true;
        if (index < state.messages.length - 1) {
          final prevMessage = state.messages[index + 1];
          final timeDiff = message.timestamp.difference(prevMessage.timestamp).inMinutes;
          showTimestamp = timeDiff > 10; // Show timestamp if more than 10 minutes between messages
        }
        return Column(
          children: [
            if (showTimestamp) _buildTimestamp(message.timestamp),
            _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  Widget _buildTimestamp(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        _formatMessageTime(timestamp, showFullDate: true),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 64 : 0,
          right: isMe ? 0 : 64,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.network(
                  message.mediaUrl!,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content ?? "", // Add null check and default empty string
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe ? Colors.white70 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isSending) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 5,
            color: Colors.black.withAlpha(10),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: TextField(
              controller: _controller.messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              onSubmitted: (_) => _controller.sendMessage(),
            ),
          ),
          IconButton(
            icon: isSending
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.send, color: AppColors.primary),
            onPressed: isSending ? null : () => _controller.sendMessage(),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptionBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Messages are end-to-end encrypted. No one outside of this chat can read or listen to them.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _controller.pickImage(source: ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _controller.pickImage(source: ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: const Text('Location'),
              onTap: () {
                Navigator.pop(context);
                showCustomSnackBar(context, message: "Location sharing coming soon!", isError: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.primary),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                _navigateToProfile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete Chat', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppColors.error),
              title: const Text('Block User', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                showCustomSnackBar(context, message: "Block feature coming soon!", isError: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _controller.deleteChat();
                Navigator.pop(context); // Return to chat list
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete conversation'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('DELETE', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime timestamp, {bool showFullDate = false}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (!showFullDate) {
      return DateFormat('h:mm a').format(timestamp);
    }

    if (messageDate == today) {
      return 'Today, ${DateFormat('h:mm a').format(timestamp)}';
    } else if (messageDate == yesterday) {
      return 'Yesterday, ${DateFormat('h:mm a').format(timestamp)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    }
  }
}