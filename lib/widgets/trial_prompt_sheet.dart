import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart';
import '../app_state.dart';
import 'package:provider/provider.dart';
import 'auth_prompt_dialog.dart';
import 'rainbow_hanger_icon.dart';
import '../screens/user_profile_screen.dart';

class TrialPromptSheet extends StatelessWidget {
  final Post post;

  const TrialPromptSheet({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    // Get real users who tried this prompt from the post data
    final List<TrialRecord> triedUsers = List<TrialRecord>.from(post.trialsList)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Take only the latest 10 as requested
    final latestTriedUsers = triedUsers.take(10).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // We take about 90% of screen height so the list can scroll nicely 
      // without fighting the bottom sheet fully.
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Drag handle
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
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  
                  // Clean, Centered Header Hierarchy
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Generated using',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.toolsUsed.isNotEmpty ? post.toolsUsed : 'An AI Tool',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 40),
                        
                        // Hero Data: The Count inside the Rainbow Hanger
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            const RainbowHangerIcon(
                              size: 140, // Slightly reduced for elegance
                              animate: true,
                            ),
                            Positioned(
                              bottom: 20, // Moved down to the center of the triangular body 
                              child: Text(
                                '${post.trialsCount}',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: -1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Supporting Label correctly scaled down
                        Text(
                          'Total Trials',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),

                  const Text(
                    'People who tried this prompt :',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Users List
                  if (latestTriedUsers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Be the first to try this prompt!',
                          style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                        ),
                      ),
                    )
                  else
                    ...latestTriedUsers.map((user) => GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(username: user.username),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[100],
                              ),
                              child: (user.avatar.isNotEmpty && user.avatar.startsWith('http'))
                                  ? CachedNetworkImage(
                                      imageUrl: user.avatar,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(color: Colors.grey[100]),
                                      errorWidget: (context, url, error) => Center(
                                        child: Text(
                                          user.username.isNotEmpty ? user.username[user.username.startsWith('@') ? 1 : 0].toUpperCase() : '?',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        user.username.isNotEmpty ? user.username[user.username.startsWith('@') ? 1 : 0].toUpperCase() : '?',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.username,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 15, 
                                      color: Colors.black87
                                    ),
                                  ),
                                  if (user.name.isNotEmpty && user.name != user.username)
                                    Text(
                                      user.name,
                                      style: TextStyle(
                                        color: Colors.grey[500], 
                                        fontSize: 13
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Consumer<AppState>(
                              builder: (context, state, child) {
                                final bool isFollowing = state.isFollowing(user.username);
                                // Don't show follow button for self
                                if (state.isLoggedIn && state.currentUser == user.username) {
                                  return const SizedBox.shrink();
                                }
                                return ElevatedButton(
                                  onPressed: () {
                                    if (!state.isLoggedIn) {
                                      AuthPromptDialog.show(
                                        context,
                                        title: 'Want to follow this user?',
                                        subtitle: 'Sign in to subscribe to this channel.',
                                      );
                                      return;
                                    }
                                    if (isFollowing) {
                                      state.unfollowUser(user.username);
                                    } else {
                                      state.followUser(user.username);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFollowing ? Colors.white : Colors.grey[100],
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: isFollowing ? BorderSide(color: Colors.grey[300]!) : BorderSide.none,
                                    ),
                                  ),
                                  child: Text(isFollowing ? 'Following' : 'Follow', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Bottom Copy Prompt Button (pinned to bottom)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  spreadRadius: 20,
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!appState.isLoggedIn) {
                    AuthPromptDialog.show(
                      context,
                      title: 'Try this prompt?',
                      subtitle: 'Sign in to remix and create your own art.',
                    );
                    return;
                  }
                  Clipboard.setData(ClipboardData(text: post.prompt));
                  // Optimistic trial record
                  appState.recordTrial(post.id);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prompt copied. Create your own version!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text(
                  'Copy Prompt',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrialPromptSheetWithButton extends StatelessWidget {
  final Post post;
  const TrialPromptSheetWithButton({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return TrialPromptSheet(post: post);
  }
}
