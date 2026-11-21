import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_schema.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Future<Database>? _databaseFuture;
  Future<Database> get database => _databaseFuture ??= _openDatabase();

  Future<Database> _openDatabase() async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'database'));
    await folder.create(recursive: true);
    return openDatabase(
      p.join(folder.path, 'resaneh_vault.db'),
      version: DatabaseSchema.version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async => DatabaseSchema.create(db),
      onUpgrade: (db, from, to) async => DatabaseSchema.upgrade(db, from, to),
    );
  }

  Future<void> close() async {
    final future = _databaseFuture;
    _databaseFuture = null;
    if (future != null) {
      final db = await future;
      await db.close();
    }
  }

  Future<void> deleteDatabaseFile() async {
    await close();
    final root = await getApplicationDocumentsDirectory();
    final path = p.join(root.path, 'database', 'resaneh_vault.db');
    await databaseFactory.deleteDatabase(path);
  }
}
