import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/file_classifier.dart';

class ThumbnailService {
  static const _channel = MethodChannel('com.resaneh.media/thumbnail');

  Future<String?> createThumbnail({
    required String sourcePath,
    required String outputDirectory,
    required String mediaId,
    required MediaFileType fileType,
  }) async {
    if (fileType != MediaFileType.image && fileType != MediaFileType.video) {
      return null;
    }
    await Directory(outputDirectory).create(recursive: true);
    final output = File(p.join(outputDirectory, '$mediaId.jpg'));
    try {
      if (await output.exists()) await output.delete();
      final ok = await _channel.invokeMethod<bool>(
        fileType == MediaFileType.image
            ? 'createImageThumbnail'
            : 'createVideoThumbnail',
        <String, Object>{
          'sourcePath': sourcePath,
          'destinationPath': output.path,
          'maxWidth': 480,
          'maxHeight': 480,
          'quality': 82,
          'timeUs': 1000000,
        },
      );
      if (ok != true || !await output.exists() || await output.length() == 0) {
        if (await output.exists()) await output.delete();
        return null;
      }
      return p.join('thumbnails', '$mediaId.jpg');
    } on PlatformException {
      if (await output.exists()) await output.delete();
      return null;
    } on MissingPluginException {
      if (await output.exists()) await output.delete();
      return null;
    }
  }
}
