import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/app_colors.dart';
import '../../core/models.dart';

class CommentsSheet extends StatefulWidget {
  final String videoId;
  const CommentsSheet({super.key, required this.videoId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _db = Supabase.instance.client;
  final _commentController = TextEditingController();
  final List<Comment> _comments = [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final data = await _db
          .from('comments')
          .select('*, profiles(id, username, avatar_url)')
          .eq('video_id', widget.videoId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _comments.clear();
          _comments.addAll((data as List).map((e) => Comment.fromJson(e)));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _posting = true);
    try {
      final userId = _db.auth.currentUser!.id;
      await _db.from('comments').insert({
        'user_id': userId,
        'video_id': widget.videoId,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      });
      _commentController.clear();
      await _loadComments();
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'التعليقات',
            style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(color: AppColors.divider),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _comments.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد تعليقات بعد\nكن أول من يعلق!',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _comments.length,
                        itemBuilder: (_, i) => _buildCommentItem(_comments[i]),
                      ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: AppColors.text),
                    decoration: const InputDecoration(
                      hintText: 'أضف تعليقاً...',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _postComment(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _posting ? null : _postComment,
                  icon: _posting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final avatarUrl = comment.author?.avatarUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    comment.author?.username.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '@\${comment.author?.username ?? 'user'}',
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt, locale: 'ar'),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(color: AppColors.text, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
