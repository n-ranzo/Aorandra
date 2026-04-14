import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aorandra/features/profile/ui/profile_screen.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final ScrollController scrollController;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.scrollController,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController controller = TextEditingController();

  List comments = [];
  bool isSending = false;
  String myAvatar = "";

  String? replyingToCommentId;
  String? replyingToUsername;

  Map<String, bool> expandedReplies = {};

  String formatCommentTime(String? createdAt) {
  if (createdAt == null) return "now";

  final time = DateTime.parse(createdAt).toLocal();
  final diff = DateTime.now().difference(time);

  if (diff.inSeconds <= 0) return "now";
  if (diff.inSeconds < 60) return "${diff.inSeconds}s";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m";
  if (diff.inHours < 24) return "${diff.inHours}h";
  if (diff.inDays < 7) return "${diff.inDays}d";

  return "${time.day}/${time.month}";
}

  @override
  void initState() {
    super.initState();
    loadComments();
    loadMyAvatar();
  }

 void replyToComment(
  String commentId,
  String username,
) {
  setState(() {
    replyingToCommentId = commentId;
    replyingToUsername = username;
  });

  controller.text = "@$username ";
  controller.selection = TextSelection.fromPosition(
    TextPosition(
      offset: controller.text.length,
    ),
  );
}

  // ======================
  // LOAD COMMENTS
  // ======================
 Future<void> loadComments() async {
  try {
    final data = await supabase
        .from("comments")
        .select()
        .eq("post_id", widget.postId)
        .order("created_at", ascending: true);

    if (mounted) {
      setState(() {
        comments = data;
      });
    }
  } catch (e) {
    debugPrint("LOAD ERROR: $e");
  }
}

  // ======================
  // LOAD MY AVATAR
  // ======================
  Future<void> loadMyAvatar() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final data = await supabase
          .from("users")
          .select("image")
          .eq("id", user.id)
          .single();

      if (mounted) {
        setState(() {
          myAvatar = data["image"] ?? '';
        });
      }
    } catch (e) {
      debugPrint("AVATAR ERROR: $e");
    }
  }

  // ======================
  // SEND COMMENT
  // ======================
  Future<void> sendComment() async {
  if (isSending) return;

  final text = controller.text.trim();
  if (text.isEmpty) return;

  final user = supabase.auth.currentUser;
  if (user == null) return;

  setState(() => isSending = true);

  try {
    final userData = await supabase
        .from("users")
        .select("username")
        .eq("id", user.id)
        .single();

    await supabase.from("comments").insert({
      "post_id": widget.postId,
      "user_id": user.id,
      "username": userData["username"],
      "content": text,
      "parent_comment_id": replyingToCommentId,
    });

    controller.clear();

    setState(() {
      replyingToCommentId = null;
      replyingToUsername = null;
    });

    await loadComments();

    final allComments = await supabase
        .from("comments")
        .select()
        .eq("post_id", widget.postId);

    await supabase
        .from("aoras")
        .update({
          "comments": allComments.length,
        })
        .eq("id", widget.postId);
  } catch (e) {
    debugPrint("SEND ERROR: $e");
  } finally {
    if (mounted) {
      setState(() => isSending = false);
    }
  }
}

  // ======================
  // DELETE COMMENT
  // ======================
  Future<void> deleteComment(String commentId) async {
    try {
      await supabase
          .from("comments")
          .delete()
          .eq("id", commentId);

      await loadComments();

      final allComments = await supabase
          .from("comments")
          .select()
          .eq("post_id", widget.postId);

      await supabase
          .from("posts")
          .update({
            "comments": allComments.length,
          })
          .eq("id", widget.postId);
    } catch (e) {
      debugPrint("DELETE ERROR: $e");
    }
  }

  // ======================
  // LIKE COMMENT
  // ======================
  Future<void> likeComment(String commentId) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final comment = comments.firstWhere(
        (c) => c["id"] == commentId,
      );

      List likedBy = List.from(
        comment["liked_by"] ?? [],
      );

      List dislikedBy = List.from(
        comment["disliked_by"] ?? [],
      );

      if (likedBy.contains(currentUser.id)) {
        likedBy.remove(currentUser.id);
      } else {
        likedBy.add(currentUser.id);
        dislikedBy.remove(currentUser.id);
      }

      await supabase
          .from("comments")
          .update({
            "liked_by": likedBy,
            "disliked_by": dislikedBy,
            "likes_count": likedBy.length,
            "dislikes_count": dislikedBy.length,
          })
          .eq("id", commentId);

      await loadComments();
    } catch (e) {
      debugPrint("LIKE COMMENT ERROR: $e");
    }
  }

  // ======================
  // DISLIKE COMMENT
  // ======================
  Future<void> dislikeComment(String commentId) async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      final comment = comments.firstWhere(
        (c) => c["id"] == commentId,
      );

      List likedBy = List.from(
        comment["liked_by"] ?? [],
      );

      List dislikedBy = List.from(
        comment["disliked_by"] ?? [],
      );

      if (dislikedBy.contains(currentUser.id)) {
        dislikedBy.remove(currentUser.id);
      } else {
        dislikedBy.add(currentUser.id);
        likedBy.remove(currentUser.id);
      }

      await supabase
          .from("comments")
          .update({
            "liked_by": likedBy,
            "disliked_by": dislikedBy,
            "likes_count": likedBy.length,
            "dislikes_count": dislikedBy.length,
          })
          .eq("id", commentId);

      await loadComments();
    } catch (e) {
      debugPrint("DISLIKE COMMENT ERROR: $e");
    }
  }

  // ======================
