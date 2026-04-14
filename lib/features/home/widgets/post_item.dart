import 'package:flutter/material.dart';
import 'post_header.dart';
import 'post_actions.dart';

class PostItem extends StatelessWidget {
  final String userId;
  final String username;
  final String imageUrl;

  final bool isLiked;
  final int likesCount;

  final VoidCallback onLike;

  const PostItem({
    super.key,
    required this.userId,
    required this.username,
    required this.imageUrl,
    required this.isLiked,
    required this.likesCount,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // HEADER
        PostHeader(
          userId: userId,
          username: username,
        ),

        const SizedBox(height: 10),

        // IMAGE
        Image.network(imageUrl),

        const SizedBox(height: 10),

        // ACTIONS
        PostActions(
          isLiked: isLiked,
          likesCount: likesCount,
          onLike: onLike,
          onComment: () {},
          onShare: () {},
          onSave: () {},
        ),
      ],
    );
  }
}