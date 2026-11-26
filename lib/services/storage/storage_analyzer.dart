import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/app_database.dart';
import 'vault_inventory.dart';

class StorageReport {
  const StorageReport({
    required this.photoBytes,
    required this.videoBytes,
    required this.pdfBytes,
    required this.otherBytes,
    required this.thumbnailBytes,
    required this.databaseBytes,
    required this.clipCount,
    required this.mediaCount,
    required this.orphanBytes,
  });
  final int photoBytes;
  final int videoBytes;
  final int pdfBytes;
  final int otherBytes;
  final int thumbnailBytes;
  final int databaseBytes;
  final int clipCount;
  final int mediaCount;
  final int orphanBytes;

  int get total => photoBytes + videoBytes + pdfBytes + otherBytes +
      thumbnailBytes + databaseBytes + orphanBytes;
}

class StorageAnalyzer {
  StorageAnalyzer({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<StorageReport> analyze() async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT file_type, SUM(file_size) AS size, COUNT(*) AS count
      FROM media_items GROUP BY file_type
    ''');
    final sizes = <String, int>{};
    var count = 0;
    for (final row in rows) {
      sizes[row['file_type'] as String] = (row['size'] as num?)?.toInt() ?? 0;
      count += (row['count'] as num).toInt();
    }
    final clips = await db.rawQuery('SELECT COUNT(*) AS count FROM clip_entries');
    final clipCount = (clips.first['count'] as num).toInt();
    final root = await getApplicationDocumentsDirectory();
    final refs = await VaultInventory.references(db);
    var thumbs = 0, orphanBytes = 0;
    await for (final file in VaultInventory.files(root)) {
      final relative = p.relative(file.path, from: root.path);
      try {
        final size = await file.length();
        if (!refs.contains(relative)) {
          orphanBytes += size;
        } else if (relative.startsWith('thumbnails/')) {
          thumbs += size;
        }
      } on FileSystemException {
        // A concurrent import/deletion may have removed a file during scanning.
      }
    }
    final databaseSize = await _directorySize(Directory(p.join(root.path, 'database')));
    return StorageReport(
      photoBytes: sizes['image'] ?? 0,
      videoBytes: sizes['video'] ?? 0,
      pdfBytes: sizes['pdf'] ?? 0,
      otherBytes: sizes['other'] ?? 0,
      thumbnailBytes: thumbs,
      databaseBytes: databaseSize,
      clipCount: clipCount,
      mediaCount: count,
      orphanBytes: orphanBytes,
    );
  }

  Future<int> _directorySize(Directory directory) async {
    if (!await directory.exists()) return 0;
    var total = 0;
    await for (final item in directory.list(recursive: true, followLinks: false)) {
      if (item is File) total += await item.length();
    }
    return total;
  }
}
