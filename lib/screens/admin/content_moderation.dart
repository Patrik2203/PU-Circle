import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase/auth_service.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';
import '../../utils/helpers.dart';

class ContentModeration extends StatefulWidget {
  final int initialTab;

  const ContentModeration({Key? key, this.initialTab = 0}) : super(key: key);

  @override
  _ContentModerationState createState() => _ContentModerationState();
}

class _ContentModerationState extends State<ContentModeration> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handlePostAction(String postId, String action) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (action == 'delete') {
        await _firestore.collection('posts').doc(postId).delete();
        AppHelpers.showSnackBar(context, 'Post deleted successfully');
      } else if (action == 'approve') {
        await _firestore.collection('posts').doc(postId).update({
          'isReported': false,
          'reviewedBy': _authService.currentUser!.uid,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
        AppHelpers.showSnackBar(context, 'Post approved');
      }
    } catch (e) {
      AppHelpers.showSnackBar(context, 'Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleReportAction(String reportId, String action, String? contentId, String? contentType) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (action == 'delete' && contentId != null && contentType != null) {
        // Delete the reported content
        await _firestore.collection(contentType).doc(contentId).delete();

        // Update report status
        await _firestore.collection('reports').doc(reportId).update({
          'status': 'resolved',
          'resolution': 'content_deleted',
          'resolvedBy': _authService.currentUser!.uid,
          'resolvedAt': FieldValue.serverTimestamp(),
        });

        AppHelpers.showSnackBar(context, 'Content deleted and report resolved');
      } else if (action == 'dismiss') {
        await _firestore.collection('reports').doc(reportId).update({
          'status': 'resolved',
          'resolution': 'dismissed',
          'resolvedBy': _authService.currentUser!.uid,
          'resolvedAt': FieldValue.serverTimestamp(),
        });

        AppHelpers.showSnackBar(context, 'Report dismissed');
      }
    } catch (e) {
      AppHelpers.showSnackBar(context, 'Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Moderation'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Posts'),
            Tab(text: 'Reports'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsModerationTab(),
          _buildReportsModerationTab(),
        ],
      ),
    );
  }

  Widget _buildPostsModerationTab() {
    return StreamBuilder(
      stream: _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No posts to moderate'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final postId = doc.id;

            return FutureBuilder(
              future: _firestore.collection('users').doc(data['uid']).get(),
              builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                final username = userData?['username'] ?? 'Unknown User';

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userData?['profileImageUrl'] != null
                              ? NetworkImage(userData!['profileImageUrl'])
                              : null,
                          child: userData?['profileImageUrl'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(username),
                        subtitle: Text(
                          data['timestamp'] != null
                              ? _formatTimestamp(data['timestamp'] as Timestamp)
                              : 'Unknown',
                        ),
                        trailing: data['isReported'] == true
                            ? const Icon(Icons.report, color: Colors.red)
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(data['caption'] ?? ''),
                      ),
                      if (data['imageUrl'] != null)
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: NetworkImage(data['imageUrl']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ButtonBar(
                        alignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _handlePostAction(postId, 'approve'),
                            child: const Text('Approve'),
                          ),
                          TextButton(
                            onPressed: () => _handlePostAction(postId, 'delete'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReportsModerationTab() {
    return StreamBuilder(
      stream: _firestore
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No pending reports'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final reportId = doc.id;
            final contentType = data['contentType']; // 'posts', 'users', etc.
            final contentId = data['contentId'];

            return Card(
              margin: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.report_problem),
                    title: Text('Report Type: ${data['type'] ?? 'Unknown'}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reason: ${data['reason'] ?? 'Not specified'}'),
                        Text(
                          'Reported: ${data['timestamp'] != null ? _formatTimestamp(data['timestamp'] as Timestamp) : 'Unknown'}',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Details: ${data['details'] ?? 'No details provided'}'),
                  ),
                  if (contentType != null && contentId != null)
                    FutureBuilder(
                      future: _firestore.collection(contentType).doc(contentId).get(),
                      builder: (context, AsyncSnapshot<DocumentSnapshot> contentSnapshot) {
                        if (contentSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        if (contentSnapshot.hasError || !contentSnapshot.hasData || !contentSnapshot.data!.exists) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Reported content not found or already removed'),
                          );
                        }

                        final contentData = contentSnapshot.data!.data() as Map<String, dynamic>;

                        // Display reported content preview based on type
                        if (contentType == 'posts') {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Reported Content Preview:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(contentData['caption'] ?? ''),
                              ),
                              if (contentData['imageUrl'] != null)
                                Container(
                                  width: double.infinity,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(contentData['imageUrl']),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        } else if (contentType == 'users') {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  'Reported User:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: contentData['profileImageUrl'] != null
                                      ? NetworkImage(contentData['profileImageUrl'])
                                      : null,
                                  child: contentData['profileImageUrl'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(contentData['username'] ?? 'Unknown User'),
                                subtitle: Text(contentData['bio'] ?? 'No bio'),
                              ),
                            ],
                          );
                        } else {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('Unknown content type'),
                          );
                        }
                      },
                    ),
                  ButtonBar(
                    alignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _handleReportAction(reportId, 'dismiss', contentId, contentType),
                        child: const Text('Dismiss Report'),
                      ),
                      TextButton(
                        onPressed: () => _handleReportAction(reportId, 'delete', contentId, contentType),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Remove Content'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}