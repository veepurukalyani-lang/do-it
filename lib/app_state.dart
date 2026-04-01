import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'models/post.dart';
import 'services/firebase_service.dart';
import 'dart:async';
import 'dart:math' as dart_math;

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  
  StreamSubscription? _postsSubscription;
  StreamSubscription? _followingSubscription;
  StreamSubscription? _likesSubscription;
  StreamSubscription? _trialsSubscription;
  StreamSubscription<User?>? _authSubscription;
  User? _user;

  AppState._internal();
  
  void initialize() {
    _user = FirebaseAuth.instance.currentUser;
    _initAuthListener();
    _initFirebaseSync();
  }

  void _initAuthListener() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _user = user;
      if (user != null) {
        // Real user logged in via Google
        _currentUser = user.displayName ?? user.email?.split('@').first ?? 'User';
        if (!_currentUser.startsWith('@')) _currentUser = '@$_currentUser';
        _currentUserProfileImage = user.photoURL;
        
        // Ensure user document exists (only merge non-destructive profile data)
        firebaseService.updateProfile(
          _currentUser, 
          '', 
          user.photoURL,
          email: user.email,
          isNewUser: false // Changed to false to prevent count resets on every login
        );
        
        // Sync real interactive data from the cloud
        _initUserInteractionsSync();
      } else {
        // Guest user - Zero data slate
        _currentUser = '@Guest';
        _currentUserProfileImage = null; // No avatar for guests
        _currentBio = '';
        
        // Clear all local interaction caches for guest
        _following.clear();
        _likedPostIds.clear();
        _triedPostIds.clear();
      }
      _initFirebaseSync();
      notifyListeners();
    });
  }

  void _initUserInteractionsSync() {
    _followingSubscription?.cancel();
    _followingSubscription = firebaseService.getFollowingStream().listen((list) {
      _following.clear();
      _following.addAll(list);
      // Re-init feed to update recommendations based on new follows
      _initFirebaseSync();
      notifyListeners();
    });

    _likesSubscription?.cancel();
    _likesSubscription = firebaseService.getLikedPostsStream().listen((list) {
      _likedPostIds.clear();
      _likedPostIds.addAll(list);
      notifyListeners();
    });

    _trialsSubscription?.cancel();
    _trialsSubscription = firebaseService.getTriedPostsStream().listen((list) {
      _triedPostIds.clear();
      _triedPostIds.addAll(list);
      notifyListeners();
    });
  }

  void _initFirebaseSync() {
    _postsSubscription?.cancel();
    try {
      _postsSubscription = firebaseService.getHomeFeedStream(
        followingUsers: _following.toList()
      ).listen(
        (updatedPosts) {
          debugPrint('--- Received ${updatedPosts.length} posts from Firestore ---');
          if (updatedPosts.isEmpty) {
             debugPrint('--- WARNING: Firestore returned 0 posts! Checking DB connectivity... ---');
          }
          // 1. Generate stable random sort keys for any new posts
          bool listChanged = false;
          final _random = dart_math.Random();
          for (var p in updatedPosts) {
            if (!_randomSortOrder.containsKey(p.id)) {
              _randomSortOrder[p.id] = _random.nextDouble();
              listChanged = true;
            }
          }
          
          // 2. Sort the incoming posts based on the stable keys
          updatedPosts.sort((a, b) {
            return _randomSortOrder[a.id]!.compareTo(_randomSortOrder[b.id]!);
          });
          
          // 3. Update the internal list without clearing if possible to maintain scroll state
          if (listChanged || _posts.length != updatedPosts.length) {
            _posts.clear();
            _posts.addAll(updatedPosts);
          } else {
            // Just update existing post data (views, counts, etc.)
            for (int i = 0; i < _posts.length; i++) {
              _posts[i] = updatedPosts[i];
            }
          }
          
          notifyListeners();
        },
        onError: (error) {
          debugPrint('Firestore Stream Error: $error');
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Firestore Subscription failed: $e');
      notifyListeners();
    }
  }

  Future<void> refreshFeed() async {
    _randomSortOrder.clear(); // Force completely new random order
    _initFirebaseSync();
    // Simple delay to show the refresh indicator
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _followingSubscription?.cancel();
    _likesSubscription?.cancel();
    _trialsSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  final List<Post> _posts = [];
  final Map<String, double> _randomSortOrder = {};

  List<Post> get posts {
    // Inject the 'isLiked' state based on the synced likes list
    return _posts.map((p) {
      p.isLiked = _likedPostIds.contains(p.id);
      return p;
    }).toList();
  }

  final Set<String> _following = {};
  Set<String> get following => Set.unmodifiable(_following);

  final Set<String> _likedPostIds = {};
  final Set<String> _triedPostIds = {};
  int _followersCount = 0;
  int _followingCount = 0;

  int get followersCount => _followersCount;
  int get followingCount => _followingCount;

  String _currentUser = '@Guest';
  String _currentBio = '';
  String? _currentUserProfileImage;
  
  String get currentUser => _currentUser;
  String get currentBio => _currentBio;
  String? get currentUserProfileImage => _currentUserProfileImage;

  Future<void> updateProfile(String name, String bio, {dynamic profileImageFile}) async {
    _currentUser = name.startsWith('@') ? name : '@$name';
    _currentBio = bio;
    
    String? finalProfileImage = _currentUserProfileImage;
    
    if (profileImageFile != null) {
      if (profileImageFile is String && profileImageFile.startsWith('http')) {
        finalProfileImage = profileImageFile;
      } else {
        // Handle Blob URL or Path - need to upload it
        final uploadedUrl = await firebaseService.uploadProfileImage(profileImageFile);
        if (uploadedUrl != null) {
          finalProfileImage = uploadedUrl;
        }
      }
    }
    
    _currentUserProfileImage = finalProfileImage;
    
    if (isLoggedIn) {
      await firebaseService.updateProfile(_currentUser, _currentBio, _currentUserProfileImage, email: _user?.email);
    }
    notifyListeners();
  }

  Future<void> loginWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      if (kIsWeb) {
        await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        await FirebaseAuth.instance.signInWithProvider(googleProvider);
      }
    } catch (e) {
      debugPrint('Login failed: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    _posts.clear();
    _following.clear();
    _likedPostIds.clear();
    notifyListeners();
  }

  bool isFollowing(String username) => _following.contains(username);

  void followUser(String username) {
    if (isLoggedIn) {
      firebaseService.toggleFollow(username, false);
    } else {
      _following.add(username); // Local only for guests
      notifyListeners();
    }
  }

  void unfollowUser(String username) {
    if (isLoggedIn) {
      firebaseService.toggleFollow(username, true);
    } else {
      _following.remove(username);
      notifyListeners();
    }
  }

  int getUserTotalTries(String username) {
    final String target = username.toLowerCase().replaceAll('@', '').trim();
    return _posts.where((p) {
      final String pUser = p.username.toLowerCase().replaceAll('@', '').trim();
      return pUser == target && !p.isVideo && p.prompt.trim().isNotEmpty;
    }).fold(0, (sum, post) => sum + post.trialsCount);
  }

  void addPost(Post post) {
    // Handled by Firestore stream
  }

  void toggleLike(String postId) {
    final currentlyLiked = _likedPostIds.contains(postId);
    if (isLoggedIn) {
      firebaseService.toggleLike(postId, currentlyLiked);
    } else {
      // Local mock feedback for guests
      if (currentlyLiked) _likedPostIds.remove(postId);
      else _likedPostIds.add(postId);
      notifyListeners();
    }
  }

  Future<void> submitComment(String postId, String comment) async {
    if (isLoggedIn) {
      await firebaseService.addComment(
        postId, 
        username: _currentUser, 
        profileImage: _currentUserProfileImage ?? '', 
        text: comment
      );
    }
  }

  bool hasTried(String postId) => _triedPostIds.contains(postId);

  Future<List<Map<String, dynamic>>> searchAccounts(String query) async {
    return await firebaseService.searchUsers(query);
  }

  final Set<String> _recordingTrialIds = {};
  
  Future<void> recordTrial(String postId) async {
    final alreadyTried = _triedPostIds.contains(postId) || _recordingTrialIds.contains(postId);
    if (!isLoggedIn || alreadyTried) return;
    
    _recordingTrialIds.add(postId);
    
    try {
      // Optimistic update
      final postIndex = _posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        final newRecord = TrialRecord(
          username: _currentUser,
          name: _currentUser, 
          avatar: _currentUserProfileImage ?? '',
          timestamp: DateTime.now(),
        );
        
        _posts[postIndex].trialsCount++;
        if (!_posts[postIndex].trialsList.any((t) => t.username == _currentUser)) {
          _posts[postIndex].trialsList.insert(0, newRecord);
          if (_posts[postIndex].trialsList.length > 50) {
            _posts[postIndex].trialsList.removeLast();
          }
        }
        
        _triedPostIds.add(postId);
        notifyListeners();
      }
      
      await firebaseService.recordTrial(
        postId,
        username: _currentUser,
        name: _currentUser,
        avatar: _currentUserProfileImage ?? '',
      );
    } catch (e) {
      debugPrint('Trial recording error: $e');
    } finally {
      _recordingTrialIds.remove(postId);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await firebaseService.deletePost(postId);
    } catch (e) {
      debugPrint('Error deleting post: $e');
    }
  }

  bool _isNavBarVisible = true;
  bool get isNavBarVisible => _isNavBarVisible;

  void setNavBarVisible(bool visible) {
    if (_isNavBarVisible != visible) {
      _isNavBarVisible = visible;
      notifyListeners();
    }
  }
}

final appState = AppState();
