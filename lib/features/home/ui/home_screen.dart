// ================================
// DART CORE
// ================================
import 'dart:async';
import 'dart:ui';

// ================================
// FLUTTER
// ================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ================================
// BACKEND (SUPABASE)
// ================================
import 'package:supabase_flutter/supabase_flutter.dart';

// ================================
// MEDIA (VIDEO / IMAGES)
// ================================
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ================================
// SHARE
// ================================
import 'package:share_plus/share_plus.dart';

// ================================
// CORE (GLOBAL UI / CONFIG)
// ================================
import 'package:aorandra/core/utils/glass_container.dart';

// ================================
// CONTROLLERS
// ================================
import 'package:aorandra/features/home/logic/home_controller.dart';

// ================================
// SERVICES (GLOBAL)
// ================================
import 'package:aorandra/shared/services/search_history_service.dart';
import 'package:aorandra/shared/services/user_manager.dart';

// ================================
// SHARED WIDGETS
// ================================
import 'package:aorandra/shared/widgets/user_avatar.dart'; // 🔥 IMPORTANT

// ================================
// FEATURE SCREENS
// ================================
import 'package:aorandra/features/home/ui/story_screen.dart';
import 'package:aorandra/features/comments/ui/comments_screen.dart';
import 'package:aorandra/features/profile/ui/profile_screen.dart';
import 'package:aorandra/features/chat/ui/chat_list_screen.dart';
import 'package:aorandra/features/post/ui/post_screen.dart';
import 'package:aorandra/features/camera/ui/camera_screen.dart';
import 'package:aorandra/features/aoris/ui/aoris_screen.dart';
import 'package:aorandra/features/notifications/ui/notfications_screen.dart';
import 'package:aorandra/features/home/widgets/feed_widget.dart';

// ================================
// FEATURE WIDGETS
// ================================
import 'package:aorandra/features/aoris/ui/widgets/story_item.dart';
// ================================
// HOME SCREEN
// ================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ================================
  // SERVICES
  // ================================

  final supabase = Supabase.instance.client;
  // ignore: unused_field
  final SearchHistoryService searchHistoryService = SearchHistoryService();
  

 final GlobalKey<RefreshIndicatorState> _refreshKey =
    GlobalKey<RefreshIndicatorState>();
  // ================================
  // CONTROLLERS
  // ================================

  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

late Future<List<dynamic>> _postsFuture;
  // ================================
  // GESTURE & ANIMATION STATE
  // ================================

  double storyProgress = 0.0;
  double searchProgress = 0.0;
  double navDrag = 0.0;
  double _sideDrag = 120;
  double headerOffset = 0;

  // ================================
  // TAB & SEARCH STATE
  // ================================

  bool isTyping = false;
  int currentTab = 0;
  int searchTab = 0;
  // ignore: unused_field
  int activeStoryIndex = 0;
  // ignore: unused_field
  List<String> searchHistory = [];
  bool showFlyingPreview = false;
  Map? currentSharedPost;
  bool isHandleLoading = false;

  // ================================
  // LIKE STATE - optimistic updates
  // ================================

  Map<String, bool> savePosts = {};
  Map<String, bool> likedPosts = {};
  Map<String, int> likesCount = {};
  Map<String, int> commentsCount = {};
  

  Set<String> selectedUsers = {};
  TextEditingController shareMessageController = TextEditingController();

  // 🔥 PAGE CONTROLLERS لكل بوست
final Map<String, PageController> pageControllers = {};

// 🔥 CURRENT PAGE لكل بوست
final Map<String, ValueNotifier<int>> pageIndexes = {};

  // ================================
  // DEBOUNCE TIMER
  // ================================

  String myAvatar = '';

  Timer? _debounce;

  // ================================
  // HELPERS
  // ================================

  void _copyLink(Map post) async {
  final link = "https://yourapp.com/post/${post['id']}";

  await Clipboard.setData(ClipboardData(text: link));

  HapticFeedback.mediumImpact(); // 🔥 اهتزاز خفيف

  Navigator.pop(context);

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Link copied"),
      duration: Duration(milliseconds: 800),
    ),
  );
}

void _reportPost(Map post) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  try {
    await supabase.from('reports').insert({
      'post_id': post['id'],
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Reported"),
      ),
    );
  } catch (e) {
    debugPrint("Report failed: $e");
  }
}

// ================================
  // 
  // ================================

Future<int> getSharesCount(String postId) async {
  final data = await supabase
      .from('messages')
      .select('id')
      .eq('post_id', postId);

  return data.length;
}

  bool get isNavExpanded => navDrag < -30;

bool isRefreshing = false;

Future<void> _manualRefresh() async {
  if (isRefreshing) return;

  setState(() => isRefreshing = true);

  final stopwatch = Stopwatch()..start();

  try {
    final newPosts = await _fetchPosts();

    await _loadLikesCounts();
    await _loadLikedPosts();

    // ⬇️ فرق الوقت
    final elapsed = stopwatch.elapsedMilliseconds;

    // ⬇️ إذا كان سريع زود وقت
    if (elapsed < 700) {
      await Future.delayed(Duration(milliseconds: 700 - elapsed));
    }

    if (!mounted) return;

    setState(() {
      _postsFuture = Future.value(newPosts);
    });

  } catch (e) {
    debugPrint('Refresh failed: $e');
  } finally {
    if (mounted) {
      setState(() => isRefreshing = false);
    }
  }
}

  // ================================
  // LIFECYCLE
  // ================================

 @override
