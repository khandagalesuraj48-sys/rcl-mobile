/* (3.27.0) The app lock asks the phone itself (local_auth). (3.127.0) Only the fingerprint / face – Android's BiometricPrompt, the
 * iPhone's Face ID / Touch ID – never the phone's own PIN / pattern / passcode (biometricOnly). See applock.dart. */
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'applock.dart';

class PhoneLockGate implements LockGate {
  final _a = LocalAuthentication();

  @override
  Future<LockAnswer> ask(String reason) async {
    try {
      final ok = await _a.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
      return LockAnswer(ok ? LockOutcome.ok : LockOutcome.no);
    } on LocalAuthException catch (e) {
      final c = e.code;
      if (c == LocalAuthExceptionCode.noCredentialsSet || c == LocalAuthExceptionCode.noBiometricHardware || c == LocalAuthExceptionCode.noBiometricsEnrolled) {
        return const LockAnswer(LockOutcome.noLock);
      }
      if (c == LocalAuthExceptionCode.authInProgress) return const LockAnswer(LockOutcome.busy);
      if (c == LocalAuthExceptionCode.temporaryLockout || c == LocalAuthExceptionCode.biometricLockout) {
        return const LockAnswer(LockOutcome.no, 'Too many tries – wait a little, or use your password.');
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

  /// (3.127.0) An iPhone says which one it has (Face ID / Touch ID); an Android phone only that it has one ("weak" / "strong") –
  /// then both are offered and its own popup takes the one that is set.
  @override
  Future<Set<String>> bios() async {
    try {
      final l = await _a.getAvailableBiometrics();
      return {
        if (l.contains(BiometricType.fingerprint)) 'finger',
        if (l.contains(BiometricType.face)) 'face',
        if (l.contains(BiometricType.weak) || l.contains(BiometricType.strong)) ...{'finger', 'face'},
      };
    } catch (_) {
      return {};
    }
  }
}
