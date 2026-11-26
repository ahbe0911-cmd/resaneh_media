import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../data/database/search_index.dart';
import '../../data/database/database_schema.dart';
import 'backup_cipher.dart';

typedef BackupProgress = void Function(double? fraction, String stage);

class BackupService {
  BackupService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  static const _uuid = Uuid();
  static const _backupFormat = 1;
  static const _maximumEntries = 50000;
  static const _maximumBytes = 100 * 1024 * 1024 * 1024; // 100 GiB.
  static const _collections = ['database', 'vault', 'thumbnails'];
  static const _stageName = '.resaneh_restore_stage';
  static const _previousName = '.resaneh_restore_previous';
  static const _journalName = '.resaneh_restore_journal.json';

  Future<Directory> _root() => getApplicationDocumentsDirectory();

  Future<Directory> _scratch() async {
    final cache = await getTemporaryDirectory();
    final dir = Directory(p.join(cache.path, 'resaneh_backup_${_uuid.v4()}'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> createBackup({required String applicationId,
    String? password, BackupProgress? onProgress}) async {
    final scratch = await _scratch();
    final root = await _root();
    final zip = File(p.join(scratch.path, 'resaneh-backup.zip'));
    final snapshot = Directory(p.join(scratch.path, 'snapshot'));
    await snapshot.create(recursive: true);

    try {
      onProgress?.call(null, 'آماده‌سازی نسخه ثابت اطلاعات');
      // Closing SQLite makes the DB copy consistent, including WAL checkpoints.
      await _database.close();
      try {
        for (final folder in _collections) {
          final source = Directory(p.join(root.path, folder));
          if (await source.exists()) {
            await _copyDirectory(source, Directory(p.join(snapshot.path, folder)));
          }
        }
      } finally {
        // Reopen as early as possible; users can continue after ZIP creation.
        await _database.database;
      }

      final dbSnapshot = File(p.join(snapshot.path, 'database', 'resaneh_vault.db'));
      if (!await dbSnapshot.exists()) {
        throw StateError('پایگاه داده برای پشتیبان‌گیری یافت نشد.');
      }

      // A backup must remain portable to Android devices without FTS5.
      // Rebuild the derived indexes on restore; hashes cover the stripped copy.
      final copy = await openDatabase(dbSnapshot.path, singleInstance: false);
      try {
        await SearchIndex.removeFromBackup(copy);
      } finally {
        await copy.close();
      }

      await packSnapshot(snapshot: snapshot, scratch: scratch, zip: zip,
        applicationId: applicationId,
        onProgress: (value, label) => onProgress?.call(
          value == null ? null : value * (password == null ? 0.98 : 0.65), label));
      if (password != null) {
        final encrypted = File(p.join(scratch.path, 'resaneh-backup.rmb'));
        await _runWorker(_encrypt, [zip.path, encrypted.path, password],
          onProgress: (value, label) => onProgress?.call(
            value == null ? null : 0.65 + value * 0.34, label));
        await zip.delete();
        onProgress?.call(1, 'بکاپ آماده ذخیره است');
        return encrypted;
      }
      onProgress?.call(1, 'بکاپ آماده ذخیره است');
      return zip;
    } catch (_) {
      await scratch.delete(recursive: true);
      rethrow;
    } finally {
      if (await snapshot.exists()) await snapshot.delete(recursive: true);
    }
  }

  static Future<void> _runWorker(
    Future<void> Function(List<String>, SendPort) task, List<String> args,
    {BackupProgress? onProgress}
  ) async {
    final port = ReceivePort();
    final subscription = port.listen((message) {
      if (message is List && message.length == 2) {
        onProgress?.call((message[0] as num?)?.toDouble(), message[1] as String);
      }
    });
    final send = port.sendPort;
    try {
      await _executeWorker(task, args, send);
    } finally {
      await subscription.cancel();
      port.close();
    }
  }

  // Keep the isolate closure in its own scope: no UI callbacks, database
  // handles, ReceivePorts or service instances may be captured.
  static Future<void> _executeWorker(
      Future<void> Function(List<String>, SendPort) task,
      List<String> args, SendPort send) =>
      Isolate.run(() => task(args, send));

  static Future<void> packSnapshot({
    required Directory snapshot, required Directory scratch, required File zip,
    required String applicationId, BackupProgress? onProgress,
  }) => _runWorker(_pack, [snapshot.path, scratch.path, zip.path, applicationId],
    onProgress: onProgress);

  static Future<void> unpackSnapshot({
    required File zip, required Directory destination,
    required String applicationId, BackupProgress? onProgress,
  }) => _runWorker(_unpack, [zip.path, destination.path, applicationId],
    onProgress: onProgress);

  static Future<void> _pack(List<String> args, SendPort send) async {
    final snapshot = Directory(args[0]);
    final scratch = Directory(args[1]);
    final zip = File(args[2]);
    final applicationId = args[3];
      final files = await _filesRecursively(snapshot);
      final entries = <Map<String, Object?>>[];
      var totalBytes = 0;
      var done = 0;
      final total = files.length;
      send.send([0.0, 'محاسبه هش فایل‌ها']);
      for (final file in files) {
        final rel = p.relative(file.path, from: snapshot.path).replaceAll('\\', '/');
        if (!_allowedFilePath('data/$rel')) {
          done++;
          continue;
        }
        final bytes = await file.length();
        totalBytes += bytes;
        if (entries.length >= _maximumEntries - 1 || totalBytes > _maximumBytes) {
          throw const FormatException('حجم یا تعداد فایل‌های بکاپ بیش از حد مجاز است.');
        }
        entries.add({
          'path': 'data/$rel',
          'bytes': bytes,
          'sha256': (await sha256.bind(file.openRead()).first).toString(),
        });
        send.send([total == 0 ? 0.0 : 0.4 * ++done / total, 'محاسبه هش فایل‌ها']);
      }
      if (!entries.any((entry) => entry['path'] == 'data/database/resaneh_vault.db')) {
        throw StateError('پایگاه داده در نسخه پشتیبان وجود ندارد.');
      }
      final manifest = File(p.join(scratch.path, 'manifest.json'));
      await manifest.writeAsString(jsonEncode({
        'format': _backupFormat,
        'applicationId': applicationId,
        'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
        'pinIncluded': false,
        'entries': entries,
      }), flush: true);

      final manifestBytes = await manifest.length();
      if (manifestBytes > 20 * 1024 * 1024 || totalBytes + manifestBytes > _maximumBytes) {
        throw const FormatException('اندازه manifest یا بکاپ بیش از حد مجاز است.');
      }
      final encoder = ZipFileEncoder();
      encoder.create(zip.path);
      try {
        await encoder.addFile(manifest, 'manifest.json');
        var packed = 0;
        for (final entry in entries) {
          final name = entry['path']! as String;
          final source = File(p.join(snapshot.path, name.substring('data/'.length)));
          await encoder.addFile(source, name);
          send.send([0.4 + 0.6 * ++packed / entries.length, 'فشرده‌سازی ZIP']);
        }
      } finally {
        await encoder.close();
      }

  }

  static Future<void> _encrypt(List<String> args, SendPort send) async {
    send.send([null, 'مشتق‌سازی کلید رمزگذاری']);
    await BackupCipher.encrypt(File(args[0]), File(args[1]), args[2],
      progress: (done, total) => send.send([done / total, 'رمزگذاری بکاپ']));
  }

  static Future<void> _decrypt(List<String> args, SendPort send) async {
    send.send([null, 'بررسی رمز بکاپ']);
    await BackupCipher.decrypt(File(args[0]), File(args[1]), args[2],
      progress: (done, total) => send.send([done / total, 'رمزگشایی بکاپ']));
  }

  static Future<void> _unpack(List<String> args, SendPort send) =>
      _extractValidatedZip(File(args[0]), Directory(args[1]), args[2],
        (fraction, stage) => send.send([fraction, stage]));

  Future<void> deleteExportTemp(File zip) async {
    final directory = zip.parent;
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> restoreBackup({
    required File zip,
    required String applicationId,
    String? password, BackupProgress? onProgress,
  }) async {
    final scratch = await _scratch();
    final extracted = Directory(p.join(scratch.path, 'extracted'));
    await extracted.create(recursive: true);
    try {
      final encrypted = await BackupCipher.isEncrypted(zip);
      var source = zip;
      if (encrypted) {
        if (password == null) throw const FormatException('این بکاپ رمز دارد.');
        source = File(p.join(scratch.path, 'decrypted.zip'));
        await _runWorker(_decrypt, [zip.path, source.path, password],
          onProgress: (value, stage) => onProgress?.call(
            value == null ? null : value * 0.30, stage));
      }
      await unpackSnapshot(zip: source, destination: extracted, applicationId: applicationId,
        onProgress: (value, stage) => onProgress?.call(value == null ? null :
          (encrypted ? 0.30 + value * 0.55 : value * 0.85), stage));
      if (encrypted) await source.delete();
      onProgress?.call(null, 'اعتبارسنجی دیتابیس');
      final database = File(p.join(extracted.path, 'data', 'database', 'resaneh_vault.db'));
      await _validateSqlite(database, extracted);
      onProgress?.call(null, 'جایگزینی ایمن اطلاعات');
      await _commitRestore(Directory(p.join(extracted.path, 'data')));
      onProgress?.call(1, 'بازیابی کامل شد');
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  static Future<void> _extractValidatedZip(
    File zip,
    Directory destination,
    String applicationId,
    BackupProgress progress,
  ) async {
    progress(null, 'خواندن ساختار ZIP');
    if (!await zip.exists()) throw StateError('فایل ZIP وجود ندارد.');
    final input = InputFileStream(zip.path);
    final actual = <String, int>{};
    try {
      final archive = ZipDecoder().decodeStream(
        input, verify: true, throwOnError: true,
      );
      var count = 0;
      var total = 0;
      for (final entry in archive) {
        if (entry.isSymbolicLink) {
          throw const FormatException('پیوند نمادین در ZIP مجاز نیست.');
        }
        if (!entry.isFile) {
          // Directory entries are unnecessary; refuse to avoid ambiguous names.
          throw const FormatException('ساختار پوشه ZIP معتبر نیست.');
        }
        final name = entry.name;
        if (!_allowedFilePath(name) || actual.containsKey(name)) {
          throw FormatException('مسیر نامعتبر یا تکراری: $name');
        }
        count++;
        total += entry.size;
        if (count > _maximumEntries || total > _maximumBytes || entry.size < 0) {
          throw const FormatException('محدودیت تعداد یا حجم فایل‌های ZIP رعایت نشده است.');
        }
        if (name == 'manifest.json' && entry.size > 20 * 1024 * 1024) {
          throw const FormatException('manifest بیش از حد بزرگ است.');
        }
        final outputPath = p.normalize(p.join(destination.path, p.joinAll(name.split('/'))));
        if (!p.isWithin(destination.path, outputPath)) {
          throw const FormatException('مسیر ZIP خارج از پوشه امن است.');
        }
        await Directory(p.dirname(outputPath)).create(recursive: true);
        final output = OutputFileStream(outputPath);
        try {
          entry.writeContent(output);
        } finally {
          output.closeSync();
        }
        final diskSize = await File(outputPath).length();
        if (diskSize != entry.size) {
          throw FormatException('حجم واقعی فایل با ZIP برابر نیست: $name');
        }
        actual[name] = diskSize;
        progress(0.6 * count / archive.length, 'استخراج فایل‌ها');
      }
    } finally {
      input.closeSync();
    }

    final manifestFile = File(p.join(destination.path, 'manifest.json'));
    if (!await manifestFile.exists() || await manifestFile.length() > 20 * 1024 * 1024) {
      throw const FormatException('فایل manifest وجود ندارد یا بیش از حد بزرگ است.');
    }
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('ساختار manifest صحیح نیست.');
    }
    if (decoded['format'] != _backupFormat || decoded['applicationId'] != applicationId) {
      throw const FormatException('نسخه یا نوع اپلیکیشن این بکاپ سازگار نیست.');
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const FormatException('فهرست فایل‌های بکاپ معتبر نیست.');
    }
    final expected = <String>{};
    for (final raw in rawEntries) {
      if (raw is! Map<String, dynamic>) throw const FormatException('رکورد فایل نامعتبر است.');
      final name = raw['path'];
      final bytes = raw['bytes'];
      final checksum = raw['sha256'];
      if (name is! String || bytes is! int || checksum is! String ||
          !_allowedFilePath(name) || name == 'manifest.json' || !expected.add(name)) {
        throw const FormatException('فهرست فایل‌ها حاوی مسیر نامعتبر است.');
      }
      if (actual[name] != bytes) throw FormatException('فایل بکاپ ناقص است: $name');
      final file = File(p.join(destination.path, p.joinAll(name.split('/'))));
      final digest = (await sha256.bind(file.openRead()).first).toString();
      if (digest != checksum) throw FormatException('فایل بکاپ آسیب دیده است: $name');
      progress(0.6 + 0.4 * expected.length / rawEntries.length, 'اعتبارسنجی هش فایل‌ها');
    }
    if (!expected.contains('data/database/resaneh_vault.db') ||
        actual.length != expected.length + 1) {
      throw const FormatException('محتوای بکاپ با فهرست manifest مطابقت ندارد.');
    }
  }

  static bool _allowedFilePath(String path) {
    if (path == 'manifest.json') return true;
    if (path.contains('\\') || path.startsWith('/') || path.contains('//') ||
        path.split('/').any((segment) => segment.isEmpty || segment == '.' || segment == '..')) {
      return false;
    }
    if (path == 'data/database/resaneh_vault.db') return true;
    if (path.startsWith('data/vault/')) {
      final file = path.substring('data/vault/'.length);
      return RegExp(r'^[0-9a-f-]{36}(\.[a-z0-9]{1,12})?$').hasMatch(file);
    }
    if (path.startsWith('data/thumbnails/')) {
      final file = path.substring('data/thumbnails/'.length);
      return RegExp(r'^[0-9a-f-]{36}\.jpg$').hasMatch(file);
    }
    return false;
  }

  Future<void> _validateSqlite(File file, Directory extracted) async {
    final db = await openDatabase(file.path, readOnly: true, singleInstance: false);
    try {
      final version = await db.getVersion();
      if (version < 1 || version > DatabaseSchema.version) {
        throw const FormatException('نسخه دیتابیس بکاپ پشتیبانی نمی‌شود.');
      }
      final status = await db.rawQuery('PRAGMA quick_check');
      if (status.isEmpty || status.first.values.first != 'ok') {
        throw const FormatException('یکپارچگی پایگاه داده قابل تأیید نیست.');
      }
      final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'");
      final names = tables.map((row) => row['name']).toSet();
      if (!names.containsAll([
        'media_items', 'tags', 'media_tags', 'clip_entries', 'app_settings'
      ])) {
        throw const FormatException('جداول لازم دیتابیس در بکاپ موجود نیستند.');
      }
      final rows = await db.query('media_items',
          columns: ['relative_path', 'thumbnail_path']);
      for (final row in rows) {
        final relative = row['relative_path'];
        final thumbnail = row['thumbnail_path'];
        if (relative is! String || !relative.startsWith('vault/') || !_allowedFilePath('data/$relative')) {
          throw const FormatException('مسیر فایل در دیتابیس نامعتبر است.');
        }
        final original = File(p.join(extracted.path, 'data', relative));
        if (!await original.exists()) throw FormatException('فایل آرشیو یافت نشد: $relative');
        if (thumbnail != null) {
          if (thumbnail is! String || !thumbnail.startsWith('thumbnails/') || !_allowedFilePath('data/$thumbnail')) {
            throw const FormatException('مسیر تصویر پیش‌نمایش نامعتبر است.');
          }
          if (!await File(p.join(extracted.path, 'data', thumbnail)).exists()) {
            throw const FormatException('تصویر پیش‌نمایش در بکاپ وجود ندارد.');
          }
        }
      }
    } finally {
      await db.close();
    }
  }

  Future<void> _commitRestore(Directory restoredData) async {
    final root = await _root();
    final stage = Directory(p.join(root.path, _stageName));
    final previous = Directory(p.join(root.path, _previousName));
    final journal = File(p.join(root.path, _journalName));

    await recoverInterruptedRestore();
    await stage.create(recursive: true);
    try {
      for (final folder in _collections) {
        final source = Directory(p.join(restoredData.path, folder));
        final target = Directory(p.join(stage.path, folder));
        if (await source.exists()) {
          await _copyDirectory(source, target);
        } else {
          await target.create(recursive: true);
        }
      }
      await _database.close();
      final hadOriginal = <String, bool>{};
      for (final folder in _collections) {
        hadOriginal[folder] = await Directory(p.join(root.path, folder)).exists();
      }
      final temporaryJournal = File('${journal.path}.tmp');
      await temporaryJournal.writeAsString(jsonEncode(hadOriginal), flush: true);
      await temporaryJournal.rename(journal.path);
      try {
        await previous.create(recursive: true);
        for (final folder in _collections) {
          final original = Directory(p.join(root.path, folder));
          if (await original.exists()) {
            await original.rename(p.join(previous.path, folder));
          }
        }
        for (final folder in _collections) {
          await Directory(p.join(stage.path, folder))
              .rename(p.join(root.path, folder));
        }
        await _database.database;
        await journal.delete(); // The new data are committed.
      } catch (_) {
        await recoverInterruptedRestore();
        rethrow;
      }
    } finally {
      if (await stage.exists()) await stage.delete(recursive: true);
      if (!await journal.exists() && await previous.exists()) {
        await previous.delete(recursive: true);
      }
    }
  }

  /// Remove only abandoned, app-owned backup scratch folders on cold start.
  Future<void> clearAbandonedScratch() async {
    final cache = await getTemporaryDirectory();
    if (!await cache.exists()) return;
    await for (final entity in cache.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = p.basename(entity.path);
      if (name == 'resaneh_backup_imports' ||
          RegExp(r'^resaneh_backup_[0-9a-f-]{36}
  Future<void> recoverInterruptedRestore() async {
    final root = await _root();
    final journal = File(p.join(root.path, _journalName));
    final previous = Directory(p.join(root.path, _previousName));
    final stage = Directory(p.join(root.path, _stageName));
    if (!await journal.exists()) {
      final temporaryJournal = File('${journal.path}.tmp');
      if (await temporaryJournal.exists()) await temporaryJournal.delete();
      if (await previous.exists()) await previous.delete(recursive: true);
      if (await stage.exists()) await stage.delete(recursive: true);
      return;
    }
    final decoded = jsonDecode(await journal.readAsString());
    if (decoded is! Map<String, dynamic>) throw StateError('Restore recovery journal is corrupt.');
    await _database.close();
    for (final folder in _collections) {
      final current = Directory(p.join(root.path, folder));
      final original = Directory(p.join(previous.path, folder));
      if (await original.exists()) {
        // The original was already moved; restore it, discarding any new data.
        if (await current.exists()) await current.delete(recursive: true);
        await original.rename(current.path);
      } else if (decoded[folder] == false) {
        // No original existed; a newly installed folder can be discarded.
        if (await current.exists()) await current.delete(recursive: true);
      } else if (!await current.exists()) {
        // Crash after journal creation but before moving this original.
        throw StateError('Missing original $folder during recovery.');
      }
    }
    await journal.delete();
    if (await previous.exists()) await previous.delete(recursive: true);
    if (await stage.exists()) await stage.delete(recursive: true);
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      if (entity is Link) throw StateError('پیوند نمادین برای بکاپ مجاز نیست.');
      final relative = p.relative(entity.path, from: source.path);
      final newPath = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(p.dirname(newPath)).create(recursive: true);
        await entity.copy(newPath);
      }
    }
  }

  static Future<List<File>> _filesRecursively(Directory directory) async {
    final result = <File>[];
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is Link) throw StateError('پیوند نمادین در آرشیو مجاز نیست.');
      if (entity is File) result.add(entity);
    }
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }
}
).hasMatch(name)) {
        try { await entity.delete(recursive: true); } on FileSystemException {
          // OS cache cleanup may already have removed this directory.
        }
      }
    }
  }

