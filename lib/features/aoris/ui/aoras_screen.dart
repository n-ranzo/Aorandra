// lib/screens/aoras/aoras_screen.dart

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'widgets/video_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aorandra/features/comments/ui/comments_screen.dart';



// ================================
// AORAS SCREEN
// ================================

/// AorasScreen - Vertical video feed interface (TikTok/Reels style)
/// 
/// Features:
/// - Vertical PageView for video swiping
/// - Floating action buttons with animation
/// - Rotating music vinyl indicator
/// - Glassmorphism UI elements
/// - Gradient overlays for text readability
class AorasScreen extends StatefulWidget {
  final List<String> videos;

  final Function(Map videos) onShare;

  const AorasScreen({



    super.key,
    required this.videos,
    required this.onShare,
  });

  @override
  State<AorasScreen> createState() => _AorasScreenState();
}

class _AorasScreenState extends State<AorasScreen>
    with TickerProviderStateMixin {
  // ================================
  // CONTROLLERS & STATE
  // ================================

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late final AnimationController _floatingController;
  late final AnimationController _vinylController;

  Set<String> likedVideos = {};
   Set<String> saveedVideo = {};
    Set<String> followingUsers = {};

    List<Map<String, dynamic>> videos = [];
    bool isLoading = true;

    

// ================================
  // LIFECYCLE METHODS
  // ================================

    Future<void> refreshFeed() async {
  setState(() {
    isLoading = true;
  });

  await loadVideos();
}

Future<void> _openComments(Map video) async {
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
            postId: video['id'],
            scrollController: scrollController,
          );
        },
      );
    },
  );
}

Future<void> loadVideos() async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;

  final videoData = await supabase
      .from('aoras')
      .select()
      .order('created_at', ascending: false);

  final likesData = await supabase
      .from('likes')
      .select('post_id')
      .eq('user_id', userId);

  final likedIds = likesData
      .map<String>((e) => e['post_id'].toString())
      .toSet();

  // 🔥 احسب اللايكات لكل فيديو
  for (var video in videoData) {
    final count = await supabase
        .from('likes')
        .select()
        .eq('post_id', video['id']);

    video['likes_count'] = count.length;
  }

  setState(() {
    videos = List<Map<String, dynamic>>.from(videoData);
    likedVideos = likedIds;
    isLoading = false;
  });
}

Future<void> _toggleLike(Map video) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser!.id;

  final String videoId = video['id'];
  final bool isLiked = likedVideos.contains(videoId);

  // 🔥 UI + COUNT (instant مثل انستا)
  setState(() {
    if (isLiked) {
      likedVideos.remove(videoId);
      video['likes_count'] = (video['likes_count'] ?? 0) - 1;
    } else {
      likedVideos.add(videoId);
      video['likes_count'] = (video['likes_count'] ?? 0) + 1;
    }
  });

  try {
    if (isLiked) {
      await supabase
          .from('likes')
          .delete()
          .eq('post_id', videoId)
          .eq('user_id', userId);

      await supabase
          .from('aoras')
          .update({
            'likes_count': video['likes_count'],
          })
          .eq('id', videoId);

    } else {
      await supabase.from('likes').insert({
        'post_id': videoId,
        'user_id': userId,
      });

      await supabase
          .from('aoras')
          .update({
            'likes_count': video['likes_count'],
          })
          .eq('id', videoId);
    }

  } catch (e) {
    print("LIKE ERROR: $e");
  }
}

Future<int> getSharesCount(String videoId) async {
  final supabase = Supabase.instance.client;

  final data = await supabase
      .from('messages')
      .select('id')
      .eq('post_id', videoId);

  return data.length;
}


  // ================================
  // LIFECYCLE METHODS
  // ================================



  @override
void initState() {
  super.initState();

  _floatingController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  _vinylController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  loadVideos(); // 🔥 مهم
}



  @override
  void dispose() {
    _pageController.dispose();
    _floatingController.dispose();
    _vinylController.dispose();
    super.dispose();
  }

void _toggleSave(String videoId) {
  setState(() {
    if (saveedVideo.contains(videoId)) {
      saveedVideo.remove(videoId);
    } else {
      saveedVideo.add(videoId);
    }
  });
}

