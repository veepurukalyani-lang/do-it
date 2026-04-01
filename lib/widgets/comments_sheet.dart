import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../app_state.dart';
import 'auth_prompt_dialog.dart';

class CommentsSheet extends StatefulWidget {
  final Post post;
  const CommentsSheet({super.key, required this.post});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _controller = TextEditingController();

  void _addComment() {
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: 'Want to join the conversation?',
        subtitle: 'Sign in to comment.',
      );
      return;
    }
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      context.read<AppState>().submitComment(widget.post.id, text);
      setState(() {
        final newComment = Comment(
          username: appState.currentUser,
          profileImage: appState.currentUserProfileImage ?? '',
          text: text,
          timestamp: DateTime.now(),
        );
        widget.post.commentsList.insert(0, newComment);
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // balance
                Text(
                  '${widget.post.commentsList.length} Comments',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          // Comments List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: widget.post.commentsList.length,
              itemBuilder: (context, index) {
                final comment = widget.post.commentsList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.purple.withOpacity(0.1),
                        backgroundImage: comment.profileImage.isNotEmpty 
                            ? NetworkImage(comment.profileImage) 
                            : null,
                        child: comment.profileImage.isEmpty 
                            ? const Icon(Icons.person, size: 18, color: Colors.deepPurple) 
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              comment.username,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(comment.text, style: const TextStyle(color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Input Field
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  backgroundImage: appState.currentUserProfileImage != null 
                      ? NetworkImage(appState.currentUserProfileImage!) 
                      : null,
                  child: appState.currentUserProfileImage == null 
                      ? const Icon(Icons.person, size: 18, color: Colors.deepPurple) 
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.black87),
                    onTap: () {
                      if (!appState.isLoggedIn) {
                        AuthPromptDialog.show(
                          context,
                          title: 'Want to join the conversation?',
                          subtitle: 'Sign in to continue.',
                        );
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Add comment...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.deepPurple),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
