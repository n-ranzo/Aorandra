import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models.dart';

class FeedService {
  final _db = Supabase.instance.client;

  Future<List<VideoPost>> fetchVideos({int limit = 10, int offset = 0}) async {
    final userId = _db.auth.currentUser?.id;

    final data = await _db
        .from('videos')
        .select('*, profiles(id, username, avatar_url)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    final posts = (data as List).map((e) => VideoPost.fromJson(e)).toList();

    if (userId != null && posts.isNotEmpty) {
      final videoIds = posts.map((p) => p.id).toList();
      final likes = await _db
          .from('likes')
          .select('video_id')
          .eq('user_id', userId)
          .inFilter('video_id', videoIds);

      final likedIds = (likes as List).map((l) => l['video_id'] as String).toSet();
      for (final post in posts) {
        post.isLiked = likedIds.contains(post.id);
      }
    }

    return posts;
  }

  Future<void> toggleLike(String videoId, {required bool wasLiked}) async {
    final userId = _db.auth.currentUser!.id;
    if (wasLiked) {
      await _db.from('likes').delete().match({'user_id': userId, 'video_id': videoId});
      await _db.rpc('decrement_likes', params: {'video_id': videoId});
    } else {
      await _db.from('likes').insert({'user_id': userId, 'video_id': videoId});
      await _db.rpc('increment_likes', params: {'video_id': videoId});
    }
  }
}
