import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoryService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // ===============================
  // UPLOAD STORY
  // ===============================
  static Future<void> uploadStory(File file) async {
    final user = _supabase.auth.currentUser;

    if (user == null) throw Exception("User not logged in");

    final fileName =
        DateTime.now().millisecondsSinceEpoch.toString();

    // upload to storage
    await _supabase.storage
        .from('media') // storage bucket name
        .upload('stories/$fileName.jpg', file);

    // get public url
    final publicUrl = _supabase.storage
        .from('media')
        .getPublicUrl('stories/$fileName.jpg');

    // insert into database
    await _supabase.from('stories').insert({
      'userId': user.id,
      'mediaUrl': publicUrl,
      'createdAt': DateTime.now().toIso8601String(),
      'username': user.email ?? 'User',
      'userImage': user.userMetadata?['avatar_url'] ?? '',
      'viewers': [],
    });
  }
}