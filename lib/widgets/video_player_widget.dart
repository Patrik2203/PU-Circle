import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../utils/colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String postId;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    required this.postId,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.network(widget.videoUrl);
      await _controller.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _isError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }

    setState(() {
      _isPlaying = _controller.value.isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 50,
            ),
            SizedBox(height: 8),
            Text(
              'Error loading video',
              style: TextStyle(
                color: AppColors.error,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Hero(
          tag: 'post_video_${widget.postId}',
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        ),
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: AnimatedOpacity(
                opacity: _isPlaying ? 0.0 : 0.7,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: AppColors.primary,
              bufferedColor: Colors.grey[400]!,
              backgroundColor: Colors.grey[600]!,
            ),
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
          ),
        ),
      ],
    );
  }
}