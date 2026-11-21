import 'package:flutter/services.dart';

/// Android Storage Access Framework: transfers ZIP files without loading
/// their bytes into Dart memory or requesting broad storage permissions.
class BackupDocumentsChannel {
  const BackupDocumentsChannel();

  static const MethodChannel _channel = MethodChannel(
    'com.resaneh.media/backup_documents',
  );

  Future<bool> exportZip({
    required String sourcePath,
    required String suggestedName,
  }) async {
    return await _channel.invokeMethod<bool>('exportZip', {
          'sourcePath': sourcePath,
          'suggestedName': suggestedName,
        }) ?? false;
  }

  /// Returns a private temporary path, or null if the user cancelled.
  Future<String?> importZip() => _channel.invokeMethod<String>('importZip');
}
