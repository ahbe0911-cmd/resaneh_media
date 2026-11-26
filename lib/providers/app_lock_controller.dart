import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/security/app_lock_service.dart';
import '../services/security/device_security_service.dart';

class AppLockController extends ChangeNotifier {
  AppLockController({required AppLockService service, DeviceSecurityService? device})
      : _service = service, _device = device ?? DeviceSecurityService();
  final AppLockService _service;
  final DeviceSecurityService _device;

  bool _ready = false;
  bool _enabled = false;
  bool _unlocked = false;
  bool _biometric = false;
  bool _available = false;
  bool _secureScreen = true;
  bool _authenticating = false;
  bool _background = false;
  bool _disposed = false;
  int _timeoutMinutes = 0;
  int _epoch = 0;
  String? _error;
  final _away = Stopwatch();
  Timer? _timer;
  Future<void> _screenTask = Future<void>.value();

  bool get isReady => _ready;
  bool get enabled => _enabled;
  bool get unlocked => !_enabled || _unlocked;
  bool get biometricEnabled => _enabled && _biometric;
  bool get biometricAvailable => _available;
  bool get secureScreen => _secureScreen;
  int get timeoutMinutes => _timeoutMinutes;
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _syncScreen() {
    final value = !_ready || (_enabled && (!_unlocked || _secureScreen || _background));
    _screenTask = _screenTask.then((_) async {
      try {
        await _device.setSecure(value);
      } catch (_) {
        // Android starts with FLAG_SECURE set. Do not claim that an
        // unsuccessful platform call changed that protection.
      }
    });
  }

  Future<void> initialize() async {
    try {
      _enabled = await _service.enabled;
      _unlocked = !_enabled;
      _biometric = _enabled && await _service.biometricsEnabled;
      _timeoutMinutes = await _service.timeoutMinutes;
      _secureScreen = await _service.secureScreen;
    } catch (error) {
      _error = error.toString();
      _enabled = true;
      _unlocked = false;
      _biometric = false;
    }
    _ready = true;
    _syncScreen();
    _notify();
    await refreshBiometrics();
  }

  Future<void> refreshBiometrics() async {
    try {
      _available = await _device.hasBiometrics;
    } catch (_) {
      _available = false;
    }
    _notify();
  }

  void onBackground() {
    if (_background) return;
    _background = true;
    _epoch++;
    _away..reset()..start();
    _timer?.cancel();
    if (_enabled) {
      if (_timeoutMinutes == 0) {
        lock();
      } else {
        _timer = Timer(Duration(minutes: _timeoutMinutes), lock);
      }
    }
    _syncScreen();
    _notify();
  }

  void onForeground() {
    if (!_background) return;
    _background = false;
    _timer?.cancel();
    if (_enabled && _away.elapsed >= Duration(minutes: _timeoutMinutes)) {
      lock();
    }
    _away..stop()..reset();
    _syncScreen();
    _notify();
    unawaited(refreshBiometrics());
  }

  void lock() {
    if (!_enabled) return;
    _epoch++;
    _unlocked = false;
    _syncScreen();
    _notify();
  }

  Future<bool> unlock(String pin) async {
    if (!_enabled || _authenticating || _background) return false;
    final epoch = _epoch;
    _authenticating = true;
    try {
      final valid = await _service.verify(pin);
      if (valid && epoch == _epoch && !_background && !_disposed) {
        _unlocked = true;
        _error = null;
        _syncScreen();
        _notify();
        return true;
      }
      return false;
    } finally {
      _authenticating = false;
    }
  }

  Future<bool> unlockBiometric() async {
    if (!biometricEnabled || !_available || _authenticating || _background) return false;
    final epoch = _epoch;
    _authenticating = true;
    try {
      final ok = await _device.authenticate();
      if (ok && epoch == _epoch && !_background && !_disposed && biometricEnabled) {
        _unlocked = true;
        _error = null;
        _syncScreen();
        _notify();
        return true;
      }
      return false;
    } finally {
      _authenticating = false;
    }
  }

  Future<void> configureBiometrics(bool value, {String? pin}) async {
    if (!_enabled || !_unlocked || _authenticating || _background) {
      throw StateError('ابتدا قفل برنامه را باز کنید.');
    }
    final epoch = _epoch;
    _authenticating = true;
    try {
      if (value) {
        if (pin == null || !await _service.verify(pin)) {
          throw StateError('رمز فعلی صحیح نیست.');
        }
        if (!await _device.hasBiometrics || !await _device.authenticate()) {
          throw StateError('احراز هویت بیومتریک انجام نشد.');
        }
        if (_epoch != epoch || _background || !_unlocked) {
          throw StateError('برنامه قفل شد؛ دوباره تلاش کنید.');
        }
      }
      await _service.setBiometrics(value);
      _biometric = value;
      _notify();
    } finally {
      _authenticating = false;
    }
  }

  Future<void> setTimeout(int minutes) async {
    if (!_enabled || !_unlocked || ![0, 1, 5].contains(minutes)) return;
    await _service.setTimeout(minutes);
    _timeoutMinutes = minutes;
    _notify();
  }

  Future<void> setSecureScreen(bool value) async {
    if (!_enabled || !_unlocked) return;
    await _service.setSecureScreen(value);
    _secureScreen = value;
    _syncScreen();
    _notify();
  }

  Future<void> enable(String pin) async {
    await _service.setPin(pin);
    await _service.setBiometrics(false);
    _biometric = false;
    _enabled = true;
    _unlocked = !_background;
    _error = null;
    _syncScreen();
    _notify();
  }

  Future<void> change(String oldPin, String newPin) async {
    await _service.setPin(newPin, currentPin: oldPin);
    _enabled = true;
    _unlocked = !_background;
    _error = null;
    _syncScreen();
    _notify();
  }

  Future<void> disable(String pin) async {
    await _service.removePin(pin);
    _timer?.cancel();
    _epoch++;
    _enabled = false;
    _biometric = false;
    _unlocked = true;
    _error = null;
    _syncScreen();
    _notify();
  }

  void afterFactoryReset() {
    _timer?.cancel();
    _epoch++;
    _enabled = false;
    _biometric = false;
    _timeoutMinutes = 0;
    _secureScreen = true;
    _unlocked = true;
    _error = null;
    _ready = true;
    _syncScreen();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
