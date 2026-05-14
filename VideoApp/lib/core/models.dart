class VideoPost {
  final String id;
  final String userId;
  final String videoUrl;
  final String? thumbnailUrl;
  final String caption;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final UserProfile? author;
  bool isLiked;

  VideoPost({
    required this.id,
    required this.userId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.caption,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    this.author,
    this.isLiked = false,
  });

  factory VideoPost.fromJson(Map<String, dynamic> json) => VideoPost(
        id: json['id'],
        userId: json['user_id'],
        videoUrl: json['video_url'],
        thumbnailUrl: json['thumbnail_url'],
        caption: json['caption'] ?? '',
        likesCount: json['likes_count'] ?? 0,
        commentsCount: json['comments_count'] ?? 0,
        createdAt: DateTime.parse(json['created_at']),
        author: json['profiles'] != null
            ? UserProfile.fromJson(json['profiles'])
            : null,
      );
}

class UserProfile {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;

  UserProfile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        username: json['username'] ?? 'user',
        avatarUrl: json['avatar_url'],
        bio: json['bio'],
        followersCount: json['followers_count'] ?? 0,
        followingCount: json['following_count'] ?? 0,
      );
}

class Comment {
  final String id;
  final String userId;
  final String videoId;
  final String content;
  final DateTime createdAt;
  final UserProfile? author;

  Comment({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'],
        userId: json['user_id'],
        videoId: json['video_id'],
        content: json['content'],
        createdAt: DateTime.parse(json['created_at']),
        author: json['profiles'] != null
            ? UserProfile.fromJson(json['profiles'])
            : null,
      );
}
