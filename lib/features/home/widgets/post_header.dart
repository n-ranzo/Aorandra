import 'package:flutter/material.dart';
import 'package:aorandra/shared/widgets/user_avatar.dart';

class PostHeader extends StatelessWidget {
  final String userId;
  final String username;

  const PostHeader({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(userId: userId),
        const SizedBox(width: 10),

        Expanded(
          child: Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const Icon(Icons.more_vert, color: Colors.white),
      ],
    );
  }
}