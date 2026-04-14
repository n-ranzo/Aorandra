import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// =============================================
/// USER AVATAR (LIVE STREAM VERSION - FIXED)
/// Real-time avatar + Supabase public URL support
/// =============================================
class UserAvatar extends StatelessWidget {
  final String userId;
  final double radius;

  const UserAvatar({
    super.key,
    required this.userId,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double size = radius * 2;

    final supabase = Supabase.instance.client;

    // Safety check
    if (userId.isEmpty) return _buildDefaultAvatar(theme, size);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', userId),
      builder: (context, snapshot) {
        
        // ================= NO DATA =================
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildDefaultAvatar(theme, size);
        }

        final profile = snapshot.data!.first;
        final String? avatarPath = profile['avatar_url'];

        // ================= EMPTY AVATAR =================
        if (avatarPath == null || avatarPath.trim().isEmpty) {
          return _buildDefaultAvatar(theme, size);
        }

        // ================= 🔥 FIX: CONVERT TO PUBLIC URL =================
        final imageUrl = supabase.storage
            .from('avatars') // ⚠️ تأكد اسم bucket
            .getPublicUrl(avatarPath);

        // ================= IMAGE =================
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,

            // 🔥 Prevent old cached image
            useOldImageOnUrlChange: false,

            placeholder: (context, url) => Container(
              width: size,
              height: size,
              color: theme.dividerColor.withOpacity(0.1),
            ),

            errorWidget: (context, url, error) =>
                _buildDefaultAvatar(theme, size),
          ),
        );
      },
    );
  }

  /// ================= DEFAULT AVATAR =================
  Widget _buildDefaultAvatar(ThemeData theme, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: theme.iconTheme.color?.withOpacity(0.5),
      ),
    );
  }
}