import 'dart:io';

/// A copied, temporary input independent from the source application's cache.
class IncomingFile {
  final File stagedFile;
  final String originalName;
  final String? mimeType;

  const IncomingFile({
    required this.stagedFile,
    required this.originalName,
    this.mimeType,
  });
}
