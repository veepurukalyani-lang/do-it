import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../app_state.dart';
import 'video_viewer.dart';
import '../widgets/rainbow_hanger_icon.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/rainbow_text.dart';
import '../services/firebase_service.dart';
import '../widgets/auth_prompt_dialog.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;

  const UserProfileScreen({super.key, required this.username});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isManageMode = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final bool isMe = widget.username == state.currentUser;
        final bool isFollowing = state.isFollowing(widget.username);
        final int totalTries = state.getUserTotalTries(widget.username);


        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Navigator.canPop(context) ? const BackButton(color: Colors.black) : null,
            title: Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            actions: [
              if (isMe) 
                IconButton(
                  icon: Icon(_isManageMode ? Icons.close : Icons.settings_outlined, color: Colors.black),
                  onPressed: () {
                    if (_isManageMode) {
                      setState(() => _isManageMode = false);
                    } else {
                      _showSettings(context, state);
                    }
                  },
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Column(
                          children: [
                            _buildProfileHeader(widget.username),
                            const SizedBox(height: 20),
                            Text(
                              widget.username.replaceFirst('@', ''),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: -0.5, color: Colors.black),
                            ),
                            const SizedBox(height: 12),
                            StreamBuilder<Map<String, dynamic>?>(
                              stream: firebaseService.getUserData(widget.username),
                              builder: (context, snapshot) {
                                final data = snapshot.data;
                                final bio = data?['bio'] ?? (isMe ? state.currentBio : 'AI Art enthusiast & prompt engineer. Stay creative! 🎨✨');
                                return Text(
                                  bio,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 15, height: 1.4),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            
                            // Stats
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  StreamBuilder<Map<String, dynamic>?>(
                                    stream: firebaseService.getUserData(widget.username),
                                    builder: (context, snapshot) {
                                      final data = snapshot.data;
                                      final followers = data?['followersCount'] ?? 0;
                                      final following = data?['followingCount'] ?? 0;
                                      
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          GestureDetector(
                                            onTap: isMe ? () => _showUserList(context, 'Following', state) : null,
                                            child: _buildStat('Following', '$following'),
                                          ),
                                          const SizedBox(width: 20),
                                          _buildHangerStat(totalTries),
                                          const SizedBox(width: 20),
                                          GestureDetector(
                                            onTap: (isMe && state.isLoggedIn) ? () => _showUserList(context, 'Followers', state) : null,
                                            child: _buildStat('Followers', '$followers'),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            if (isMe)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: OutlinedButton(
                                        onPressed: () => _showEditProfile(context, state),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.grey[300]!),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text('Edit profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SizedBox(
                                      height: 38,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() => _isManageMode = true);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Manage mode enabled. Tap a post to delete.'), duration: Duration(seconds: 2)),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.grey[300]!),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          foregroundColor: Colors.black,
                                        ),
                                        child: const Text('Manage Reels/post', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 12),
                            
                            if (!isMe)
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (!state.isLoggedIn) {
                                      AuthPromptDialog.show(
                                        context,
                                        title: 'Want to follow this user?',
                                        subtitle: 'Sign in to stay updated on their latest art.',
                                      );
                                      return;
                                    }
                                    if (isFollowing) {
                                      state.unfollowUser(widget.username);
                                    } else {
                                      state.followUser(widget.username);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing ? Colors.grey[100] : Colors.black,
                                    foregroundColor: isFollowing ? Colors.black : Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const Divider(height: 1),
                      
                      // Instagram Style Grid
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: StreamBuilder<List<Post>>(
                          stream: firebaseService.getUserPostsStream(widget.username),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ));
                            }
                            final userPosts = snapshot.data ?? [];
                            if (userPosts.isEmpty) {
                              return Center(child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Column(
                                  children: [
                                    Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey[300]),
                                    const SizedBox(height: 8),
                                    Text('No posts yet', style: TextStyle(color: Colors.grey[400])),
                                  ],
                                ),
                              ));
                            }
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                                childAspectRatio: 0.8,
                              ),
                              itemCount: userPosts.length,
                              itemBuilder: (context, index) {
                                final post = userPosts[index];
                                return _buildGridItem(post, isMe, state, userPosts, index);
                              },
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridItem(dynamic post, bool isMe, AppState state, List<dynamic> userPosts, int index) {
    return GestureDetector(
      onTap: () {
        if (_isManageMode && isMe) {
          _showEditPostDialog(context, post, state);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenVideoViewer(
                posts: userPosts.cast<Post>(),
                initialIndex: index,
              ),
            ),
          );
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or Placeholder for Video (Handle both network and potential local paths)
          Container(
            color: Colors.grey[200],
            child: post.mediaUrl.startsWith('http')
                ? ((post.isVideo && post.thumbnailUrl.isEmpty)
                    ? Container(color: Colors.black87)
                    : Image.network(
                        post.isVideo ? post.thumbnailUrl : post.mediaUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[400]));
                        },
                        errorBuilder: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ))
                : ((post.isVideo && post.thumbnailUrl.isEmpty)
                    ? Container(color: Colors.black87)
                    : Image.network(post.isVideo ? post.thumbnailUrl : post.mediaUrl, fit: BoxFit.cover)),
          ),
          
          // Overlay for Views/Type (Premium styling)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(post.isVideo ? Icons.play_arrow_rounded : Icons.remove_red_eye_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _formatCount(post.viewsCount),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          
          if (post.isVideo)
            const Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.video_library_rounded, size: 16, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
            ),
  
  
          // Manage Mode: Edit Pen Icon
          if (isMe && _isManageMode)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.deepPurple),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditPostDialog(BuildContext context, dynamic post, AppState state) {
    final titleController = TextEditingController(text: post.caption);
    final promptController = TextEditingController(text: post.prompt);
    final toolController = TextEditingController(text: post.toolsUsed);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post.isVideo ? 'Edit Reel' : 'Edit Post'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Caption/Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              if (!post.isVideo) ...[
                TextField(
                  controller: promptController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Prompt',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: toolController,
                  decoration: InputDecoration(
                    labelText: 'AI Tool Used',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => _confirmDelete(post.id, state),
                child: const Text('Delete Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel')
          ),
          ElevatedButton(
            onPressed: () {
              firebaseService.updatePost(
                postId: post.id,
                caption: titleController.text,
                prompt: promptController.text,
                toolsUsed: toolController.text,
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Changes saved successfully!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String postId, AppState state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text('Do you really want to delete this reel/post? This action is permanent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('No', style: TextStyle(fontWeight: FontWeight.bold))
          ),
          TextButton(
            onPressed: () {
              state.deletePost(postId);
              Navigator.pop(context); // Pop confirm dialog
              Navigator.pop(context); // Pop edit dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post deleted successfully.')),
              );
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Options', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                _showEditProfile(context, state);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded),
              title: const Text('Manage Reels/Posts'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _isManageMode = true);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              subtitle: const Text('you may lose all your data'),
              onTap: () {
                Navigator.pop(context);
                state.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session cleared successfully.')),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context, AppState state) {
    final nameController = TextEditingController(text: state.currentUser);
    final bioController = TextEditingController(text: state.currentBio);
    XFile? selectedFile; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Profile'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                    if (image != null) {
                      setDialogState(() => selectedFile = image);
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: selectedFile != null
                            ? Image.network(selectedFile!.path, fit: BoxFit.cover)
                            : (state.currentUserProfileImage != null
                                ? CachedNetworkImage(
                                    imageUrl: state.currentUserProfileImage!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorWidget: (context, url, error) => const Icon(Icons.person, size: 40, color: Colors.grey),
                                  )
                                : const Icon(Icons.add_a_photo, color: Colors.grey, size: 30)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: bioController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                showDialog(
                  context: context, 
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator())
                );
                await state.updateProfile(nameController.text, bioController.text, profileImageFile: selectedFile);
                Navigator.pop(context); // Pop loading
                Navigator.pop(context); // Pop dialog
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserList(BuildContext context, String title, AppState state) {
    final bool isMe = widget.username == state.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<dynamic>(
                stream: title == 'Following' 
                    ? firebaseService.getFollowingStream().map((list) => list.map((u) => {'username': u}).toList())
                    : firebaseService.getFollowersStream(widget.username),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final List users = snapshot.data!;
                  
                  if (users.isEmpty) {
                    return Center(child: Text('No $title yet.', style: TextStyle(color: Colors.grey[400])));
                  }

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userMap = users[index];
                      final String user = userMap['username']?.toString() ?? 'User';
                      final String profileImg = userMap['profileImage']?.toString() ?? '';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[100],
                          backgroundImage: profileImg.isNotEmpty ? CachedNetworkImageProvider(profileImg) : null,
                          child: (profileImg.isEmpty && user.isNotEmpty) 
                              ? Text(user[1].toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 12)) 
                              : (user.isEmpty ? const Icon(Icons.person, color: Colors.black) : null),
                        ),
                        title: Text(user, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
                        trailing: (isMe && title == 'Following') ? ElevatedButton(
                          onPressed: () => state.unfollowUser(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Unfollow', style: TextStyle(fontSize: 12)),
                        ) : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UserProfileScreen(username: user)),
                          );
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
    );
  }

  Widget _buildProfileHeader(String username) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: firebaseService.getUserData(username),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final String? profileImg = data?['profileImage'];
        final bool hasValidImage = profileImg != null && profileImg.isNotEmpty && profileImg.startsWith('http') && !profileImg.contains('.svg');

        return Container(
          width: 100,
          height: 100,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: !hasValidImage ? LinearGradient(
              colors: [Colors.purpleAccent.withOpacity(0.8), Colors.pinkAccent.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
            color: hasValidImage ? Colors.grey[200] : null,
            boxShadow: [
              BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: hasValidImage
              ? Image.network(
                  profileImg!,
                  fit: BoxFit.cover,
                  width: 100,
                  height: 100,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purpleAccent.withOpacity(0.8), Colors.pinkAccent.withOpacity(0.8)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        username.isNotEmpty ? username[username.startsWith('@') ? 1 : 0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    username.isNotEmpty ? username[username.startsWith('@') ? 1 : 0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
        );
      }
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildHangerStat(int totalTries) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RainbowHangerIcon(size: 20),
            const SizedBox(width: 4),
            Text(_formatCount(totalTries), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Trials', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
