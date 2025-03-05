import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/firestore_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../widgets/post_widget.dart';
import '../../widgets/common_widgets.dart';
import 'create_post_screen.dart';
import '../match/match_screen.dart';
import '../messaging/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notification_screen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, UserModel> _postOwners = {};
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  int _currentIndex = 0;
  UserModel? _currentUser;
  bool _isLoading = true;
  List<PostModel> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = _authService.currentUser?.uid;
      if (currentUserId == null) {
        print("DEBUG: No current user found");
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
        return;
      }

      print("DEBUG: Attempting to get user data for $currentUserId");
      final userData = await _authService.getUserData(currentUserId);

      if (userData == null) {
        print("DEBUG: No user data found for $currentUserId");
        // Create default profile logic
        await _authService.createDefaultUserProfile(currentUserId);

        final retryData = await _authService.getUserData(currentUserId);
        if (retryData == null) {
          print("DEBUG: Failed to create user profile");
          throw Exception('Failed to create user profile');
        }
        _currentUser = retryData;
      } else {
        _currentUser = userData;
      }

      // Load posts
      await _loadPosts();
    } catch (e) {
      print("DEBUG: Full error in _loadUserData: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  Future<void> _loadPosts() async {
    if (_currentUser == null) return;
    try {
      // Get posts from following users
      final posts = await _firestoreService.getHomeFeedPosts(_currentUser!.uid);

      // Create a map of post owners
      Map<String, UserModel> postOwners = {};
      for (var post in posts) {
        if (!postOwners.containsKey(post.userId)) {
          final userData = await _firestoreService.getUserData(post.userId);
          if (userData != null) {
            postOwners[post.userId] = userData;
          }
        }
      }

      if (mounted) {
        setState(() {
          _posts = posts;
          _postOwners = postOwners;
        });
      }
    } catch (e) {
      print("Error loading posts: $e");
    }
  }


  Future<void> _refreshData() async {
    await _loadPosts();
  }

  void _navigateToCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          onPostCreated: _refreshData,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.staggeredDotsWave(
          color: AppColors.primary,
          size: 40,
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sentiment_dissatisfied,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Follow more users or create a post to see content here',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _navigateToCreatePost,
              child: const Text('Create Post'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          final postOwner = _postOwners[post.userId] ?? _currentUser!;
          return PostWidget(
            post: post,
            postOwner: postOwner,
            onRefresh: _refreshData,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Add null check for _currentUser
    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<Widget> _screens = [
      _buildBody(),
      const MatchScreen(),
      const SizedBox(), // Placeholder for FAB
      const ChatListScreen(),
      ProfileScreen(userId: _currentUser!.uid),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PU Circle',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await _authService.logout();
                if (!mounted) return;

                // Navigate back to login screen
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                      (route) => false,
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error logging out: ${e.toString()}')),
                );
              }
            },
          ),
        ],
      ),
      body: _screens[_currentIndex] == const SizedBox()
          ? _screens[0] // Show home screen if FAB placeholder is selected
          : _screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex == 2 ? 0 : _currentIndex,
        onTap: (index) {
          // Handle center button (index 2) separately
          if (index == 2) {
            _navigateToCreatePost();
          } else {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Match',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Post',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}