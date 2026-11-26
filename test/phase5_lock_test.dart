import 'package:flutter_test/flutter_test.dart';
import 'package:resaneh_media/providers/app_lock_controller.dart';
import 'package:resaneh_media/services/security/app_lock_service.dart';
import 'package:resaneh_media/services/security/device_security_service.dart';

class MemoryLock extends AppLockService {
  bool bio = false;
  int timeout = 0;
  bool secure = true;
  @override
  Future<bool> get enabled async => true;
  @override
  Future<bool> get biometricsEnabled async => bio;
  @override
  Future<int> get timeoutMinutes async => timeout;
  @override
  Future<bool> get secureScreen async => secure;
  @override
  Future<bool> verify(String pin) async => pin == '1234';
  @override
  Future<void> setBiometrics(bool value) async { bio = value; }
  @override
  Future<void> setTimeout(int value) async { timeout = value; }
  @override
  Future<void> setSecureScreen(bool value) async { secure = value; }
}

class FakeDevice extends DeviceSecurityService {
  final flags = <bool>[];
  bool result = true;
  @override
  Future<bool> get hasBiometrics async => true;
  @override
  Future<bool> authenticate() async => result;
  @override
  Future<void> setSecure(bool value) async { flags.add(value); }
}

void main() {
  test('PIN required and immediate lock on background', () async {
    final device = FakeDevice();
    final lock = AppLockController(service: MemoryLock(), device: device);
    await lock.initialize();
    expect(lock.unlocked, isFalse);
    expect(await lock.unlock('0000'), isFalse);
    expect(await lock.unlock('1234'), isTrue);
    expect(await lock.unlockBiometric(), isFalse);
    await expectLater(lock.configureBiometrics(true, pin: '0000'),
      throwsStateError);
    await lock.configureBiometrics(true, pin: '1234');
    lock.onBackground();
    expect(lock.unlocked, isFalse);
    expect(await lock.unlockBiometric(), isFalse);
    lock.onForeground();
    expect(await lock.unlockBiometric(), isTrue);
    expect(lock.unlocked, isTrue);
    lock.dispose();
  });

  test('short background interval respects configured grace period', () async {
    final lock = AppLockController(service: MemoryLock(), device: FakeDevice());
    await lock.initialize();
    await lock.unlock('1234');
    await lock.setTimeout(1);
    lock.onBackground();
    expect(lock.unlocked, isTrue);
    lock.onForeground();
    expect(lock.unlocked, isTrue);
    lock.lock();
    expect(lock.unlocked, isFalse);
    lock.dispose();
  });

  test('cancelled biometrics cannot unlock and PIN remains available', () async {
    final service = MemoryLock()..bio = true;
    final device = FakeDevice()..result = false;
    final lock = AppLockController(service: service, device: device);
    await lock.initialize();
    expect(await lock.unlockBiometric(), isFalse);
    expect(lock.unlocked, isFalse);
    expect(await lock.unlock('1234'), isTrue);
    lock.dispose();
  });
}
