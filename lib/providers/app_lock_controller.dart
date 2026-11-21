import 'package:flutter/foundation.dart';

import '../services/security/app_lock_service.dart';

class AppLockController extends ChangeNotifier {
  AppLockController({required AppLockService service}) : _service = service;
  final AppLockService _service;

  bool _ready = false;
  bool _enabled = false;
  bool _unlocked = false;
  String? _error;
  bool get isReady => _ready;
  bool get enabled => _enabled;
  bool get unlocked => !_enabled || _unlocked;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      _enabled = await _service.enabled;
      _unlocked = !_enabled;
      _ready = true;
      notifyListeners();
    } catch (error) {
      _error = error.toString();
      _ready = true;
      _enabled = true;
      _unlocked = false;
      notifyListeners();
    }
  }

  void lock() {
    if (!_enabled) return;
    _unlocked = false;
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    final valid = await _service.verify(pin);
    if (valid) {
      _unlocked = true;
      _error = null;
      notifyListeners();
    }
    return valid;
  }

  Future<void> enable(String pin) async {
    await _service.setPin(pin);
    _enabled = true;
    _unlocked = true;
    _error = null;
    notifyListeners();
  }

  Future<void> change(String oldPin, String newPin) async {
    await _service.setPin(newPin, currentPin: oldPin);
    _enabled = true;
    _unlocked = true;
    notifyListeners();
  }

  Future<void> disable(String pin) async {
    await _service.removePin(pin);
    _enabled = false;
    _unlocked = true;
    notifyListeners();
  }

  void afterFactoryReset() {
    _enabled = false;
    _unlocked = true;
    _error = null;
    _ready = true;
    notifyListeners();
  }
}
