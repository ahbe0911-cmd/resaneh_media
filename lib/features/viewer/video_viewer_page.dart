import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoViewerPage extends StatefulWidget {
  final String filePath;
  final String title;
  const VideoViewerPage({super.key, required this.filePath, required this.title});
  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  late final VideoPlayerController _player;
  late final Future<void> _initializing;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.file(File(widget.filePath));
    _initializing = _player.initialize();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '${d.inMinutes.toString().padLeft(2, '0')}:$s';
  }

  Future<void> _seekBy(int seconds) async {
    final p = _player.value.position + Duration(seconds: seconds);
    final max = _player.value.duration;
    final target = p < Duration.zero ? Duration.zero : (p > max ? max : p);
    await _player.seekTo(target);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: Text(widget.title,
        maxLines: 1, overflow: TextOverflow.ellipsis),
      foregroundColor: Colors.white, backgroundColor: Colors.black),
    body: FutureBuilder<void>(
      future: _initializing,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || _player.value.hasError) {
          return const Center(child: Text('این ویدیو قابل پخش نیست.',
              style: TextStyle(color: Colors.white)));
        }
        return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _player,
          builder: (context, value, child) {
            final duration = value.duration.inMilliseconds.toDouble();
            final max = duration > 0 ? duration : 1.0;
            final position = value.position.inMilliseconds.toDouble()
                .clamp(0.0, max);
            return SafeArea(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                Expanded(child: Center(child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                  child: VideoPlayer(_player),
                ))),
                VideoProgressIndicator(_player, allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_duration(value.position),
                        style: const TextStyle(color: Colors.white)),
                    Text(_duration(value.duration),
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                Slider(value: position, min: 0, max: max,
                  onChanged: duration > 0 ? (v) => _player.seekTo(
                      Duration(milliseconds: v.round())) : null),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(onPressed: () => _seekBy(-10),
                      icon: const Icon(Icons.replay_10, color: Colors.white)),
                    IconButton.filled(
                      onPressed: () => value.isPlaying
                          ? _player.pause() : _player.play(),
                      icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                    ),
                    IconButton(onPressed: () => _seekBy(10),
                      icon: const Icon(Icons.forward_10, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
              ]),
            ));
          },
        );
      },
    ),
  );
}
