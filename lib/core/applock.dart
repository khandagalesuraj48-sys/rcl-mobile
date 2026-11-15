/* THE APP LOCK (3.27.0, asked 20-10-2026: "ॲप उघडायला Fingerprint / Face lock … KR PERFECT"; asked again when the app was away for
 * more than a minute).
 * (3.127.0, asked 15-11-2026: "app lock … by default ti on aahe – ata as nasel, te setting madhe asel – app la lock lawaych ki nahi
 * to user cha perspective asel, ani kas lawaych te user tharwel: pin thewaych ki password ki only finger ki only face – mhanje phone
 * lock cha nahi"; "jyani phone la lock nahi lawale tyana sakke notification jate lock lawaysathi – te ata band hoil") THE PERSON
 * CHOOSES:
 *   – OFF unless he himself turns it on (My settings → App lock) – for every person, also those who had it before.
 *   – He chooses how it opens: his own 4-digit PIN, his own password (both for this phone only – kept here as a salted fingerprint
 *     (SHA-256), never sent anywhere), only his fingerprint or only his face (the phone's own popup, WITHOUT the phone's PIN /
 *     pattern). The phone's own screen lock is not used any more, and nobody is told to set one.
 *   – Kept on this phone, for each person who signs in on it.
 *   – Forgot the PIN / password: he signs in again with his Sketchline password (the PIN / password he forgot is gone; he can set a
 *     new one). Fingerprint / face not working: "Use password instead" – the same sign-in (his choice stays). 5 wrong PINs /
 *     passwords: signed out – the sign-in with his Sketchline password opens it.
 *   – A sign-in typed just now (the password) is not asked again. Locked again after more than [away] in the background.
 * Nothing goes to the server: the fingerprint / face never leaves the phone (the phone only answers "it is him" or not). */
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'api.dart' show Keep;

/// How the phone is asked for the fingerprint / face (local_auth on the phone – lock_gate.dart; a pretend one in the tests).
abstract class LockGate {
  /// Asks the phone for the fingerprint / face only (never the phone's PIN); [reason] is shown in the phone's own popup.
  Future<LockAnswer> ask(String reason);

  /// (3.127.0) what this phone can open the app with: 'finger', 'face' (an iPhone says which one it has; an Android phone only says
  /// that it has one – both are offered, its own popup takes what is set). Empty: none is set on this phone.
  Future<Set<String>> bios();
}

/// ok – it is him; no – he did not (cancelled, wrong finger); noLock – no fingerprint / face is set on this phone; busy – asked
/// already; error – something else (said in [LockAnswer.text]).
enum LockOutcome { ok, no, noLock, busy, error }

class LockAnswer {
  const LockAnswer(this.outcome, [this.text = '']);
  final LockOutcome outcome;
  final String text;
}

/// (3.127.0) what a person chose: [how] 'pin' | 'password' | 'finger' | 'face'; for a PIN / password its salted fingerprint.
class LockChoice {
  const LockChoice(this.how, {this.salt = '', this.hash = ''});
  final String how, salt, hash;
  bool get code => how == 'pin' || how == 'password';
  Map<String, String> toJson() => {'how': how, if (code) 'salt': salt, if (code) 'hash': hash};
  static LockChoice? fromJson(Object? j) {
    if (j is! Map) return null;
    final how = '${j['how'] ?? ''}';
    if (!const ['pin', 'password', 'finger', 'face'].contains(how)) return null;
    final c = LockChoice(how, salt: '${j['salt'] ?? ''}', hash: '${j['hash'] ?? ''}');
    return c.code && (c.salt.isEmpty || c.hash.isEmpty) ? null : c;
  }
}

/// The words of each way (My settings → App lock).
String lockWay(String how) => switch (how) { 'pin' => 'PIN', 'password' => 'Password', 'finger' => 'Fingerprint only', 'face' => 'Face only', _ => 'Off' };

class AppLock extends ChangeNotifier {
  AppLock(this.gate, {Keep? keep, this.away = const Duration(minutes: 1)})
      : _keep = keep,
        loaded = keep == null;
  final LockGate gate;
  final Keep? _keep;
  final Duration away;
  DateTime Function() clock = DateTime.now;

  /// Where the choices are kept on the phone.
  static const kKey = 'applock';
  /// Wrong PINs / passwords in a row before he must sign in again.
  static const maxWrong = 5;

