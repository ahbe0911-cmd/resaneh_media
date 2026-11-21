import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../import/incoming_file.dart';
import '../import/incoming_file_service.dart';

typedef IncomingFilesCallback = Future<void> Function(List<IncomingFile>);
typedef IncomingTextCallback = void Function(String);
typedef IncomingErrorCallback = void Function(String);

/// Stages shared media before calling reset(), which clears the native intent.
class ShareIntentService {
  final IncomingFileService files;
  final IncomingFilesCallback onFiles;
  final IncomingTextCallback onText;
  final IncomingErrorCallback onError;

  ShareIntentService({
    required this.files,
    required this.onFiles,
    required this.onText,
    required this.onError,
  });

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  Future<void> _serial = Future<void>.value();
  bool _started = false;
  bool _disposed = false;
  String? _lastSignature;
  DateTime? _lastSeen;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _queue,
      onError: (Object error) => onError(error.toString()),
    );
    try {
      final initial = await ReceiveSharingIntent.instance.getInitialMedia();
      _queue(initial);
    } catch (error) {
      onError('خطا در دریافت Share: $error');
    }
  }

  void _queue(List<SharedMediaFile> incoming) {
    if (_disposed || incoming.isEmpty) return;
    _serial = _serial.then((_) => _process(incoming)).catchError((Object e) {
      if (!_disposed) onError('خطا در پردازش Share: $e');
    });
  }

  Future<void> _process(List<SharedMediaFile> incoming) async {
    if (_disposed) return;
    // Android may deliver the same cold-start intent through both streams.
    final signature = incoming.map((x) => '${x.type.name}:${x.path}').join('|');
    final now = DateTime.now();
    if (signature == _lastSignature &&
        _lastSeen != null &&
        now.difference(_lastSeen!) < const Duration(seconds: 3)) {
      return;
    }
    _lastSignature = signature;
    _lastSeen = now;

    final staged = <IncomingFile>[];
    final texts = <String>[];
    try {
      for (final media in incoming) {
        if (media.type == SharedMediaType.text ||
            media.type == SharedMediaType.url) {
          final content = (media.message?.trim().isNotEmpty == true)
              ? media.message!.trim()
              : media.path.trim();
          if (content.isNotEmpty) texts.add(content);
          continue;
        }
        try {
          final name = p.basename(media.path);
          staged.add(await files.stageSharedPath(
            path: media.path,
            originalName: name.isEmpty ? 'shared_file' : name,
            mimeType: media.mimeType,
          ));
        } catch (error) {
          onError('دریافت ${p.basename(media.path)} ناموفق بود: $error');
        }
      }
    } finally {
      try {
        await ReceiveSharingIntent.instance.reset();
      } catch (error) {
        if (!_disposed) onError('خطای بازنشانی Share: $error');
      }
    }

    if (_disposed) {
      await files.cleanup(staged);
      return;
    }
    if (staged.isNotEmpty) {
      try {
        await onFiles(staged);
      } catch (error) {
        await files.cleanup(staged);
        onError('نمایش فایل‌های دریافتی ناموفق بود: $error');
      }
    }
    for (final value in texts) {
      if (!_disposed) onText(value);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    await _serial;
  }
}
