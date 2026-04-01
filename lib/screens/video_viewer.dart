import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/post.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/trial_prompt_sheet.dart';
import '../widgets/custom_rocket_icon.dart';
import '../widgets/rainbow_hanger_icon.dart';
import 'user_profile_screen.dart';
import '../app_state.dart';
import 'package:provider/provider.dart';
import '../widgets/rainbow_text.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/share_sheet.dart';

class FullScreenVideoViewer extends StatefulWidget {
  final List<Post> posts;
  final int initialIndex;

  const FullScreenVideoViewer({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    // Hide nav bar when entering full screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.setNavBarVisible(false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Use addPostFrameCallback to avoid calling notifyListeners during build/dispose cycle if possible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.setNavBarVisible(true);
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          appState.setNavBarVisible(true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: widget.posts.length,
                itemBuilder: (context, index) {
                  final post = widget.posts[index];
                  if (post.isVideo) {
                    return VideoPage(post: post);
                  } else {
                    return ImagePage(post: post);
                  }
                },
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.close, size: 32, color: Colors.white),
                  onPressed: () {
                    appState.setNavBarVisible(true);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImagePage extends StatefulWidget {
  final Post post;
  const ImagePage({super.key, required this.post});

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  final GlobalKey<RocketLaunchButtonState> _rocketKey = GlobalKey<RocketLaunchButtonState>();

  void _onLikeTap() {
    if (!mounted) return;
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Like this post?',
        subtitle: 'Sign in to make your opinion count.',
      );
      return;
    }
    setState(() {
      if (!widget.post.isLiked) {
        widget.post.isLiked = true;
        widget.post.likesCount++;
      } else {
        widget.post.isLiked = false;
        widget.post.likesCount--;
      }
    });
    appState.toggleLike(widget.post.id);
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _onDoubleTap() {
    _rocketKey.currentState?.launch(isDoubleTap: true);
  }

  void _onShareTap() {
    setState(() => widget.post.sharesCount++);
    ShareSheet.show(context, "https://ai-art-2d80a.web.app/p/${widget.post.id}");
  }

  void _onSaveTap() {
    setState(() => widget.post.isSaved = !widget.post.isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.post.isSaved ? 'Saved to collection' : 'Removed from collection'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showComments() {
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Want to join the conversation?',
        subtitle: 'Sign in to continue.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsSheet(post: widget.post),
    ).then((_) => setState(() {}));
  }

  void _showTrialPrompt() {
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Try this prompt?',
        subtitle: 'Sign in to create your own version.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentPost = Provider.of<AppState>(context, listen: false).posts.firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post);
        return TrialPromptSheetWithButton(post: currentPost);
      },
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. IMAGE PLAYER (Base Layer)
        (kIsWeb || widget.post.mediaUrl.startsWith('http'))
            ? FittedBox(
                fit: BoxFit.contain,
                clipBehavior: Clip.hardEdge,
                child: CachedNetworkImage(
                  imageUrl: widget.post.mediaUrl,
                ),
              )
            : Container(color: Colors.black), // Fallback

        // 2. GESTURE DETECTION LAYER (Middle Layer)
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: _onDoubleTap,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),

        // 3. UI OVERLAYS (Top Layer - Shadows)
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent, Colors.black.withOpacity(0.4)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Non-ignored interactive parts
        Positioned(
          bottom: 20,
          left: 12,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  appState.setNavBarVisible(true);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(username: widget.post.username),
                    ),
                  ).then((_) {
                    if (mounted) appState.setNavBarVisible(false);
                  });
                },
                child: Row(
                  children: [
                    Text(
                      widget.post.username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    if (widget.post.username != Provider.of<AppState>(context, listen: false).currentUser)
                      Consumer<AppState>(
                        builder: (context, state, child) {
                          final bool isFollowing = state.isFollowing(widget.post.username);
                          return GestureDetector(
                            onTap: () {
                              if (!state.isLoggedIn) {
                                AuthPromptDialog.show(
                                  context,
                                  title: 'Want to follow this user?',
                                  subtitle: 'Sign in to subscribe to this channel.',
                                );
                                return;
                              }
                              if (isFollowing) {
                                state.unfollowUser(widget.post.username);
                              } else {
                                state.followUser(widget.post.username);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.post.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Positioned(
          bottom: 20,
          right: 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: RocketLaunchButton(
                  key: _rocketKey,
                  likeCount: widget.post.likesCount,
                  isLiked: widget.post.isLiked,
                  onTap: _onLikeTap,
                  iconSize: 32,
                  authTitle: 'Like this post?',
                  authSubtitle: 'Sign in to make your opinion count.',
                ),
              ),
              if (!widget.post.isVideo && widget.post.prompt.isNotEmpty)
                _buildActionButton(
                  icon: const RainbowHangerIcon(size: 32),
                  label: _fmt(Provider.of<AppState>(context, listen: false).posts.firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post).trialsCount),
                  onTap: _showTrialPrompt,
                  isRainbow: false,
                ),
              _buildActionButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 32),
                label: _fmt(widget.post.commentsList.length),
                onTap: _showComments,
              ),
              _buildActionButton(
                icon: const Icon(Icons.share_outlined, size: 32),
                label: _fmt(widget.post.sharesCount),
                onTap: _onShareTap,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool isRainbow = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          IconButton(
            icon: icon,
            color: Colors.white,
            onPressed: onTap,
          ),
          isRainbow 
            ? RainbowText(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
            : Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class VideoPage extends StatefulWidget {
  final Post post;
  const VideoPage({super.key, required this.post});

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> with SingleTickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _isPaused = false;
  bool _isFinishedLoading = false;
  final GlobalKey<RocketLaunchButtonState> _rocketKey = GlobalKey<RocketLaunchButtonState>();
  
  bool _showRocket = false;
  late AnimationController _rocketController;
  late Animation<double> _rocketAnimation;

  @override
  void initState() {
    super.initState();
    
    _rocketController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _rocketAnimation = Tween<double>(
      begin: 0,
      end: -150,
    ).animate(
      CurvedAnimation(parent: _rocketController, curve: Curves.easeOut),
    );

    if (widget.post.mediaUrl.startsWith('http') || kIsWeb) {
      final String safeUrl = widget.post.mediaUrl.replaceAll('file://', '');
      _videoController = VideoPlayerController.networkUrl(Uri.parse(safeUrl));
    } else {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.post.mediaUrl));
    }
    
    _videoController.initialize().then((_) {
      if (mounted) {
        setState(() => _isFinishedLoading = true);
        _videoController.play();
        _videoController.setLooping(true);
        _videoController.setVolume(1.0); // Ensure volume is up
      }
    }).catchError((e) {
      debugPrint("Video init error: $e");
    });
    _videoController.addListener(_videoListener);
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }
  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _rocketController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_videoController.value.isInitialized) return;
    if (_videoController.value.isPlaying) {
      _videoController.pause();
      setState(() => _isPaused = true);
    } else {
      _videoController.play();
      setState(() => _isPaused = false);
    }
  }

  void _onDoubleTap() {
    _rocketKey.currentState?.launch(isDoubleTap: true);
  }

  void _onLikeTap() {
    if (!mounted) return;
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Like this video?',
        subtitle: 'Sign in to make your opinion count.',
      );
      return;
    }
    setState(() {
      if (!widget.post.isLiked) {
        widget.post.isLiked = true;
        widget.post.likesCount++;
      } else {
        widget.post.isLiked = false;
        widget.post.likesCount--;
      }
    });
    appState.toggleLike(widget.post.id);
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  void _onShareTap() {
    setState(() => widget.post.sharesCount++);
    ShareSheet.show(context, "https://ai-art-2d80a.web.app/p/${widget.post.id}");
  }

  void _onSaveTap() {
    setState(() => widget.post.isSaved = !widget.post.isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.post.isSaved ? 'Saved to collection' : 'Removed from collection'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showComments() {
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Want to join the conversation?',
        subtitle: 'Sign in to continue.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CommentsSheet(post: widget.post),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _showTrialPrompt() {
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Try this prompt?',
        subtitle: 'Sign in to create your own version.',
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentPost = Provider.of<AppState>(context, listen: false).posts.firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post);
        return TrialPromptSheetWithButton(post: currentPost);
      },
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. VIDEO PLAYER (Base Layer)
        if (_isFinishedLoading)
          FittedBox(
            fit: BoxFit.contain,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _videoController.value.size.width,
              height: _videoController.value.size.height,
              child: VideoPlayer(_videoController),
            ),
          )
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),

        // 2. GESTURE DETECTION LAYER (Middle Layer - Full Screen)
        // This ensures taps anywhere on the screen trigger the gestures.
        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlay,
            onDoubleTap: _onDoubleTap,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),

        // 3. UI OVERLAYS (Top Layer)
        // Shadows and visual decorations are ignored for hits so they don't block the gesture layer.
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Gradients for readability
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),

              // Play/Pause Animation Overlay
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isPaused ? 1.0 : 0.0,
                  child: const Icon(
                    Icons.play_arrow,
                    size: 90,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Interactive UI Elements (Title, Buttons, etc.)
        // These are placed AFTER the gesture layer to prioritize their hits.
        
        // Bottom Information Area
        Positioned(
          bottom: 20,
          left: 16,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  appState.setNavBarVisible(true);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(username: widget.post.username),
                    ),
                  ).then((_) {
                    if (mounted) appState.setNavBarVisible(false);
                  });
                },
                child: Row(
                  children: [
                    Text(
                      widget.post.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.post.username != Provider.of<AppState>(context, listen: false).currentUser)
                      Consumer<AppState>(
                        builder: (context, state, child) {
                          final bool isFollowing = state.isFollowing(widget.post.username);
                          return GestureDetector(
                            onTap: () {
                              if (!state.isLoggedIn) {
                                AuthPromptDialog.show(
                                  context,
                                  title: 'Want to follow this user?',
                                  subtitle: 'Sign in to stay updated on their latest art.',
                                );
                                return;
                              }
                              if (isFollowing) {
                                state.unfollowUser(widget.post.username);
                              } else {
                                state.followUser(widget.post.username);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.post.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),

        // Side Action Buttons
        Positioned(
          bottom: 20,
          right: 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: RocketLaunchButton(
                  key: _rocketKey,
                  likeCount: widget.post.likesCount,
                  isLiked: widget.post.isLiked,
                  onTap: _onLikeTap,
                  iconSize: 32,
                  authTitle: 'Like this video?',
                  authSubtitle: 'Sign in to make your opinion count.',
                ),
              ),
              if (!widget.post.isVideo && widget.post.prompt.isNotEmpty)
                _buildActionButton(
                  icon: const RainbowHangerIcon(size: 32),
                  label: _fmt(Provider.of<AppState>(context, listen: false).posts.firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post).trialsCount),
                  onTap: _showTrialPrompt,
                  isRainbow: false,
                ),
              _buildActionButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 32),
                label: _fmt(widget.post.commentsList.length),
                onTap: _showComments,
              ),
              _buildActionButton(
                icon: const Icon(Icons.share_outlined, size: 32),
                label: _fmt(widget.post.sharesCount),
                onTap: _onShareTap,
              ),
            ],
          ),
        ),

        // Bottom Progress Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _videoController,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    bool isRainbow = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
          IconButton(
            icon: icon,
            color: Colors.white,
            onPressed: onTap,
          ),
          isRainbow 
            ? RainbowText(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
            : Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
