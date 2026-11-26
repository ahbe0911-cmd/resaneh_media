import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:resaneh_media/services/backup/backup_cipher.dart';
import 'package:resaneh_media/services/backup/backup_service.dart';

void main() {
  test('encrypted backup round trip, wrong password and corruption', () async {
    final root = await Directory.systemTemp.createTemp('resaneh-crypto-');
    try {
      final plain = File(p.join(root.path, 'source.zip'));
      final data = List<int>.generate(BackupCipher.chunkBytes + 17, (i) => i % 251);
      await plain.writeAsBytes(data);
      final encrypted = File(p.join(root.path, 'backup.rmb'));
      final restored = File(p.join(root.path, 'restored.zip'));
      const password = 'رمز-آزمایشی-2026';
      await BackupCipher.encrypt(plain, encrypted, password);
      expect(await BackupCipher.isEncrypted(encrypted), isTrue);
      expect(await BackupCipher.isEncrypted(plain), isFalse);
      await BackupCipher.decrypt(encrypted, restored, password);
      expect(await restored.readAsBytes(), orderedEquals(data));
      final wrong = File(p.join(root.path, 'wrong.zip'));
      await expectLater(BackupCipher.decrypt(encrypted, wrong, 'wrong-password'),
        throwsFormatException);
      expect(await wrong.exists(), isFalse);
      final bytes = await encrypted.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await encrypted.writeAsBytes(bytes);
      await expectLater(BackupCipher.decrypt(encrypted, wrong, password),
        throwsFormatException);
      expect(await wrong.exists(), isFalse);
      await encrypted.writeAsBytes(bytes.sublist(0, bytes.length - 1));
      await expectLater(BackupCipher.decrypt(encrypted, wrong, password),
        throwsFormatException);
      expect(await wrong.exists(), isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('legacy format 1 ZIP worker round trip and flavor validation', () async {
    final root = await Directory.systemTemp.createTemp('resaneh-zip-');
    try {
      final snapshot = await Directory(p.join(root.path, 'snapshot')).create();
      final database = await Directory(p.join(snapshot.path, 'database')).create();
      await File(p.join(database.path, 'resaneh_vault.db')).writeAsString('snapshot');
      final vault = await Directory(p.join(snapshot.path, 'vault')).create();
      const name = '12345678-1234-1234-1234-123456789001.pdf';
      await File(p.join(vault.path, name)).writeAsString('sample');
      final zip = File(p.join(root.path, 'backup.zip'));
      const id = 'com.resaneh.ketabkhaneh';
      await BackupService.packSnapshot(snapshot: snapshot, scratch: root,
        zip: zip, applicationId: id);
      final destination = await Directory(p.join(root.path, 'restore')).create();
      await BackupService.unpackSnapshot(zip: zip, destination: destination,
        applicationId: id);
      expect(await File(p.join(destination.path, 'data', 'vault', name)).readAsString(),
        'sample');
      final wrong = await Directory(p.join(root.path, 'wrong')).create();
      await expectLater(BackupService.unpackSnapshot(zip: zip, destination: wrong,
        applicationId: 'com.resaneh.kafinet'), throwsFormatException);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
