import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class UploadService {

  // ============================
  // Upload file to storage
  // ============================
  static Future<String> uploadFile(File file, String userId) async {
    final supabase = Supabase.instance.client;

    try {
      // Unique file name
      final fileName =
          "${DateTime.now().millisecondsSinceEpoch}_$userId";

      // Get file extension
      final extension = file.path.split('.').last.toLowerCase();

      // Storage path
      final path = 'media/$userId/$fileName.$extension';

      // Detect content type
      String contentType;
      if (extension == 'mp4') {
        contentType = 'video/mp4';
      } else if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else {
        contentType = 'application/octet-stream';
      }

      // Upload file
      await supabase.storage.from('media').upload(
        path,
        file,
        fileOptions: FileOptions(
          contentType: contentType,
          upsert: true,
        ),
      );

      // Get public URL
      final url = supabase.storage.from('media').getPublicUrl(path);

      print("UPLOAD SUCCESS: $url");

      return url;

    } catch (e) {
      print("UPLOAD ERROR: $e");
      rethrow;
    }
  }

  // ============================
  // Upload story + save to database
  // ============================
  static Future<void> uploadStory(File file) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      print("User not logged in");
      return;
    }

    try {
      // 1. Upload file
      final mediaUrl = await uploadFile(file, user.id);

      // 2. Insert into stories table
      await supabase.from('stories').insert({
        'userid': user.id,
        'mediaUrl': mediaUrl,
        'username': user.userMetadata?['username'] ?? 'User',
        'userimage': user.userMetadata?['avatar_url'] ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'viewers': [],
      });

      print("STORY SAVED SUCCESS");

    } catch (e) {
      print("STORY SAVE ERROR: $e");
    }
  }
}