import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/media_item.dart';
import '../vault/vault_service.dart';

class MediaActionService {
  Future<File> _source(MediaItem item, VaultService vault) async {
    await vault.initialize();
    final file = vault.resolveStoredFile(item.relativePath);
    if (!await file.exists()) {
      throw FileSystemException('فایل آرشیوشده پیدا نشد', file.path);
    }
    return file;
  }

  Future<ShareResult> shareFile(MediaItem item, VaultService vault) async {
    final file = await _source(item, vault);
    return SharePlus.instance.share(ShareParams(
      title: item.title,
      files: [XFile(file.path, mimeType: item.mimeType)],
      fileNameOverrides: [item.originalName],
    ));
  }

  Future<ShareResult> shareFiles(
    List<MediaItem> items, VaultService vault,
  ) async {
    if (items.isEmpty) throw ArgumentError('هیچ فایلی انتخاب نشده است');
    final files = <XFile>[];
    final names = <String>[];
    for (final item in items) {
      final file = await _source(item, vault);
      files.add(XFile(file.path, mimeType: item.mimeType));
      names.add(item.originalName);
    }
    return SharePlus.instance.share(ShareParams(
      title: 'فایل‌های آرشیو',
      files: files,
      fileNameOverrides: names,
    ));
  }

  Future<OpenResult> openExternal(MediaItem item, VaultService vault) async {
    final file = await _source(item, vault);
    return OpenFilex.open(file.path, type: item.mimeType);
  }
}
