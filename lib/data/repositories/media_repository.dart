import 'package:sqflite/sqflite.dart';
import '../../core/utils/file_classifier.dart';
import '../../core/utils/archive_sort.dart';
import '../../core/utils/persian_normalizer.dart';
import '../database/app_database.dart';
import '../database/search_index.dart';
import '../models/media_item.dart';
import 'tag_repository.dart';

class MediaRepository {
  MediaRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  List<String> _uniqueTags(List<String> raw) {
    final unique = <String, String>{};
    for (final value in raw) {
      final normalized = PersianNormalizer.normalize(value);
      if (normalized.isNotEmpty) {
        unique.putIfAbsent(normalized, () => value.trim());
      }
    }
    return unique.values.toList();
  }

  Future<void> insert(MediaItem item, {List<String> tagNames = const []}) async {
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.insert('media_items', item.toMap());
      for (final tag in _uniqueTags(tagNames)) {
        final tagId = await TagRepository.ensureInTransaction(tx, tag);
        await tx.insert(
          'media_tags',
          {'media_id': item.id, 'tag_id': tagId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<MediaItem>> search({
    String query = '',
    MediaFileType? type,
    ArchiveSort sort = ArchiveSort.newest,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _database.database;
    final conditions = <String>[];
    final args = <Object?>[];
    final normalized = PersianNormalizer.normalize(query);
    if (normalized.isNotEmpty) {
      final match = SearchIndex.matchExpression(query);
      if (SearchIndex.enabled(db) && match != null) {
        conditions.add('''m.id IN (
          SELECT id FROM media_fts WHERE media_fts MATCH ?
          UNION
          SELECT mt.media_id FROM media_tags mt
          JOIN tags_fts tf ON tf.id=mt.tag_id
          WHERE tags_fts MATCH ?
        )''');
        args.addAll([match, match]);
      }
      // Verify against the original predicates to preserve exact semantics.
      conditions.add('''
        (m.search_text LIKE ? ESCAPE '!'
         OR m.search_compact LIKE ? ESCAPE '!'
         OR EXISTS (
           SELECT 1 FROM media_tags mt
           JOIN tags t ON t.id=mt.tag_id
           WHERE mt.media_id=m.id
           AND (t.normalized_name LIKE ? ESCAPE '!'
             OR t.compact_name LIKE ? ESCAPE '!')
         ))
      ''');
      args.addAll([
        '%${PersianNormalizer.escapeLike(normalized)}%',
        '%${PersianNormalizer.escapeLike(PersianNormalizer.compact(query))}%',
        '%${PersianNormalizer.escapeLike(normalized)}%',
        '%${PersianNormalizer.escapeLike(PersianNormalizer.compact(query))}%',
      ]);
    }
    if (type != null) {
      conditions.add('m.file_type = ?');
      args.add(type.name);
    }
    final clause = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery(
      '''SELECT m.* FROM media_items m $clause
         ORDER BY m.is_pinned DESC, ${sort.sqlOrder}
         LIMIT ? OFFSET ?''',
      [...args, limit.clamp(1, 500), offset < 0 ? 0 : offset],
    );
    return _hydrate(rows, db);
  }

  Future<MediaItem?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query(
      'media_items', where: 'id = ?', whereArgs: [id], limit: 1,
    );
    if (rows.isEmpty) return null;
    return (await _hydrate(rows, db)).single;
  }

  Future<List<MediaItem>> _hydrate(
    List<Map<String, Object?>> rows,
    DatabaseExecutor db,
  ) async {
    if (rows.isEmpty) return [];
    final ids = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final tagRows = await db.rawQuery('''
      SELECT mt.media_id, t.name FROM media_tags mt
      JOIN tags t ON t.id = mt.tag_id
      WHERE mt.media_id IN ($placeholders)
      ORDER BY t.name COLLATE NOCASE ASC
    ''', ids);
    final grouped = <String, List<String>>{};
    for (final row in tagRows) {
      final id = row['media_id'] as String;
      grouped.putIfAbsent(id, () => []).add(row['name'] as String);
    }
    return rows.map((row) => MediaItem.fromMap(
      row,
      tags: grouped[row['id'] as String] ?? const [],
    )).toList();
  }

  Future<bool> updateMetadata({
    required String id,
    required String title,
    required String description,
    required List<String> tags,
  }) async {
    final current = await getById(id);
    if (current == null) return false;
    if (title.trim().isEmpty) throw ArgumentError('عنوان الزامی است');
    final unique = _uniqueTags(tags);
    final source = [title.trim(), current.originalName, description, ...unique].join(' ');
    final db = await _database.database;
    await db.transaction((tx) async {
      await tx.update('media_items', {
        'title': title.trim(),
        'description': description.trim(),
        'search_text': PersianNormalizer.normalize(source),
        'search_compact': PersianNormalizer.compact(source),
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      }, where: 'id = ?', whereArgs: [id]);
      await tx.delete('media_tags', where: 'media_id = ?', whereArgs: [id]);
      for (final name in unique) {
        final tagId = await TagRepository.ensureInTransaction(tx, name);
        await tx.insert('media_tags', {'media_id': id, 'tag_id': tagId},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    return true;
  }

  Future<bool> setPinned(String id, bool pinned) async {
    final db = await _database.database;
    return await db.update('media_items', {
      'is_pinned': pinned ? 1 : 0,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]) > 0;
  }

  Future<int> deleteById(String id) async {
    final db = await _database.database;
    return db.delete('media_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM media_items');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> countByType(MediaFileType type) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM media_items WHERE file_type = ?',
      [type.name],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
