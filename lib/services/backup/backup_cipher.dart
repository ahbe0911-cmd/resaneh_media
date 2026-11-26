import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Resaneh encrypted backup envelope v2. All ZIP bytes (including names and
/// manifest) are encrypted. Each fixed-size record authenticates the header
/// and its index; the authenticated total size detects truncation and append.
class BackupCipher {
  BackupCipher._();
  static const magic = [82, 83, 78, 72, 66, 75, 2, 0];
  static const chunkBytes = 1024 * 1024;
  static const maxBytes = 105 * 1024 * 1024 * 1024;
  static const _headerBytes = 40;
  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2(macAlgorithm: Hmac.sha256(),
    iterations: 600000, bits: 256);

  static Future<bool> isEncrypted(File file) async {
    final input = await file.open();
    try {
      final prefix = await input.read(magic.length);
      return prefix.length == magic.length &&
          List.generate(magic.length, (i) => prefix[i] == magic[i]).every((x) => x);
    } finally {
      await input.close();
    }
  }

  static Uint8List _random(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
  }

  static Uint8List _counter(int index) =>
      (ByteData(4)..setUint32(0, index, Endian.big)).buffer.asUint8List();

  static List<int> _nonce(Uint8List header, int index) =>
      [...header.sublist(24, 32), ..._counter(index)];

  static List<int> _aad(Uint8List header, int index) =>
      [...header, ..._counter(index)];

  static Future<SecretKey> _key(String password, Uint8List header) =>
      _kdf.deriveKeyFromPassword(password: password, nonce: header.sublist(8, 24));

  static Future<void> encrypt(File source, File destination, String password,
      {void Function(int, int)? progress}) async {
    if (password.runes.length < 8 || password.runes.length > 256) {
      throw ArgumentError('رمز بکاپ باید بین ۸ تا ۲۵۶ نویسه باشد.');
    }
    final length = await source.length();
    if (length <= 0 || length > maxBytes) throw const FormatException('حجم بکاپ نامعتبر است.');
    final header = Uint8List(_headerBytes)
      ..setRange(0, 8, magic)
      ..setRange(8, 24, _random(16))
      ..setRange(24, 32, _random(8));
    ByteData.sublistView(header).setUint64(32, length, Endian.big);
    final key = await _key(password, header);
    final input = await source.open();
    RandomAccessFile? output;
    var success = false;
    try {
      output = await destination.open(mode: FileMode.write);
      await output.writeFrom(header);
      var done = 0, index = 0;
      while (done < length) {
        final count = min(chunkBytes, length - done);
        final clear = await input.read(count);
        if (clear.length != count) throw const FormatException('فایل ورودی تغییر کرده است.');
        final box = await _cipher.encrypt(clear, secretKey: key,
          nonce: _nonce(header, index), aad: _aad(header, index));
        await output.writeFrom(box.cipherText);
        await output.writeFrom(box.mac.bytes);
        done += count;
        index++;
        progress?.call(done, length);
      }
      if ((await input.read(1)).isNotEmpty) throw const FormatException('فایل ورودی تغییر کرده است.');
      await output.flush();
      success = true;
    } finally {
      await input.close();
      await output?.close();
      if (!success && await destination.exists()) await destination.delete();
    }
  }

  static Future<void> decrypt(File source, File destination, String password,
      {void Function(int, int)? progress}) async {
    if (password.isEmpty || password.runes.length > 256) {
      throw const FormatException('رمز بکاپ را وارد کنید.');
    }
    final input = await source.open();
    RandomAccessFile? output;
    var success = false;
    try {
      final header = await input.read(_headerBytes);
      if (header.length != _headerBytes ||
          !List.generate(magic.length, (i) => header[i] == magic[i]).every((x) => x)) {
        throw const FormatException('قالب بکاپ رمزگذاری‌شده معتبر نیست.');
      }
      final length = ByteData.sublistView(header).getUint64(32, Endian.big);
      if (length <= 0 || length > maxBytes) throw const FormatException('حجم بکاپ نامعتبر است.');
      final chunks = (length + chunkBytes - 1) ~/ chunkBytes;
      if (await input.length() != _headerBytes + length + chunks * 16) {
        throw const FormatException('بکاپ ناقص یا آسیب‌دیده است.');
      }
      final key = await _key(password, header);
      output = await destination.open(mode: FileMode.write);
      var done = 0, index = 0;
      while (done < length) {
        final count = min(chunkBytes, length - done);
        final cipher = await input.read(count);
        final tag = await input.read(16);
        if (cipher.length != count || tag.length != 16) {
          throw const FormatException('بکاپ ناقص است.');
        }
        final clear = await _cipher.decrypt(
          SecretBox(cipher, nonce: _nonce(header, index), mac: Mac(tag)),
          secretKey: key, aad: _aad(header, index),
        );
        await output.writeFrom(clear);
        done += count;
        index++;
        progress?.call(done, length);
      }
      await output.flush();
      success = true;
    } on SecretBoxAuthenticationError {
      throw const FormatException('رمز اشتباه است یا بکاپ دستکاری شده است.');
    } finally {
      await input.close();
      await output?.close();
      if (!success && await destination.exists()) await destination.delete();
    }
  }
}
