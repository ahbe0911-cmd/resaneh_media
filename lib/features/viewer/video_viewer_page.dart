import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../providers/app_lock_controller.dart';
import 'viewer_formatters.dart';

class VideoViewerPage extends StatefulWidget {
  const VideoViewerPage({super.key, required this.filePath, required this.title});
  final String filePath;
  final String title;

  @override
  State<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage>
    with WidgetsBindingObserver {
  late final VideoPlayerController _player;
  late final Future<void> _initializing;
  AppLockController? _lock;
  Timer? _hideTimer;
  bool _controls = true;
  bool _fullscreen = false;
  bool _speedMenu = false;
  bool _background = false;
  bool _wasPlaying = false;
  double? _dragPosition;
  Future<void> _orientationTask = Future<void>.value();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = VideoPlayerController.file(File(widget.filePath));
    _player.addListener(_playbackChanged);
    _initializing = _player.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lock = context.read<AppLockController>();
    if (!identical(_lock, lock)) {
      _lock?.removeListener(_lockChanged);
      _lock = lock..addListener(_lockChanged);
    }
  }

  bool get _private => _background || _lock?.unlocked == false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    if (_background) _pauseForPrivacy();
  }

  void _lockChanged() {
    if (_lock?.unlocked == false) _pauseForPrivacy();
  }

  void _pauseForPrivacy() {
    _hideTimer?.cancel();
    if (_player.value.isInitialized && _player.value.isPlaying) {
      unawaited(_runPlayer(_player.pause));
    }
    if (mounted) setState(() {
      _controls = true;
      _speedMenu = false;
      _dragPosition = null;
    });
  }

  void _playbackChanged() {
    final playing = _player.value.isPlaying;
    if (playing && _private) {
      unawaited(_runPlayer(_player.pause));
      return;
    }
    if (playing == _wasPlaying) return;
    _wasPlaying = playing;
    if (playing) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
      if (mounted && !_controls) setState(() => _controls = true);
    }
  }

  Future<void> _runPlayer(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted && !_private) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('عملیات پخش انجام نشد: $error')),
        );
      }
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!_player.value.isPlaying || _speedMenu ||
        _dragPosition != null || _private) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.value.isPlaying && !_speedMenu &&
          _dragPosition == null && !_private) {
        setState(() => _controls = false);
      }
    });
  }

  void _toggleControls() {
    if (_private) return;
    _hideTimer?.cancel();
    setState(() {
      _controls = !_controls;
      _speedMenu = false;
    });
    if (_controls) _scheduleHide();
  }

  Future<void> _togglePlay() async {
    if (_private || !_player.value.isInitialized) return;
    await _runPlayer(() async {
      if (_player.value.isPlaying) {
        await _player.pause();
      } else {
        final value = _player.value;
        if (value.duration > Duration.zero && value.position >= value.duration) {
          await _player.seekTo(Duration.zero);
        }
        if (mounted && !_private) await _player.play();
      }
    });
    if (mounted) _scheduleHide();
  }

  Future<void> _seekBy(int seconds) async {
    if (_private) return;
    final target = ViewerFormatters.clampPosition(
      _player.value.position + Duration(seconds: seconds),
      _player.value.duration,
    );
    await _runPlayer(() => _player.seekTo(target));
    if (mounted) _scheduleHide();
  }

  Future<void> _seekTo(double value) async {
    if (_private) return;
    final position = ViewerFormatters.clampPosition(
      Duration(milliseconds: value.round()), _player.value.duration,
    );
    await _runPlayer(() => _player.seekTo(position));
    if (!mounted) return;
    setState(() => _dragPosition = null);
    _scheduleHide();
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speedMenu = false);
    await _runPlayer(() => _player.setPlaybackSpeed(speed));
    if (mounted) _scheduleHide();
  }

  void _queueOrientation(List<DeviceOrientation> orientations) {
    _orientationTask = _orientationTask.then((_) async {
      try {
        await SystemChrome.setPreferredOrientations(orientations);
      } catch (_) {
        // Android may restrict rotation. The responsive layout still works.
      }
    });
  }

  void _setFullscreen(bool value) {
    if (_fullscreen == value) return;
    setState(() {
      _fullscreen = value;
      _controls = true;
      _speedMenu = false;
    });
    _queueOrientation(value ? const [
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ] : const []);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _lock?.removeListener(_lockChanged);
    WidgetsBinding.instance.removeObserver(this);
    _player.removeListener(_playbackChanged);
    unawaited(_player.dispose());
    // Restore the unrestricted app orientation even if a pending landscape
    // request completes after the route has been dismissed.
    if (_fullscreen) _queueOrientation(const []);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_fullscreen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _fullscreen) _setFullscreen(false);
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: FutureBuilder<void>(
        future: _initializing,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _status(const CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError || _player.value.hasError) {
            return _status(const Text('این ویدیو قابل پخش نیست.',
              style: TextStyle(color: Colors.white70)));
          }
          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _player,
            builder: (context, value, child) {
              if (value.hasError) return _status(const Text(
                'خطا در پخش ویدیو.', style: TextStyle(color: Colors.white70)));
              return _buildPlayer(context, value);
            },
          );
        },
      )),
    ),
  );

  Widget _status(Widget child) => Stack(fit: StackFit.expand, children: [
    Center(child: child),
    Align(alignment: AlignmentDirectional.topStart, child: IconButton(
      tooltip: 'بازگشت', color: Colors.white,
      onPressed: () => _fullscreen ? _setFullscreen(false) : Navigator.maybePop(context),
      icon: const BackButtonIcon(),
    )),
  ]);

  Widget _buildPlayer(BuildContext context, VideoPlayerValue value) {
    final duration = value.duration.inMilliseconds.toDouble();
    final max = duration > 0 ? duration : 1.0;
    final position = (_dragPosition ?? value.position.inMilliseconds.toDouble())
        .clamp(0.0, max).toDouble();
    final tint = Theme.of(context).colorScheme.primary;
    final active = Color.lerp(tint, Colors.white, .36)!;
    return Stack(fit: StackFit.expand, children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Center(child: AspectRatio(
          aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
          child: VideoPlayer(_player),
        )),
      ),
      if (value.isBuffering) const IgnorePointer(child: Center(
        child: CircularProgressIndicator(color: Colors.white70),
      )),
      Align(alignment: Alignment.topCenter, child: IgnorePointer(
        ignoring: !_controls,
        child: AnimatedOpacity(opacity: _controls ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xE6000000), Colors.transparent],
            )),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 5, 12, 20),
              child: Row(children: [
                IconButton(tooltip: _fullscreen ? 'خروج از تمام‌صفحه' : 'بازگشت',
                  onPressed: () => _fullscreen
                    ? _setFullscreen(false) : Navigator.maybePop(context),
                  color: Colors.white, icon: const BackButtonIcon()),
                Expanded(child: Text(widget.title, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 17,
                    fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
      )),
      Align(alignment: Alignment.center, child: IgnorePointer(
        ignoring: !_controls,
        child: AnimatedOpacity(opacity: _controls ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Row(mainAxisSize: MainAxisSize.min, textDirection: TextDirection.ltr,
            children: [
              _PlayerButton(icon: Icons.replay_10_rounded,
                label: '۱۰ ثانیه عقب', onPressed: () => _seekBy(-10)),
              const SizedBox(width: 12),
              IconButton.filled(
                tooltip: value.isPlaying ? 'توقف موقت' : 'پخش',
                style: IconButton.styleFrom(backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(64, 64)),
                onPressed: _togglePlay,
                icon: Icon(value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 36),
              ),
              const SizedBox(width: 12),
              _PlayerButton(icon: Icons.forward_10_rounded,
                label: '۱۰ ثانیه جلو', onPressed: () => _seekBy(10)),
            ]),
        ),
      )),
      Align(alignment: Alignment.bottomCenter, child: IgnorePointer(
        ignoring: !_controls,
        child: AnimatedOpacity(opacity: _controls ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Color(0xF2000000), Colors.transparent],
            )),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_speedMenu) Wrap(
                  spacing: 6, runSpacing: 4, alignment: WrapAlignment.center,
                  children: [
                    for (final speed in const [0.5, 1.0, 1.5, 2.0])
                      ChoiceChip(
                        label: Text(ViewerFormatters.speed(speed)),
                        selected: value.playbackSpeed == speed,
                        onSelected: (_) => _setSpeed(speed),
                      ),
                  ],
                ),
                Directionality(textDirection: TextDirection.ltr, child: Row(children: [
                  Text(ViewerFormatters.playbackTime(Duration(milliseconds: position.round())),
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                  Expanded(child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      activeTrackColor: active, inactiveTrackColor: Colors.white30,
                      thumbColor: active, overlayColor: Colors.white12,
                    ),
                    child: Slider(
                      value: position, max: max,
                      onChangeStart: duration > 0 ? (v) {
                        _hideTimer?.cancel();
                        setState(() => _dragPosition = v);
                      } : null,
                      onChanged: duration > 0 ? (v) => setState(() => _dragPosition = v) : null,
                      onChangeEnd: duration > 0 ? _seekTo : null,
                    ),
                  )),
                  Text(ViewerFormatters.playbackTime(value.duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                Row(children: [
                  TextButton.icon(
                    onPressed: () {
                      _hideTimer?.cancel();
                      setState(() => _speedMenu = !_speedMenu);
                      if (!_speedMenu) _scheduleHide();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    icon: const Icon(Icons.speed_rounded, size: 21),
                    label: Text(ViewerFormatters.speed(value.playbackSpeed)),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _fullscreen ? 'خروج از تمام‌صفحه' : 'تمام‌صفحه',
                    color: Colors.white,
                    onPressed: () => _setFullscreen(!_fullscreen),
                    icon: Icon(_fullscreen ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded, size: 27),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      )),
    ]);
  }
}

class _PlayerButton extends StatelessWidget {
  const _PlayerButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(backgroundColor: Colors.black54,
      foregroundColor: Colors.white, minimumSize: const Size(52, 52)),
    icon: Icon(icon, size: 27),
  );
}
