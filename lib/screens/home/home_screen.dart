import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pu_circle/screens/admin/user_management.dart';
import 'package:pu_circle/screens/auth/login_screen.dart'; // Import the login screen directly
import 'package:pu_circle/screens/home/search_screen.dart';
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
  bool _isLoggingOut = false;

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
          _navigateToLogin();
        }
        return;
      }

      print("DEBUG: Attempting to get user data for $currentUserId");
      final userData = await _authService.getUserData(currentUserId);

      if (userData == null) {
        print("DEBUG: No user data found for $currentUserId");
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
        showCustomSnackBar(
            context,
            message: 'Error loading data: ${e.toString()}',
            isError: true
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

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
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
      if (mounted) {
        showCustomSnackBar(
            context,
            message: 'Error loading posts: ${e.toString()}',
            isError: true
        );
      }
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

  Future<void> _handleLogout() async {
    // Prevent double-tapping the logout button
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
      if (!mounted) return;
      _navigateToLogin();
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(
          context,
          message: 'Error logging out: ${e.toString()}',
          isError: true
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  Widget _buildEmptyPostsView() {
    return EmptyStateWidget(
      message: 'No posts yet. Follow more users or create a post to see content here.',
      icon: Icons.sentiment_dissatisfied,
      actionText: 'Create Post',
      onAction: _navigateToCreatePost,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingSpinner(text: 'Loading posts...');
    }

    if (_posts.isEmpty) {
      return _buildEmptyPostsView();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primary,
      backgroundColor: AppColors.cardBackground,
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

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Add null check for _currentUser
    if (_currentUser == null) {
      return const Scaffold(
        body: LoadingSpinner(text: 'Loading user data...'),
      );
    }

    final List<Widget> _screens = [
      _buildHomeScreen(),
      const MatchScreen(),
      const SizedBox(), // Placeholder for FAB
      const ChatListScreen(),
      ProfileScreen(userId: _currentUser!.uid),
    ];

    return Scaffold(
      appBar: _currentIndex == 0 ? _buildAppBar() : null,
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
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
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

  PreferredSizeWidget _buildAppBar() {
    return CustomAppBar(
      title: 'PU Circle',
      showBackButton: false,
      backgroundColor: Colors.black,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: AppColors.primary),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SearchScreen(),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
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
          icon: _isLoggingOut
              ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          )
              : const Icon(Icons.logout, color: AppColors.primary),
          onPressed: _isLoggingOut ? null : _handleLogout,
        ),
      ],
    );
  }

  Widget _buildHomeScreen() {
    return _buildBody();
  }
}