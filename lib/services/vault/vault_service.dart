import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/file_classifier.dart';
import '../../core/utils/archive_sort.dart';
import '../../core/utils/persian_normalizer.dart';
import '../../data/models/media_item.dart';
import '../../data/repositories/media_repository.dart';
import '../thumbnails/thumbnail_service.dart';

class VaultService {
  VaultService({MediaRepository? repository, ThumbnailService? thumbnailService})
      : _repository = repository ?? MediaRepository(),
        _thumbnails = thumbnailService ?? ThumbnailService();

  final MediaRepository _repository;
  final ThumbnailService _thumbnails;
  static const _uuid = Uuid();
  Directory? _root;
  Directory? _vault;
  Directory? _thumbs;

  /// Idempotent even after Factory Reset removes old folders.
  Future<void> initialize() async {
    _root ??= await getApplicationDocumentsDirectory();
    _vault = Directory(p.join(_root!.path, 'vault'));
    _thumbs = Directory(p.join(_root!.path, 'thumbnails'));
    await _vault!.create(recursive: true);
    await _thumbs!.create(recursive: true);
    await Directory(p.join(_root!.path, 'temp')).create(recursive: true);
  }

  Directory get vaultDirectory {
    if (_vault == null) throw StateError('Vault is not initialized.');
    return _vault!;
  }

  Directory get thumbnailDirectory {
    if (_thumbs == null) throw StateError('Vault is not initialized.');
    return _thumbs!;
  }

  Future<MediaItem> importFile({
    required File sourceFile,
    required String title,
    String description = '',
    List<String> tags = const [],
    String? originalName,
    String? mimeType,
  }) async {
    await initialize();
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('عنوان فایل الزامی است.');
    if (!await sourceFile.exists()) {
      throw FileSystemException('فایل ورودی وجود ندارد.', sourceFile.path);
    }
    final name = originalName?.trim().isNotEmpty == true
        ? p.basename(originalName!.trim())
        : p.basename(sourceFile.path);
    final safeName = name.isEmpty ? 'unnamed_file' : name;
    final header = await sourceFile.openRead(0, 32)
        .fold<List<int>>(<int>[], (previous, chunk) => previous..addAll(chunk));
    final detectedMime = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim().toLowerCase()
        : lookupMimeType(safeName, headerBytes: header) ?? 'application/octet-stream';
    final extension = _extension(p.extension(safeName).toLowerCase(), detectedMime);
    final type = FileClassifier.classify(mimeType: detectedMime, extension: extension);
    final id = _uuid.v4();
    final storedName = '$id$extension';
    final stored = File(p.join(vaultDirectory.path, storedName));
    String? thumbnailPath;
    try {
      await sourceFile.copy(stored.path);
      final size = await stored.length();
      if (type == MediaFileType.image || type == MediaFileType.video) {
        thumbnailPath = await _thumbnails.createThumbnail(
          sourcePath: stored.path,
          outputDirectory: thumbnailDirectory.path,
          mediaId: id,
          fileType: type,
        );
      }
      final now = DateTime.now().toUtc();
      final searchable = [cleanTitle, safeName, description, ...tags].join(' ');
      final item = MediaItem(
        id: id,
        title: cleanTitle,
        originalName: safeName,
        storedName: storedName,
        relativePath: p.join('vault', storedName),
        thumbnailPath: thumbnailPath,
        mimeType: detectedMime,
        fileType: type,
        fileSize: size,
        description: description.trim(),
        searchText: PersianNormalizer.normalize(searchable),
        searchCompact: PersianNormalizer.compact(searchable),
        isPinned: false,
        createdAt: now,
        updatedAt: now,
        tags: tags,
      );
      await _repository.insert(item, tagNames: tags);
      return item;
    } catch (_) {
      if (await stored.exists()) await stored.delete();
      if (thumbnailPath != null) {
        final thumb = resolveStoredFile(thumbnailPath);
        if (await thumb.exists()) await thumb.delete();
      }
      rethrow;
    }
  }

  String _extension(String candidate, String mimeType) {
    if (RegExp(r'^\.[a-z0-9]{1,12}$').hasMatch(candidate)) return candidate;
    final inferred = extensionFromMime(mimeType);
    if (inferred == null || !RegExp(r'^[a-z0-9]{1,12}$').hasMatch(inferred)) {
      return '';
    }
    return '.$inferred';
  }

  File resolveStoredFile(String relativePath) {
    final root = _root;
    if (root == null) throw StateError('Vault is not initialized.');
    if (p.isAbsolute(relativePath)) throw ArgumentError('Absolute paths not allowed.');
    final path = p.normalize(p.join(root.path, relativePath));
    if (!p.isWithin(root.path, path)) throw ArgumentError('Invalid vault path.');
    return File(path);
  }

  File? resolveThumbnailFile(MediaItem item) {
    return item.thumbnailPath == null ? null : resolveStoredFile(item.thumbnailPath!);
  }

  Future<bool> deleteItem(String id) async {
    await initialize();
    final item = await _repository.getById(id);
    if (item == null) return false;
    if (await _repository.deleteById(id) == 0) return false;
    for (final relative in [
      item.relativePath,
      if (item.thumbnailPath != null) item.thumbnailPath!,
    ]) {
      try {
        final file = resolveStoredFile(relative);
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Storage analyzer can report unreferenced files for maintenance.
      }
    }
    return true;
  }

  Future<List<MediaItem>> search({
    String query = '', MediaFileType? type, ArchiveSort sort = ArchiveSort.newest,
    int limit = 100, int offset = 0,
  }) async {
    await initialize();
    return _repository.search(query: query, type: type, sort: sort, limit: limit, offset: offset);
  }

  Future<MediaItem?> getById(String id) async {
    await initialize();
    return _repository.getById(id);
  }

  Future<bool> updateMetadata({
    required String id,
    required String title,
    required String description,
    required List<String> tags,
  }) async {
    await initialize();
    return _repository.updateMetadata(id: id, title: title,
        description: description, tags: tags);
  }

  Future<bool> setPinned(String id, bool pinned) async {
    await initialize();
    return _repository.setPinned(id, pinned);
  }
}
