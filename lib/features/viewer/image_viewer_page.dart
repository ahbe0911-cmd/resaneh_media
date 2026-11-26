import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/jalali_formatter.dart';
import '../../data/models/media_item.dart';
import '../archive/widgets/media_details_sheet.dart';

@immutable
class ViewerImage {
  const ViewerImage({required this.item, required this.filePath});
  final MediaItem item;
  final String filePath;

  ViewerImage withItem(MediaItem value) =>
      ViewerImage(item: value, filePath: filePath);
}

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.onShare,
    required this.onTogglePin,
  }) : assert(images.length > 0),
       assert(initialIndex >= 0 && initialIndex < images.length);

  final List<ViewerImage> images;
  final int initialIndex;
  final Future<void> Function(MediaItem) onShare;
  final Future<bool> Function(MediaItem) onTogglePin;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pages;
  late final List<ViewerImage> _images;
  late int _index;
  bool _zoomed = false;
  bool _controls = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _images = List.of(widget.images);
    _index = widget.initialIndex;
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    final item = _images[_index].item;
    setState(() => _busy = true);
    try {
      await widget.onShare(item);
    } catch (error) {
      _message('اشتراک‌گذاری ناموفق بود: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pin() async {
    if (_busy) return;
    final index = _index;
    final entry = _images[index];
    setState(() => _busy = true);
    try {
      final ok = await widget.onTogglePin(entry.item);
      if (!mounted) return;
      if (ok) {
        setState(() => _images[index] = entry.withItem(
          entry.item.copyWith(isPinned: !entry.item.isPinned),
        ));
        _message(entry.item.isPinned ? 'سنجاق برداشته شد.' : 'تصویر سنجاق شد.');
      } else {
        _message('تغییر سنجاق انجام نشد.');
      }
    } catch (error) {
      _message('تغییر سنجاق ناموفق بود: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _details() {
    if (_busy) return;
    final item = _images[_index].item;
    showModalBottomSheet<void>(
      context: context, useSafeArea: true, showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(child: MediaDetailsSheet(item: item)),
    );
  }

  void _navigate(int index) {
    if (_busy || _zoomed || index < 0 || index >= _images.length ||
        !_pages.hasClients) return;
    _pages.animateToPage(index, duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final item = _images[_index].item;
    final count = JalaliFormatter.toPersianDigits(
      '${_index + 1} از ${_images.length}',
    );
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Stack(fit: StackFit.expand, children: [
        PageView.builder(
          controller: _pages,
          physics: _zoomed || _busy
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          itemCount: _images.length,
          onPageChanged: (value) => setState(() {
            _index = value;
            _zoomed = false;
          }),
          itemBuilder: (context, index) => _ZoomableImage(
            key: ValueKey(_images[index].item.id),
            entry: _images[index],
            active: index == _index,
            onToggleControls: () => setState(() => _controls = !_controls),
            onZoomChanged: (zoomed) {
              if (mounted && index == _index && _zoomed != zoomed) {
                setState(() => _zoomed = zoomed);
              }
            },
          ),
        ),
        Align(alignment: Alignment.topCenter, child: IgnorePointer(
          ignoring: !_controls,
          child: AnimatedOpacity(
            opacity: _controls ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xED000000), Colors.transparent],
              )),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 16, 28),
                child: Row(children: [
                  IconButton(tooltip: 'بازگشت',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const BackButtonIcon(), color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white,
                        fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(count, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                  if (_busy) const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ]),
              ),
            ),
          ),
        )),
        Align(alignment: Alignment.bottomCenter, child: IgnorePointer(
          ignoring: !_controls,
          child: AnimatedOpacity(
            opacity: _controls ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Color(0xF2000000), Colors.transparent],
              )),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_images.length > 1) Row(
                    mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(tooltip: 'تصویر قبلی',
                      onPressed: _index > 0 && !_zoomed && !_busy
                        ? () => _navigate(_index - 1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: Colors.white, disabledColor: Colors.white24),
                    Text(count, style: const TextStyle(color: Colors.white70)),
                    IconButton(tooltip: 'تصویر بعدی',
                      onPressed: _index + 1 < _images.length && !_zoomed && !_busy
                        ? () => _navigate(_index + 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: Colors.white, disabledColor: Colors.white24),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _ViewerAction(icon: Icons.ios_share_rounded,
                      label: 'اشتراک', onPressed: _busy ? null : _share),
                    _ViewerAction(icon: item.isPinned ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                      label: item.isPinned ? 'رفع سنجاق' : 'سنجاق',
                      onPressed: _busy ? null : _pin),
                    _ViewerAction(icon: Icons.info_outline_rounded,
                      label: 'جزئیات', onPressed: _busy ? null : _details),
                  ]),
                ]),
              ),
            ),
          ),
        )),
      ])),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({required this.icon, required this.label, this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white38),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 23),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]),
  );
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    super.key, required this.entry, required this.active,
    required this.onToggleControls, required this.onZoomChanged,
  });
  final ViewerImage entry;
  final bool active;
  final VoidCallback onToggleControls;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _animation;
  Animation<Matrix4>? _tween;
  TapDownDetails? _doubleTap;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_changed);
    _animation = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 240))..addListener(() {
        final value = _tween?.value;
        if (value != null) _transform.value = value;
      });
  }

  @override
  void didUpdateWidget(covariant _ZoomableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && oldWidget.active) {
      _animation.stop();
      _transform.value = Matrix4.identity();
    }
  }

  void _changed() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.015;
    if (zoomed == _zoomed) return;
    if (!mounted) return;
    setState(() => _zoomed = zoomed);
    if (widget.active) widget.onZoomChanged(zoomed);
  }

  void _toggleZoom(Size size) {
    _animation.stop();
    final point = _doubleTap?.localPosition ?? size.center(Offset.zero);
    const scale = 2.5;
    final target = _zoomed ? Matrix4.identity() :
      (Matrix4.diagonal3Values(scale, scale, 1)
        ..setTranslationRaw(-point.dx * (scale - 1), -point.dy * (scale - 1), 0));
    _tween = Matrix4Tween(begin: _transform.value.clone(), end: target)
      .chain(CurveTween(curve: Curves.easeOutCubic)).animate(_animation);
    HapticFeedback.selectionClick();
    _animation.forward(from: 0);
  }

  @override
  void dispose() {
    _transform.removeListener(_changed);
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheSize = math.max(1, math.min(4096,
        (math.max(constraints.maxWidth, constraints.maxHeight) * dpr * 2).round()));
      final picture = Image(
        image: ResizeImage(FileImage(File(widget.entry.filePath)),
          width: cacheSize, height: cacheSize, policy: ResizeImagePolicy.fit),
        fit: BoxFit.contain,
        gaplessPlayback: false,
        errorBuilder: (_, _, _) => const Center(child: Text(
          'نمایش این تصویر ممکن نیست.',
          style: TextStyle(color: Colors.white70),
        )),
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggleControls,
        onDoubleTapDown: (details) => _doubleTap = details,
        onDoubleTap: () => _toggleZoom(constraints.biggest),
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1, maxScale: 6,
          panEnabled: _zoomed,
          onInteractionStart: (_) => _animation.stop(),
          child: SizedBox.expand(child: HeroMode(
            enabled: widget.active,
            child: Hero(tag: 'media_${widget.entry.item.id}', child: picture),
          )),
        ),
      );
    },
  );
}
