import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// =============================================
/// HOME CONTROLLER
/// Manages UI configurations and Data logic
/// =============================================
class HomeController {
  
  // ======================================================
  // ===================== DATA LOGIC =====================
  // ======================================================

  static final _supabase = Supabase.instance.client;

  /// Fetch posts with linked profile data (username & avatar)
 static Future<List<dynamic>> fetchPosts() async {
  try {
    final response = await _supabase
        .from('posts')
        .select('''
          id,
          user_id,
          media_urls,
          caption,
          type,
          likes,
          comments,
          shares,
          created_at,
          profiles (
            username,
            avatar_url
          )
        ''')
        .order('created_at', ascending: false)
        .range(0, 10);

    return response as List<dynamic>;
  } catch (e) {
    debugPrint('Error fetching posts: $e');
    return [];
  }
}

  /// Fetch comments with linked profile data
  static Future<List<dynamic>> fetchComments(String postId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('''
            *,
            profiles (
              username,
              avatar_url
            )
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return response as List<dynamic>;
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return [];
    }
  }

  // ======================================================
  // ====================== UI CONFIG =====================
  // ======================================================

  static double headerTop = 12;
  static double headerHorizontal = 20;
  static double titleFontSize = 26;
  static double headerIconSize = 26;
  static double headerIconsSpacing = 14;

  static double storyPanelWidth = 90;
  static double storyPanelTop = 110;
  static double storyPanelBottom = 110;
  static double storyPanelRadius = 50;
  static double storyAvatarRadius = 26;
  static double storyTextSize = 10;

  static double searchRadius = 28;
  static double searchBarHeight = 56;
  static double searchBarHorizontalMargin = 8;
  static double searchBarRadius = 40;
  static double searchBarPaddingVertical = 14;
  static double searchTopSpacing = 18;
  static double searchTabsSpacing = 12;

  static double searchHandleWidth = 100;
  static double searchHandleHeight = 4;
  static double searchHandleRadius = 20;
  static double searchHandleOpacity = 0.4;

  static double searchExpandedHeight = 0.85;
  static double searchExpandedRadius = 30;

  static double suggestionAvatarRadius = 30;
  static double suggestionCardWidth = 92;
  static double suggestionTextSize = 11;

  static double emptyIconCircleSize = 78;
  static double emptyIconSize = 34;
  static double emptyTitleSize = 20;
  static double emptySubtitleSize = 13;

  static double postRadius = 18;
  static double postSpacing = 8;
  static double postCount = 12;

  static double navExpandedWidth = 330;
  static double navCollapsedWidth = 170;
  static double navExpandedHeight = 74;
  static double navCollapsedHeight = 22;
  static double navBottom = 20;
  static double navOffsetX = 0;
  static double navOffsetY = 0;
  static double navRadius = 40;
  static double navIconSize = 24;

  static double handleWidth = 110;
  static double handleHeight = 5;
  static double handleBottom = 300;
  static double handleOffsetX = 0;
  static double handleOffsetY = 0;
  static double handleOpacity = 0.5;
  static double handleRadius = 20;
}