void initState() {
  super.initState();

  _postsFuture = _fetchPosts();

  _loadMyAvatar();
  _loadLikedPosts();
  _loadLikesCounts();
  _loadCommentsCounts();
  _loadSavedPosts();

  _loadUsers(); 

  searchController.addListener(_onSearchChanged);

  _scrollController.addListener(() {
    if (!mounted) return;
    final offset = _scrollController.offset;
    setState(() {
      headerOffset = (offset * 0.7).clamp(0, 80);
    });
  });
}

Future<void> _loadUsers() async {
  try {
    final data = await supabase
        .from('profiles')
        .select('id, username, avatar_url');

    UserManager.instance.setUsers(data);

    if (mounted) setState(() {}); // 🔥 هذا هو الحل
  } catch (e) {
    debugPrint("LOAD USERS ERROR: $e");
  }
}

void _shareExternally(Map post) {
  final String text =
      "${post['caption'] ?? ''}\n\nhttps://yourapp.com/post/${post['id']}";

  Share.share(text);
}

void _openShareSheet(Map post) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return _buildShareSheet(post, scrollController);
        },
      );
    },
  );
}

// Separate function to call Supabase
Future<List<dynamic>> _fetchPosts() async {
  try {
    // ============================
    // 1. FETCH POSTS
    // ============================
    // Get all posts ordered by newest first
    final posts = await supabase
        .from('posts')
        .select()
        .eq('type', 'post') // Only fetch real posts
        .order('created_at', ascending: false);

    // If no posts, return empty list
    if (posts.isEmpty) return [];

    // ============================
    // 2. EXTRACT UNIQUE USER IDS
    // ============================
    // Collect all unique user IDs from posts
    final userIds = posts
        .map((post) => post['user_id'])
        .where((id) => id != null)
        .toSet() // Remove duplicates
        .toList();

    // ============================
    // 3. FETCH USERS (FIXED 🔥)
    // ============================
    // IMPORTANT:
    // We use "profiles" instead of "users"
    // to keep consistency across the app
    final users = await supabase
        .from('profiles') // ✅ unified source
        .select('id, username, avatar_url')
        .inFilter('id', userIds);

    // ============================
    // 4. MAP USERS BY ID
    // ============================
    // Convert list of users into a map for fast lookup
    // Also normalize field names (avatar_url → image)
    final Map<String, dynamic> usersMap = {
      for (var user in users)
        user['id'].toString(): {
          'id': user['id'],
          'username': user['username'] ?? 'User',
          'image': user['avatar_url'] ?? '', // 🔥 unified key
        }
    };

    // ============================
    // 5. MERGE POSTS + USER DATA
    // ============================
    // Attach user info directly into each post
    final enrichedPosts = posts.map((post) {
      final userId = post['user_id']?.toString();

      return {
        ...post,

        // Inject user object into post
        'user': usersMap[userId] ?? {
          'id': userId,
          'username': 'User',
          'image': '',
        },
      };
    }).toList();

    // ============================
    // 6. RETURN FINAL DATA
    // ============================
    return enrichedPosts;

  } catch (e) {
    // ============================
    // ERROR HANDLING
    // ============================
    print("FETCH POSTS ERROR: $e");
    return [];
  }
}

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    // dispose scroll controller to prevent memory leak
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSavedPosts() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  final data = await supabase
      .from('saved_posts')
      .select('post_id')
      .eq('user_id', userId);

  setState(() {
    savePosts = {
      for (var item in data)
        item['post_id'].toString(): true,
    };
  });
}

Future<void> _toggleSave(String postId) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  final isSaved = savePosts[postId] ?? false;

  // 🔥 UI فوري
  setState(() {
    savePosts[postId] = !isSaved;
  });

  try {
    final existing = await supabase
        .from('saved_posts')
        .select()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    if (existing != null) {
      await supabase
          .from('saved_posts')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
    } else {
      await supabase
          .from('saved_posts')
          .insert({
            'user_id': userId,
            'post_id': postId,
          });
    }
  } catch (e) {
    // rollback
    setState(() {
      savePosts[postId] = isSaved;
    });
  }
}

  // ================================
  // SEARCH
  // ================================

  /// Debounced search handler - waits 500ms before triggering to reduce API calls
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          isTyping = searchController.text.isNotEmpty;
        });
      }
    });
  }

  // ================================
  // COMMENTS
  // ================================
  /// Open the comments bottom sheet for a given post
Future<void> _openComments(String postId) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        snap: true,
        snapSizes: const [0.65, 0.95],
        builder: (_, scrollController) {
          return CommentsScreen(
            postId: postId,
            scrollController: scrollController,
          );
        },
      );
    },
  );

  // After closing comments, refresh counts to reflect any new comments or likes
  await _manualRefresh();
}

void _openPostMenu(
  String postId,
  String ownerId,
  String caption,
) {
  final currentUserId = supabase.auth.currentUser?.id;
  final bool isMe = currentUserId == ownerId;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) {
      return GlassContainer(
        height: isMe ? 260 : 300,
        radius: 28,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // HANDLE
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // TOP ACTION BOXES
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (isMe)
                    _topAction(
                      Icons.delete_outline,
                      "Delete",
                      () {
                        Navigator.pop(context);
                        _deletePost(postId);
                      },
                      isDanger: true,
                    )
                  else
                    _topAction(
                      Icons.block,
                      "Not interested",
                      () {
                        Navigator.pop(context);
                      },
                    ),

                  _topAction(
                    isMe ? Icons.edit : Icons.flag,
                    isMe ? "Edit" : "Report",
                    () {
                      Navigator.pop(context);

                      if (isMe) {
                        _editPostCaption(postId, caption);
                      }
                    },
                    isDanger: !isMe,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // COPY LINK
              _menuItem(
                Icons.link,
                "Copy link",
                () async {
                  await Clipboard.setData(
                    ClipboardData(text: postId),
                  );

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Link copied"),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _deletePost(String postId) async {
  try {
    await supabase
        .from('posts')
        .delete()
        .eq('id', postId);

    await _manualRefresh();
  } catch (e) {
    debugPrint("Delete failed: $e");
  }
}

void _editPostCaption(String postId, String oldCaption) {
  final controller =
      TextEditingController(text: oldCaption);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          "Edit caption",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Write caption...",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await supabase
                  .from('posts')
                  .update({
                    'caption': controller.text.trim(),
                  })
                  .eq('id', postId);

              Navigator.pop(context);
              _manualRefresh();
            },
            child: const Text("Save"),
          ),
        ],
      );
    },
  );
}

  // ================================
  // LIKE - toggle with optimistic update
  // ================================

 /// Toggle like state - updates UI immediately then syncs to server