  /// Run before the application opens its database to recover after a crash.
  Future<void> recoverInterruptedRestore() async {
    final root = await _root();
    final journal = File(p.join(root.path, _journalName));
    final previous = Directory(p.join(root.path, _previousName));
    final stage = Directory(p.join(root.path, _stageName));
    if (!await journal.exists()) {
      final temporaryJournal = File('${journal.path}.tmp');
      if (await temporaryJournal.exists()) await temporaryJournal.delete();
      if (await previous.exists()) await previous.delete(recursive: true);
      if (await stage.exists()) await stage.delete(recursive: true);
      return;
    }
    final decoded = jsonDecode(await journal.readAsString());
    if (decoded is! Map<String, dynamic>) throw StateError('Restore recovery journal is corrupt.');
    await _database.close();
    for (final folder in _collections) {
      final current = Directory(p.join(root.path, folder));
      final original = Directory(p.join(previous.path, folder));
      if (await original.exists()) {
        // The original was already moved; restore it, discarding any new data.
        if (await current.exists()) await current.delete(recursive: true);
        await original.rename(current.path);
      } else if (decoded[folder] == false) {
        // No original existed; a newly installed folder can be discarded.
        if (await current.exists()) await current.delete(recursive: true);
      } else if (!await current.exists()) {
        // Crash after journal creation but before moving this original.
        throw StateError('Missing original $folder during recovery.');
      }
    }
    await journal.delete();
    if (await previous.exists()) await previous.delete(recursive: true);
    if (await stage.exists()) await stage.delete(recursive: true);
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: true, followLinks: false)) {
      if (entity is Link) throw StateError('پیوند نمادین برای بکاپ مجاز نیست.');
      final relative = p.relative(entity.path, from: source.path);
      final newPath = p.join(target.path, relative);
      if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      } else if (entity is File) {
        await Directory(p.dirname(newPath)).create(recursive: true);
        await entity.copy(newPath);
      }
    }
  }

  static Future<List<File>> _filesRecursively(Directory directory) async {
    final result = <File>[];
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is Link) throw StateError('پیوند نمادین در آرشیو مجاز نیست.');
      if (entity is File) result.add(entity);
    }
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }
}