void _repost(Map video) {
  print("Repost ${video['id']}");
}
  


  // ================================
  // MAIN BUILD METHOD
  // ================================

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [

        // ================= DATA =================
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(),
          )
        else if (videos.isEmpty)
          const Center(
            child: Text(
              "No videos yet",
              style: TextStyle(color: Colors.white),
            ),
          )
        else
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final video = videos[index];

              return Stack(
                children: [
                  VideoItem(
                    file: video['video_url'],
                    isActive: index == _currentIndex,
                  ),

                  const _TopGradientOverlay(),
                  const _BottomGradientOverlay(),

                  _buildRightActions(video),
                  _buildBottomInfo(video),
                  _buildMusicVinyl(video),
                ],
              );
            },
          ),

        // ================= TOP BAR =================
        _buildTopBar(),
      ],
    ),
  );
}

  // ================================
  // UI BUILDERS - TOP BAR
  // ================================

 Widget _buildTopBar() {
  return Positioned(
    top: MediaQuery.of(context).padding.top + 8,
    left: 16,
    right: 16,
    child: Row(
      children: [

        // 🔥 REFRESH BUTTON (LEFT)
        GestureDetector(
          onTap: refreshFeed,
          child: const Icon(
            Icons.refresh,
            color: Colors.white,
            size: 26,
          ),
        ),

        const Spacer(),

        // Title
        const Text(
          "Aoras",
          style: TextStyle(
            fontFamily: "PacificoFont",
            color: Colors.white,
            fontSize: 20,
          ),
        ),

        const Spacer(),

        // ⚙️ SETTINGS
        GestureDetector(
          onTap: () {},
          child: const Icon(
            Icons.tune_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ],
    ),
  );
}

  // ================================
  // UI BUILDERS - RIGHT ACTIONS
  // ================================

Widget _buildRightActions(Map video) {
  final String videoId = video['id'];

  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser!.id;

  final isMe = video['user_id'] == currentUserId;

  final int likesCount = video['likes_count'] ?? 0;
  final bool isLiked = likedVideos.contains(videoId);

  return Positioned(
    right: 10,
    bottom: 120,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ================= ❤️ LIKE =================
        GestureDetector(
          onTap: () => _toggleLike(video),
          child: Column(
            children: [
              Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.white,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                "$likesCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ================= 💬 COMMENTS =================
        GestureDetector(
          onTap: () => _openComments(video),
          child: Column(
            children: [
              const Icon(
                Icons.mode_comment_outlined,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(height: 4),

              FutureBuilder(
                future: supabase
                    .from("comments")
                    .select()
                    .eq("post_id", videoId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text(
                      "0",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    );
                  }

                  final count = (snapshot.data as List).length;

                  return Text(
                    "$count",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ================= 🔁 REPOST =================
        if (!isMe) ...[
          GestureDetector(
            onTap: () => _repost(video),
            child: Column(
              children: [
                const Icon(
                  Icons.repeat,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  "${video['reposts_count'] ?? 0}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // ================= 📤 SHARE =================
        GestureDetector(
          onTap: () => widget.onShare(video),
          child: Column(
            children: [
              const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 26,
             ),

             const SizedBox(height: 4),

             FutureBuilder<int>(
               future: getSharesCount(video['id']),
               builder: (context, snapshot) {
                 final shares = snapshot.data ?? 0;

                 return Text(
                   "$shares",
                   style: const TextStyle(
                     color: Colors.white,
                     fontSize: 11,
                   ),
                 );
               },
             ),
          ],
        ),
       ),

        const SizedBox(height: 14),

        // ================= SAVE =================
        GestureDetector(
          onTap: () => _toggleSave(videoId),
          child: Column(
            children: [
              Icon(
                saveedVideo.contains(videoId)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: saveedVideo.contains(videoId)
                    ? const Color.fromARGB(255, 155, 7, 39) 
                   : Colors.white,
                size: 26,
              ),
           ],
         ),
       ),
      ],
    ),
  );
}



  // ================================
  // UI BUILDERS - BOTTOM INFO
  // ================================

 Widget _buildBottomInfo(Map video) {
  final supabase = Supabase.instance.client;

  final currentUserId = supabase.auth.currentUser!.id;
  final isMe = video['user_id'] == currentUserId;

  return Positioned(
    left: 16,
    right: 88,
    bottom: 56,
    child: FutureBuilder(
      future: supabase
          .from('profiles') // 🔥 FIX
          .select('username, avatar_url') // 🔥 FIX
          .eq('id', video['user_id'])
          .maybeSingle(), // 🔥 مهم بدل single
      builder: (context, snapshot) {
        String username = "User";
        String? avatar;

        if (snapshot.hasData && snapshot.data != null) {
          final data = snapshot.data as Map;
          username = data['username'] ?? "User";
          avatar = data['avatar_url'];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= USER =================
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.8),
                      width: 1.2,
                    ),
                    image: avatar != null && avatar.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(avatar),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatar == null || avatar.isEmpty
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                isMe
                    ? const SizedBox(width: 70)
                    : _glassFollowButton(video['user_id']),
              ],
            ),

            const SizedBox(height: 12),

            // ================= DESCRIPTION =================
            Text(
              video['description'] ?? "",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    ),
  );
}
  // ================================
  // UI BUILDERS - MUSIC VINYL
  // ================================

 Widget _buildMusicVinyl(Map video) {
  final String? musicImage = video['music_image'];

  return Positioned(
    right: 16,
    bottom: 40, 
    child: GestureDetector(
      onTap: () {},
      child: SizedBox(
        width: 60, 
        height: 60,
        child: AnimatedBuilder(
          animation: _vinylController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _vinylController.value * math.pi * 2,
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Vinyl Base
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF232323),
                      Color(0xFF111111),
                      Colors.black,
                    ],
                  ),
                ),
              ),

              // Rings 
              ...List.generate(4, (i) {
                final size = 40.0 - (i * 6);
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                );
              }),

              // Music Image
              if (musicImage != null && musicImage.isNotEmpty)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(musicImage),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),

              // Center dot
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  // ================================
  // UI BUILDERS - HELPERS
  // ================================

  

  /// Glassmorphism Follow Button
  Widget _glassFollowButton(String userId) {
  final isFollowing = followingUsers.contains(userId);

  return GestureDetector(
    onTap: () {
      setState(() {
        if (isFollowing) {
          followingUsers.remove(userId);
        } else {
          followingUsers.add(userId);
        }
      });
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.30)),
          ),
          child: Text(
            isFollowing ? "Following" : "Follow",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}
  /// Glassmorphism Circle Button (Top Bar)
  Widget _glassCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

// ================================
// GRADIENT OVERLAYS
// ================================

/// Top gradient overlay for text readability
class _TopGradientOverlay extends StatelessWidget {
  const _TopGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 180,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}



/// Bottom gradient overlay for text readability
class _BottomGradientOverlay extends StatelessWidget {
  const _BottomGradientOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 240,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black87,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}