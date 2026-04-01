import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String username;
  final String profileImage;
  final String text;
  final DateTime timestamp;

  Comment({
    required this.username,
    required this.profileImage,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'profileImage': profileImage,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      username: map['username'] ?? 'Anonymous',
      profileImage: map['profileImage'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) 
          : DateTime.now(),
    );
  }
}

class TrialRecord {
  final String username;
  final String name;
  final String avatar;
  final DateTime timestamp;

  TrialRecord({
    required this.username,
    required this.name,
    required this.avatar,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'name': name,
      'avatar': avatar,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory TrialRecord.fromMap(Map<String, dynamic> map) {
    return TrialRecord(
      username: map['username'] ?? 'Anonymous',
      name: map['name'] ?? '',
      avatar: map['avatar'] ?? '',
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) 
          : DateTime.now(),
    );
  }
}

class Post {
  final String id;
  final String userId;
  final String username;
  final String profileImage;
  final String mediaUrl;
  final String thumbnailUrl;
  final bool isVideo;
  final String mediaType; // 'video' or 'image'
  final String caption;
  final String prompt;
  final String toolsUsed;
  int likesCount;
  int trialsCount;
  int viewsCount;
  int sharesCount;
  final List<Comment> commentsList;
  final List<TrialRecord> trialsList;
  final DateTime createdAt;
  bool isLiked;
  bool isSaved;

  Post({
    required this.id,
    this.userId = '',
    required this.username,
    this.profileImage = '',
    required this.mediaUrl,
    this.thumbnailUrl = '',
    required this.isVideo,
    this.mediaType = 'image',
    required this.caption,
    required this.prompt,
    required this.toolsUsed,
    this.likesCount = 0,
    this.trialsCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    List<Comment>? commentsList,
    List<TrialRecord>? trialsList,
    DateTime? createdAt,
    this.isLiked = false,
    this.isSaved = false,
  }) : this.createdAt = createdAt ?? DateTime.now(),
       this.commentsList = commentsList ?? [],
       this.trialsList = trialsList ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'profileImage': profileImage,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'isVideo': isVideo,
      'mediaType': mediaType,
      'caption': caption,
      'prompt': prompt,
      'toolsUsed': toolsUsed,
      'likesCount': likesCount,
      'trialsCount': trialsCount,
      'viewsCount': viewsCount,
      'sharesCount': sharesCount,
      'commentsList': commentsList.map((c) => c.toMap()).toList(),
      'trialsList': trialsList.map((t) => t.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Anonymous',
      profileImage: map['profileImage'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      isVideo: map['isVideo'] ?? (map['mediaType'] == 'video') || (map['mediaUrl']?.toString().toLowerCase().endsWith('.mp4') ?? false),
      mediaType: map['mediaType'] ?? ((map['isVideo'] == true || (map['mediaUrl']?.toString().toLowerCase().endsWith('.mp4') ?? false)) ? 'video' : 'image'),
      caption: map['caption'] ?? '',
      prompt: map['prompt'] ?? '',
      toolsUsed: map['toolsUsed'] ?? map['toolUsed'] ?? '',
      likesCount: map['likesCount'] ?? map['likes'] ?? 0,
      trialsCount: map['trialsCount'] ?? map['remixes'] ?? 0,
      viewsCount: map['viewsCount'] ?? map['views'] ?? 0,
      sharesCount: map['sharesCount'] ?? map['shares'] ?? 0,
      commentsList: (map['commentsList'] as List?)
              ?.where((c) => c is Map)
              .map((c) => Comment.fromMap(Map<String, dynamic>.from(c)))
              .toList() ??
          [],
      trialsList: (map['trialsList'] as List?)
              ?.where((t) => t is Map)
              .map((t) => TrialRecord.fromMap(Map<String, dynamic>.from(t)))
              .toList() ??
          [],
      createdAt: map['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt']) 
          : (map['timestamp'] != null ? DateTime.fromMillisecondsSinceEpoch(map['timestamp']) : DateTime.now()),
      isLiked: false,
      isSaved: false,
    );
  }
}
