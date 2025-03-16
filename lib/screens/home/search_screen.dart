import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../profile/profile_screen.dart';
import '../../firebase/firestore_service.dart';
import '../../models/user_model.dart';
import '../../utils/colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query);
    } else {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) return; // Don't search for very short queries

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      List<UserModel> results = await _firestoreService.searchUsers(query);

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error searching users: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching users: ${e.toString()}')),
        );
      }
    }
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Users',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                      : null,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _performSearch,
              ),
            ),
          ),
          Expanded(
            child: _isSearching
                ? Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: AppColors.primary,
                size: 40,
              ),
            )
                : _hasSearched && _searchResults.isEmpty
                ? _buildNoResultsFound()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 80,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No users found matching "${_searchController.text}"',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          onTap: () => _navigateToProfile(user.uid),
          leading: CircleAvatar(
            backgroundImage: user.profileImageUrl.isNotEmpty
                ? NetworkImage(user.profileImageUrl)
                : null,
            backgroundColor: user.profileImageUrl.isEmpty
                ? AppColors.primary
                : null,
            child: user.profileImageUrl.isEmpty
                ? Text(
              user.username.isNotEmpty
                  ? user.username[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
                : null,
          ),
          title: Text(
            user.username,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: user.bio.isNotEmpty
              ? Text(
            user.bio,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
              : null,
          trailing: const Icon(Icons.chevron_right),
        );
      },
    );
  }
}