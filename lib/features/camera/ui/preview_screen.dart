import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../services/upload_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_screen.dart';

class PreviewScreen extends StatefulWidget {
  final List<File> videos;
  final String type; // "post" or "story"

  const PreviewScreen({
    super.key,
    required this.videos,
    required this.type,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _controller;
  int currentIndex = 0;
  bool isVideo = true;
  bool isLoading = false;

  // ============================
  // INIT
  // ============================

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  // ============================
  // LOAD MEDIA (IMAGE / VIDEO)
  // ============================

  void _loadMedia() {
    _controller?.dispose();

    final file = widget.videos[currentIndex];
    isVideo = file.path.endsWith(".mp4");

    if (isVideo) {
      _controller = VideoPlayerController.file(file)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _controller!.play();
            _controller!.setLooping(true);
          }
        });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ============================
  // CHANGE MEDIA
  // ============================

  void _changeMedia(int index) {
    setState(() {
      currentIndex = index;
    });
    _loadMedia();
  }

  // ============================
  // MEDIA VIEW (MAIN FIX)
  // ============================

  Widget _buildMedia() {
    final file = widget.videos[currentIndex];

    final media = isVideo
        ? (_controller != null && _controller!.value.isInitialized)
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
        : Image.file(
            file,
            fit: BoxFit.cover,
          );

    // ============================
    // POST MODE (4:5 + lifted up)
    // ============================
    if (widget.type == "post") {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 100), 
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: media,
            ),
          ),
        ),
      );
    }

    // ============================
    // STORY (FULLSCREEN)
    // ============================
    return Positioned.fill(child: media);
  }

  // ============================
  // UPLOAD
  // ============================
  
  // ignore: unused_element
  Future<void> _upload() async {
  setState(() => isLoading = true);

  try {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) throw Exception("User not logged in");

    final userId = user.id;

    final userData = await supabase
        .from('users')
        .select()
        .eq('id', userId)
        .single();

    final username = userData['username'] ?? "User";
    final userImage = userData['image'] ?? "";

    List<String> uploadedUrls = [];

    for (var file in widget.videos) {
      final url = await UploadService.uploadFile(file, userId);
      uploadedUrls.add(url);
    }

    print("TYPE: ${widget.type}"); // 🔥 مهم للتأكد

    // ============================
    // STORY
    // ============================
    if (widget.type == "story") {
      for (var url in uploadedUrls) {
        await supabase.from("stories").insert({
          "user_id": userId,
          "media_url": url,
          "created_at": DateTime.now().toIso8601String(),
          "username": username,
          "avatar_url": userImage,
          "viewers": [],
        });
      }
    }

    // ============================
    // AORAS
    // ============================
    else if (widget.type == "aoras") {
      for (var url in uploadedUrls) {
        await supabase.from("aoras").insert({
          "user_id": userId,
          "video_url": url,
          "created_at": DateTime.now().toIso8601String(),
        });
      }
    }

    // ============================
    // POST (ONLY IF EXPLICIT)
    // ============================
    else if (widget.type == "post") {
      await supabase.from("posts").insert({
        "user_id": userId,
        "media_url": uploadedUrls.first,
        "media_urls": uploadedUrls,
        "type": "post",
      });
    }

    // ============================
    // UNKNOWN TYPE (DEBUG)
    // ============================
    else {
      throw Exception("Unknown type: ${widget.type}");
    }

    Navigator.pop(context);

  } catch (e) {
    print("UPLOAD ERROR: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Upload Failed \n$e")),
    );
  }

  if (mounted) setState(() => isLoading = false);
}
  // ============================
  // UI
  // ============================

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        // MEDIA
        _buildMedia(),

        // ============================
        // CLOSE BUTTON (MATCH CAMERA)
        // ============================
        Positioned(
          top: MediaQuery.of(context).padding.top + 10, 
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 28, 
            ),
          ),
        ),

        // ============================
        // NEXT BUTTON
        // ============================
        Positioned(
          bottom: 40,
          right: 20,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditScreen(
                    videos: widget.videos,
                    type: widget.type,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                children: [
                  Text(
                    "Next",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: Colors.black),
                ],
              ),
            ),
          ),
        ),

        // ============================
        // MEDIA LIST (THUMBNAILS)
        // ============================
        Positioned(
          bottom: 110,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.videos.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _changeMedia(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: 60,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: currentIndex == index
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}
}