import 'package:flutter/material.dart';

class CommentsButton extends StatelessWidget {
  final VoidCallback onTap;

  const CommentsButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Icon(
        Icons.chat_bubble_outline,
        color: Colors.white,
      ),
    );
  }
}