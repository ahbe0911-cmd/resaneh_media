import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:resaneh_media/data/database/database_schema.dart';
import 'package:resaneh_media/services/storage/vault_maintenance_service.dart';

void main() {
  sqfliteFfiInit();
  test('cleanup keeps referenced, recent and unknown files; removes only old orphans', () async {
    final root = await Directory.systemTemp.createTemp('resaneh-maintenance-');
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    try {
      await DatabaseSchema.create(db);
      final vault = await Directory(p.join(root.path, 'vault')).create();
      final thumbnails = await Directory(p.join(root.path, 'thumbnails')).create();
      const a = '12345678-1234-1234-1234-123456789001';
      const b = '12345678-1234-1234-1234-123456789002';
      const c = '12345678-1234-1234-1234-123456789003';
      final keep = await File(p.join(vault.path, '$a.pdf')).writeAsString('keep');
      final orphan = await File(p.join(vault.path, '$b.pdf')).writeAsString('orphan');
      final recent = await File(p.join(vault.path, '$c.pdf')).writeAsString('recent');
      final unknown = await File(p.join(vault.path, 'unknown.pdf')).writeAsString('unknown');
      final thumb = await File(p.join(thumbnails.path, '$b.jpg')).writeAsString('thumb');
      final now = DateTime.now();
      for (final file in [keep, orphan, unknown, thumb]) {
        await file.setLastModified(now.subtract(const Duration(hours: 1)));
      }
      await db.insert('media_items', {
        'id': a, 'title': 'keep', 'original_name': 'keep.pdf',
        'stored_name': '$a.pdf', 'relative_path': 'vault/$a.pdf',
        'thumbnail_path': 'thumbnails/$b.jpg', 'mime_type': 'application/pdf',
        'file_type': 'pdf', 'created_at': 1, 'updated_at': 1,
      });
      final result = await VaultMaintenanceService.cleanupFiles(db, root, now: now);
      expect(result.files, 1);
      expect(result.bytes, 6);
      expect(await orphan.exists(), isFalse);
      expect(await keep.exists(), isTrue);
      expect(await thumb.exists(), isTrue);
      expect(await recent.exists(), isTrue);
      expect(await unknown.exists(), isTrue);
      expect(await db.query('media_items'), hasLength(1));
    } finally {
      await db.close();
      await root.delete(recursive: true);
    }
  });
}
