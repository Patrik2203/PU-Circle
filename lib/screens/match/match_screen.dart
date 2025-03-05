import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../firebase/match_service.dart';
import '../../models/user_model.dart';
import 'match_detail_screen.dart';
import '../../utils/colors.dart';
import '../../widgets/profile_card_widget.dart';
import '../../widgets/common_widgets.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({Key? key}) : super(key: key);

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with SingleTickerProviderStateMixin {
  final MatchService _matchService = MatchService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<UserModel> _potentialMatches = [];
  bool _isLoading = true;
  bool _showMatchAnimation = false;
  UserModel? _matchedUser;

  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadPotentialMatches();

    // Setup animation controller for match animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
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
        setState(() {
          _potentialMatches = matches;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
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

  Future<void> _handleSwipe(UserModel user, bool isLiked) async {
    // Remove the user from the list
    setState(() {
      _potentialMatches.remove(user);
    });

    if (isLiked) {
      try {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          // Check if it's a match
          final bool isMatch = await _matchService.likeUser(userId, user.uid);

          if (isMatch) {
            setState(() {
              _showMatchAnimation = true;
              _matchedUser = user;
            });
            _animationController.reset();
            _animationController.forward();
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }

    // If no more potential matches, reload
    if (_potentialMatches.isEmpty) {
      _loadPotentialMatches();
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
      appBar: AppBar(
        title: const Text('Find Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPotentialMatches,
          ),
          IconButton(
            icon: const Icon(Icons.people),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          _potentialMatches.isEmpty
              ? _buildNoMatchesView()
              : _buildMatchCards(),

          // Match animation overlay
          if (_showMatchAnimation) _buildMatchAnimation(),
        ],
      ),
    );
  }

  Widget _buildNoMatchesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_search,
            size: 80,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No more potential matches',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new students',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadPotentialMatches,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCards() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Swipe right to connect or left to pass',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: _potentialMatches.asMap().entries.map((entry) {
              // Only show the top 3 cards in the stack for performance
              if (entry.key > 2) return const SizedBox.shrink();

              final user = entry.value;
              final isTop = entry.key == 0;

              return Positioned(
                bottom: 40.0 + (entry.key * 8),
                child: Transform.scale(
                  scale: 1.0 - (entry.key * 0.05),
                  child: IgnorePointer(
                    ignoring: !isTop,
                    child: Opacity(
                      opacity: isTop ? 1.0 : 0.9 - (entry.key * 0.1),
                      child: Draggable<UserModel>(
                        data: user,
                        feedback: Material(
                          color: Colors.transparent,
                          child: ProfileCardWidget(
                            user: user,
                            onLike: () {},
                            onDislike: () {},
                            onProfileTap: () {},
                            isMatch: false,
                          ),
                        ),
                        childWhenDragging: const SizedBox.shrink(),
                        onDragEnd: (details) {
                          // Determine swipe direction based on offset
                          if (details.offset.dx > 100) {
                            // Swiped right - like
                            _handleSwipe(user, true);
                          } else if (details.offset.dx < -100) {
                            // Swiped left - pass
                            _handleSwipe(user, false);
                          }
                        },
                        child: ProfileCardWidget(
                          user: user,
                          showActions: isTop,
                          onLike: () => _handleSwipe(user, true),
                          onDislike: () => _handleSwipe(user, false),
                          onProfileTap: () {}, // Add this missing required parameter
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchAnimation() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'It\'s a Match!',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Transform.scale(
                  scale: _animation.value,
                  child: const Icon(
                    Icons.favorite,
                    color: AppColors.match,
                    size: 120,
                  ),
                ),
                const SizedBox(height: 32),
                if (_matchedUser != null)
                  Text(
                    'You and ${_matchedUser!.username} liked each other',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showMatchAnimation = false;
                    });
                    if (_matchedUser != null) {
                      _navigateToMatchDetail(_matchedUser!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.match,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Start Chatting'),
                ),
              ],
            ),
          ),
        );
      },
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('userId1', isEqualTo: _auth.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot1) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
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
                  final matchData = matches[index].data() as Map<String, dynamic>;
                  final String matchId = matches[index].id;

                  // Determine the other user's ID
                  final String currentUserId = _auth.currentUser!.uid;
                  final String otherUserId = matchData['userId1'] == currentUserId
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
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: CircularProgressIndicator(),
                          ),
                          title: Text('Loading...'),
                        );
                      }

                      if (!userSnapshot.hasData || userSnapshot.data == null) {
                        return const ListTile(
                          title: Text('User not found'),
                        );
                      }

                      final user = userSnapshot.data!;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.profileImageUrl.isNotEmpty
                              ? NetworkImage(user.profileImageUrl)
                              : null,
                          child: user.profileImageUrl.isEmpty
                              ? Text(user.username.isNotEmpty ? user.username[0] : '?')
                              : null,
                        ),
                        title: Text(user.username),
                        subtitle: Text(
                          matchData['matchedByAdmin'] == true
                              ? 'Matched by admin'
                              : 'Matched through PU Circle',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MatchDetailScreen(
                                      matchedUser: user,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () {
                                _showUnmatchDialog(context, matchId, user.username);
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MatchDetailScreen(
                                matchedUser: user,
                              ),
                            ),
                          );
                        },
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

  void _showUnmatchDialog(BuildContext context, String matchId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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