  final _choices = <String, LockChoice>{};

  /// The choices are read (until then a signed-in app shows the lock's ground – nothing of the ERP).
  bool loaded;
  /// The person signed in now (the lock layer says it).
  String user = '';
  /// Locked until he opens it (the app has just been opened, or was away too long).
  bool locked = true;
  /// Asking the phone right now.
  bool asking = false;
  /// The last "no" / problem, for the lock screen.
  String said = '';
  /// Wrong PINs / passwords in a row.
  int wrong = 0;
  DateTime? _left;
  bool _leftForPicker = false;

  /// What the person signed in now chose; null = the lock is off for him.
  LockChoice? get choice => _choices[user.trim().toLowerCase()];
  /// The lock screen is over the app now.
  bool get closed => user.isNotEmpty && (!loaded || (locked && choice != null));
  bool get tooMany => wrong >= maxWrong;

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

  /// Reads the choices kept on this phone (main.dart, at the start; not readable in 5 s: the lock stays off – never a stuck screen).
  Future<void> open() async {
    try {
      final raw = await _keep?.read(kKey).timeout(const Duration(seconds: 5));
      final j = raw == null || raw.isEmpty ? null : jsonDecode(raw);
      if (j is Map) {
        j.forEach((k, v) {
          final c = LockChoice.fromJson(v);
          if (c != null) _choices['$k'] = c;
        });
      }
    } catch (_) {/* nothing readable: the lock is off */}
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      await _keep?.write(kKey, _choices.isEmpty ? null : jsonEncode(_choices.map((k, v) => MapEntry(k, v.toJson()))));
    } catch (_) {/* kept in memory for now */}
  }

  static String _hash(String salt, String code) {
    List<int> d = utf8.encode('$salt|$code');
    for (var i = 0; i < 20000; i++) {
      d = sha256.convert(d).bytes;
    }
    return base64Url.encode(d);
  }

  /// He turns the lock on (or changes how it opens): [code] is the PIN / password for 'pin' / 'password'.
  Future<void> choose(String how, [String code = '']) async {
    final u = user.trim().toLowerCase();
    if (u.isEmpty) return;
    if (how == 'pin' || how == 'password') {
      final r = Random.secure(), salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
      _choices[u] = LockChoice(how, salt: salt, hash: _hash(salt, code));
    } else {
      _choices[u] = LockChoice(how);
    }
    locked = false; // (he is in the app now)
    wrong = 0;
    said = '';
    await _save();
    notifyListeners();
  }

  /// He turns the lock off – or forgot his PIN / password (then he signs in again).
  Future<void> forget() async {
    final u = user.trim().toLowerCase();
    if (_choices.remove(u) == null) return;
    await _save();
    notifyListeners();
  }

  /// The app went to the background (another app, the screen off).
  void away0() {
    if (asking) return; // (the phone's own popup is another screen: not "away")
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

  /// Locked at once (as after a minute away).
  void lockNow() {
    _left = null;
    locked = true;
    said = '';
    notifyListeners();
  }

  /// A password typed just now (a fresh sign-in): not asked again.
  void signedIn() {
    _left = null;
    wrong = 0;
    if (!locked && said.isEmpty) return;
    locked = false;
    said = '';
    notifyListeners();
  }

  /// His PIN / password typed on the lock screen: right → open; wrong → said (after [maxWrong] he signs in again).
  Future<bool> tryCode(String code) async {
    final c = choice;
    if (c == null || !c.code || !locked) return true;
    if (_hash(c.salt, code) == c.hash) {
      locked = false;
      wrong = 0;
      said = '';
      notifyListeners();
      return true;
    }
    wrong++;
    said = c.how == 'pin' ? 'Wrong PIN.' : 'Wrong password.';
    notifyListeners();
    return false;
  }

  /// Asks the phone for the fingerprint / face (the lock screen does this by itself when it is shown, and on "Unlock").
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
        wrong = 0;
      case LockOutcome.noLock:
        said = 'No fingerprint or face is set on this phone – use your password.';
      case LockOutcome.no:
        said = a.text; // (cancelled: nothing to say – Unlock asks again)
      case LockOutcome.busy:
        break;
      case LockOutcome.error:
        said = 'The phone could not ask – press Unlock to try again.';
    }
    _left = null;
    notifyListeners();
  }
}
