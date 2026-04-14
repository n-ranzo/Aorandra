import 'package:flutter/material.dart';
import 'like_button.dart';
import 'comments_button.dart';

class PostActions extends StatelessWidget {
  final bool isLiked;
  final int likesCount;

  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  const PostActions({
    super.key,
    required this.isLiked,
    required this.likesCount,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [

        // ❤️ LIKE
        LikeButton(
          isLiked: isLiked,
          likesCount: likesCount,
          onTap: onLike,
        ),

        const SizedBox(width: 15),

        // 💬 COMMENT
        CommentsButton(onTap: onComment),

        const SizedBox(width: 15),

        // 📤 SHARE
        GestureDetector(
          onTap: onShare,
          child: const Icon(Icons.send, color: Colors.white),
        ),

        const Spacer(),

        // 🔖 SAVE
        GestureDetector(
          onTap: onSave,
          child: const Icon(Icons.bookmark_border, color: Colors.white),
        ),
      ],
    );
  }
}