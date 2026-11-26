import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class DeviceSecurityService {
  DeviceSecurityService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;
  static const _channel = MethodChannel('com.resaneh.media/security');

  Future<bool> get hasBiometrics async =>
      await _auth.canCheckBiometrics &&
      (await _auth.getAvailableBiometrics()).isNotEmpty;

  Future<bool> authenticate() => _auth.authenticate(
    localizedReason: 'برای دسترسی به آرشیو خصوصی هویت خود را تأیید کنید.',
    biometricOnly: true,
    persistAcrossBackgrounding: false,
  );

  Future<void> setSecure(bool enabled) async {
    await _channel.invokeMethod<bool>('setSecure', {'enabled': enabled});
  }
}
