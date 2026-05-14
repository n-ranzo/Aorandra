import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/models.dart';
import '../comments/comments_sheet.dart';
import '../feed/feed_service.dart';
import 'video_player_widget.dart';

class VideoCard extends StatefulWidget {
  final VideoPost post;
  final bool isActive;

  const VideoCard({super.key, required this.post, required this.isActive});

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  final _feedService = FeedService();
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
  }

  Future<void> _toggleLike() async {
    final previouslyLiked = _isLiked;
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await _feedService.toggleLike(widget.post.id, wasLiked: previouslyLiked);
    } catch (_) {
      // rollback on failure
      setState(() {
        _isLiked = previouslyLiked;
        _likesCount += previouslyLiked ? 1 : -1;
      });
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CommentsSheet(videoId: widget.post.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return SizedBox(
      width: screenSize.width,
      height: screenSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayerWidget(
            videoUrl: widget.post.videoUrl,
            isActive: widget.isActive,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.transparent, AppColors.overlay],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 80,
            bottom: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 10),
                    Text(
                      '@${widget.post.author?.username ?? 'user'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  widget.post.caption,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                _ActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? AppColors.primary : Colors.white,
                  label: _formatCount(_likesCount),
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.comment_outlined,
                  label: _formatCount(widget.post.commentsCount),
                  onTap: _openComments,
                ),
                const SizedBox(height: 20),
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'شارك',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = widget.post.author?.avatarUrl;
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary,
      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              widget.post.author?.username.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
