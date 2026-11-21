import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PIN is not stored in plain text. A salted PBKDF2-HMAC-SHA256 verifier
/// is protected by the OS-backed encrypted secure storage.
class AppLockService {
  AppLockService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _verifierKey = 'resaneh_pin_verifier_v1';
  static const _failureKey = 'resaneh_pin_failures_v1';
  static const _blockedUntilKey = 'resaneh_pin_blocked_until_v1';
  static const _iterations = 120000;

  Future<bool> get enabled async => (await _storage.read(key: _verifierKey)) != null;

  bool _validPin(String input) => RegExp(r'^\d{4}$').hasMatch(input);

  Future<void> setPin(String pin, {String? currentPin}) async {
    if (!_validPin(pin)) throw ArgumentError('رمز باید دقیقاً چهار رقم باشد.');
    if (await enabled) {
      if (currentPin == null || !await verify(currentPin)) {
        throw StateError('رمز فعلی صحیح نیست.');
      }
    }
    final random = Random.secure();
    final salt = List<int>.generate(24, (_) => random.nextInt(256));
    final digest = await compute(_derivePin, <Object>[pin, salt, _iterations]);
    final payload = jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'iterations': _iterations,
      'hash': base64Encode(digest),
    });
    await _storage.write(key: _verifierKey, value: payload);
    await _clearFailures();
  }

  Future<void> removePin(String currentPin) async {
    if (!await verify(currentPin)) throw StateError('رمز فعلی صحیح نیست.');
    await _storage.delete(key: _verifierKey);
    await _clearFailures();
  }

  Future<bool> verify(String pin) async {
    if (!_validPin(pin)) return false;
    final blockedUntil = int.tryParse(
          await _storage.read(key: _blockedUntilKey) ?? '',
        ) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < blockedUntil) {
      throw StateError('تلاش‌های زیاد؛ کمی بعد دوباره امتحان کنید.');
    }
    final payload = await _storage.read(key: _verifierKey);
    if (payload == null) return false;
    final values = jsonDecode(payload) as Map<String, dynamic>;
    final salt = base64Decode(values['salt'] as String);
    final expected = base64Decode(values['hash'] as String);
    final iterations = values['iterations'] as int;
    final candidate = await compute(
      _derivePin,
      <Object>[pin, salt, iterations],
    );
    var difference = expected.length ^ candidate.length;
    for (var i = 0; i < min(expected.length, candidate.length); i++) {
      difference |= expected[i] ^ candidate[i];
    }
    if (difference == 0) {
      await _clearFailures();
      return true;
    }
    final failures = 1 + (int.tryParse(
          await _storage.read(key: _failureKey) ?? '',
        ) ?? 0);
    await _storage.write(key: _failureKey, value: '$failures');
    if (failures >= 5) {
      await _storage.write(
        key: _blockedUntilKey,
        value: '${DateTime.now().add(const Duration(seconds: 45)).millisecondsSinceEpoch}',
      );
      await _storage.write(key: _failureKey, value: '0');
    }
    return false;
  }

  Future<void> _clearFailures() async {
    await _storage.delete(key: _failureKey);
    await _storage.delete(key: _blockedUntilKey);
  }

  Future<void> clearForFactoryReset() => _storage.deleteAll();
}

List<int> _derivePin(List<Object> args) {
  final password = utf8.encode(args[0] as String);
  final salt = (args[1] as List).cast<int>();
  final iterations = args[2] as int;
  if (iterations < 10000 || iterations > 1000000) {
    throw StateError('Invalid PIN verifier configuration');
  }
  final mac = Hmac(sha256, password);
  final first = mac.convert(<int>[...salt, 0, 0, 0, 1]).bytes;
  final output = List<int>.from(first);
  var previous = first;
  for (var i = 1; i < iterations; i++) {
    previous = mac.convert(previous).bytes;
    for (var j = 0; j < output.length; j++) {
      output[j] ^= previous[j];
    }
  }
  return output;
}
