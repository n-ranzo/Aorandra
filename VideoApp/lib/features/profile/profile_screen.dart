import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/models.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = Supabase.instance.client;
  UserProfile? _profile;
  List<Map<String, dynamic>> _videos = [];
  bool _loading = true;

  String get _targetUserId => widget.userId ?? _db.auth.currentUser!.id;
  bool get _isOwnProfile => _targetUserId == _db.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profileData = await _db
          .from('profiles')
          .select()
          .eq('id', _targetUserId)
          .single();

      final videosData = await _db
          .from('videos')
          .select('id, thumbnail_url, video_url, likes_count')
          .eq('user_id', _targetUserId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _profile = UserProfile.fromJson(profileData);
          _videos = List<Map<String, dynamic>>.from(videosData);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _db.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_profile?.username ?? 'البروفايل'),
        actions: [
          if (_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: _signOut,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildProfileHeader()),
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildVideoThumb(_videos[index]),
                  childCount: _videos.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppColors.primary,
            backgroundImage: _profile?.avatarUrl != null
                ? CachedNetworkImageProvider(_profile!.avatarUrl!)
                : null,
            child: _profile?.avatarUrl == null
                ? Text(
                    _profile?.username.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            '@\${_profile?.username ?? ''}',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_profile?.bio != null && _profile!.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _profile!.bio!,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(_videos.length.toString(), 'فيديو'),
              _buildStatDivider(),
              _buildStat(_formatCount(_profile?.followersCount ?? 0), 'متابع'),
              _buildStatDivider(),
              _buildStat(_formatCount(_profile?.followingCount ?? 0), 'يتابع'),
            ],
          ),
          const SizedBox(height: 20),
          if (_isOwnProfile)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('تعديل البروفايل'),
              ),
            ),
          const SizedBox(height: 8),
          const Divider(color: AppColors.divider),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 30, color: AppColors.divider);
  }

  Widget _buildVideoThumb(Map<String, dynamic> video) {
    final thumbUrl = video['thumbnail_url'] as String?;
    return GestureDetector(
      onTap: () {},
      child: Stack(
        fit: StackFit.expand,
        children: [
          thumbUrl != null
              ? CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover)
              : Container(
                  color: AppColors.surface,
                  child: const Icon(Icons.play_circle_outline, color: AppColors.textSecondary),
                ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 12),
                const SizedBox(width: 2),
                Text(
                  _formatCount(video['likes_count'] ?? 0),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '\${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '\${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
