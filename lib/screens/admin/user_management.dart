import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/match_service.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';

class UserManagement extends StatefulWidget {
  final int initialTab;

  const UserManagement({
    Key? key,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  _UserManagementState createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final MatchService _matchService = MatchService();

  String _searchQuery = '';
  UserModel? _selectedUser1;
  UserModel? _selectedUser2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Algorithm Match'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildAlgorithmMatchTab(),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search users by name or email...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              // Filter users based on search query
              final filteredDocs = _searchQuery.isEmpty
                  ? snapshot.data!.docs
                  : snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final username = (data['username'] as String? ?? '').toLowerCase();
                final email = (data['email'] as String? ?? '').toLowerCase();
                return username.contains(_searchQuery) ||
                    email.contains(_searchQuery);
              }).toList();

              return ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final userData = doc.data() as Map<String, dynamic>;
                  final user = UserModel.fromMap(userData);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.profileImageUrl.isNotEmpty
                          ? NetworkImage(user.profileImageUrl)
                          : null,
                      child: user.profileImageUrl.isEmpty
                          ? Text(user.username[0].toUpperCase())
                          : null,
                    ),
                    title: Text(user.username),
                    subtitle: Text(user.email),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        switch (value) {
                          case 'view':
                            _viewUserDetails(user);
                            break;
                          case 'delete':
                            _showDeleteConfirmation(user);
                            break;
                          case 'ban':
                            _showBanConfirmation(user);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('View Details'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete User'),
                        ),
                        const PopupMenuItem(
                          value: 'ban',
                          child: Text('Ban User'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAlgorithmMatchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Algorithm Match',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select two users to create an algorithm match between them.',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),

          // User 1 Selection
          const Text(
            'User 1',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildUserSelector(
            selectedUser: _selectedUser1,
            onUserSelected: (user) {
              setState(() {
                _selectedUser1 = user;
              });
            },
          ),
          const SizedBox(height: 20),

          // User 2 Selection
          const Text(
            'User 2',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildUserSelector(
            selectedUser: _selectedUser2,
            onUserSelected: (user) {
              setState(() {
                _selectedUser2 = user;
              });
            },
          ),
          const SizedBox(height: 30),

          // Match Button
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.favorite),
              label: const Text('Create Algorithm Match'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: (_selectedUser1 != null && _selectedUser2 != null)
                  ? () => _createAlgorithmMatch()
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSelector({
    required UserModel? selectedUser,
    required Function(UserModel) onUserSelected,
  }) {
    return InkWell(
      onTap: () => _showUserSelectionDialog(onUserSelected),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: selectedUser == null
            ? const Text('Tap to select a user')
            : Row(
          children: [
            CircleAvatar(
              backgroundImage: selectedUser.profileImageUrl.isNotEmpty
                  ? NetworkImage(selectedUser.profileImageUrl)
                  : null,
              child: selectedUser.profileImageUrl.isEmpty
                  ? Text(selectedUser.username[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedUser.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(selectedUser.email),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  if (selectedUser == _selectedUser1) {
                    _selectedUser1 = null;
                  } else if (selectedUser == _selectedUser2) {
                    _selectedUser2 = null;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserSelectionDialog(Function(UserModel) onUserSelected) async {
    showDialog(
      context: context,
      builder: (context) {
        String searchText = '';

        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Select User'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by name or email',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchText = value.toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('users').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                              return const Center(child: Text('No users found'));
                            }

                            final filteredDocs = searchText.isEmpty
                                ? snapshot.data!.docs
                                : snapshot.data!.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final username = (data['username'] as String? ?? '').toLowerCase();
                              final email = (data['email'] as String? ?? '').toLowerCase();
                              return username.contains(searchText) ||
                                  email.contains(searchText);
                            }).toList();

                            return ListView.builder(
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final userData = doc.data() as Map<String, dynamic>;
                                final user = UserModel.fromMap(userData);

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: user.profileImageUrl.isNotEmpty
                                        ? NetworkImage(user.profileImageUrl)
                                        : null,
                                    child: user.profileImageUrl.isEmpty
                                        ? Text(user.username[0].toUpperCase())
                                        : null,
                                  ),
                                  title: Text(user.username),
                                  subtitle: Text(user.email),
                                  onTap: () {
                                    onUserSelected(user);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            }
        );
      },
    );
  }

  void _viewUserDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.username),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.profileImageUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      user.profileImageUrl,
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildInfoRow('Email', user.email),
              _buildInfoRow('Gender', user.gender),
              _buildInfoRow('Single', user.isSingle ? 'Yes' : 'No'),
              _buildInfoRow('Admin', user.isAdmin ? 'Yes' : 'No'),
              if (user.bio.isNotEmpty) _buildInfoRow('Bio', user.bio),
              const SizedBox(height: 10),
              const Text(
                'Followers',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(user.followers.length.toString()),
              const SizedBox(height: 10),
              const Text(
                'Following',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(user.following.length.toString()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete ${user.username}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Delete user documents
                await _firestore.collection('users').doc(user.uid).delete();

                // Delete user posts
                final postsSnapshot = await _firestore
                    .collection('posts')
                    .where('userId', isEqualTo: user.uid)
                    .get();

                for (var doc in postsSnapshot.docs) {
                  await doc.reference.delete();
                }

                // Delete user from matches
                final matchesSnapshot = await _firestore
                    .collection('matches')
                    .where(Filter.or(
                  Filter('user1Id', isEqualTo: user.uid),
                  Filter('user2Id', isEqualTo: user.uid),
                ))
                    .get();

                for (var doc in matchesSnapshot.docs) {
                  await doc.reference.delete();
                }

                // Close loading dialog
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('User ${user.username} deleted successfully')),
                );
              } catch (e) {
                // Close loading dialog
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting user: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBanConfirmation(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ban User'),
        content: Text(
          'Are you sure you want to ban ${user.username}? They will no longer be able to access the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Update user document to mark as banned
                await _firestore.collection('users').doc(user.uid).update({
                  'isBanned': true,
                  'bannedAt': FieldValue.serverTimestamp(),
                });

                // Close loading dialog
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('User ${user.username} banned successfully')),
                );
              } catch (e) {
                // Close loading dialog
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error banning user: $e')),
                );
              }
            },
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _createAlgorithmMatch() async {
    if (_selectedUser1 == null || _selectedUser2 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both users')),
      );
      return;
    }

    // Check if users are the same
    if (_selectedUser1!.uid == _selectedUser2!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot match a user with themselves')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Create match between users
      await _matchService.createMatch(
        _selectedUser1!.uid,
        _selectedUser2!.uid,
          matchedByAdmin : true,
      );

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Algorithm match created between ${_selectedUser1!.username} and ${_selectedUser2!.username}',
          ),
        ),
      );

      // Reset selection
      setState(() {
        _selectedUser1 = null;
        _selectedUser2 = null;
      });
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating match: $e')),
      );
    }
  }
}