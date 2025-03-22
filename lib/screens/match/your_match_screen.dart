import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../firebase/match_service.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../profile/profile_screen.dart';
import 'match_detail_screen.dart';

class MatchListScreen extends StatefulWidget {
  const MatchListScreen({Key? key}) : super(key: key);

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  List<UserModel> _pendingRequests = [];
  bool _isLoadingPendingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    try {
      setState(() {
        _isLoadingPendingRequests = true;
      });

      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Get IDs of users with pending requests
        final pendingUserIds = await _matchService.getPendingMatchRequests(userId);

        // Fetch user data for each ID
        final List<UserModel> pendingUsers = [];
        for (String pendingUserId in pendingUserIds) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(pendingUserId)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            data['uid'] = userDoc.id;
            pendingUsers.add(UserModel.fromMap(data));
          }
        }

        setState(() {
          _pendingRequests = pendingUsers;
          _isLoadingPendingRequests = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingPendingRequests = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pending requests: ${e.toString()}')),
        );
      }
    }
  }

// Method to accept a match request
  Future<void> _acceptMatchRequest(String otherUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Create a match
        final bool isMatch = await _matchService.likeUser(userId, otherUserId);

        if (isMatch && mounted) {
          // Get the user model for animation
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUserId)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>;
            data['uid'] = userDoc.id;
            final matchedUser = UserModel.fromMap(data);

            // Navigate to match detail screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MatchDetailScreen(matchedUser: matchedUser),
              ),
            );
          }

          // Refresh the pending requests list
          _loadPendingRequests();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting match: ${e.toString()}')),
        );
      }
    }
  }

// Method to decline a match request
  Future<void> _declineMatchRequest(String otherUserId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        // Find and delete the like document - THIS IS THE FIX
        QuerySnapshot likeQuery = await FirebaseFirestore.instance
            .collection('likes')
            .where('likerId', isEqualTo: otherUserId)  // Changed from 'userId'
            .where('likedId', isEqualTo: userId)  // Changed from 'likedUserId'
            .get();

        if (likeQuery.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('likes')
              .doc(likeQuery.docs.first.id)
              .delete();
        }

        // Refresh the pending requests list
        _loadPendingRequests();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request declined'),),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining request: ${e.toString()}')),
        );
      }
    }
  }

  

  final MatchService _matchService = MatchService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Matches'),
        backgroundColor: AppColors.background,
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: 'Your Matches'),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Pending Requests'),
                      if (_pendingRequests.isNotEmpty)
                        Container(
                          margin: EdgeInsets.only(left: 8),
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _pendingRequests.length.toString(),
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Existing matches list (your current code)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('matches')
                        .where('userId1', isEqualTo: _auth.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot1) {
                      // ... Your existing code for matches list
                      // Keep this entire section as is
                      return Scaffold(
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
                    },
                  ),

                  // Tab 2: Pending requests
                  _buildPendingRequestsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsList() {
    if (_isLoadingPendingRequests) {
      return Center(child: CircularProgressIndicator());
    }

    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_alt_outlined,
              size: 80,
              color: AppColors.textLight,
            ),
            SizedBox(height: 16),
            Text(
              'No pending requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8),
            Text(
              'When someone likes your profile, they\'ll appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: _loadPendingRequests,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingRequests,
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          final user = _pendingRequests[index];

          return Card(
            elevation: 2,
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                backgroundImage: user.profileImageUrl.isNotEmpty
                    ? NetworkImage(user.profileImageUrl)
                    : null,
                child: user.profileImageUrl.isEmpty
                    ? Text(
                  user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
                    : null,
              ),
              title: Text(
                user.username,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${user.username} wants to match with you',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _declineMatchRequest(user.uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                    child: Text('Decline'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _acceptMatchRequest(user.uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text('Accept'),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(userId: user.uid),
                  ),
                );
              },
            ),
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