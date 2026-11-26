import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:resaneh_media/core/utils/persian_normalizer.dart';
import 'package:resaneh_media/data/database/database_schema.dart';
import 'package:resaneh_media/data/database/search_index.dart';

void main() {
  sqfliteFfiInit();

  test('quoted Persian substring expressions and short query fallback', () {
    expect(SearchIndex.matchExpression('اب'), isNull);
    expect(SearchIndex.matchExpression('ثبت‌نام'),
      'normal : "ثبت نام" OR compact : "ثبتنام"');
    expect(SearchIndex.matchExpression('a"b'), contains('"a""b"'));
  });

  test('FTS index updates, portable backup and v2 schema', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseSchema.version,
        onCreate: (db, _) => DatabaseSchema.create(db),
        onOpen: SearchIndex.initialize,
      ));
    try {
      final columns = await db.rawQuery('PRAGMA table_info(media_items)');
      expect(columns.any((row) => row['name'] == 'checksum_sha256'), isTrue);
      expect(SearchIndex.enabled(db), isTrue);
      final text = PersianNormalizer.normalize('ثبت‌نام یارانه ۱۴۰۵');
      await db.insert('clip_entries', {
        'id': 'a', 'title': 'ثبت نام', 'body': 'یارانه',
        'search_text': text, 'search_compact': PersianNormalizer.compact(text),
        'created_at': 1, 'updated_at': 1,
      });
      Future<List<Map<String, Object?>>> search(String query) => db.rawQuery(
        'SELECT id FROM clip_fts WHERE clip_fts MATCH ?',
        [SearchIndex.matchExpression(query)],
      );
      expect(await search('بتنا'), hasLength(1));
      expect(await search('۱۴۰۵'), hasLength(1));
      await db.update('clip_entries', {'search_text': 'کتابخانه', 'search_compact': 'کتابخانه'},
        where: 'id=?', whereArgs: ['a']);
      expect(await search('یارانه'), isEmpty);
      expect(await search('تابخ'), hasLength(1));
      await SearchIndex.removeFromBackup(db);
      expect(await db.query('clip_entries'), hasLength(1));
      await SearchIndex.initialize(db);
      expect(await search('تابخ'), hasLength(1));
      await db.delete('clip_entries', where: 'id=?', whereArgs: ['a']);
      expect(await search('تابخ'), isEmpty);
    } finally {
      await db.close();
    }
  });

  test('migration v1 preserves existing archive and settings', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    try {
      // Build the old schema by removing the new nullable column and indexes.
      await DatabaseSchema.create(db);
      await db.execute('ALTER TABLE media_items DROP COLUMN checksum_sha256');
      await db.insert('app_settings', {
        'setting_key': 'theme_mode', 'setting_value': 'dark', 'updated_at': 1,
      });
      await db.insert('media_items', {
        'id': 'a', 'title': 'کتاب', 'original_name': 'book.pdf',
        'stored_name': 'a.pdf', 'relative_path': 'vault/a.pdf',
        'mime_type': 'application/pdf', 'file_type': 'pdf',
        'created_at': 1, 'updated_at': 1,
        'search_text': 'کتاب', 'search_compact': 'کتاب',
      });
      await DatabaseSchema.upgrade(db, 1, 2);
      await SearchIndex.initialize(db);
      expect(await db.query('media_items'), hasLength(1));
      expect((await db.query('app_settings')).single['setting_value'], 'dark');
      expect(await db.rawQuery('SELECT id FROM media_fts WHERE media_fts MATCH ?',
        [SearchIndex.matchExpression('کتاب')]), hasLength(1));
    } finally {
      await db.close();
    }
  });
}
