import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─────────────────────────────────────────────
  // FEED STREAMS
  // ─────────────────────────────────────────────

  /// "For You" feed — recent 60 posts, sorted by engagement score locally
  /// "For You" feed — recent 200 posts, interleaved by creator for diversity
  Stream<List<Post>> getHomeFeedStream({List<String>? followingUsers}) {
    return _firestore
        .collection('posts')
        .limit(40) // Reduced from 400 to 40 for 1s load time
        .snapshots()
        .map((snapshot) {
      List<Post> allPosts = snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList();

      // 1. Group posts by creator
      final Map<String, List<Post>> groupedByCreator = {};
      for (var post in allPosts) {
        groupedByCreator.putIfAbsent(post.username, () => []).add(post);
      }

      // 2. Interleave: Pick one from each creator in a deterministic round-robin fashion
      final List<Post> interleavedPosts = [];
      final List<String> creators = groupedByCreator.keys.toList()..sort();
      
      bool addedAny = true;
      int index = 0;
      while (addedAny) {
        addedAny = false;
        for (var creator in creators) {
          final creatorPosts = groupedByCreator[creator]!;
          if (index < creatorPosts.length) {
            interleavedPosts.add(creatorPosts[index]);
            addedAny = true;
          }
        }
        index++;
      }

      return interleavedPosts;
    });
  }

  /// "Following" feed — only posts from people you follow
  Stream<List<Post>> getFollowingFeedStream(List<String> followingUsernames) {
    if (followingUsernames.isEmpty) return Stream.value([]);

    // Firestore whereIn limit is 30 — chunk if needed
    final chunks = <List<String>>[];
    for (int i = 0; i < followingUsernames.length; i += 30) {
      chunks.add(followingUsernames.sublist(i, i + 30 > followingUsernames.length ? followingUsernames.length : i + 30));
    }

    // Merge streams for all chunks
    if (chunks.length == 1) {
      return _firestore
          .collection('posts')
          .where('username', whereIn: chunks[0])
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots()
          .map((s) => s.docs.map((d) => Post.fromMap(d.data())).toList());
    }

    // For multiple chunks, use the first chunk (keep it simple)
    return _firestore
        .collection('posts')
        .where('username', whereIn: chunks[0])
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((s) => s.docs.map((d) => Post.fromMap(d.data())).toList());
  }

  /// "New" feed — purely chronological, most recent first
  Stream<List<Post>> getNewFeedStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots()
        .map((s) => s.docs.map((d) => Post.fromMap(d.data())).toList());
  }

  /// Trending posts — sorted by trialsCount in real time
  Stream<List<Post>> getTrendingFeedStream({int limit = 20}) {
    return _firestore
        .collection('posts')
        .orderBy('trialsCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => Post.fromMap(d.data())).toList());
  }

  /// Real-time leaderboard — artists ranked by total trials across all their posts
  /// Uses a compound aggregation stream: listens to all posts and groups locally
  Stream<List<Map<String, dynamic>>> getTrendingArtistsStream() {
    return _firestore
        .collection('posts')
        .orderBy('trialsCount', descending: true)
        .limit(100) // Reduced from 400 to 100 for faster aggregation
        .snapshots()
        .map((snapshot) {
      final Map<String, int> userTrials = {};
      final Map<String, int> userLikes = {};
      final Map<String, int> userViews = {};
      final Map<String, String> userAvatars = {};
      final Map<String, int> userPostCount = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Normalization for aggregation: lowercase, no @
        final rawUser = data['username']?.toString() ?? 'Anonymous';
        final username = rawUser.trim(); // Keep original casing but trim whitespace
        final lookupKey = username.toLowerCase().replaceAll('@', '');
        
        final isVideo = data['isVideo'] == true || (data['mediaUrl']?.toString().toLowerCase().endsWith('.mp4') ?? false);
        final trials = data['trialsCount'] ?? data['remixes'] ?? 0;
        final prompt = data['prompt']?.toString() ?? '';

        // ONLY aggregate trials for non-video posts with prompts
        if (!isVideo && prompt.trim().isNotEmpty) {
          userTrials[lookupKey] = (userTrials[lookupKey] ?? 0) + (trials as num).toInt();
          // Keep track of the display name
          userAvatars[lookupKey + '_dn'] = username;
        }
        
        userLikes[lookupKey] = (userLikes[lookupKey] ?? 0) + (data['likesCount'] as num? ?? 0).toInt();
        userViews[lookupKey] = (userViews[lookupKey] ?? 0) + (data['viewsCount'] as num? ?? 0).toInt();
        userPostCount[lookupKey] = (userPostCount[lookupKey] ?? 0) + 1;
        
        final profileImage = data['profileImage']?.toString() ?? '';
        if (profileImage.isNotEmpty && !profileImage.contains('.svg')) {
          userAvatars[lookupKey] = profileImage;
        }
      }

      final sorted = userTrials.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(20).map((entry) => {
        'username': userAvatars[entry.key + '_dn'] ?? entry.key,
        'trials': entry.value,
        'likes': userLikes[entry.key] ?? 0,
        'views': userViews[entry.key] ?? 0,
        'posts': userPostCount[entry.key] ?? 0,
        'avatar': userAvatars[entry.key] ?? '',
      }).toList();
    });
  }

  // ─────────────────────────────────────────────
  // USER INTERACTION STREAMS
  // ─────────────────────────────────────────────

  Stream<List<String>> getFollowingStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('following')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  Stream<List<Map<String, dynamic>>> getFollowersStream(String username) {
    return _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return [];
      final followers = await snapshot.docs.first.reference.collection('followers').get();
      return followers.docs.map((d) => {
        'username': d.id,
        'profileImage': d.data()['profileImage'] ?? '',
      }).toList();
    });
  }

  Stream<List<String>> getLikedPostsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likes')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  Stream<List<String>> getTriedPostsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('trials')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toList());
  }

  // ─────────────────────────────────────────────
  // VIEW TRACKING
  // ─────────────────────────────────────────────

  /// Call this when a post appears in the viewport — debounced per session
  Future<void> recordView(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'viewsCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('View record error: $e');
    }
  }

  // ─────────────────────────────────────────────
  // FOLLOWS
  // ─────────────────────────────────────────────

  Future<void> toggleFollow(String targetUsername, bool currentlyFollowing) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final myUid = user.uid;
    final myUsername = user.displayName ?? user.email?.split('@').first ?? 'User';
    
    final batch = _firestore.batch();
    
    // 1. Update my 'following' subcollection
    final myFollowingRef = _firestore.collection('users').doc(myUid).collection('following').doc(targetUsername);
    
    // 2. Identify the target user's document
    final targetUserQuery = await _firestore.collection('users').where('username', isEqualTo: targetUsername).limit(1).get();
    DocumentReference? targetUserRef;
    if (targetUserQuery.docs.isNotEmpty) {
      targetUserRef = targetUserQuery.docs.first.reference;
    }

    if (currentlyFollowing) {
      batch.delete(myFollowingRef);
      // Decrement counts
      batch.update(_firestore.collection('users').doc(myUid), {'followingCount': FieldValue.increment(-1)});
      if (targetUserRef != null) {
        batch.update(targetUserRef, {'followersCount': FieldValue.increment(-1)});
        // Remove me from their followers
        batch.delete(targetUserRef.collection('followers').doc(myUsername));
      }
    } else {
      batch.set(myFollowingRef, {'timestamp': FieldValue.serverTimestamp()});
      // Increment counts
      batch.set(_firestore.collection('users').doc(myUid), {'followingCount': FieldValue.increment(1)}, SetOptions(merge: true));
      if (targetUserRef != null) {
        batch.update(targetUserRef, {'followersCount': FieldValue.increment(1)});
        // Add me to their followers
        batch.set(targetUserRef.collection('followers').doc(myUsername), {
          'timestamp': FieldValue.serverTimestamp(),
          'profileImage': user.photoURL ?? '',
        });
      }
    }
    
    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // UPLOAD
  // ─────────────────────────────────────────────

  Future<void> uploadPost({
    required String caption,
    required String prompt,
    required String toolsUsed,
    required dynamic file,
    required bool isVideo,
    dynamic thumbnailFile,
    String? username,
    String? profileImage,
    Function(String stage, double progress)? onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('You must be signed in to upload posts.');

      final String finalUsername = (username != null && username.isNotEmpty)
          ? username
          : (user.displayName?.isNotEmpty == true
              ? user.displayName!
              : (user.email?.split('@').first ?? 'Artist'));

      final rawProfileImage = profileImage ?? user.photoURL ?? '';
      final String finalProfileImage = rawProfileImage.contains('.svg') ? '' : rawProfileImage;

      final String userId = user.uid;
      final String postId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';

      onProgress?.call('Uploading...', 0.0);

      final String mimeType = isVideo ? 'video/mp4' : 'image/jpeg';
      final SettableMetadata metadata = SettableMetadata(contentType: mimeType);
      final Reference ref = _storage.ref().child('media/$postId');

      UploadTask uploadTask;
      final bytes = file is Uint8List ? file : await (file as dynamic).readAsBytes();
      uploadTask = ref.putData(bytes, metadata);
      
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            double progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress?.call('Uploading media... ${(progress * 100).toInt()}%', progress * 0.8);
          }
        },
        onError: (e) => debugPrint('Upload task error: $e'),
      );

      final TaskSnapshot mediaSnapshot = await uploadTask;
      final String mediaUrl = await mediaSnapshot.ref.getDownloadURL();

      String thumbnailUrl = isVideo ? '' : mediaUrl;
      if (thumbnailFile != null) {
        onProgress?.call('Uploading thumbnail...', 0.85);
        final Reference thumbRef = _storage.ref().child('thumbnails/$postId');
        final SettableMetadata thumbMeta = SettableMetadata(contentType: 'image/jpeg');

        final thumbBytes = thumbnailFile is Uint8List ? thumbnailFile : await (thumbnailFile as dynamic).readAsBytes();
        final UploadTask thumbTask = thumbRef.putData(thumbBytes, thumbMeta);

        final TaskSnapshot thumbSnapshot = await thumbTask;
        thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();
      }

      onProgress?.call('Saving post...', 0.95);

      final post = Post(
        id: postId,
        userId: userId,
        username: finalUsername,
        profileImage: finalProfileImage,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        isVideo: isVideo,
        mediaType: isVideo ? 'video' : 'image',
        caption: caption,
        prompt: prompt,
        toolsUsed: toolsUsed,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('posts').doc(postId).set(post.toMap());
      onProgress?.call('Done!', 1.0);
    } catch (e) {
      debugPrint('Upload error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // LIKES
  // ─────────────────────────────────────────────

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final batch = _firestore.batch();
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = _firestore.collection('users').doc(user.uid).collection('likes').doc(postId);
    if (currentlyLiked) {
      batch.update(postRef, {'likesCount': FieldValue.increment(-1)});
      batch.delete(likeRef);
    } else {
      batch.update(postRef, {'likesCount': FieldValue.increment(1)});
      batch.set(likeRef, {'timestamp': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // TRIALS
  // ─────────────────────────────────────────────

  Future<void> recordTrial(String postId, {
    required String username,
    required String name,
    required String avatar,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final postRef = _firestore.collection('posts').doc(postId);
    final userTrialRef = _firestore.collection('users').doc(user.uid).collection('trials').doc(postId);
    
    // Use a transaction to ensure atomicity and avoid duplicates
    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final data = postDoc.data()!;
      final List trialsList = data['trialsList'] ?? [];
      
      // Check if user already in the trialsList
      final bool alreadyInList = trialsList.any((t) {
        if (t is Map) {
          return t['username'] == username;
        }
        return false;
      });

      if (!alreadyInList) {
        final trialRecord = {
          'username': username,
          'name': name,
          'avatar': avatar,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        transaction.update(postRef, {
          'trialsCount': FieldValue.increment(1),
          'trialsList': FieldValue.arrayUnion([trialRecord]),
        });
        transaction.set(userTrialRef, {'timestamp': FieldValue.serverTimestamp()});
      }
    });
  }

  // ─────────────────────────────────────────────
  // COMMENTS
  // ─────────────────────────────────────────────

  Future<void> addComment(String postId, {required String username, required String profileImage, required String text}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final commentMap = {
      'username': username.startsWith('@') ? username : '@$username',
      'profileImage': profileImage,
      'text': text,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    await _firestore.collection('posts').doc(postId).update({
      'commentsList': FieldValue.arrayUnion([commentMap]),
    });
  }

  // ─────────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────────

  /// Generate search keywords from a username for substring matching.
  /// e.g. "@IRAVARAJU Manojkumar" -> ["iravaraju", "manojkumar", "iravaraju manojkumar", ...]
  List<String> _generateSearchKeywords(String username, {String? email}) {
    final Set<String> keywords = {};
    
    // Clean the username (remove @)
    final cleanName = username.startsWith('@') ? username.substring(1) : username;
    final lowerName = cleanName.toLowerCase().trim();
    
    // Add full name
    if (lowerName.isNotEmpty) keywords.add(lowerName);
    
    // Add each word
    final words = lowerName.split(RegExp(r'[\s_\-\.]+'));
    for (var word in words) {
      if (word.isNotEmpty) keywords.add(word);
    }
    
    // Add prefixes of each word (for type-ahead)
    for (var word in words) {
      for (int i = 1; i <= word.length && i <= 10; i++) {
        keywords.add(word.substring(0, i));
      }
    }
    
    // Add prefixes of the full name
    for (int i = 1; i <= lowerName.length && i <= 15; i++) {
      keywords.add(lowerName.substring(0, i));
    }
    
    return keywords.toList();
  }

  Future<String?> uploadProfileImage(dynamic file) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final String userId = user.uid;
      final Reference ref = _storage.ref().child('profiles/$userId/pfp.jpg');
      
      final SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');
      
      UploadTask uploadTask;
      if (file is Uint8List) {
        uploadTask = ref.putData(file, metadata);
      } else {
        final bytes = await (file as dynamic).readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      }
      
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Profile upload error: $e');
      return null;
    }
  }

  Future<void> updateProfile(String username, String bio, String? profileImage, {String? email, bool isNewUser = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final resolvedEmail = email ?? user.email ?? '';
    final searchKeywords = _generateSearchKeywords(username, email: resolvedEmail);
    
    // If profileImage is a local path or blob URL, we should NOT save it directly.
    // However, this method is called both for initial sync (where it's a real URL)
    // and for updates. We'll handle the upload in AppState for now or here.
    
    final data = {
      'username': username,
      'bio': bio,
      'profileImage': profileImage,
      'email': resolvedEmail,
      'searchKeywords': searchKeywords,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isNewUser) {
      data.putIfAbsent('followersCount', () => 0);
      data.putIfAbsent('followingCount', () => 0);
    }

    await _firestore.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
    await user.updateDisplayName(username);
    if (profileImage != null && profileImage.startsWith('http')) {
      await user.updatePhotoURL(profileImage);
    }
  }

  Stream<Map<String, dynamic>?> getUserData(String username) {
    return _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isNotEmpty ? s.docs.first.data() : null);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    final lowercaseQuery = query.toLowerCase().trim();
    
    // Use searchKeywords array-contains for substring matching
    final snapshot = await _firestore
        .collection('users')
        .where('searchKeywords', arrayContains: lowercaseQuery)
        .limit(60) // Increased limit to fetch enough candidates for deduplication
        .get();
        
    final Map<String, Map<String, dynamic>> uniqueUsers = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final username = data['username']?.toString().toLowerCase().trim() ?? '';
      if (username.isNotEmpty && !uniqueUsers.containsKey(username)) {
        uniqueUsers[username] = data;
      }
    }
    
    return uniqueUsers.values.toList();
  }


  /// Optimized: Fetch posts for a specific user directly from Firestore
  Stream<List<Post>> getUserPostsStream(String username) {
    return _firestore
        .collection('posts')
        .where('username', isEqualTo: username)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => Post.fromMap(d.data())).toList());
  }

  Future<void> updatePost({
    required String postId,
    required String caption,
    required String prompt,
    required String toolsUsed,
  }) async {
    await _firestore.collection('posts').doc(postId).update({
      'caption': caption,
      'prompt': prompt,
      'toolsUsed': toolsUsed,
    });
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
    try {
      await _storage.ref().child('media/$postId').delete();
    } catch (e) {
      debugPrint('Storage delete error: $e');
    }
  }
}

final firebaseService = FirebaseService();
