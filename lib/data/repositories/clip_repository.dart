import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/persian_normalizer.dart';
import '../database/app_database.dart';
import '../models/clip_entry.dart';

class ClipRepository {
  ClipRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  static const _uuid = Uuid();

  Future<ClipEntry> add({required String title, required String body}) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('عنوان متن الزامی است.');
    }
    if (body.trim().isEmpty) {
      throw ArgumentError('محتوای متن نمی‌تواند خالی باشد.');
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final text = '$cleanTitle ${body.trim()}';
    final map = <String, Object?>{
      'id': _uuid.v4(),
      'title': cleanTitle,
      'body': body.trim(),
      'search_text': PersianNormalizer.normalize(text),
      'search_compact': PersianNormalizer.compact(text),
      'is_pinned': 0,
      'created_at': now,
      'updated_at': now,
    };
    final db = await _database.database;
    await db.insert('clip_entries', map);
    return ClipEntry.fromMap(map);
  }

  Future<List<ClipEntry>> search({
    String query = '',
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _database.database;
    final normalized = PersianNormalizer.normalize(query);
    final compact = PersianNormalizer.compact(query);
    final where = normalized.isEmpty
        ? null
        : "search_text LIKE ? ESCAPE '!' OR search_compact LIKE ? ESCAPE '!'";
    final args = normalized.isEmpty
        ? null
        : [
            '%${PersianNormalizer.escapeLike(normalized)}%',
            '%${PersianNormalizer.escapeLike(compact)}%',
          ];
    final rows = await db.query(
      'clip_entries',
      where: where,
      whereArgs: args,
      orderBy: 'is_pinned DESC, created_at DESC, id DESC',
      limit: limit.clamp(1, 500),
      offset: offset < 0 ? 0 : offset,
    );
    return rows.map(ClipEntry.fromMap).toList();
  }

  Future<bool> update({
    required String id,
    required String title,
    required String body,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || body.trim().isEmpty) {
      throw ArgumentError('عنوان و متن الزامی هستند.');
    }
    final text = '$cleanTitle ${body.trim()}';
    final db = await _database.database;
    final affected = await db.update(
      'clip_entries',
      {
        'title': cleanTitle,
        'body': body.trim(),
        'search_text': PersianNormalizer.normalize(text),
        'search_compact': PersianNormalizer.compact(text),
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return affected > 0;
  }

  Future<bool> setPinned(String id, bool isPinned) async {
    final db = await _database.database;
    return await db.update('clip_entries', {
          'is_pinned': isPinned ? 1 : 0,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        }, where: 'id = ?', whereArgs: [id]) >
        0;
  }

  Future<bool> delete(String id) async {
    final db = await _database.database;
    return await db.delete('clip_entries', where: 'id = ?', whereArgs: [id]) > 0;
  }

  Future<int> count() async {
    final db = await _database.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM clip_entries');
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
