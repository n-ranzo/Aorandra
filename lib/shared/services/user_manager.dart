import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserManager extends ChangeNotifier {
  // ================= SINGLETON =================
  static final UserManager instance = UserManager._();
  UserManager._();

  final supabase = Supabase.instance.client;

  // ================= CACHE =================
  /// Stores users locally (id -> user data)
  final Map<String, Map<String, dynamic>> _users = {};

  // ================= SET SINGLE USER =================
  /// Add or replace a single user in cache
  void setUser(String userId, Map<String, dynamic> data) {
    _users[userId] = data;
    notifyListeners(); // 🔥 update UI
  }

  // ================= SET MULTIPLE USERS =================
  /// Add multiple users at once (used on app start / fetch)
  void setUsers(List users) {
    for (var u in users) {
      final id = u['id']?.toString();
      if (id != null) {
        _users[id] = u;
      }
    }
    notifyListeners(); // 🔥 update UI
  }

  // ================= UPDATE USER =================
  /// Merge new data into existing user (Realtime updates)
  void updateUser(String userId, Map<String, dynamic> newData) {
    if (_users.containsKey(userId)) {
      _users[userId] = {
        ..._users[userId]!,
        ...newData,
      };
    } else {
      _users[userId] = newData;
    }

    notifyListeners(); // 🔥 realtime UI update
  }

  // ================= REMOVE USER =================
  /// Remove user from cache
  void removeUser(String userId) {
    _users.remove(userId);
    notifyListeners();
  }

  // ================= GET USER =================
  /// Get full user object
  Map<String, dynamic>? getUser(String userId) {
    return _users[userId];
  }

  // ================= GET ALL USERS =================
  /// Get all cached users
  List<Map<String, dynamic>> getAllUsers() {
    return _users.values.toList();
  }

  // ================= GET USERNAME =================
  /// Safe username getter
  String getUsername(String userId) {
    final user = _users[userId];
    return (user?['username'] ?? 'User').toString();
  }

  // ================= GET AVATAR =================
  /// 🔥 FIXED: Uses avatar_url instead of old 'image'
  String getAvatar(String userId) {
    final user = _users[userId];

    final avatar = (user?['avatar_url'] ?? '')
        .toString()
        .trim();

    // Validate URL
    if (avatar.isEmpty ||
        avatar == 'null' ||
        !avatar.toLowerCase().startsWith('http')) {
      return '';
    }

    return avatar;
  }

  // ================= REALTIME LISTENER =================
  /// Listen to profile updates from Supabase (Realtime)
  void listenToProfileChanges() {
    supabase
        .channel('profiles_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final newData = payload.newRecord;

            final userId = newData['id']?.toString();
            if (userId == null) return;

            // 🔥 update cache instantly
            updateUser(userId, newData);
          },
        )
        .subscribe();
  }

  // ================= CLEAR CACHE =================
  /// Clear all cached users (logout / refresh)
  void clear() {
    _users.clear();
    notifyListeners();
  }
}