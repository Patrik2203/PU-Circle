import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/colors.dart';

class ProfileCardWidget extends StatelessWidget {
  final UserModel user;
  final Function() onLike;
  final Function() onDislike;
  final Function() onProfileTap;
  final bool showActions;
  final bool isMatch;

  const ProfileCardWidget({
    super.key,
    required this.user,
    required this.onLike,
    required this.onDislike,
    required this.onProfileTap,
    this.showActions = true,
    this.isMatch = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: Material(
          color: AppColors.cardBackground,
          child: Stack(
            children: [
              // Profile Image
              GestureDetector(
                onTap: onProfileTap,
                child: Hero(
                  tag: 'profile_${user.uid}',
                  child: SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: user.profileImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: user.profileImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.primaryLight.withOpacity(0.1),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.primaryLight.withOpacity(0.1),
                              child: const Center(
                                child: Icon(
                                  Icons.person,
                                  size: 80,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.primaryLight.withOpacity(0.1),
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                size: 80,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // Match Indicator
              if (isMatch)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.match,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 16.0,
                        ),
                        SizedBox(width: 4.0),
                        Text(
                          'MATCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // User Info Gradient Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username and Age
                      Row(
                        children: [
                          Text(
                            user.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (user.gender != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                user.gender?.toLowerCase() == 'male'
                                    ? Icons.male
                                    : Icons.female,
                                color: Colors.white,
                                size: 20.0,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4.0),

                      // User Bio (limited to 2 lines)
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Text(
                          user.bio!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14.0,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                      const SizedBox(height: 8.0),

                      // User Interests Chips
                      if (user.interests != null && user.interests!.isNotEmpty)
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 6.0,
                          children: user.interests!.map((interest) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical: 4.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Text(
                                interest,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.0,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),

              // Like/Dislike Actions
              if (showActions)
                Positioned(
                  bottom: 16.0,
                  right: 16.0,
                  child: Row(
                    children: [
                      // Dislike Button
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 24.0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.matchDislike,
                            size: 28.0,
                          ),
                          onPressed: onDislike,
                        ),
                      ),

                      const SizedBox(width: 16.0),

                      // Like Button
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 24.0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.favorite,
                            color: AppColors.matchLike,
                            size: 28.0,
                          ),
                          onPressed: onLike,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Optional: Swipeable Profile Card (for Tinder-like functionality)
class SwipeableProfileCard extends StatelessWidget {
  final UserModel user;
  final Function(bool isLiked) onSwipe;
  final Function() onProfileTap;

  const SwipeableProfileCard({
    Key? key,
    required this.user,
    required this.onSwipe,
    required this.onProfileTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Draggable(
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: ProfileCardWidget(
            user: user,
            onLike: () => onSwipe(true),
            onDislike: () => onSwipe(false),
            onProfileTap: onProfileTap,
            showActions: false,
          ),
        ),
      ),
      childWhenDragging: Container(),
      onDragEnd: (details) {
        if (details.offset.dx > 100) {
          // Swiped right (like)
          onSwipe(true);
        } else if (details.offset.dx < -100) {
          // Swiped left (dislike)
          onSwipe(false);
        }
      },
      child: ProfileCardWidget(
        user: user,
        onLike: () => onSwipe(true),
        onDislike: () => onSwipe(false),
        onProfileTap: onProfileTap,
      ),
    );
  }
}

// Match Animation Overlay Widget
class MatchAnimationWidget extends StatefulWidget {
  final UserModel matchedUser;
  final VoidCallback onAnimationComplete;
  final VoidCallback onChatNow;

  const MatchAnimationWidget({
    Key? key,
    required this.matchedUser,
    required this.onAnimationComplete,
    required this.onChatNow,
  }) : super(key: key);

  @override
  State<MatchAnimationWidget> createState() => _MatchAnimationWidgetState();
}

class _MatchAnimationWidgetState extends State<MatchAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Auto dismiss after 5 seconds if user doesn't interact
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onAnimationComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: InkWell(
        onTap: widget.onAnimationComplete,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Heart Animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: const Icon(
                  Icons.favorite,
                  color: AppColors.match,
                  size: 100.0,
                ),
              ),

              const SizedBox(height: 24.0),

              // It's a Match Text
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  "It's a Match!",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16.0),

              // Matched User Info
              FadeTransition(
                opacity: _fadeAnimation,
                child: Text(
                  "You and ${widget.matchedUser.username} liked each other",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16.0,
                  ),
                ),
              ),

              const SizedBox(height: 40.0),

              // Matched User Profile Pic
              FadeTransition(
                opacity: _fadeAnimation,
                child: CircleAvatar(
                  radius: 60.0,
                  backgroundImage: widget.matchedUser.profileImageUrl != null
                      ? NetworkImage(widget.matchedUser.profileImageUrl!)
                      : const AssetImage('assets/images/default_profile.png')
                          as ImageProvider,
                ),
              ),

              const SizedBox(height: 40.0),

              // Chat Now Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: ElevatedButton(
                  onPressed: widget.onChatNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32.0,
                      vertical: 12.0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                  child: const Text(
                    "Chat Now",
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16.0),

              // Keep Swiping Button
              FadeTransition(
                opacity: _fadeAnimation,
                child: TextButton(
                  onPressed: widget.onAnimationComplete,
                  child: const Text(
                    "Keep Swiping",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.0,
                    ),
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
