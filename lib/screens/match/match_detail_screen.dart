import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase/messaging_service.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../../utils/colors.dart';
import '../messaging/chat_screen.dart';
import '../profile/profile_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final UserModel matchedUser;

  const MatchDetailScreen({
    Key? key,
    required this.matchedUser,
  }) : super(key: key);

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _chatRoomId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getChatRoomId();
  }

  Future<void> _getChatRoomId() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = _auth.currentUser!.uid;
      final otherUserId = widget.matchedUser.uid;

      // Find the chat room between these two users
      final querySnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in querySnapshot.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(otherUserId)) {
          _chatRoomId = doc.id;
          break;
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _startChat() async {
    if (_chatRoomId != null) {
      // Navigate to chat screen if chat room exists
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: _chatRoomId!,
            otherUser: widget.matchedUser,
          ),
        ),
      );
    } else {
      // Should never happen since matches auto-create chat rooms
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Chat room not found')),
      );
    }
  }

  Future<void> _sendPredefinedMessage() async {
    if (_chatRoomId == null) {
      return;
    }

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        final message = 'Wanna meet at PU Circle or on a tea post?';

        // Create message document
        await _firestore.collection('chats').doc(_chatRoomId).collection('messages').add({
          'text': message,
          'senderId': currentUser.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });

        // Update last message in chat document
        await _firestore.collection('chats').doc(_chatRoomId).update({
          'lastMessage': message,
          'lastMessageSenderId': currentUser.uid,
          'lastMessageTimestamp': FieldValue.serverTimestamp(),
        });

        // Navigate to chat
        _startChat();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _viewProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: widget.matchedUser.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.matchedUser;
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(user.username),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Profile image
                  user.profileImageUrl.isNotEmpty
                      ? Image.network(
                    user.profileImageUrl,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: AppColors.primary.withOpacity(0.7),
                    child: Center(
                      child: Text(
                        user.username.isNotEmpty
                            ? user.username[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Gradient overlay for better text visibility
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                        ],
                        stops: [0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble),
                onPressed: _startChat,
                tooltip: 'Start Chat',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bio section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.bio.isNotEmpty
                              ? user.bio
                              : 'No bio available',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Interests section if interests are available
                  if (user.interests.isNotEmpty) ...[
                    Text(
                      'Interests',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.interests.map((interest) {
                        return Chip(
                          label: Text(interest),
                          backgroundColor: AppColors.primaryLight.withOpacity(0.2),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Predefined message button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Break the ice',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a predefined message to start the conversation',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _sendPredefinedMessage,
                          borderRadius: BorderRadius.circular(12.0),
                          child: Container(
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: AppColors.accent,
                                width: 1.0,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColors.accent,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Wanna meet at PU Circle or on a tea post?',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.send,
                                  color: AppColors.accent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _viewProfile,
                  icon: const Icon(Icons.person),
                  label: const Text('View Profile'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startChat,
                  icon: const Icon(Icons.chat),
                  label: const Text('Start Chat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}