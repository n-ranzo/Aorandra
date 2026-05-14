import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/app_colors.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();
  File? _videoFile;
  VideoPlayerController? _previewController;
  bool _uploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;

    final file = File(picked.path);
    final controller = VideoPlayerController.file(file);
    await controller.initialize();

    _previewController?.dispose();
    setState(() {
      _videoFile = file;
      _previewController = controller;
    });
    controller.play();
    controller.setLooping(true);
  }

  Future<void> _upload() async {
    if (_videoFile == null) return;

    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف وصفاً للفيديو')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final db = Supabase.instance.client;
      final userId = db.auth.currentUser!.id;
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      await db.storage.from('videos').upload(
        fileName,
        _videoFile!,
        fileOptions: const FileOptions(contentType: 'video/mp4'),
      );

      final videoUrl = db.storage.from('videos').getPublicUrl(fileName);

      await db.from('videos').insert({
        'user_id': userId,
        'video_url': videoUrl,
        'caption': caption,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع الفيديو بنجاح! ✅'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _videoFile = null;
          _previewController?.dispose();
          _previewController = null;
          _captionController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رفع فيديو'),
        actions: [
          if (_videoFile != null && !_uploading)
            TextButton(
              onPressed: _upload,
              child: const Text(
                'نشر',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _uploading ? null : _pickVideo,
              child: Container(
                height: 400,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _videoFile != null ? AppColors.primary : AppColors.divider,
                    width: 2,
                  ),
                ),
                child: _previewController != null && _previewController!.value.isInitialized
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: AspectRatio(
                          aspectRatio: _previewController!.value.aspectRatio,
                          child: VideoPlayer(_previewController!),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.video_library_outlined, size: 64, color: AppColors.primary),
                          SizedBox(height: 16),
                          Text(
                            'اضغط لاختيار فيديو',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'الحد الأقصى: 3 دقائق',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _captionController,
              maxLength: 200,
              maxLines: 3,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(
                hintText: 'أضف وصفاً لفيديوك...',
                counterStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            if (_uploading) ...[
              const Text('جاري الرفع...', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: AppColors.primary, backgroundColor: AppColors.surface),
            ] else if (_videoFile != null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _upload,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('نشر الفيديو'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _pickVideo,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('اختر فيديو آخر'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_library_outlined),
                  label: const Text('اختر فيديو من الاستوديو'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
