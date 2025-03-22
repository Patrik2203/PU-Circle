import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pu_circle/screens/admin/user_management.dart';
import 'package:pu_circle/screens/auth/login_screen.dart';
import 'package:pu_circle/screens/home/search_screen.dart';

import '../../controllers/home_controller.dart';
import '../../firebase/auth_service.dart';
import '../../models/post_model.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_appBar.dart';
import '../../widgets/post_widget.dart';
import '../../widgets/common_widgets.dart';
import 'create_post_screen.dart';
import '../match/match_screen.dart';
import '../messaging/chat_list_screen.dart';
import '../profile/profile_screen.dart';
import '../notifications/notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  // Keep widget state alive when switching tabs
  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  int _currentIndex = 0;
  late HomeController _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    // Create controller
    _controller = HomeController();

    // Check if user is authenticated
    if (!_controller.checkAuthStatus()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToLogin();
      });
      return;
    }

    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.loadUserData(context);
    });
  }

  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  void _navigateToCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreatePostScreen(
          onPostCreated: () => _controller.refreshData(),
        ),
      ),
    );
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
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        // If there are no posts from following users
        if (controller.posts.isEmpty) {
          if (controller.isEmptyFollowingFeed) {
            // Load random posts if the feed is empty
            // controller.loadRandomPostsForEmptyFeed();
            return _buildEmptyPostsView();
          } else {
            return _buildEmptyPostsView();
          }
        }

        return RefreshIndicator(
          onRefresh: () => controller.refreshData(),
          color: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          child: Stack(
            children: [
              ListView.builder(
                controller: controller.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: controller.posts.length + 1, // +1 for loading indicator or message
                itemBuilder: (context, index) {
                  if (index < controller.posts.length) {
                    final post = controller.posts[index];
                    final postOwner = controller.postOwners[post.userId] ?? controller.currentUser!;

                    // Use a more efficient post widget that doesn't trigger full refreshes
                    return PostWidget(
                      key: ValueKey(post.postId), // Key for optimized rebuilds
                      post: post,
                      postOwner: postOwner,
                      onRefresh: () => controller.updatePost(post), // Just update this post
                    );
                  } else {
                    // Footer widget
                    if (controller.isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            strokeWidth: 2.0,
                          ),
                        ),
                      );
                    } else if (controller.isShowingRandomPosts) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            "Showing posts from around PU Circle",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    } else if (!controller.hasMorePosts) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: Text(
                            "You're all caught up!",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox(height: 50);
                  }
                },
              ),

              // Transition message overlay
              if (controller.showTransitionMessage)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(90),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        controller.transitionMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // For AutomaticKeepAliveClientMixin

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // Provide the controller to the widget tree
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<HomeController>(
        builder: (context, controller, child) {
          if (controller.currentUser == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          }

          final List<Widget> _screens = [
            _buildHomeScreen(),
            const MatchScreen(),
            const SizedBox(), // Placeholder for FAB
            const ChatListScreen(),
            ProfileScreen(userId: controller.currentUser!.uid),
          ];

          return Scaffold(
            appBar: _currentIndex == 0 ? _buildAppBar() : null,
            body: _screens[_currentIndex] == const SizedBox()
                ? _screens[0] // Show home screen if FAB placeholder is selected
                : _screens[_currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex == 2 ? 0 : _currentIndex,
              onTap: (index) {
                // Handle center button (index 2) separately
                if (index == 2) {
                  // Navigate to search screen instead
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
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
                  icon: Icon(Icons.search),
                  activeIcon: Icon(Icons.search),
                  label: 'Search', // Changed from 'Post'
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
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: Size.fromHeight(kToolbarHeight),
      child: Consumer<HomeController>(
        builder: (context, controller, child) {
          return CustomAppBar(
            title: 'PU Circle',
            showBackButton: false,
            backgroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                onPressed: _navigateToCreatePost,
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
                icon: controller.isLoggingOut
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
                    : const Icon(Icons.logout, color: AppColors.primary),
                onPressed: controller.isLoggingOut ? null : () => controller.logout(context).then((_) => _navigateToLogin()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHomeScreen() {
    return _buildBody();
  }
}