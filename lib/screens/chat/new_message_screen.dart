import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// SCREENS
import 'package:aorandra/screens/chat/chat_screen.dart';

class NewMessageScreen extends StatefulWidget {
  final String currentUserId;

  const NewMessageScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final supabase = Supabase.instance.client;

  double searchHeight = 50;

  final TextEditingController searchController = TextEditingController();

  String query = "";

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      setState(() {
        query = searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ===============================
  // GENERATE CHAT ID
  // ===============================
  String generateChatId(String a, String b) {
    return a.hashCode <= b.hashCode ? "$a$b" : "$b$a";
  }

  // ===============================
  // CREATE / OPEN CHAT
  // ===============================
  Future<void> openChat(String otherUserId) async {
    final chatId = generateChatId(widget.currentUserId, otherUserId);

    final chat = await supabase
        .from('chats')
        .select()
        .eq('id', chatId)
        .maybeSingle();

    if (chat == null) {
      await supabase.from('chats').insert({
        "id": chatId,
        "participants": [widget.currentUserId, otherUserId],
        "created_at": DateTime.now().toIso8601String(),
      });
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUserId: widget.currentUserId,
          otherUserId: otherUserId,
          chatId: chatId,
        ),
      ),
    );
  }

  // ===============================
  // MAIN UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(theme),
          _buildSearch(theme, isDark),
          _buildUsers(theme, isDark),
        ],
      ),
    );
  }

  // ===============================
  // HEADER
  // ===============================
  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 10,
        right: 10,
        bottom: 10,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back,
              color: theme.iconTheme.color,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "New Message",
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // SEARCH BAR
  // ===============================
  Widget _buildSearch(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: searchHeight,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.black12,
              ),
            ),
            child: TextField(
              controller: searchController,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: "Search users...",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                border: InputBorder.none,
                icon: Icon(
                  Icons.search,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===============================
  // USERS LIST
  // ===============================
  Widget _buildUsers(ThemeData theme, bool isDark) {
    return Expanded(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: supabase.from('users').select(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                color: theme.textTheme.bodyLarge?.color,
              ),
            );
          }

          final users = snapshot.data!;

          final filteredUsers = users.where((user) {
            final username = user['username']
                .toString()
                .toLowerCase();

            return username.contains(query) &&
                user['id'] != widget.currentUserId;
          }).toList();

          if (filteredUsers.isEmpty) {
            return _emptyState(theme, isDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              return _userItem(filteredUsers[index], theme, isDark);
            },
          );
        },
      ),
    );
  }

  // ===============================
  // USER ITEM
  // ===============================
  Widget _userItem(Map<String, dynamic> user, ThemeData theme, bool isDark) {
    final username = user['username'];
    final userId = user['id'];

    return GestureDetector(
      onTap: () => openChat(userId),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor:
                  isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(width: 12),
            Text(
              username,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================
  // EMPTY STATE
  // ===============================
  Widget _emptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 60,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 15),
          Text(
            "No users found",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}