// EDIT COMMENT
// ======================
Future<void> editComment(
  String commentId,
  String oldText,
) async {
  controller.text = oldText;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: "Edit comment...",
                  hintStyle: const TextStyle(
                    color: Colors.white38,
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final newText = controller.text.trim();
                if (newText.isEmpty) return;

                await supabase
                    .from("comments")
                    .update({
                      "content": newText,
                    })
                    .eq("id", commentId);

                controller.clear();
                Navigator.pop(context);
                await loadComments();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // ======================
  // UI
  // ======================
@override
Widget build(BuildContext context) {
  return Container(
    decoration: const BoxDecoration(
      color: Color(0xFF121212),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    child: Column(
      children: [
        // HEADER
        Padding(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 5,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Comments",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // COMMENTS LIST
        Expanded(
          child: comments.isEmpty
              ? const Center(
                  child: Text(
                    "No comments yet",
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index];

                    final replies = comments.where(
                      (item) =>
                          item["parent_comment_id"] == c["id"],
                    ).toList();

                    if (c["parent_comment_id"] != null) {
                      return const SizedBox();
                    }

                    final currentUserId =
                        supabase.auth.currentUser?.id;

                    final likedBy =
                        List.from(c["liked_by"] ?? []);

                    final dislikedBy =
                        List.from(c["disliked_by"] ?? []);

                    final isLiked =
                        likedBy.contains(currentUserId);

                    final isDisliked =
                        dislikedBy.contains(currentUserId);

                    return FutureBuilder(
                      future: supabase
                          .from("users")
                          .select("image")
                          .eq("id", c["user_id"])
                          .single(),
                      builder: (context, snapshot) {
                        String avatarUrl = "";

                        if (snapshot.hasData) {
                          avatarUrl =
                              snapshot.data?["image"] ?? "";
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: GestureDetector(
                            onLongPress: () {
                              final currentUserId =
                                  supabase.auth.currentUser?.id;

                              if (currentUserId == c["user_id"]) {
                                showDialog(
                                  context: context,
                                  barrierColor:
                                      Colors.transparent,
                                  builder: (_) {
                                    return Stack(
                                      children: [
                                        Positioned(
                                          left: 75,
                                          top: 250 + (index * 58),
                                          child: Material(
                                            color:
                                                Colors.transparent,
                                            child: Container(
                                              width: 170,
                                              decoration:
                                                  BoxDecoration(
                                                color: Colors.black
                                                    .withValues(
                                                  alpha: 0.82,
                                                ),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  18,
                                                ),
                                                border:
                                                    Border.all(
                                                  color:
                                                      Colors.white
                                                          .withValues(
                                                    alpha: 0.10,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  InkWell(
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                      top:
                                                          Radius.circular(
                                                        18,
                                                      ),
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(
                                                        context,
                                                      );

                                                      editComment(
                                                        c["id"],
                                                        c["content"] ??
                                                            "",
                                                      );
                                                    },
                                                    child:
                                                        const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal:
                                                            16,
                                                        vertical:
                                                            14,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .edit_outlined,
                                                            color:
                                                                Colors.white,
                                                            size:
                                                                22,
                                                          ),
                                                          SizedBox(
                                                            width:
                                                                10,
                                                          ),
                                                          Text(
                                                            "Edit",
                                                            style:
                                                                TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize:
                                                                  15,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () {
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text: c["content"] ??
                                                              "",
                                                        ),
                                                      );
                                                      Navigator.pop(
                                                        context,
                                                      );
                                                    },
                                                    child:
                                                        const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal:
                                                            16,
                                                        vertical:
                                                            14,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .copy_outlined,
                                                            color:
                                                                Colors.white,
                                                            size:
                                                                22,
                                                          ),
                                                          SizedBox(
                                                            width:
                                                                10,
                                                          ),
                                                          Text(
                                                            "Copy",
                                                            style:
                                                                TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize:
                                                                  15,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                      bottom:
                                                          Radius.circular(
                                                        18,
                                                      ),
                                                    ),
                                                    onTap:
                                                        () async {
                                                      Navigator.pop(
                                                        context,
                                                      );
                                                      await deleteComment(
                                                        c["id"],
                                                      );
                                                    },
                                                    child:
                                                        const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal:
                                                            16,
                                                        vertical:
                                                            14,
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .delete_outline,
                                                            color:
                                                                Colors.red,
                                                            size:
                                                                22,
                                                          ),
                                                          SizedBox(
                                                            width:
                                                                10,
                                                          ),
                                                          Text(
                                                            "Delete",
                                                            style:
                                                                TextStyle(
                                                              color:
                                                                  Colors.red,
                                                              fontSize:
                                                                  15,
                                                              fontWeight:
                                                                  FontWeight.w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              }
                            },
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProfileScreen(
                                          userId: c["user_id"],
                                          username:
                                              c["username"] ?? "user",
                                        ),
                                      ),
                                    );
                                  },
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        Colors.white12,
                                    backgroundImage:
                                        avatarUrl.isNotEmpty
                                            ? NetworkImage(
                                                avatarUrl,
                                              )
                                            : null,
                                    child: avatarUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 18,
                                            color:
                                                Colors.white,
                                          )
                                        : null,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      ProfileScreen(
                                                    userId:
                                                        c["user_id"],
                                                    username:
                                                        c["username"] ??
                                                            "user",
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              c["username"] ??
                                                  "user",
                                              style:
                                                  const TextStyle(
                                                color:
                                                    Colors.white,
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 8,
                                          ),
                                          Text(
                                            formatCommentTime(
                                              c["created_at"],
                                            ),
                                            style:
                                                TextStyle(
                                              color: Colors.white
                                                  .withValues(
                                                alpha: 0.45,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(
                                        height: 6,
                                      ),

                                      Text(
                                        c["content"] ?? "",
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.white,
                                          fontSize: 14,
                                          height: 1.35,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 10,
                                      ),

                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              likeComment(
                                                c["id"],
                                              );
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isLiked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  size: 15,
                                                  color: isLiked
                                                      ? Colors.red
                                                      : Colors.white
                                                          .withValues(
                                                        alpha: 0.65,
                                                      ),
                                                ),
                                                const SizedBox(
                                                  width: 4,
                                                ),
                                                Text(
                                                  "${c["likes_count"] ?? 0}",
                                                  style:
                                                      TextStyle(
                                                    color: isLiked
                                                        ? Colors.red
                                                        : Colors.white
                                                            .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(
                                            width: 18,
                                          ),

                                          GestureDetector(
                                            onTap: () {
                                              dislikeComment(
                                                c["id"],
                                              );
                                            },
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons
                                                      .thumb_down_alt_outlined,
                                                  size: 15,
                                                  color: isDisliked
                                                      ? Colors.blueGrey
                                                      : Colors.white
                                                          .withValues(
                                                        alpha: 0.65,
                                                      ),
                                                ),
                                                const SizedBox(
                                                  width: 4,
                                                ),
                                                Text(
                                                  "${c["dislikes_count"] ?? 0}",
                                                  style:
                                                      TextStyle(
                                                    color: isDisliked
                                                        ? Colors.blueGrey
                                                        : Colors.white
                                                            .withValues(
                                                          alpha: 0.55,
                                                        ),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(
                                        height: 8,
                                      ),

                                      GestureDetector(
                                        onTap: () {
                                          replyToComment(
                                            c["id"],
                                            c["username"] ??
                                                "user",
                                          );
                                        },
                                        child: Text(
                                          "Reply",
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(
                                              alpha: 0.60,
                                            ),
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                      if (replies.isNotEmpty) ...[
                                        const SizedBox(height: 8),

                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              expandedReplies[c["id"]] =
                                                  !(expandedReplies[
                                                          c["id"]] ??
                                                      false);
                                            });
                                          },
                                          child: Text(
                                            expandedReplies[c["id"]] ??
                                                    false
                                                ? "Hide replies"
                                                : "View ${replies.length} replies",
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(
                                                alpha: 0.55,
                                              ),
                                              fontSize: 12,
                                              fontWeight:
                                                  FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                        if (expandedReplies[c["id"]] ??
                                            false)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(
                                              left: 35,
                                              top: 12,
                                            ),
                                            child: Column(
                                              children: replies
                                                  .map((reply) {
                                                return FutureBuilder(
                                                  future: supabase
                                                      .from("users")
                                                      .select(
                                                          "image, username")
                                                      .eq(
                                                        "id",
                                                        reply["user_id"],
                                                      )
                                                      .single(),
                                                  builder: (
                                                    context,
                                                    replySnap,
                                                  ) {
                                                    String replyAvatar =
                                                        "";
                                                    String replyUsername =
                                                        reply["username"] ??
                                                            "user";

                                                    if (replySnap
                                                        .hasData) {
                                                      replyAvatar =
                                                          replySnap.data?[
                                                                  "image"] ??
                                                              "";
                                                      replyUsername =
                                                          replySnap.data?[
                                                                  "username"] ??
                                                              replyUsername;
                                                    }

                                                    final replyLiked =
                                                        List.from(
                                                      reply["liked_by"] ??
                                                          [],
                                                    ).contains(
                                                      currentUserId,
                                                    );

                                                    final replyDisliked =
                                                        List.from(
                                                      reply["disliked_by"] ??
                                                          [],
                                                    ).contains(
                                                      currentUserId,
                                                    );

                                                    return Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                        bottom: 14,
                                                      ),
                                                      child: Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          GestureDetector(
                                                            onTap: () {
                                                              Navigator.push(
                                                                context,
                                                                MaterialPageRoute(
                                                                  builder:
                                                                      (_) =>
                                                                          ProfileScreen(
                                                                    userId: reply[
                                                                        "user_id"],
                                                                    username:
                                                                        replyUsername,
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            child:
                                                                CircleAvatar(
                                                              radius: 14,
                                                              backgroundColor:
                                                                  Colors
                                                                      .white12,
                                                              backgroundImage:
                                                                  replyAvatar
                                                                          .isNotEmpty
                                                                      ? NetworkImage(
                                                                          replyAvatar,
                                                                        )
                                                                      : null,
                                                              child: replyAvatar
                                                                      .isEmpty
                                                                  ? const Icon(
                                                                      Icons
                                                                          .person,
                                                                      size:
                                                                          12,
                                                                      color: Colors
                                                                          .white,
                                                                    )
                                                                  : null,
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                            width: 10,
                                                          ),

                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                GestureDetector(
                                                                  onTap:
                                                                      () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (_) =>
                                                                                ProfileScreen(
                                                                          userId:
                                                                              reply["user_id"],
                                                                          username:
                                                                              replyUsername,
                                                                        ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  child:
                                                                      Text(
                                                                    replyUsername,
                                                                    style:
                                                                        const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontWeight:
                                                                          FontWeight.bold,
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                                ),

                                                                const SizedBox(
                                                                  height:
                                                                      4,
                                                                ),

                                                                Text(
                                                                  reply["content"] ??
                                                                      "",
                                                                  style:
                                                                      const TextStyle(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                                ),

                                                                const SizedBox(
                                                                  height:
                                                                      8,
                                                                ),

                                                                Row(
                                                                  children: [
                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        likeComment(
                                                                          reply["id"],
                                                                        );
                                                                      },
                                                                      child:
                                                                          Row(
                                                                        children: [
                                                                          Icon(
                                                                            replyLiked
                                                                                ? Icons.favorite
                                                                                : Icons.favorite_border,
                                                                            size:
                                                                                14,
                                                                            color: replyLiked
                                                                                ? Colors.red
                                                                                : Colors.white54,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            "${reply["likes_count"] ?? 0}",
                                                                            style:
                                                                                const TextStyle(
                                                                              color: Colors.white54,
                                                                              fontSize: 10,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),

                                                                    const SizedBox(
                                                                      width:
                                                                          14,
                                                                    ),

                                                                    GestureDetector(
                                                                      onTap:
                                                                          () {
                                                                        dislikeComment(
                                                                          reply["id"],
                                                                        );
                                                                      },
                                                                      child:
                                                                          Row(
                                                                        children: [
                                                                          Icon(
                                                                            Icons.thumb_down_alt_outlined,
                                                                            size:
                                                                                14,
                                                                            color: replyDisliked
                                                                                ? Colors.blueGrey
                                                                                : Colors.white54,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            "${reply["dislikes_count"] ?? 0}",
                                                                            style:
                                                                                const TextStyle(
                                                                              color: Colors.white54,
                                                                              fontSize: 10,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),

        // INPUT BAR
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              10,
              5,
              10,
              10,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      myAvatar.isNotEmpty
                          ? NetworkImage(myAvatar)
                          : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                    onSubmitted: (_) =>
                        sendComment(),
                    decoration: InputDecoration(
                      hintText:
                          "Add a comment...",
                      hintStyle:
                          const TextStyle(
                        color: Colors.white38,
                      ),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(
                          25,
                        ),
                        borderSide:
                            BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap:
                      isSending ? null : sendComment,
                  child: Container(
                    padding:
                        const EdgeInsets.all(10),
                    decoration:
                        const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                            color: Colors.black,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}