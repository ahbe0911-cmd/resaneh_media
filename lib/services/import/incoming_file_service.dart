import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'incoming_file.dart';

class IncomingFileService {
  static final Uuid _uuid = Uuid();

  Future<Directory> _stagingDirectory() async {
    final base = await getTemporaryDirectory();
    final directory = Directory(p.join(base.path, 'resaneh_imports'));
    await directory.create(recursive: true);
    return directory;
  }

  /// API for file_picker 13.x: returns List<PlatformFile>, not FilePickerResult.
  Future<List<IncomingFile>> pickFiles() async {
    final selected = await FilePicker.pickFiles(type: FileType.any);
    final staged = <IncomingFile>[];
    try {
      for (final file in selected) {
        final incoming = await _stage(
          file.readAsByteStream(),
          originalName: file.name,
          mimeType: lookupMimeType(file.name),
        );
        staged.add(incoming);
      }
      return staged;
    } catch (_) {
      await cleanup(staged);
      rethrow;
    }
  }

  Future<IncomingFile> stageSharedPath({
    required String path,
    required String originalName,
    String? mimeType,
  }) async {
    final uri = Uri.tryParse(path);
    final localPath = uri != null && uri.scheme == 'file'
        ? uri.toFilePath()
        : path;
    // receive_sharing_intent provides a local cached path for shared files.
    final source = File(localPath);
    if (!await source.exists()) {
      throw FileSystemException('Shared file not available', localPath);
    }
    return _stage(
      source.openRead(),
      originalName: originalName,
      mimeType: mimeType ?? lookupMimeType(originalName),
    );
  }

  Future<IncomingFile> _stage(
    Stream<List<int>> bytes, {
    required String originalName,
    String? mimeType,
  }) async {
    final directory = await _stagingDirectory();
    final rawExtension = p.extension(originalName).toLowerCase();
    final extension = RegExp(r'^\.[a-z0-9]{1,12}$').hasMatch(rawExtension)
        ? rawExtension
        : '';
    final output = File(p.join(directory.path, '${_uuid.v4()}$extension'));
    final sink = output.openWrite();
    try {
      await sink.addStream(bytes);
      await sink.flush();
      await sink.close();
    } catch (_) {
      try { await sink.close(); } catch (_) {}
      if (await output.exists()) await output.delete();
      rethrow;
    }
    return IncomingFile(
      stagedFile: output,
      originalName: p.basename(originalName).isEmpty
          ? 'untitled$extension'
          : p.basename(originalName),
      mimeType: mimeType,
    );
  }

  Future<void> deleteStaged(IncomingFile incoming) async {
    final allowedDirectory = await _stagingDirectory();
    final target = p.normalize(incoming.stagedFile.absolute.path);
    if (p.dirname(target) != p.normalize(allowedDirectory.absolute.path)) {
      throw ArgumentError('Refusing to delete a non-staged file');
    }
    if (await incoming.stagedFile.exists()) {
      await incoming.stagedFile.delete();
    }
  }

  Future<void> clearStaging() async {
    final directory = await _stagingDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> cleanup(Iterable<IncomingFile> files) async {
    for (final file in files) {
      try {
        await deleteStaged(file);
      } on FileSystemException {
        // OS may already have removed an ephemeral staging file.
      }
    }
  }
}
