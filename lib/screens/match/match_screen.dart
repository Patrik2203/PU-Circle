import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pu_circle/screens/profile/profile_screen.dart';
import '../../firebase/match_service.dart';
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
  final MatchService _matchService = MatchService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<UserModel> _potentialMatches = [];
  bool _isLoading = true;
  bool _showMatchAnimation = false;
  UserModel? _matchedUser;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadPotentialMatches();

    // Setup animation controller for match animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showMatchAnimation = false;
            });
            _navigateToMatchDetail(_matchedUser!);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadPotentialMatches() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        final matches = await _matchService.getPotentialMatches(userId);

        // Sort the matches by some criteria if needed
        // matches.sort((a, b) => ...);

        setState(() {
          _potentialMatches = matches;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to load matches: ${e.toString()}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  Future<void> _handleSwipe(UserModel user, bool isLiked) async {
    // First call your match checking logic but wait to remove the card
    if (isLiked) {
      try {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          final bool isMatch = await _matchService.likeUser(userId, user.uid);

          if (isMatch && mounted) {
            setState(() {
              _showMatchAnimation = true;
              _matchedUser = user;
            });
            _animationController.reset();
            _animationController.forward();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }

    // Now remove the user from the list - this creates a smoother transition
    if (mounted) {
      setState(() {
        _potentialMatches.remove(user);
      });

      // If no more potential matches, reload
      if (_potentialMatches.isEmpty) {
        _loadPotentialMatches();
      }
    }
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
            onPressed: _loadPotentialMatches,
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
              AppColors.primary.withOpacity(0.8),
              AppColors.background,
              AppColors.background,
            ],
          ),
        ),
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                  fit: StackFit.expand,
                  children: [
                    _potentialMatches.isEmpty
                        ? _buildNoMatchesView()
                        : _buildMatchCards(),

                    // Match animation overlay
                    if (_showMatchAnimation && _matchedUser != null)
                      MatchAnimationWidget(
                        matchedUser: _matchedUser!,
                        onStartChatting: () {
                          setState(() {
                            _showMatchAnimation = false;
                          });
                          _navigateToMatchDetail(_matchedUser!);
                        },
                        animationController: _animationController,
                      ),
                  ],
                ),
      ),
    );
  }

  Widget _buildNoMatchesView() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
              'Check back later for new Profiles',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loadPotentialMatches,
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

  Widget _buildMatchCards() {
    return Column(
      children: [
        const SizedBox(height: kToolbarHeight + 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swipe, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Swipe right to connect',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use more screen space
              final cardWidth = constraints.maxWidth * 0.95;
              final cardHeight = constraints.maxHeight * 0.85;

              return Stack(
                alignment: Alignment.center,
                children:
                    _potentialMatches.asMap().entries.map((entry) {
                      // Only show top 2 cards for better performance
                      if (entry.key > 1) return const SizedBox.shrink();

                      final user = entry.value;
                      final isTop = entry.key == 0;

                      return Positioned(
                        // Center the card better
                        top: 20.0 + (entry.key * 4),
                        bottom: 20.0 + (entry.key * 4),
                        child: SizedBox(
                          width: cardWidth,
                          height: cardHeight,
                          child: Transform.scale(
                            // Less aggressive scaling for better visibility
                            scale: 1.0 - (entry.key * 0.03),
                            child: IgnorePointer(
                              ignoring: !isTop,
                              child: Opacity(
                                // Make background cards more visible
                                opacity: isTop ? 1.0 : 0.0,
                                child: Draggable<UserModel>(
                                  data: user,
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: SizedBox(
                                      width: cardWidth,
                                      height: cardHeight,
                                      child: ProfileCardWidget(
                                        user: user,
                                        onLike: () {},
                                        onDislike: () {},
                                        onProfileTap: () {},
                                        showActions: false,
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                  ),
                                  child: ProfileCardWidget(
                                    user: user,
                                    showActions: isTop,
                                    onLike: () => _handleSwipe(user, true),
                                    onDislike: () => _handleSwipe(user, false),
                                    onProfileTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => ProfileScreen(
                                                userId: user.uid,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class MatchListScreen extends StatefulWidget {
  const MatchListScreen({Key? key}) : super(key: key);

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  final MatchService _matchService = MatchService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Matches'),
        backgroundColor: AppColors.primary,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('matches')
                .where('userId1', isEqualTo: _auth.currentUser?.uid)
                .snapshots(),
        builder: (context, snapshot1) {
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance
                    .collection('matches')
                    .where('userId2', isEqualTo: _auth.currentUser?.uid)
                    .snapshots(),
            builder: (context, snapshot2) {
              if (snapshot1.connectionState == ConnectionState.waiting ||
                  snapshot2.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot1.hasError || snapshot2.hasError) {
                return Center(
                  child: Text('Error: ${snapshot1.error ?? snapshot2.error}'),
                );
              }

              final List<DocumentSnapshot> matches = [];

              if (snapshot1.hasData) {
                matches.addAll(snapshot1.data!.docs);
              }

              if (snapshot2.hasData) {
                matches.addAll(snapshot2.data!.docs);
              }

              if (matches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 80,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No matches yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start swiping to find new friends!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Find Friends'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final matchData =
                      matches[index].data() as Map<String, dynamic>;
                  final String matchId = matches[index].id;

                  // Determine the other user's ID
                  // Determine the other user's ID
                  final String currentUserId = _auth.currentUser!.uid;
                  final String otherUserId =
                      matchData['userId1'] == currentUserId
                          ? matchData['userId2']
                          : matchData['userId1'];

                  return FutureBuilder<UserModel?>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(otherUserId)
                        .get()
                        .then((doc) {
                          if (doc.exists) {
                            final data = doc.data() as Map<String, dynamic>;
                            data['uid'] = doc.id;
                            return UserModel.fromMap(data);
                          }
                          return null;
                        }),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          title: Text('Loading...'),
                        );
                      }

                      if (!userSnapshot.hasData || userSnapshot.data == null) {
                        return const ListTile(title: Text('User not found'));
                      }

                      final user = userSnapshot.data!;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primary.withOpacity(0.2),
                            backgroundImage:
                                user.profileImageUrl.isNotEmpty
                                    ? NetworkImage(user.profileImageUrl)
                                    : null,
                            child:
                                user.profileImageUrl.isEmpty
                                    ? Text(
                                      user.username.isNotEmpty
                                          ? user.username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    )
                                    : null,
                          ),
                          title: Text(
                            user.username,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            matchData['matchedByAdmin'] == true
                                ? 'Matched by Algorithm'
                                : 'Matched through PU Circle',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.chat_bubble_outline,
                                  color: AppColors.primary,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => MatchDetailScreen(
                                            matchedUser: user,
                                          ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.person_remove_outlined,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  _showUnmatchDialog(
                                    context,
                                    matchId,
                                    user.username,
                                  );
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        MatchDetailScreen(matchedUser: user),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showUnmatchDialog(
    BuildContext context,
    String matchId,
    String username,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Unmatch User'),
            content: Text(
              'Are you sure you want to unmatch with $username? '
              'This will delete your chat history and remove the connection.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _matchService.unmatchUsers(matchId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unmatched successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Unmatch'),
              ),
            ],
          ),
    );
  }
}
