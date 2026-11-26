import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/file_classifier.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/tag_repository.dart';
import '../thumbnails/thumbnail_service.dart';
import 'vault_inventory.dart';

class MaintenanceResult {
  const MaintenanceResult({this.files = 0, this.bytes = 0, this.tags = 0,
    this.rebuilt = 0, this.failed = 0, this.skipped = 0});
  final int files, bytes, tags, rebuilt, failed, skipped;
}

class VaultMaintenanceService {
  VaultMaintenanceService({AppDatabase? database, ThumbnailService? thumbnails})
      : _database = database ?? AppDatabase.instance,
        _thumbnails = thumbnails ?? ThumbnailService();

  final AppDatabase _database;
  final ThumbnailService _thumbnails;
  static const _uuid = Uuid();
  bool _running = false;

  Future<MaintenanceResult> cleanup() async {
    if (_running) throw StateError('عملیات نگهداری در حال اجراست.');
    _running = true;
    try {
      final root = await getApplicationDocumentsDirectory();
      final db = await _database.database;
      final result = await cleanupFiles(db, root);
      final tags = await TagRepository(database: _database).deleteUnusedTags();
      return MaintenanceResult(files: result.files, bytes: result.bytes,
        tags: tags, failed: result.failed, skipped: result.skipped);
    } finally {
      _running = false;
    }
  }

  /// Call under exclusive app maintenance. A grace period additionally
  /// protects incomplete imports and files created by interrupted operations.
  static Future<MaintenanceResult> cleanupFiles(Database db, Directory root,
      {DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).subtract(const Duration(minutes: 10));
    final refs = await VaultInventory.references(db);
    var count = 0, bytes = 0, failed = 0, skipped = 0;
    await for (final file in VaultInventory.files(root)) {
      final relative = p.relative(file.path, from: root.path);
      if (refs.contains(relative)) continue;
      if (!VaultInventory.isManaged(relative)) {
        skipped++;
        continue;
      }
      try {
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file || !stat.modified.isBefore(cutoff)) {
          skipped++;
          continue;
        }
        final removed = await db.transaction((tx) async {
          if (await VaultInventory.isReferenced(tx, relative)) return false;
          if (await FileSystemEntity.type(file.path, followLinks: false) !=
              FileSystemEntityType.file) return false;
          // Recheck age immediately before removing the same file.
          if (!(await file.lastModified()).isBefore(cutoff)) return false;
          await file.delete();
          return true;
        });
        if (removed) {
          count++;
          bytes += stat.size;
        } else {
          skipped++;
        }
      } catch (_) {
        failed++;
      }
    }
    return MaintenanceResult(files: count, bytes: bytes, failed: failed, skipped: skipped);
  }

  Future<MaintenanceResult> rebuildThumbnails({
    void Function(int done, int total)? onProgress,
  }) async {
    if (_running) throw StateError('عملیات نگهداری در حال اجراست.');
    _running = true;
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory(p.join(root.path, 'thumbnails'));
      await directory.create(recursive: true);
      if (await FileSystemEntity.type(directory.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw StateError('پوشه پیش‌نمایش نامعتبر است.');
      }
      final db = await _database.database;
      final rows = await db.query('media_items',
        columns: ['id', 'relative_path', 'thumbnail_path', 'file_type'],
        where: "file_type IN ('image','video','pdf')", orderBy: 'id ASC');
      var rebuilt = 0, failed = 0, done = 0;
      onProgress?.call(0, rows.length);
      for (final row in rows) {
        String? created;
        try {
          final relative = VaultInventory.safeRelative(row['relative_path'] as String);
          if (relative == null || !relative.startsWith('vault/') ||
              !VaultInventory.isManaged(relative)) throw StateError('مسیر نامعتبر');
          final source = File(p.join(root.path, relative));
          final parent = Directory(p.dirname(source.path));
          if (await FileSystemEntity.type(parent.path, followLinks: false) !=
              FileSystemEntityType.directory ||
              await FileSystemEntity.type(source.path, followLinks: false) !=
              FileSystemEntityType.file) throw StateError('فایل اصلی موجود نیست');
          created = await _thumbnails.createThumbnail(
            sourcePath: source.path, outputDirectory: directory.path,
            mediaId: _uuid.v4(),
            fileType: MediaFileType.fromValue(row['file_type'] as String),
          );
          if (created == null) throw StateError('پیش‌نمایش ساخته نشد');
          final changed = await db.update('media_items', {'thumbnail_path': created},
            where: 'id=? AND relative_path=? AND thumbnail_path IS ?',
            whereArgs: [row['id'], row['relative_path'], row['thumbnail_path']]);
          if (changed != 1) throw StateError('رکورد تغییر کرده است');
          created = null; // Published; never delete the new referenced image.
          rebuilt++;
          final old = row['thumbnail_path'];
          if (old is String && old.startsWith('thumbnails/') &&
              VaultInventory.isManaged(old)) {
            try {
              await db.transaction((tx) async {
                if (await VaultInventory.isReferenced(tx, old)) return;
                final file = File(p.join(root.path, old));
                if (await FileSystemEntity.type(file.path, followLinks: false) ==
                    FileSystemEntityType.file) await file.delete();
              });
            } catch (_) {
              // Leftover thumbnail is harmless and can be cleaned later.
            }
          }
        } catch (_) {
          failed++;
          if (created != null && VaultInventory.isManaged(created)) {
            try {
              if (!await VaultInventory.isReferenced(db, created)) {
                final file = File(p.join(root.path, created));
                if (await FileSystemEntity.type(file.path, followLinks: false) ==
                    FileSystemEntityType.file) await file.delete();
              }
            } catch (_) {}
          }
        } finally {
          done++;
          onProgress?.call(done, rows.length);
        }
      }
      return MaintenanceResult(rebuilt: rebuilt, failed: failed);
    } finally {
      _running = false;
    }
  }
}
