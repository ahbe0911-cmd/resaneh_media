import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../security/app_lock_service.dart';
import '../import/incoming_file_service.dart';

class FactoryResetService {
  FactoryResetService({
    AppDatabase? database,
    AppLockService? lockService,
    IncomingFileService? incomingFileService,
  }) : _database = database ?? AppDatabase.instance,
       _lock = lockService ?? AppLockService(),
       _incoming = incomingFileService ?? IncomingFileService();

  final AppDatabase _database;
  final AppLockService _lock;
  final IncomingFileService _incoming;

  Future<void> reset() async {
    final root = await getApplicationDocumentsDirectory();
    await _database.close();
    // Database, vault, thumbnails and temporary material owned by this app.
    for (final name in <String>[
      'database', 'vault', 'thumbnails', 'temp',
      '.resaneh_restore_stage', '.resaneh_restore_previous',
    ]) {
      final directory = Directory(p.join(root.path, name));
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    final journal = File(p.join(root.path, '.resaneh_restore_journal.json'));
    if (await journal.exists()) await journal.delete();
    final temporaryJournal = File('${journal.path}.tmp');
    if (await temporaryJournal.exists()) await temporaryJournal.delete();
    await _lock.clearForFactoryReset();
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await _incoming.clearStaging();
    final cache = await getTemporaryDirectory();
    await for (final entity in cache.list(followLinks: false)) {
      if (entity is Directory &&
          (p.basename(entity.path) == 'resaneh_backup_imports' ||
              p.basename(entity.path).startsWith('resaneh_backup_'))) {
        await entity.delete(recursive: true);
      }
    }
    await _database.database;
  }
}
