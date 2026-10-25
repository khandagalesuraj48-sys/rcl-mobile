/* THE APP LOCK (3.27.0, asked 20-10-2026: "ॲप उघडायला Fingerprint / Face lock … KR PERFECT"; his choices: for everyone, on by
 * itself and it cannot be switched off; asked again when the app was away for more than a minute).
 *   – The app opens with a kept sign-in → it is locked: the phone's own fingerprint / face – or its PIN / pattern / password – opens
 *     it (Android: BiometricPrompt; iPhone: Face ID / Touch ID; the computer app: Windows Hello). Nothing of the ERP is shown before.
 *   – The app was in the background (another app, the screen off) for more than [away] → locked again when it comes back.
 *   – A sign-in typed just now (the password) is not asked again.
 *   – A phone with NO screen lock at all: the app is not stopped (the people at the sites must be able to work) – it says, in red,
 *     to set a screen lock on the phone. The same when the phone cannot ask (no such part on that device).
 * Nothing goes to the server: the fingerprint / face never leaves the phone (the phone only answers "it is him" or not). */
import 'package:flutter/foundation.dart';

/// How the phone is asked (local_auth on the phone – lock_gate.dart; a pretend one in the tests).
abstract class LockGate {
  /// Asks the phone; [reason] is shown in the phone's own box.
  Future<LockAnswer> ask(String reason);
}

/// ok – it is him; no – he did not (cancelled, wrong finger); noLock – the phone has no screen lock / cannot ask; busy – asked already;
/// error – something else (said in [LockAnswer.text]).
enum LockOutcome { ok, no, noLock, busy, error }

class LockAnswer {
  const LockAnswer(this.outcome, [this.text = '']);
  final LockOutcome outcome;
  final String text;
}

class AppLock extends ChangeNotifier {
  AppLock(this.gate, {this.away = const Duration(minutes: 1)});
  final LockGate gate;
  final Duration away;
  DateTime Function() clock = DateTime.now;

  /// Locked until the phone says it is him (the app has just been opened).
  bool locked = true;
  /// Asking the phone right now.
  bool asking = false;
  /// The phone has no screen lock (or cannot ask): the app is open, with the red line.
  bool noLock = false;
  /// The last "no" / problem, for the lock screen.
  String said = '';
  int _errors = 0;
  DateTime? _left;
  bool _leftForPicker = false;

  /// (3.41.0, asked 25-10-2026: "complete process zal shiway madhech cut hou naye") the app's OWN camera, gallery or file box is open
  /// (a photo for an entry, Scan with Mobile, a bill copy …): the phone shows another screen, but the person is still at work in the
  /// app – the lock does not come in the middle of it. Only when that box stays open longer than [pickerAway] is it locked again.
  static int outside = 0;
  static const pickerAway = Duration(minutes: 10);

  /// [f] opens the app's own camera / gallery / file box – while it is open the app is not "away".
  static Future<T> whileOutside<T>(Future<T> Function() f) async {
    outside++;
    try {
      return await f();
    } finally {
      outside--;
    }
  }

  /// The app went to the background (another app, the screen off).
  void away0() {
    if (asking) return; // (the phone's own PIN screen is another screen: not "away")
    if (_left == null) _leftForPicker = outside > 0;
    _left ??= clock();
  }

  /// The app is back: locked again when it was away for more than [away] (its own camera / file box: more than [pickerAway]).
  void back() {
    final l = _left;
    _left = null;
    if (asking || l == null || locked) return;
    if (clock().difference(l) >= (_leftForPicker ? pickerAway : away)) {
      locked = true;
      said = '';
      notifyListeners();
    }
  }

  /// A password typed just now (a fresh sign-in): not asked again.
  void signedIn() {
    _left = null;
    if (!locked) return;
    locked = false;
    said = '';
    notifyListeners();
  }

  /// Asks the phone (the lock screen does this by itself when it is shown, and on "Unlock").
  Future<void> unlock(String reason) async {
    if (!locked || asking) return;
    asking = true;
    said = '';
    notifyListeners();
    LockAnswer a;
    try {
      a = await gate.ask(reason);
    } catch (e) {
      a = LockAnswer(LockOutcome.error, '$e');
    }
    asking = false;
    switch (a.outcome) {
      case LockOutcome.ok:
        locked = false;
        noLock = false;
        _errors = 0;
      case LockOutcome.noLock:
        locked = false; // (never stops the work: the red line asks for a screen lock)
        noLock = true;
      case LockOutcome.no:
        said = a.text.isNotEmpty ? a.text : 'Not unlocked – press Unlock and try again.';
      case LockOutcome.busy:
        break;
      case LockOutcome.error:
        // the phone could not ask twice in a row (a fault of that phone): the app opens with the red line rather than stopping the work
        _errors++;
        if (_errors >= 2) {
          locked = false;
          noLock = true;
        } else {
          said = 'The phone could not ask for the fingerprint – press Unlock to try again.';
        }
    }
    _left = null;
    notifyListeners();
  }
}
