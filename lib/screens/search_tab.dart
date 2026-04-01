import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../app_state.dart';
import 'video_viewer.dart';
import 'user_profile_screen.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ['All', 'Videos', 'Images', 'Trending', 'Accounts'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _openFullScreenViewer(List<Post> filteredPosts, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => FullScreenVideoViewer(
        posts: filteredPosts,
        initialIndex: index,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.black87),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search prompts, hashtags, accounts...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          // Filtering logic
          List<Post> filteredPosts = state.posts.where((post) {
            final matchesSearch = post.caption.toLowerCase().contains(_searchQuery) ||
                post.prompt.toLowerCase().contains(_searchQuery) == true ||
                post.username.toLowerCase().contains(_searchQuery);

            if (!matchesSearch) return false;

            if (_selectedCategoryIndex == 1) return post.isVideo; // Videos
            if (_selectedCategoryIndex == 2) return !post.isVideo; // Images
            return true; // All / Trending
          }).toList();

          if (_selectedCategoryIndex == 3) {
            // Trending: sort by likes + remixes
            filteredPosts.sort((a, b) => (b.likesCount + b.trialsCount).compareTo(a.likesCount + a.trialsCount));
          }

          return Column(
            children: [
              // Categories
              const SizedBox(height: 12),
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    bool isSelected = _selectedCategoryIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: ChoiceChip(
                        label: Text(_categories[index]),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        selected: isSelected,
                        selectedColor: Colors.deepPurple,
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        side: BorderSide(color: isSelected ? Colors.deepPurple : Colors.transparent),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _selectedCategoryIndex == 4 
                    ? _buildAccountSearch(state)
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: filteredPosts.length,
                        itemBuilder: (context, index) {
                          final post = filteredPosts[index];
                          return GestureDetector(
                            onTap: () => _openFullScreenViewer(filteredPosts, index),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                post.mediaUrl.startsWith('http')
                                    ? ((post.isVideo && post.thumbnailUrl.isEmpty)
                                        ? Container(color: Colors.black87)
                                        : Image.network(
                                            post.isVideo ? post.thumbnailUrl : post.mediaUrl,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, p) => p == null ? child : Container(color: Colors.grey[200]),
                                            errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                                          ))
                                    : Image.network(post.mediaUrl, fit: BoxFit.cover),
                                if (post.isVideo)
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountSearch(AppState state) {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search for AI Creators', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: state.searchAccounts(_searchQuery),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No accounts found', style: TextStyle(color: Colors.grey)),
          );
        }

        final filteredUsers = snapshot.data!;

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final userData = filteredUsers[index];
            final username = userData['username'] ?? 'Anonymous';
            final avatarUrl = userData['profileImage'] ?? '';
            final bio = userData['bio'] ?? 'AI Creator';

            return ListTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(username: username),
                  ),
                );
              },
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepPurple.withOpacity(0.1),
                  image: avatarUrl.isNotEmpty && avatarUrl.startsWith('http')
                      ? NetworkImage(avatarUrl)
                      : null,
                ),
                child: avatarUrl.isEmpty || !avatarUrl.startsWith('http')
                    ? Center(child: Text(username.isNotEmpty ? username[username.startsWith('@') ? 1 : 0].toUpperCase() : '?', style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)))
                    : null,
              ),
              title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              subtitle: Text(bio, style: TextStyle(color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
            );
          },
        );
      },
    );
  }
}
