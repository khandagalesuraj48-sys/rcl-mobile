/* (3.27.0) The app lock asks the phone itself (local_auth): Android's BiometricPrompt (fingerprint / face, or the phone's PIN /
 * pattern / password), the iPhone's Face ID / Touch ID / passcode, Windows Hello on a computer. See applock.dart. */
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'applock.dart';

class PhoneLockGate implements LockGate {
  final _a = LocalAuthentication();

  @override
  Future<LockAnswer> ask(String reason) async {
    try {
      if (!await _a.isDeviceSupported()) return const LockAnswer(LockOutcome.noLock); // no screen lock, no fingerprint
      final ok = await _a.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
      return LockAnswer(ok ? LockOutcome.ok : LockOutcome.no);
    } on LocalAuthException catch (e) {
      final c = e.code;
      if (c == LocalAuthExceptionCode.noCredentialsSet || c == LocalAuthExceptionCode.noBiometricHardware || c == LocalAuthExceptionCode.noBiometricsEnrolled) {
        return const LockAnswer(LockOutcome.noLock);
      }
      if (c == LocalAuthExceptionCode.authInProgress) return const LockAnswer(LockOutcome.busy);
      if (c == LocalAuthExceptionCode.temporaryLockout || c == LocalAuthExceptionCode.biometricLockout) {
        return const LockAnswer(LockOutcome.no, 'Too many tries – wait a little, or use the phone\'s PIN.');
      }
      if (c == LocalAuthExceptionCode.userCanceled || c == LocalAuthExceptionCode.systemCanceled || c == LocalAuthExceptionCode.timeout || c == LocalAuthExceptionCode.userRequestedFallback) {
        return const LockAnswer(LockOutcome.no);
      }
      return LockAnswer(LockOutcome.error, e.description ?? c.name);
    } on MissingPluginException {
      return const LockAnswer(LockOutcome.noLock); // (this device has no such part)
    } on PlatformException catch (e) {
      return LockAnswer(LockOutcome.error, e.message ?? e.code);
    }
  }
}
