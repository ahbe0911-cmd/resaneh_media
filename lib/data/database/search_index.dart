import 'package:sqflite/sqflite.dart';

import '../../core/utils/persian_normalizer.dart';

/// FTS is derived data, never the source of truth. The trigram tokenizer
/// preserves substring matching (including Persian compact spellings).
/// Android SQLite builds without FTS5/trigram continue with the exact LIKE query.
class SearchIndex {
  SearchIndex._();
  static final _enabled = Expando<bool>();
  static const _tables = <String, String>{
    'media_fts': 'media_items',
    'clip_fts': 'clip_entries',
    'tags_fts': 'tags',
  };

  static bool enabled(Database db) => _enabled[db] == true;

  static Future<void> initialize(Database db) async {
    _enabled[db] = false;
    try {
      await db.execute(
        "CREATE VIRTUAL TABLE temp.resaneh_fts_probe USING fts5(value, tokenize='trigram')",
      );
      await db.execute('DROP TABLE temp.resaneh_fts_probe');
    } on DatabaseException catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('no such module') ||
          message.contains('no such tokenizer') ||
          message.contains('error in tokenizer constructor')) return;
      rethrow;
    }
    await db.transaction((tx) async {
      for (final entry in _tables.entries) {
        final index = entry.key;
        final table = entry.value;
        final normal = table == 'tags' ? 'normalized_name' : 'search_text';
        final compact = table == 'tags' ? 'compact_name' : 'search_compact';
        final existing = await tx.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [index],
        );
        if (existing.isEmpty) {
          await tx.execute(
            "CREATE VIRTUAL TABLE $index USING fts5(id UNINDEXED, normal, compact, tokenize='trigram')",
          );
          await tx.execute(
            'INSERT INTO $index(rowid, id, normal, compact) '
            'SELECT rowid, id, $normal, $compact FROM $table',
          );
        }
        await tx.execute('''
          CREATE TRIGGER IF NOT EXISTS ${index}_ai AFTER INSERT ON $table BEGIN
            INSERT INTO $index(rowid, id, normal, compact)
            VALUES(new.rowid, new.id, new.$normal, new.$compact);
          END
        ''');
        await tx.execute('''
          CREATE TRIGGER IF NOT EXISTS ${index}_ad AFTER DELETE ON $table BEGIN
            DELETE FROM $index WHERE rowid=old.rowid;
          END
        ''');
        await tx.execute('''
          CREATE TRIGGER IF NOT EXISTS ${index}_au AFTER UPDATE OF id, $normal, $compact ON $table BEGIN
            DELETE FROM $index WHERE rowid=old.rowid;
            INSERT INTO $index(rowid, id, normal, compact)
            VALUES(new.rowid, new.id, new.$normal, new.$compact);
          END
        ''');
      }
    });
    _enabled[db] = true;
  }

  /// Strip only derived search data from an exported copy, never the live vault.
  static Future<void> removeFromBackup(Database db) async {
    await db.transaction((tx) async {
      for (final index in _tables.keys) {
        for (final suffix in ['ai', 'ad', 'au']) {
          await tx.execute('DROP TRIGGER IF EXISTS ${index}_$suffix');
        }
        await tx.execute('DROP TABLE IF EXISTS $index');
      }
    });
    _enabled[db] = false;
  }

  static String? matchExpression(String input) {
    final normal = PersianNormalizer.normalize(input);
    final compact = PersianNormalizer.compact(input);
    // FTS5 trigram cannot match strings shorter than three Unicode characters.
    // Fall back for such queries, and for embedded NULs rejected by SQLite FTS.
    if (normal.runes.length < 3 || compact.runes.length < 3 ||
        normal.contains(String.fromCharCode(0))) return null;
    String quote(String value) => '"${value.replaceAll('"', '""')}"';
    return 'normal : ${quote(normal)} OR compact : ${quote(compact)}';
  }
}
