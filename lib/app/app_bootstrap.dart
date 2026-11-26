import 'package:flutter/material.dart';

import '../services/backup/backup_service.dart';
import 'flavor_config.dart';
import 'resaneh_app.dart';

Future<void> bootstrap(FlavorConfig flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Recover interrupted restore before any SQLite connection is opened.
  final backup = BackupService();
  await backup.recoverInterruptedRestore();
  await backup.clearAbandonedScratch();
  runApp(ResanehApp(config: flavor));
}
