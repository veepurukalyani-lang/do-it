import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';
import '../models/post.dart';
import '../widgets/rainbow_hanger_icon.dart';
import 'user_profile_screen.dart';
import '../widgets/rainbow_text.dart';
import '../services/firebase_service.dart';

class TrendingTab extends StatefulWidget {
  const TrendingTab({super.key});

  @override
  State<TrendingTab> createState() => _TrendingTabState();
}

class _TrendingTabState extends State<TrendingTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 100,
        title: const Padding(
          padding: EdgeInsets.only(top: 20, left: 8),
          child: Text(
            'Most Popular Artists',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: 34,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firebaseService.getTrendingArtistsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
          }
          
          final top10Users = snapshot.data ?? [];
          
          if (top10Users.isEmpty) {
            return const Center(child: Text("No trending creators yet. Be the first to try a prompt!", style: TextStyle(color: Colors.grey, fontSize: 16)));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            itemCount: top10Users.length,
            itemBuilder: (context, index) {
              final entry = top10Users[index];
              final username = entry['username'] ?? 'Anonymous';
              final trialsCount = entry['trials'] ?? 0;
              final avatarUrl = entry['avatar']?.toString();
              final rank = index + 1;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(username: username),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: Colors.grey[100],
                  leading: SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        // Rank number BEFORE everything
                        SizedBox(
                          width: 32,
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              color: Colors.grey[400], // Muted rank
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        // Avatar
                        Container(
                          width: 54,
                          height: 54,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[100],
                          ),
                          child: avatarUrl != null && avatarUrl.startsWith('http')
                              ? Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, p) => p == null ? child : Container(color: Colors.grey[100]),
                                  errorBuilder: (context, error, stackTrace) => Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold))),
                                )
                              : Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold))),
                        ),
                      ],
                    ),
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RainbowHangerIcon(size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _formatCount(trialsCount),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
