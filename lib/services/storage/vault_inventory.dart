import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class VaultInventory {
  VaultInventory._();

  static const folders = ['vault', 'thumbnails'];
  static final _vaultName = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(\.[a-z0-9]{1,12})?$');
  static final _thumbName = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$');

  static bool isManaged(String relative) {
    final parts = relative.split('/');
    if (parts.length != 2) return false;
    return switch (parts[0]) {
      'vault' => _vaultName.hasMatch(parts[1]),
      'thumbnails' => _thumbName.hasMatch(parts[1]),
      _ => false,
    };
  }

  static String? safeRelative(String value) {
    if (p.isAbsolute(value) || value.contains('\\')) return null;
    final normalized = p.normalize(value);
    final parts = normalized.split('/');
    if (parts.length < 2 || !folders.contains(parts.first)) return null;
    return normalized;
  }

  static Future<Set<String>> references(DatabaseExecutor db) async {
    final rows = await db.query('media_items', columns: ['relative_path', 'thumbnail_path']);
    final result = <String>{};
    for (final row in rows) {
      for (final key in ['relative_path', 'thumbnail_path']) {
        final value = row[key];
        if (value is String) {
          final relative = safeRelative(value);
          if (relative != null) result.add(relative);
        }
      }
    }
    return result;
  }

  /// Never traverse symlinks or nested directories; only files owned directly
  /// by the application's vault/thumbnail folders are eligible for cleanup.
  static Stream<File> files(Directory root) async* {
    for (final folder in folders) {
      final dir = Directory(p.join(root.path, folder));
      if (await FileSystemEntity.type(dir.path, followLinks: false) !=
          FileSystemEntityType.directory) continue;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File &&
            await FileSystemEntity.type(entity.path, followLinks: false) ==
              FileSystemEntityType.file) yield entity;
      }
    }
  }

  static Future<bool> isReferenced(DatabaseExecutor db, String relative) async {
    // Compare normalized paths too: a noncanonical legacy path must never
    // cause deletion of a referenced file.
    return (await references(db)).contains(relative);
  }
}
