import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/models.dart';
import '../feed/feed_service.dart';
import 'video_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _feedService = FeedService();
  final _pageController = PageController();
  final List<VideoPost> _posts = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_pageController.position.pixels >=
        _pageController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    try {
      final posts = await _feedService.fetchVideos();
      if (mounted) setState(() {
        _posts.addAll(posts);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _posts.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await _feedService.fetchVideos(offset: _posts.length);
      if (mounted) setState(() => _posts.addAll(more));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_posts.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.video_library_outlined, size: 64, color: AppColors.textSecondary),
              SizedBox(height: 16),
              Text(
                'لا توجد فيديوهات بعد',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'كن أول من يشارك فيديو!',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'VideoApp',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _posts.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) => VideoCard(
          post: _posts[index],
          isActive: index == _currentIndex,
        ),
      ),
    );
  }
}
