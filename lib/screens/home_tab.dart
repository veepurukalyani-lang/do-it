import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../app_state.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/custom_rocket_icon.dart';
import '../widgets/rainbow_hanger_icon.dart';
import 'video_viewer.dart';
import 'user_profile_screen.dart';
import '../widgets/trial_prompt_sheet.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/share_sheet.dart';
import '../services/firebase_service.dart';

final _viewedPosts = <String>{};

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _isTimedOut = false;
  late final javaScriptTimer = Timer(const Duration(seconds: 3), () {
    if (mounted && appState.posts.isEmpty) {
      setState(() => _isTimedOut = true);
    }
  });

  @override
  void dispose() {
    javaScriptTimer.cancel();
    super.dispose();
  }

  void _openFullScreen(List<Post> posts, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullScreenVideoViewer(posts: posts, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: isDesktop ? 0 : 48,
        title: isDesktop
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  Text('Ai', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black87, letterSpacing: -0.5)),
                  SizedBox(width: 6),
                  Text('🎨', style: TextStyle(fontSize: 24, height: 1.1)),
                  SizedBox(width: 6),
                  Text('Art', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.black87, letterSpacing: -0.5)),
                ],
              ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Consumer<AppState>(
            builder: (context, state, child) {
              final posts = state.posts;
              
              if (posts.isEmpty) {
                if (_isTimedOut) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('Taking longer than usual...', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _isTimedOut = false);
                            state.refreshFeed();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
              }

              return RefreshIndicator(
                onRefresh: () => state.refreshFeed(),
                color: Colors.deepPurple,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    return _FeedCard(
                      post: posts[index],
                      onTap: () => _openFullScreen(posts, index),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─── Feed Card ───────────────────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  final Post post;
  final VoidCallback onTap;

  const _FeedCard({required this.post, required this.onTap});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  final GlobalKey<RocketLaunchButtonState> _rocketKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_viewedPosts.contains(widget.post.id)) {
        _viewedPosts.add(widget.post.id);
        firebaseService.recordView(widget.post.id);
      }
    });
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserProfileScreen(username: post.username),
                  )),
                  child: Row(
                    children: [
                      // Avatar with gradient ring
                      Container(
                        width: 38,
                        height: 38,
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.purpleAccent, Colors.orangeAccent],
                          ),
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          padding: const EdgeInsets.all(1),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[100],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: post.profileImage.isNotEmpty && post.profileImage.startsWith('http')
                                ? Image.network(
                                    post.profileImage,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(color: Colors.grey[100]);
                                    },
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        post.username.isNotEmpty ? post.username[post.username.startsWith('@') ? 1 : 0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      post.username.isNotEmpty ? post.username[post.username.startsWith('@') ? 1 : 0].toUpperCase() : '?',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Media ────────────────────────────────────────
          GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: () => _rocketKey.currentState?.launch(isDoubleTap: true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _buildMedia(post),
              ),
            ),
          ),

          // ── Actions & Stats ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action row
                Row(
                  children: [
                    RocketLaunchButton(
                      key: _rocketKey,
                      likeCount: post.likesCount,
                      isLiked: post.isLiked,
                      iconSize: 26,
                      idleColor: Colors.black87,
                      textColor: Colors.black87,
                      direction: Axis.horizontal,
                      onTap: () {
                        if (!appState.isLoggedIn) {
                          AuthPromptDialog.show(context, title: 'Like this post?', subtitle: 'Sign in to like posts.');
                          return;
                        }
                        appState.toggleLike(post.id);
                        setState(() {
                          if (post.isLiked) { post.isLiked = false; post.likesCount--; }
                          else { post.isLiked = true; post.likesCount++; }
                        });
                      },
                    ),
                    if (!post.isVideo && post.prompt.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () {
                          if (!appState.isLoggedIn) {
                            AuthPromptDialog.show(context, title: 'Try this prompt?', subtitle: 'Sign in to copy the prompt.');
                            return;
                          }
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => TrialPromptSheetWithButton(post: post),
                          ).then((_) => setState(() {}));
                        },
                        child: Row(
                          children: [
                            const RainbowHangerIcon(size: 24),
                            const SizedBox(width: 5),
                            Text(_fmt(post.trialsCount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: widget.onTap,
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 24, color: Colors.black87),
                          const SizedBox(width: 5),
                          Text(_fmt(post.commentsList.length), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() => post.sharesCount++);
                        ShareSheet.show(context, "https://ai-art-2d80a.web.app/p/${post.id}");
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.share_outlined, size: 24, color: Colors.black87),
                          const SizedBox(width: 5),
                          Text(_fmt(post.sharesCount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Caption
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    children: [
                      TextSpan(text: post.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: '  ${post.caption}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(Post post) {
    if (post.isVideo || post.mediaUrl.toLowerCase().endsWith('.mp4')) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            post.thumbnailUrl.isNotEmpty
                ? Image.network(
                    post.thumbnailUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: Colors.black12),
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.black87),
                  )
                : Container(color: Colors.black87),
            Container(color: Colors.black.withValues(alpha: 0.08)),
            const Center(child: Icon(Icons.play_circle_fill, size: 54, color: Colors.white)),
          ],
        ),
      );
    }

    // Image
    if (kIsWeb || post.mediaUrl.startsWith('http')) {
      return Image.network(
        post.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 400,
            color: Colors.grey[100],
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
                color: Colors.deepPurple,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(height: 300, color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 48, color: Colors.grey)),
      );
    }
    return Image.network(post.mediaUrl, fit: BoxFit.cover, width: double.infinity);
  }
}