Future<void> _toggleLike(String postId, int currentServerLikes) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  final wasLiked = likedPosts[postId] ?? false;
  final prevCount = likesCount[postId] ?? currentServerLikes;

  // UI update (optimistic)
  setState(() {
    likedPosts[postId] = !wasLiked;
    likesCount[postId] = wasLiked ? prevCount - 1 : prevCount + 1;
  });

  try {
    final existing = await supabase
        .from('likes')
        .select()
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();

    if (existing != null) {
      // REMOVE LIKE
      await supabase
          .from('likes')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);

    } else {
      // ADD LIKE
      await supabase.from('likes').insert({
        'user_id': userId,
        'post_id': postId,
      });

      // ================= NOTIFICATION =================

      final postData = await supabase
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .single();

      final postOwnerId = postData['user_id'];

      if (postOwnerId != userId) {
        await supabase.from('notifications').insert({
          'receiver_id': postOwnerId,
          'sender_id': userId,
          'type': 'like',
          'post_id': postId,
          'is_read': false, // 🔥 IMPORTANT
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }

    final likes = await supabase
        .from('likes')
        .select()
        .eq('post_id', postId);

    await supabase
        .from('posts')
        .update({'likes': likes.length})
        .eq('id', postId);

    if (mounted) {
      setState(() {
        likesCount[postId] = likes.length;
      });
    }

  } catch (e) {
    setState(() {
      likedPosts[postId] = wasLiked;
      likesCount[postId] = prevCount;
    });
  }
}
  Future<void> _loadLikedPosts() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  final data =  await supabase
      .from('likes')
      .select('post_id')
      .eq('user_id', userId);

  if (!mounted) return;

  setState(() {
    likedPosts = {
      for (var item in data)
        item['post_id'].toString(): true,
    };
  });
}

Future<void> _loadLikesCounts() async {
  final likesData = await supabase
      .from('likes')
      .select('post_id');

  Map<String, int> tempCounts = {};

  for (var like in likesData) {
    final postId = like['post_id'].toString();
    tempCounts[postId] = (tempCounts[postId] ?? 0) + 1;
  }

  if (!mounted) return;

  setState(() {
    likesCount = tempCounts;
  });
}

 Future<void> _loadMyAvatar() async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return;

  try {
    final data = await supabase
        .from('profiles')
        .select('avatar_url')
        .eq('id', userId)
        .single();

    if (mounted) {
      setState(() {
        myAvatar = data['avatar_url'] ?? '';
      });
    }
  } catch (e) {
    debugPrint('Avatar load error: $e');
  }
}

