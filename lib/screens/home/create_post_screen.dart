import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../firebase/auth_service.dart';
import '../../firebase/firestore_service.dart';
import '../../firebase/storage_service.dart';
import '../../utils/colors.dart';
import '../../utils/helpers.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class CreatePostScreen extends StatefulWidget {
  final Function onPostCreated;

  const CreatePostScreen({
    Key? key,
    required this.onPostCreated,
  }) : super(key: key);

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isVideo = false;
  File? _mediaFile;
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _selectMedia(ImageSource source, bool isVideo) async {
    try {
      if (isVideo) {
        final XFile? video = await _picker.pickVideo(source: source);
        if (video != null) {
          final File videoFile = File(video.path);

          // Initialize video player
          _videoController = VideoPlayerController.file(videoFile)
            ..initialize().then((_) {
              setState(() {});
              _videoController?.play();
            });

          setState(() {
            _mediaFile = videoFile;
            _isVideo = true;
          });
        }
      } else {
        final XFile? image = await _picker.pickImage(source: source);
        if (image != null) {
          setState(() {
            _mediaFile = File(image.path);
            _isVideo = false;

            // Dispose video controller if it exists
            if (_videoController != null) {
              _videoController!.dispose();
              _videoController = null;
            }
          });
        }
      }
    } catch (e) {
      AppHelpers.showSnackBar(context, 'Error selecting media: $e');
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Select Media',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _selectMedia(ImageSource.camera, false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _selectMedia(ImageSource.gallery, false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Record Video'),
                onTap: () {
                  Navigator.pop(context);
                  _selectMedia(ImageSource.camera, true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Choose Video from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _selectMedia(ImageSource.gallery, true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createPost() async {
    if (_mediaFile == null) {
      AppHelpers.showSnackBar(context, 'Please select an image or video');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Upload media file to storage
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String mediaPath = _isVideo
          ? 'posts/videos/${currentUser.uid}_$timestamp.mp4'
          : 'posts/images/${currentUser.uid}_$timestamp.jpg';

      final String mediaUrl = _isVideo
          ? await _storageService.uploadPostVideo(_mediaFile!)
          : await _storageService.uploadPostImage(_mediaFile!);


      // Create post in Firestore
      await _firestoreService.createPost(
        userId: currentUser.uid,
        caption: _captionController.text,
        mediaUrl: mediaUrl,
        isVideo: _isVideo,
      );

      // Call callback to refresh posts
      widget.onPostCreated();

      if (!mounted) return;

      // Show success message and pop screen
      AppHelpers.showSnackBar(context, 'Post created successfully!');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'Error creating post: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? LoadingAnimationWidget.staggeredDotsWave(
              color: AppColors.primary,
              size: 20,
            )
                : const Text(
              'Post',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caption input
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                hintText: 'Write a caption...',
                border: InputBorder.none,
              ),
              maxLines: 3,
            ),
            const Divider(),

            // Media preview
            if (_mediaFile != null) ...[
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _isVideo
                      ? _videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                      : const Center(child: CircularProgressIndicator())
                      : Image.file(
                    _mediaFile!,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _showMediaOptions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Change Media'),
                ),
              ),
            ] else ...[
              const SizedBox(height: 64),
              Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate,
                      size: 80,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add Photos or Videos',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showMediaOptions,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Media'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}