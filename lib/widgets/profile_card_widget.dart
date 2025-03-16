import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/colors.dart';

class ProfileCardWidget extends StatelessWidget {
  final UserModel user;
  final bool showActions;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onProfileTap;
  final bool isMatch;

  const ProfileCardWidget({
    Key? key,
    required this.user,
    this.showActions = true,
    required this.onLike,
    required this.onDislike,
    required this.onProfileTap,
    this.isMatch = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("Building ProfileCardWidget for ${user.username}");
    return GestureDetector(
      onTap: onProfileTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile image section - takes 70% of the card height
            Expanded(
              flex: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Profile image
                  user.profileImageUrl.isNotEmpty
                      ? Image.network(
                        user.profileImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildUserInitials();
                        },
                      )
                      : _buildUserInitials(),

                  // Gradient overlay for better text visibility
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // User name and basic info
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 3,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                        // if (user.major.isNotEmpty || user.year.isNotEmpty)
                        //   Text(
                        //     [
                        //       if (user.major.isNotEmpty) user.major,
                        //       if (user.year.isNotEmpty) 'Class of ${user.year}',
                        //     ].join(' · '),
                        //     style: const TextStyle(
                        //       color: Colors.white,
                        //       fontSize: 14,
                        //       shadows: [
                        //         Shadow(
                        //           offset: Offset(0, 1),
                        //           blurRadius: 3,
                        //           color: Colors.black45,
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Info section - takes 30% of the card height
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user.bio.isNotEmpty)
                      Expanded(
                        child: Text(
                          user.bio,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    // Interest tags
                    if (user.interests.isNotEmpty)
                      Container(
                        height: 32,
                        margin: const EdgeInsets.only(top: 8),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount:
                              user.interests.length > 3
                                  ? 3
                                  : user.interests.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                user.interests[index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Action buttons
            if (showActions)
              Container(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildActionButton(
                      onPressed: onDislike,
                      icon: Icons.close,
                      backgroundColor: Colors.white,
                      iconColor: Colors.red,
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      onPressed: onLike,
                      icon: Icons.check,
                      backgroundColor: AppColors.primary,
                      iconColor: Colors.white,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInitials() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 30, color: iconColor),
      ),
    );
  }
}
