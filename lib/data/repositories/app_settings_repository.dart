import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class AppSettingsRepository {
  AppSettingsRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  Future<String?> get(String key) async {
    final db = await _database.database;
    final rows = await db.query('app_settings',
        columns: ['setting_value'], where: 'setting_key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['setting_value'] as String;
  }

  Future<void> put(String key, String value) async {
    final db = await _database.database;
    await db.insert('app_settings', {
      'setting_key': key,
      'setting_value': value,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
