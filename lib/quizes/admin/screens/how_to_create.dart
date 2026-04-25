import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class HowToCreateScreen extends StatefulWidget {
  const HowToCreateScreen({super.key});

  @override
  State<HowToCreateScreen> createState() => _HowToCreateScreenState();
}

class _HowToCreateScreenState extends State<HowToCreateScreen> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = VideoPlayerController.asset("assets/videos/tutorial.mp4");

    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {});

          // ✅ ROOT FIX: On Android, the video SurfaceTexture must be fully
          // mounted in the widget tree before play() is called. Calling play()
          // directly inside initialize().then() fires before the Texture widget
          // is attached to the GPU pipeline — causing a black screen even though
          // isPlaying = true. addPostFrameCallback ensures the frame is rendered
          // first.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _controller.play();
          });
        })
        .catchError((error) {
          if (mounted) setState(() => _hasError = true);
          debugPrint('VideoPlayer error: $error');
        });

    // Listener drives slider & play/pause icon rebuilds
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = _controller.value.isInitialized;

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: isInitialized ? _controller.value.aspectRatio : 16 / 9,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── Video surface ───────────────────────────────────────
              if (_hasError)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Could not load video.\nCheck assets/videos/tutorial.mp4',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else if (!isInitialized)
                const Center(
                  child: CircularProgressIndicator(color: Colors.tealAccent),
                )
              else
                VideoPlayer(_controller),

              // ── Play / Pause button ─────────────────────────────────
              if (_showControls && !_hasError)
                Center(
                  child: IconButton(
                    iconSize: 60,
                    color: Colors.white,
                    icon: Icon(
                      _controller.value.isPlaying
                          ? Icons.pause_circle
                          : Icons.play_circle,
                    ),
                    onPressed: () {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    },
                  ),
                ),

              // ── Seek bar + timestamps ───────────────────────────────
              if (_showControls && isInitialized && !_hasError)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    color: Colors.black54,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Slider(
                          value: _controller.value.position.inSeconds
                              .toDouble()
                              .clamp(
                                0,
                                _controller.value.duration.inSeconds.toDouble(),
                              ),
                          min: 0,
                          max: _controller.value.duration.inSeconds
                              .toDouble()
                              .clamp(1, double.infinity),
                          activeColor: Colors.tealAccent,
                          onChanged: (value) {
                            _controller.seekTo(
                              Duration(seconds: value.toInt()),
                            );
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_controller.value.position),
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              _formatDuration(_controller.value.duration),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Close button ────────────────────────────────────────
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