Future<void> _loadCommentsCounts() async {
  final data = await supabase
      .from('comments')
      .select('post_id');

  Map<String, int> temp = {};

  for (var c in data) {
    final id = c['post_id'].toString();
    temp[id] = (temp[id] ?? 0) + 1;
  }

  if (!mounted) return;

  setState(() {
    commentsCount = temp;
  });
}

  // ================================
  // PROFILE NAVIGATION
  // ================================

  /// Navigate to a user profile screen
  void _goToProfile(String username, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(username: username, userId: userId),
      ),
    );
  }

  // ================================
  // MAIN BUILD
  // ================================

  @override
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final user = supabase.auth.currentUser;

  // ================= USER LOADING STATE =================
  if (user == null) {
    return Center(
      child: CircularProgressIndicator(
        color: theme.textTheme.bodyLarge?.color,
      ),
    );
  }

  return Scaffold(
    backgroundColor: theme.scaffoldBackgroundColor,

    body: SafeArea(
      child: Stack(
        children: [

          // =========================================================
          // MAIN FEED (HOME TAB)
          // =========================================================
          if (currentTab == 0)
            buildFeed(), // 🔥 Replaced _buildRealFeed()

          // =========================================================
          // STORY SWIPE ZONE (LEFT EDGE)
          // Handles horizontal swipe to open stories panel
          // =========================================================
          Positioned(
            left: 0,
            width: 80,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx.abs() > details.delta.dy.abs()) {
                  setState(() {
                    storyProgress += details.delta.dx / 300;
                    storyProgress = storyProgress.clamp(0.0, 1.0);
                  });
                }
              },
              onHorizontalDragEnd: (_) {
                setState(() {
                  storyProgress = storyProgress > 0.4 ? 1.0 : 0.0;
                });
              },
            ),
          ),

          // =========================================================
          // SEARCH SWIPE ZONE (TOP EDGE)
          // Handles vertical swipe to open search panel
          // =========================================================
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 3) {
                  setState(() {
                    searchProgress += details.delta.dy / 420;
                    searchProgress = searchProgress.clamp(0.0, 1.0);
                  });
                }
              },
              onVerticalDragEnd: (_) {
                setState(() {
                  searchProgress = searchProgress > 0.4 ? 1.0 : 0.0;
                });
              },
            ),
          ),

          // =========================================================
          // HEADER (VISIBLE ONLY IN HOME TAB)
          // =========================================================
          if (currentTab == 0) _buildHeader(),

          // =========================================================
          // STORY PANEL (SLIDE-IN)
          // =========================================================
          if (currentTab == 0) _buildStoryPanel(),

          // =========================================================
          // AORIS (REELS TAB)
          // =========================================================
          if (currentTab == 1)
            AorasScreen(
              videos: ['assets/videos/test.mp4'],
              onShare: (video) => _openShareSheet(video),
            ),

          // =========================================================
          // CHAT TAB
          // =========================================================
          if (currentTab == 2)
            ChatListScreen(
              currentUserId: user.id,
            ),

          // =========================================================
          // PROFILE TAB
          // =========================================================
          if (currentTab == 3)
            ProfileScreen(
              username: user.email ?? 'User',
              userId: user.id,
            ),

          // =========================================================
          // SIDE PANEL (SETTINGS / MENU)
          // =========================================================
          _buildSidePanel(),

          // =========================================================
          // SIDE PANEL GESTURE DETECTOR
          // =========================================================
          _buildSideGestureDetector(),

          // =========================================================
          // SEARCH SHEET (SLIDE DOWN PANEL)
          // =========================================================
          _buildSearchSheet(),

          // =========================================================
          // BOTTOM NAVIGATION BAR
          // =========================================================
          _buildBottomBar(),
        ],
      ),
    ),
  );
}

 Widget _topAction(
  IconData icon,
  String label,
  VoidCallback onTap, {
  bool isDanger = false,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: isDanger ? Colors.red : Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isDanger ? Colors.red : Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

Widget _menuItem(
  IconData icon,
  String title,
  VoidCallback onTap, {
  bool isDanger = false,
}) {
  return ListTile(
    onTap: onTap,
    leading: Icon(
      icon,
      color: isDanger ? Colors.red : Colors.white,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: isDanger ? Colors.red : Colors.white,
      ),
    ),
  );
}

Widget _buildShareSheet(Map post, ScrollController scrollController) {
  return StatefulBuilder(
    builder: (context, setModalState) {

      // ✅ USERS FROM CACHE
      final users = UserManager.instance.getAllUsers();

      return Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          color: Colors.black.withValues(alpha: 0.85),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Column(
              children: [

                // ================= SCROLL =================
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [

                      // HANDLE
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // SEARCH
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const TextField(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Search",
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ================= USERS =================
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: users.length,
                          itemBuilder: (_, i) {
                            final user = users[i];
                            final id = user['id'].toString();
                            final isSelected = selectedUsers.contains(id);

                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) {
                                    selectedUsers.remove(id);
                                  } else {
                                    selectedUsers.add(id);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  children: [

                                    // 🔥 AVATAR (FROM MANAGER)
                                    Stack(
                                      children: [
                                        SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: UserAvatar(
                                            userId: id,
                                          ),
                                        ),

                                        if (isSelected)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.blue,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),

                                    const SizedBox(height: 5),

                                    // 🔥 USERNAME (FROM MANAGER)
                                    Text(
                                      UserManager.instance.getUsername(id),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // ================= BOTTOM =================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Column(
                    children: [

                      TextField(
                        controller: shareMessageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Write a message...",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: selectedUsers.isEmpty
                              ? null
                              : () => _sendToMultipleUsers(post),
                          child: const Text("Send"),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _externalApp(Icons.link, "Copy", () => _copyLink(post)),
                          _externalApp(Icons.bookmark_border, "Save", () => _toggleSave(post['id'])),
                          _externalApp(Icons.flag_outlined, "Report", () => _reportPost(post)),
                          _externalApp(Icons.ios_share, "More", () => _shareExternally(post)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _externalApp(
  IconData icon,
  String label,
  VoidCallback onTap,
) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            // 🔥 Glass effect
            color: Colors.white.withValues(alpha: 0.08),

            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),

          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Future<void> _sendToMultipleUsers(Map post) async {
  // ================= GET CURRENT USER =================
  final senderId = supabase.auth.currentUser?.id;
  if (senderId == null) return;

  // ================= GET MESSAGE TEXT =================
  final message = shareMessageController.text.trim();

  try {

    // ================= SHARE LOGIC =================
    // 🔥 Send the post as a message to each selected user
    for (final receiverId in selectedUsers) {

      await supabase.from('messages').insert({
        'sender_id': senderId,
        'receiver_id': receiverId,
        'post_id': post['id'], // link the post to the message
        'text': message,
        'created_at': DateTime.now().toIso8601String(),
      });

      // 🔥 DEBUG: check if data is being sent correctly
      debugPrint("SENT TO: $receiverId | POST: ${post['id']}");
    }

    // ================= CLEAR UI STATE =================
    selectedUsers.clear();               // clear selected users
    shareMessageController.clear();      // clear message input

    // ================= CLOSE SHARE SHEET =================
    Navigator.pop(context);

    // ================= SUCCESS FEEDBACK =================
    _showCenterSentToast();

    // ================= REFRESH FEED =================
    // reload posts to reflect any changes
    await _manualRefresh();

  } catch (e) {
    // ================= ERROR HANDLING =================
    debugPrint("Send failed: $e");
  }
}

void _showCenterSentToast() {
  final overlay = Overlay.of(context);
  if (overlay == null) return;

  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 250),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: value,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Text(
                      "Sent",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  overlay.insert(overlayEntry);

  Future.delayed(const Duration(milliseconds: 1000), () {
    overlayEntry.remove();
  });
}

  // ================================
  // FEED
  // ================================

 // ================= FEED =================
// ================================
// FEED BUILDER
// Returns the main feed widget (posts list)
// ================================
Widget buildFeed() {
  return FeedWidget(
    // ================= DATA =================
    // Future that fetches posts from backend
    postsFuture: _postsFuture,

    // Scroll controller for feed scrolling behavior
    scrollController: _scrollController,

    // ================= STATE =================
    // Local UI state (optimistic updates)
    likedPosts: likedPosts,
    savePosts: savePosts,
    likesCount: likesCount,
    commentsCount: commentsCount,

    // ================= MEDIA =================
    // Controllers for multi-media (carousel inside post)
    pageControllers: pageControllers,
    pageIndexes: pageIndexes,

    // ================= ACTIONS =================
    // Pull-to-refresh handler
    onRefresh: _manualRefresh,

    // Reload comments count after opening comments
    onLoadComments: _loadCommentsCounts,

    // User interactions
    onLike: _toggleLike,
    onSave: _toggleSave,
    onOpenComments: _openComments,
    onShare: _openShareSheet,
    onOpenProfile: _goToProfile,

    // 🔥 Open post options menu (3 dots)
    onOpenMenu: _openPostMenu,

    // ================= UTILITIES =================
    // Format post timestamp (e.g. 5m, 2h, 3d)
    formatTime: _formatTime,
    getSharesCount: getSharesCount,
  );
}
  // ================================
  // TIME FORMATTER
  // ================================

  /// Format a date string into a relative time label (e.g. "5m", "2h", "3d")
  String _formatTime(String? date) {
    if (date == null) return '';
    final d = DateTime.parse(date);
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds <= 0 ? 1 : diff.inSeconds}s';
    }
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${d.day}/${d.month}/${d.year}';
  }

  // ================================
  // HEADER
  // ================================

  /// Floating app name header that hides on scroll
  Widget _buildHeader() {
    final theme = Theme.of(context);

    return Positioned(
      top: HomeController.headerTop - headerOffset,
      left: HomeController.headerHorizontal,
      right: HomeController.headerHorizontal,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 3),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          final floatY = (value * 6);

          return Transform.translate(
            offset: Offset(0, floatY),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Aorandra',
                  style: TextStyle(
                    fontFamily: 'PacificoFont',
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: HomeController.titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================================
  // EMPTY STATE
  // ================================

  /// Shown when there are no posts in the feed
  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Transform.translate(
        offset: const Offset(0, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: HomeController.emptyIconCircleSize,
              height: HomeController.emptyIconCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.dividerColor, width: 1.5),
              ),
              child: Icon(Icons.favorite_border,
                  color: theme.iconTheme.color,
                  size: HomeController.emptyIconSize),
            ),
            const SizedBox(height: 14),
            Text(
              'No content yet',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: HomeController.emptyTitleSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your home feed will appear here',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: HomeController.emptySubtitleSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================
  // SIDE PANEL
  // ================================

  /// Gesture detector for the swipe-in side panel
 Widget _buildSideGestureDetector() {
  return Positioned(
    top: 0,
    right: 0,
    width: 110,
    height: 90,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        // Ignore vertical movement
        if (details.delta.dx.abs() < details.delta.dy.abs()) return;

        setState(() {
          _sideDrag += details.delta.dx;
          _sideDrag = _sideDrag.clamp(0.0, 120.0);
        });
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          final isOpen = _sideDrag < 60;
          _sideDrag = isOpen ? 0 : 120;
        });
      },
    ),
  );
}

  /// Side panel with quick-access buttons (Add Post, Notifications)
  Widget _buildSidePanel() {
    final theme = Theme.of(context);

    return Positioned(
      top: 40,
      right: -_sideDrag,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: 80,
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Add post button
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CameraScreen())),
              child: Icon(Icons.add_box_outlined,
                  color: theme.iconTheme.color, size: 30),
            ),

            const SizedBox(height: 25),

            // Notifications button
            GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen())),
              child: Icon(Icons.notifications_none,
                  color: theme.iconTheme.color, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  // ================================
  // STORY PANEL
  // ================================

// Swipeable story panel that slides in from the left edge when swiping right on the feed
Widget _buildStoryPanel() {
  const double hiddenX = -120;
  const double shownX = 10;

  final double currentX =
      hiddenX + (shownX - hiddenX) * storyProgress;

  return AnimatedPositioned(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    top: HomeController.storyPanelTop,
    bottom: HomeController.storyPanelBottom,
    left: currentX,
    child: Stack(
      children: [
        // ============================
        // PANEL
        // ============================
        GlassContainer(
          height: double.infinity,
          radius: HomeController.storyPanelRadius,
          child: SizedBox(
            width: HomeController.storyPanelWidth,
            child: Column(
              children: [
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: supabase.from('stories').select(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox();
                      }

                      final stories = snapshot.data!;
                      final currentUserId =
                          supabase.auth.currentUser?.id;

                      // ================= FILTER 24h =================
                      final validStories =
                          stories.where((story) {
                        final createdAt = DateTime.tryParse(
                            story['created_at'] ?? '');
                        if (createdAt == null) return false;

                        return createdAt.isAfter(
                          DateTime.now().subtract(
                              const Duration(hours: 24)),
                        );
                      }).toList();

                      // ================= GROUP =================
                      final Map<String,
                              List<Map<String, dynamic>>>
                          groupedStories = {};

                      for (var story in validStories) {
                        final userId =
                            story['user_id']?.toString();

                        if (userId == null) continue;

                        groupedStories
                            .putIfAbsent(userId, () => []);
                        groupedStories[userId]!.add(story);
                      }

                      final myStories =
                          groupedStories[currentUserId] ?? [];

                      groupedStories.remove(currentUserId);

                      final otherUsers =
                          groupedStories.entries.toList();

                      return ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 20),
                        itemCount:
                            otherUsers.length + 1,
                        itemBuilder: (_, index) {

                          // ================= MY STORY =================
                          if (index == 0) {
                            if (currentUserId == null) {
                              return const SizedBox.shrink();
                            }

                            final myAvatar =
                                UserManager.instance
                                    .getAvatar(currentUserId);

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                      bottom: 18),
                              child: InkWell(
                                onTap: () {
                                  if (myStories.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StoryScreen(
                                          stories: myStories
                                              .map((s) =>
                                                  s['media_url']
                                                      as String)
                                              .toList(),
                                          username: "My Story",
                                          userProfileImage:
                                              myAvatar,
                                          storyDocId: '',
                                          isMyStory: true,
                                          viewers: [],
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CameraScreen(),
                                      ),
                                    );
                                  }
                                },
                                child: StoryItem(
                                  imageUrl: myAvatar,
                                  username: 'My Story',
                                  isMe: true,
                                  hasStory:
                                      myStories.isNotEmpty,
                                ),
                              ),
                            );
                          }

                          // ================= OTHER USERS =================
                          final userStories =
                              otherUsers[index - 1].value;
                          final firstStory =
                              userStories.first;

                          final userId =
                              firstStory['user_id'].toString();

                          final avatar =
                              UserManager.instance
                                  .getAvatar(userId);

                          final username =
                              UserManager.instance
                                  .getUsername(userId);

                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: 18),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        StoryScreen(
                                      stories: userStories
                                          .map((s) =>
                                              s['media_url']
                                                  as String)
                                          .toList(),
                                      username: username,
                                      userProfileImage:
                                          avatar,
                                      storyDocId:
                                          firstStory['id'] ??
                                              '',
                                      isMyStory: false,
                                      viewers: List<
                                              Map<String,
                                                  dynamic>>.from(
                                          firstStory[
                                                  'viewers'] ??
                                              []),
                                    ),
                                  ),
                                );
                              },
                              child: StoryItem(
                                imageUrl: avatar,
                                username: username,
                                isMe: false,
                                hasStory: true,
                                isViewed: false,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // ============================
        // CLOSE HANDLE
        // ============================
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 40,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              final dx = details.delta.dx;

              setState(() {
                if (dx < 0) {
                  storyProgress += dx / 60;
                  storyProgress =
                      storyProgress.clamp(0.0, 1.0);
                }
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() {
                if (storyProgress < 0.3) {
                  storyProgress = 0.0;
                } else {
                  storyProgress = 1.0;
                }
              });
            },
          ),
        ),
      ],
    ),
  );
}



  // ================================
  // SEARCH SHEET
  // ================================

  /// Pull-down search sheet with People and Explore tabs
  Widget _buildSearchSheet() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double sheetHeight = screenHeight * 0.85;
    final double topPosition = -sheetHeight + (sheetHeight * searchProgress);

    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      height: sheetHeight,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            searchProgress += details.delta.dy / 400;
            searchProgress = searchProgress.clamp(0.0, 1.0);
          });
        },
        onVerticalDragEnd: (_) {
          setState(() {
            searchProgress = searchProgress > 0.5 ? 1 : 0;
          });
        },
        child: GlassContainer(
          height: sheetHeight,
          radius: HomeController.searchExpandedRadius,
          child: Column(
            children: [
              SizedBox(height: HomeController.searchTopSpacing),
              _buildSearchBar(),
              SizedBox(height: HomeController.searchTabsSpacing),
              _buildSearchTabs(),
              const SizedBox(height: 12),
              Expanded(
                child: searchTab == 0
                    ? (searchController.text.isEmpty
                        ? _buildPeopleHistory()
                        : _buildPeopleSuggestions())
                    : _buildExplorePosts(),
              ),
              _buildSearchHandle(),
            ],
          ),
        ),
      ),
    );
  }

  /// Search input field with clear and submit actions
  Widget _buildSearchBar() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                // withValues instead of deprecated withOpacity
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                cursorColor: theme.textTheme.bodyLarge?.color,
                onSubmitted: (value) async {
                  final query = value.trim();
                  if (query.isNotEmpty) {
                    await SearchHistoryService.addSearch('people', query);
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search Aorandra...',
                  hintStyle:
                      TextStyle(color: theme.textTheme.bodyMedium?.color),
                  border: InputBorder.none,
                  prefixIcon:
                      Icon(Icons.search, color: theme.iconTheme.color),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, color: theme.iconTheme.color),
                          onPressed: () {
                            searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // withValues instead of deprecated withOpacity
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor),
            ),
            child: IconButton(
              icon: Icon(Icons.search, color: theme.iconTheme.color),
              onPressed: () async {
                final query = searchController.text.trim();
                if (query.isNotEmpty) {
                  await SearchHistoryService.addSearch('people', query);
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Search history list for the People tab
  Widget _buildPeopleHistory() {
    return FutureBuilder<List<String>>(
      future: SearchHistoryService.getHistory('people'),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildSearchPlaceholder(
              'Search for people', Icons.person_search);
        }

        final history = snapshot.data!;

        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return ListTile(
              leading: const Icon(Icons.history, color: Colors.white54),
              title: Text(item, style: const TextStyle(color: Colors.white)),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () async {
                  await SearchHistoryService.removeItem('people', item);
                  setState(() {});
                },
              ),
              onTap: () {
                searchController.text = item;
                setState(() {});
              },
            );
          },
        );
      },
    );
  }

  /// Tab row for switching between People and Explore
  Widget _buildSearchTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildTabItem('People', 0),
        _buildTabItem('Explore', 1),
      ],
    );
  }

  /// Individual animated tab with underline indicator
  Widget _buildTabItem(String title, int index) {
    final bool active = searchTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white54 : Colors.black54;

    return GestureDetector(
      onTap: () => setState(() => searchTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: active ? activeColor : inactiveColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            child: Text(title),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 26 : 0,
            height: 2,
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  /// User search results from Supabase based on username query
  Widget _buildPeopleSuggestions() {
    if (!isTyping) {
      return _buildSearchPlaceholder('Search for users', Icons.search);
    }

    final theme = Theme.of(context);
    final query = searchController.text.trim();

    return FutureBuilder(
      // Server-side search with limit for performance
      future: supabase
          .from('profiles')
          .select()
          .ilike('username', '%$query%')
          .limit(20),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: CircularProgressIndicator(color: theme.iconTheme.color),
          );
        }

        final users = snapshot.data as List;

        if (users.isEmpty) {
          return _buildSearchPlaceholder('No users found', Icons.people_outline);
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userData = users[index];
            final String username = userData['username'] ?? '';
            final avatar = userData['image'];

            return ListTile(
              leading: CircleAvatar(
                // withValues instead of deprecated withOpacity
                backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                backgroundImage: avatar != null && avatar != ''
                    ? NetworkImage(avatar)
                    : null,
                child: avatar == null || avatar == ''
                    ? Icon(Icons.person, color: theme.iconTheme.color)
                    : null,
              ),
              title: Text(
                username,
                style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                if (username.isNotEmpty) {
                  await SearchHistoryService.addSearch('people', username);
                }
                _goToProfile(username, userData['id']);
              },
            );
          },
        );
      },
    );
  }

  /// Explore posts grid filtered by title keyword
  Widget _buildExplorePosts() {
  
  final String query = searchController.text.toLowerCase();

  return FutureBuilder(
    future: supabase.from('posts').select(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      final posts = snapshot.data as List;

      final filteredPosts = posts.where((post) {
        final title = (post['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();

      if (filteredPosts.isEmpty) {
        return _buildSearchPlaceholder('No results found', Icons.search_off);
      }

      return GridView.builder(
        padding: const EdgeInsets.all(6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: filteredPosts.length,
        itemBuilder: (context, index) {
          final postData = filteredPosts[index];
          final String mediaUrl = postData['media_url'] ?? '';

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PostScreen(postData: postData),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [

                  // MEDIA (image or video thumbnail)
                  Positioned.fill(
                    child: mediaUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.grey[900],
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[900],
                              child: const Icon(Icons.broken_image,
                                  color: Colors.white54),
                            ),
                          )
                        : Container(
                            color: Colors.grey[900],
                          ),
                  ),

                  // VIDEO ICON OVERLAY
                  if (mediaUrl.contains(".mp4"))
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(Icons.play_arrow,
                          color: Colors.white, size: 18),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

  /// Generic placeholder for empty search states
  Widget _buildSearchPlaceholder(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white38 : Colors.black38;
    final textColor = isDark ? Colors.white70 : Colors.black87;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: iconColor),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Handle bar at bottom of search sheet with optional clear history button
  Widget _buildSearchHandle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Stack(
        children: [
          // Centered drag handle bar
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Clear history button - only visible when history exists
          FutureBuilder<List<String>>(
            future: SearchHistoryService.getHistory(
              searchTab == 0 ? 'people' : 'explore',
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox();
              }

              return Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  onTap: () async {
                    if (searchTab == 0) {
                      await SearchHistoryService.clearHistory('people');
                    } else {
                      await SearchHistoryService.clearHistory('explore');
                    }
                    setState(() {});
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: isDark ? Colors.blueAccent : Colors.blue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================================
  // BOTTOM BAR
  // ================================

/// Swipe-up expandable bottom navigation bar
Widget _buildBottomBar() {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: EdgeInsets.only(bottom: HomeController.navBottom),

      // ================= DRAG TO EXPAND =================
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: (details) {
          setState(() {
            navDrag += details.delta.dy;
            navDrag = navDrag.clamp(-120.0, 0.0);
          });
        },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,

          height: isNavExpanded
              ? HomeController.navExpandedHeight
              : HomeController.handleHeight + 12,

          width: isNavExpanded
              ? HomeController.navExpandedWidth
              : HomeController.handleWidth,

          child: Transform.translate(
            offset: Offset(
              HomeController.navOffsetX,
              HomeController.navOffsetY,
            ),

            child: GlassContainer(
              height: isNavExpanded
                  ? HomeController.navExpandedHeight
                  : HomeController.handleHeight + 12,

              radius: isNavExpanded
                  ? HomeController.navRadius
                  : HomeController.handleRadius,

              child: isNavExpanded

                  // ================= EXPANDED =================
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _navIcon(Icons.home, 0),
                        _navIcon(Icons.play_arrow, 1),

                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CameraScreen(),
                            ),
                          ),
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add,
                              color: isDark ? Colors.black : Colors.white,
                              size: 30,
                            ),
                          ),
                        ),

                        _navIcon(Icons.chat_bubble_outline, 2),
                        _navProfileIcon(3),
                      ],
                    )

                  // ================= HANDLE =================
                  : Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,

                        onTap: () async {
                          if (isHandleLoading) return;

                          setState(() => isHandleLoading = true);

                          // 🔥 fake drag animation (smooth like pull)
                          await _scrollController.animateTo(
                            -80,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );

                          // 🔥 trigger real refresh
                          if (_refreshKey.currentState != null) {
                            await _refreshKey.currentState!.show();
                          }

                          if (mounted) {
                            setState(() => isHandleLoading = false);
                          }
                        },

                        child: SizedBox(
                          width: HomeController.handleWidth,
                          height: HomeController.handleHeight + 20,

                          child: Center(
                            child: isHandleLoading

                                // ================= LOADING =================
                                ? SizedBox(
                                    width: HomeController.handleHeight * 0.6,
                                    height: HomeController.handleHeight * 0.6,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )

                                // ================= IDLE =================
                                : AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width:
                                        HomeController.handleWidth * 0.55,
                                    height:
                                        HomeController.handleHeight,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.3)
                                          : Colors.black.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(
                                        HomeController.handleRadius,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _navProfileIcon(int index) {
  final theme = Theme.of(context);

  return GestureDetector(
    onTap: () => setState(() {
      currentTab = index;
      storyProgress = 0;
      searchProgress = 0;
    }),
    child: myAvatar.isNotEmpty
        ? Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: currentTab == index
                    ? theme.iconTheme.color!
                    : theme.iconTheme.color!.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 12,
              backgroundImage: NetworkImage(myAvatar),
            ),
          )
        : Icon(
            Icons.person_outline,
            color: currentTab == index
                ? theme.iconTheme.color
                : theme.iconTheme.color?.withValues(alpha: 0.5),
            size: HomeController.navIconSize,
          ),
  );
}

  /// Individual navigation icon tab button
  Widget _navIcon(IconData icon, int index) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => setState(() {
        currentTab = index;
        storyProgress = 0;
        searchProgress = 0;
      }),
      child: Icon(
        icon,
        // FittedBox fills the container with no black bars
        color: currentTab == index
            ? theme.iconTheme.color
            : theme.iconTheme.color?.withValues(alpha: 0.5),
        size: HomeController.navIconSize,
      ),
    );
  }
}

// ================================
// FEED VIDEO PLAYER
// ================================

/// Video player for feed posts with auto-play, mute toggle, and keep-alive
class _FeedVideoPlayer extends StatefulWidget {
  final String url;

  const _FeedVideoPlayer(this.url);

  @override
  State<_FeedVideoPlayer> createState() => _FeedVideoPlayerState();
}

class _FeedVideoPlayerState extends State<_FeedVideoPlayer>
    with AutomaticKeepAliveClientMixin {
  late VideoPlayerController controller;
  bool isMuted = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // networkUrl instead of deprecated network()
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        controller.setLooping(true);
        controller.setVolume(0);
        controller.play();
        // check mounted before calling setState after async gap
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  /// Toggle between play and pause
  void togglePlay() {
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  /// Toggle between muted and unmuted
  void toggleMute() {
    isMuted = !isMuted;
    controller.setVolume(isMuted ? 0 : 1);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (!controller.value.isInitialized) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // FittedBox fills the container with no black bars
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),

          // Play icon overlay when paused
          if (!controller.value.isPlaying)
            const Icon(Icons.play_circle_outline, size: 70, color: Colors.white),

          // Mute/unmute toggle button
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: toggleMute,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================
// COMMENTS SHEET
// ================================

/// Bottom sheet for viewing and posting comments on a post
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;

  const _CommentsSheet({
    required this.postId,
    required this.scrollController,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final supabase = Supabase.instance.client;
  final TextEditingController commentController = TextEditingController();

  bool isSending = false;

  // ================================
  // SEND COMMENT
  // ================================
 Future<void> _sendComment() async {
  if (isSending) return;

  final text = commentController.text.trim();
  if (text.isEmpty) return;

  final user = supabase.auth.currentUser;
  if (user == null) return;

  setState(() => isSending = true);

  try {
    // ================= INSERT COMMENT =================
    await supabase.from('comments').insert({
      'post_id': widget.postId,
      'user_id': user.id,
      'text': text,
      'username': user.userMetadata?['username'] ?? 'User',
      'avatar_url': user.userMetadata?['avatar_url'] ?? '',
      'created_at': DateTime.now().toIso8601String(),
    });

    // ================= GET POST OWNER =================
    final postData = await supabase
        .from('posts')
        .select('user_id')
        .eq('id', widget.postId)
        .single();

    final postOwnerId = postData['user_id'];

    // ================= SEND NOTIFICATION =================
    if (postOwnerId != user.id) {
      await supabase.from('notifications').insert({
        'receiver_id': postOwnerId,
        'sender_id': user.id,
        'type': 'comment',
        'post_id': widget.postId,
        'is_read': false, // 🔥 IMPORTANT
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // ================= CLEAN =================
    commentController.clear();

  } catch (e) {
    debugPrint('Comment error: $e');
  }

  setState(() => isSending = false);
}

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag handle indicator
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const Text(
          'Comments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        // Real-time comments list
        Expanded(
          child: StreamBuilder(
            stream: supabase
                .from('comments')
                .stream(primaryKey: ['id'])
                .eq('post_id', widget.postId)
                .order('created_at'),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final comments = snapshot.data as List;

              if (comments.isEmpty) {
                return const Center(
                  child: Text(
                    'No comments yet',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return ListView.builder(
                controller: widget.scrollController,
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(
                      comment['text'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Comment input row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const CircleAvatar(radius: 16),
              const SizedBox(width: 10),

              Expanded(
                child: TextField(
                  controller: commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                ),
              ),

              isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton(
                      onPressed: _sendComment,
                      child: const Text('Post'),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}