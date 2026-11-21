import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/persian_normalizer.dart';
import '../database/app_database.dart';
import '../models/media_tag.dart';

class TagRepository {
  TagRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;
  static const _uuid = Uuid();

  static Future<String> ensureInTransaction(
    Transaction transaction,
    String name,
  ) async {
    final normalized = PersianNormalizer.normalize(name);
    if (normalized.isEmpty) throw ArgumentError('نام برچسب الزامی است.');
    final existing = await transaction.query(
      'tags', columns: ['id'], where: 'normalized_name = ?',
      whereArgs: [normalized], limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;
    await transaction.insert(
      'tags',
      {
        'id': _uuid.v4(),
        'name': name.trim(),
        'normalized_name': normalized,
        'compact_name': PersianNormalizer.compact(name),
        'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final rows = await transaction.query(
      'tags', columns: ['id'], where: 'normalized_name = ?',
      whereArgs: [normalized], limit: 1,
    );
    if (rows.isEmpty) throw StateError('خطا در ذخیره برچسب');
    return rows.first['id'] as String;
  }

  Future<MediaTag> createOrGet(String name) async {
    final db = await _database.database;
    late String id;
    await db.transaction((tx) async {
      id = await ensureInTransaction(tx, name);
    });
    final rows = await db.query('tags', where: 'id = ?', whereArgs: [id]);
    return MediaTag.fromMap(rows.single);
  }

  Future<List<MediaTag>> getAll() async {
    final db = await _database.database;
    final rows = await db.query('tags', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(MediaTag.fromMap).toList();
  }

  Future<int> deleteUnusedTags() async {
    final db = await _database.database;
    return db.delete(
      'tags',
      where: 'id NOT IN (SELECT DISTINCT tag_id FROM media_tags)',
    );
  }
}
