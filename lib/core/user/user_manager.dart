import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserManager {
  // ================= SINGLETON =================
  // Global instance (accessible anywhere in the app)
  static final UserManager instance = UserManager._();
  UserManager._();

  // ================= INTERNAL CACHE =================
  // Stores all users by userId
  final Map<String, Map<String, dynamic>> _users = {};

  // ================= SET SINGLE USER =================
  // Add or update one user
  void setUser(String userId, Map<String, dynamic> data) {
    _users[userId] = data;
  }

  // ================= SET MULTIPLE USERS =================
  // Store a list of users (used after fetching posts)
  void setUsers(List users) {
    _users.clear();

    for (var u in users) {
      final id = u['id']?.toString();
      if (id != null) {
        _users[id] = u;
      }
    }
  }

  // ================= GET USER =================
  // Returns full user object (or null if not found)
  Map<String, dynamic>? getUser(String userId) {
    return _users[userId];
  }

  // ================= GET ALL USERS =================
  // Returns all cached users (used in share sheet)
  List<Map<String, dynamic>> getAllUsers() {
    return _users.values.toList();
  }

  // ================= GET USERNAME =================
  // Safe username getter
  String getUsername(String userId) {
    final user = _users[userId];
    return user?['username'] ?? 'User';
  }

  // ================= GET AVATAR =================
  // Returns valid avatar URL or empty string
  String getAvatar(String userId) {
    final user = _users[userId];

    final avatar = (user?['image'] ?? '')
        .toString()
        .trim();

    // Filter invalid values
    if (avatar.isEmpty ||
        avatar == 'null' ||
        !avatar.toLowerCase().startsWith('http')) {
      return '';
    }

    return avatar;
  }
}






// ================= USER AVATAR WIDGET =================
class UserAvatar extends StatelessWidget {
  final String userId;
  final double size;

  const UserAvatar({
    super.key,
    required this.userId,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get avatar from UserManager
    final avatar = UserManager.instance.getAvatar(userId);

    return ClipOval(
      child: avatar.isNotEmpty
          // ================= NETWORK IMAGE =================
          ? CachedNetworkImage(
              imageUrl: avatar,
              width: size,
              height: size,
              fit: BoxFit.cover,

              // Loading placeholder
              placeholder: (_, __) => Container(
                width: size,
                height: size,
                color: theme.dividerColor.withOpacity(0.2),
              ),

              // Error fallback
              errorWidget: (_, __, ___) => Container(
                width: size,
                height: size,
                color: theme.dividerColor.withOpacity(0.2),
                child: Icon(
                  Icons.person,
                  color: theme.iconTheme.color,
                ),
              ),
            )

          // ================= DEFAULT AVATAR =================
          : Container(
              width: size,
              height: size,
              color: theme.dividerColor.withOpacity(0.2),
              child: Icon(
                Icons.person,
                color: theme.iconTheme.color,
              ),
            ),
    );
  }
}