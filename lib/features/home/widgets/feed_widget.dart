import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aorandra/features/home/logic/home_controller.dart';
import 'package:aorandra/shared/services/user_manager.dart';

/// =============================================
/// FEED WIDGET
/// Displays list of posts (like Instagram/TikTok feed)
/// Handles UI only (no business logic)
/// =============================================
class FeedWidget extends StatelessWidget {
  // ================= DATA =================
  final Future<List<dynamic>> postsFuture;
  final ScrollController scrollController;

  // ================= STATE =================
  final Map<String, bool> likedPosts;
  final Map<String, bool> savePosts;
  final Map<String, int> likesCount;
  final Map<String, int> commentsCount;

  // ================= PAGE CONTROL =================
  final Map<String, PageController> pageControllers;
  final Map<String, ValueNotifier<int>> pageIndexes;

  // ================= ACTIONS =================
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadComments;

  final Function(String postId, int currentLikes) onLike;
  final Function(String postId) onSave;
  final Function(String postId) onOpenComments;
  final Function(Map post) onShare;
  final Function(String username, String userId) onOpenProfile;

  /// NEW: open post menu (3 dots)
  final Function(String postId, String userId, String caption) onOpenMenu;
  final Future<int> Function(String postId) getSharesCount;

  // ================= UTIL =================
  final String Function(String?) formatTime;

  const FeedWidget({
    super.key,
    required this.postsFuture,
    required this.scrollController,
    required this.likedPosts,
    required this.savePosts,
    required this.likesCount,
    required this.commentsCount,
    required this.pageControllers,
    required this.pageIndexes,
    required this.onRefresh,
    required this.onLoadComments,
    required this.onLike,
    required this.onSave,
    required this.onOpenComments,
    required this.onShare,
    required this.onOpenProfile,
    required this.onOpenMenu,
    required this.formatTime,
    required this.getSharesCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Positioned.fill(
      child: FutureBuilder<List<dynamic>>(
        future: postsFuture,
        builder: (context, snapshot) {
          // ================= LOADING STATE =================
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ================= ERROR STATE =================
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading feed'));
          }

          final posts = snapshot.data ?? [];

          // ================= EMPTY STATE =================
          if (posts.isEmpty) {
            return const Center(child: Text("No posts"));
          }

          // ================= LAYOUT CALCULATIONS =================
          final width = MediaQuery.of(context).size.width;
          final height = width / (4 / 5); // aspect ratio 4:5

          return RefreshIndicator(
            onRefresh: onRefresh,
            color: Colors.white,
            backgroundColor: Colors.black,
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.only(
                top: HomeController.headerTop + 80,
                bottom: 120,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];

                // ================= REAL-TIME DATA MAPPING =================
                // We fetch user data from the linked 'profiles' table in the query
                final userId = post['user_id']?.toString() ?? '';
                final postId = post['id']?.toString() ?? '';


                final profile = post['profiles'];

               final username = profile?['username'] ?? 'User';
               final avatar = profile?['avatar_url'] ?? '';
                

                // Skip invalid posts
                if (userId.isEmpty || postId.isEmpty) {
                  return const SizedBox.shrink();
                }

                // Media list (images/videos)
                final mediaList = post['media_urls'] ?? [];

                // Page controller per post (for swipe media)
                final controller = pageControllers.putIfAbsent(
                  postId,
                  () => PageController(),
                );

                // Track current page index
                final currentPage = pageIndexes.putIfAbsent(
                  postId,
                  () => ValueNotifier<int>(0),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= HEADER =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          /// User avatar - Now connected to the smart UserAvatar widget
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: theme.dividerColor.withOpacity(0.2),
                            backgroundImage: avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : null,
                          ),
                           

                          const SizedBox(width: 10),

                          /// Username (clickable) - Using real-time data from profile join
                          GestureDetector(
                            onTap: () => onOpenProfile(username, userId),
                            child: Text(
                              username,
                              style: TextStyle(
                                color: theme.textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const Spacer(),

                          /// Post menu (3 dots)
                          IconButton(
                            icon: Icon(Icons.more_horiz,
                                color: theme.iconTheme.color),
                            onPressed: () => onOpenMenu(
                              postId,
                              userId,
                              post['caption'] ?? '',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ================= MEDIA =================
                    SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        children: [
                          /// Swipeable media (images/videos)
                          PageView.builder(
                            controller: controller,
                            itemCount: mediaList.length,
                            onPageChanged: (i) => currentPage.value = i,
                            itemBuilder: (context, i) {
                              return CachedNetworkImage(
                                imageUrl: mediaList[i],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.black12),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              );
                            },
                          ),

                          /// Page indicator (top right)
                          if (mediaList.length > 1)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: ValueListenableBuilder<int>(
                                valueListenable: currentPage,
                                builder: (_, page, __) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${page + 1}/${mediaList.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ================= ACTIONS =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          /// LIKE BUTTON
                          GestureDetector(
                            onTap: () => onLike(
                              postId,
                              likesCount[postId] ?? post['likes'] ?? 0,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  likedPosts[postId] == true
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: likedPosts[postId] == true
                                      ? Colors.red
                                      : theme.iconTheme.color,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${likesCount[postId] ?? post['likes'] ?? 0}',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14),

                          /// COMMENT BUTTON
                          GestureDetector(
                            onTap: () async {
                              await onOpenComments(postId);
                              onLoadComments();
                            },
                            child: Row(
                              children: [
                                Icon(Icons.mode_comment_outlined,
                                    color: theme.iconTheme.color),
                                const SizedBox(width: 5),
                                Text(
                                  '${commentsCount[postId] ?? 0}',
                                  style: TextStyle(
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14),

                          /// SHARE BUTTON
                          GestureDetector(
                            onTap: () => onShare(post),
                            child: Row(
                              children: [
                                Icon(Icons.send, color: theme.iconTheme.color),
                                const SizedBox(width: 5),
                                FutureBuilder<int>(
                                  future: getSharesCount(postId),
                                  builder: (context, snapshot) {
                                    return Text(
                                      '${snapshot.data ?? 0}',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyMedium?.color,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          /// SAVE BUTTON
                          GestureDetector(
                            onTap: () => onSave(postId),
                            child: Icon(
                              savePosts[postId] == true
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: theme.iconTheme.color,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ================= LIKES COUNT =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${likesCount[postId] ?? post['likes'] ?? 0} likes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),

                    // ================= CAPTION =================
                    if ((post['caption'] ?? '').toString().trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: RichText(
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$username ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                              TextSpan(
                                text: post['caption'],
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 4),

                    // ================= TIME =================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        formatTime(post['created_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}