import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pu_circle/controllers/match_controller.dart';
import 'package:pu_circle/screens/match/your_match_screen.dart';
import 'package:pu_circle/screens/profile/profile_screen.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../widgets/match_animation_widget.dart';
import '../../widgets/profile_card_widget.dart';
import 'match_detail_screen.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({Key? key}) : super(key: key);

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _animationController;
  late MatchController _matchController;

  @override
  void initState() {
    super.initState();

    // Setup animation controller for match animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _matchController.setShowMatchAnimation(false);
            _navigateToMatchDetail(_matchController.matchedUser!);
          }
        });
      }
    });

// Initialize controller using Provider
    _matchController = Provider.of<MatchController>(context, listen: false);
// Schedule init() to run after the current build cycle completes
    Future.microtask(() => _matchController.init());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToMatchDetail(UserModel matchedUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MatchDetailScreen(matchedUser: matchedUser),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MatchController>(
      builder: (context, controller, child) {
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Find Friends',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => controller.loadPotentialMatches(refresh: true),
              ),
              IconButton(
                icon: const Icon(Icons.people, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MatchListScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withAlpha(80),
                  AppColors.background,
                  AppColors.background,
                ],
              ),
            ),
            child: controller.isLoading && controller.potentialMatches.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Stack(
              fit: StackFit.expand,
              children: [
                controller.potentialMatches.isEmpty
                    ? _buildNoMatchesView(controller)
                    : _buildMatchCards(controller),

                // Swipe limit indicator
                // Positioned(
                //   top: kToolbarHeight + 8,
                //   right: 20,
                //   child: Container(
                //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //     decoration: BoxDecoration(
                //       color: Colors.white,
                //       borderRadius: BorderRadius.circular(15),
                //       boxShadow: [
                //         BoxShadow(
                //           color: Colors.black.withOpacity(0.1),
                //           blurRadius: 4,
                //           offset: const Offset(0, 2),
                //         ),
                //       ],
                //     ),
                //     child: Text(
                //       '${controller.remainingSwipes}/100 swipes left',
                //       style: TextStyle(
                //         fontWeight: FontWeight.bold,
                //         color: controller.remainingSwipes < 5
                //             ? Colors.red
                //             : AppColors.textPrimary,
                //       ),
                //     ),
                //   ),
                // ),

                // Match animation overlay
                if (controller.showMatchAnimation && controller.matchedUser != null)
                  MatchAnimationWidget(
                    matchedUser: controller.matchedUser!,
                    onStartChatting: () {
                      controller.setShowMatchAnimation(false);
                      _navigateToMatchDetail(controller.matchedUser!);
                    },
                    animationController: _animationController,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoMatchesView(MatchController controller) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_search, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'No more potential matches',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              controller.hasMoreMatches
                  ? 'Loading more profiles...'
                  : 'Check back later for new Profiles',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => controller.loadPotentialMatches(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCards(MatchController controller) {
    return Column(
      children: [
        const SizedBox(height: kToolbarHeight + 34),
        // Stylish instruction banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withAlpha(80), AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withAlpha(40),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.swipe, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                controller.remainingSwipes > 0
                    ? 'Swipe cards to connect'
                    : 'No more swipes today',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        // Main card area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: controller.potentialMatches.isNotEmpty
                ? _buildSwipeableCard(controller, controller.potentialMatches[0])
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.mood_bad,
                    size: 70,
                    color: AppColors.primary.withAlpha(50),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No more profiles to show',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Check back later for new friends',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => controller.loadPotentialMatches(refresh: true),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Loading indicator for pagination
        if (controller.isLoading && controller.potentialMatches.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildSwipeableCard(MatchController controller, UserModel user) {
    // Disable swiping if no more swipes left today
    final bool canSwipe = controller.remainingSwipes > 0;

    return Dismissible(
      key: Key(user.uid),
      direction: canSwipe ? DismissDirection.horizontal : DismissDirection.none,
      onDismissed: (direction) {
        bool isLiked = direction == DismissDirection.endToStart;
        controller.handleSwipe(user, isLiked);
        // Trigger animation if needed
        if (controller.showMatchAnimation) {
          _animationController.reset();
          _animationController.forward();
        }
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade400, Colors.red.shade600],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.close,
          color: Colors.white,
          size: 40,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withAlpha(80), AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 40,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Profile card takes up most of the space
            Expanded(
              child: Stack(
                children: [
                  ProfileCardWidget(
                    user: user,
                    showActions: false,
                    onLike: () {},
                    onDislike: () {},
                    onProfileTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(userId: user.uid),
                        ),
                      );
                    },
                  ),
                  // Overlay to prevent interaction if daily limit reached
                  if (!canSwipe)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(50),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.hourglass_empty,
                                  size: 40,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Daily Limit Reached',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You\'ve used all swipes for today.\nCome back tomorrow!',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Action buttons
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    onPressed: canSwipe
                        ? () => controller.handleSwipe(user, false)
                        : null,
                    icon: Icons.close,
                    backgroundColor: canSwipe ? Colors.white : Colors.grey.shade300,
                    iconColor: canSwipe ? Colors.red : Colors.grey,
                    size: 65,
                    shadow: canSwipe,
                  ),
                  const SizedBox(width: 40),
                  _buildActionButton(
                    onPressed: canSwipe
                        ? () => controller.handleSwipe(user, true)
                        : null,
                    icon: Icons.favorite,
                    backgroundColor: canSwipe ? AppColors.primary : Colors.grey.shade300,
                    iconColor: Colors.white,
                    size: 65,
                    shadow: canSwipe,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    double size = 60,
    bool shadow = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          boxShadow: shadow
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ]
              : null,
        ),
        child: Icon(icon, size: size * 0.45, color: iconColor),
      ),
    );
  }
}