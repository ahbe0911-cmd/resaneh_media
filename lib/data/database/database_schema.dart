import 'package:sqflite/sqflite.dart';

class DatabaseSchema {
  DatabaseSchema._();
  static const int version = 2;

  static Future<void> create(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE media_items (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        original_name TEXT NOT NULL,
        stored_name TEXT NOT NULL,
        relative_path TEXT NOT NULL UNIQUE,
        thumbnail_path TEXT,
        checksum_sha256 TEXT,
        mime_type TEXT NOT NULL,
        file_type TEXT NOT NULL CHECK(file_type IN ('image','video','pdf','other')),
        file_size INTEGER NOT NULL DEFAULT 0,
        description TEXT NOT NULL DEFAULT '',
        search_text TEXT NOT NULL DEFAULT '',
        search_compact TEXT NOT NULL DEFAULT '',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL UNIQUE,
        compact_name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE media_tags (
        media_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        PRIMARY KEY (media_id, tag_id),
        FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE clip_entries (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        search_text TEXT NOT NULL DEFAULT '',
        search_compact TEXT NOT NULL DEFAULT '',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE app_settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_media_created ON media_items(created_at DESC)',
    );
    await db.execute('''
      CREATE INDEX idx_media_pinned
      ON media_items(is_pinned DESC, created_at DESC)
    ''');
    await db.execute(
      'CREATE INDEX idx_media_type ON media_items(file_type)',
    );
    await db.execute(
      'CREATE INDEX idx_media_search ON media_items(search_text)',
    );
    await db.execute(
      'CREATE INDEX idx_media_tags_tag ON media_tags(tag_id)',
    );
    await db.execute(
      'CREATE INDEX idx_tags_normalized ON tags(normalized_name)',
    );
    await db.execute(
      'CREATE INDEX idx_clip_created ON clip_entries(created_at DESC)',
    );
    await _createV2Indexes(db);
  }

  static Future<void> _createV2Indexes(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_size ON media_items(is_pinned DESC, file_size DESC, created_at DESC, id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_title ON media_items(is_pinned DESC, title COLLATE NOCASE ASC, id ASC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_media_type_order ON media_items(file_type, is_pinned DESC, created_at DESC, id DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_clip_pinned ON clip_entries(is_pinned DESC, created_at DESC, id DESC)');
  }

  static Future<void> upgrade(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var next = oldVersion + 1; next <= newVersion; next++) {
      switch (next) {
        case 2:
          await db.execute(
            'ALTER TABLE media_items ADD COLUMN checksum_sha256 TEXT',
          );
          await _createV2Indexes(db);
          break;
        default:
          throw StateError('Undefined migration to version $next');
      }
    }
  }
}
