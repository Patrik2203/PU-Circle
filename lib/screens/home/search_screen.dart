import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'explore_screen.dart';
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

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  late TabController _tabController;
  bool _isAppBarVisible = true;
  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _searchController.addListener(_onSearchChanged);

    // Initialize to show search field if starting on search tab
    Future.delayed(Duration.zero, () {
      if (_tabController.index == 1) {
        setState(() {});
      }
    });
    _mainScrollController.addListener(_scrollListener);
  }
  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _mainScrollController.removeListener(_scrollListener);
    _mainScrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_mainScrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isAppBarVisible) {
        setState(() {
          _isAppBarVisible = false;
        });
      }
    }

    if (_mainScrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isAppBarVisible) {
        setState(() {
          _isAppBarVisible = true;
        });
      }
    }
  }


  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      _performSearch(query);
      // Switch to search results tab
      _tabController.animateTo(1);
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

  void _handleTabSelection() {
    // This forces a rebuild when the tab changes
    if (_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Animated AppBar and TabBar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: _isAppBarVisible ? kToolbarHeight + 48 : 0, // 48 is for TabBar
              child: AppBar(
                title: const Text(
                  'Search & Explore',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                backgroundColor: AppColors.background,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: 'Explore'),
                    Tab(text: 'Search'),
                  ],
                ),
              ),
            ),

            // Search bar with animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: (_tabController.index == 1 && _isAppBarVisible) ? 80 : 0,
              child: Padding(
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
            ),

            // Content area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Explore Tab - pass the scroll controller
                  ExploreScreen(scrollController: _mainScrollController),

                  // Search Tab - wrap with a NotificationListener or use a scroll controller
                  NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      if (scrollNotification is ScrollUpdateNotification) {
                        _scrollListener();
                      }
                      return false;
                    },
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
            ),
          ],
        ),
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