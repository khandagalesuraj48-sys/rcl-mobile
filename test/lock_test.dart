// (3.27.0) The app lock (lib/core/applock.dart): locked when the app opens, the phone's answer opens it; locked again after more than a
// minute away; a typed sign-in is not asked again; a phone with no screen lock is not stopped (the red line).
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/applock.dart';

class FakeGate implements LockGate {
  final answers = <LockAnswer>[];
  int asked = 0;
  String reason = '';
  @override
  Future<LockAnswer> ask(String reason) async {
    asked++;
    this.reason = reason;
    return answers.isNotEmpty ? answers.removeAt(0) : const LockAnswer(LockOutcome.ok);
  }

  /// (3.92.0) what the pretend phone opens with ('face' = Face ID)
  String has = '';
  int kinds = 0;
  @override
  Future<String> kind() async {
    kinds++;
    return has;
  }
}

void main() {
  test('opens locked; the phone says "it is him" → open; a cancel → still locked, said; away 40 s → open; away 61 s → locked', () async {
    final g = FakeGate(), l = AppLock(g);
    var now = DateTime(2026, 10, 20, 9);
    l.clock = () => now;
    expect(l.locked, true);
    g.answers.add(const LockAnswer(LockOutcome.no));
    await l.unlock('Unlock RCL ERP');
    expect(g.reason, 'Unlock RCL ERP');
    expect(l.locked, true);
    expect(l.said, 'Not unlocked – press Unlock and try again.');
    await l.unlock('Unlock RCL ERP');
    expect(l.locked, false);
    expect(l.said, '');
    l.away0();
    now = now.add(const Duration(seconds: 40));
    l.back();
    expect(l.locked, false, reason: 'less than a minute away');
    l.away0();
    now = now.add(const Duration(seconds: 61));
    l.back();
    expect(l.locked, true, reason: 'more than a minute away');
    expect(g.asked, 2);
  });

  test('while the phone asks (its own PIN screen) the app is not "away"; too many tries said; a typed sign-in opens it', () async {
    final g = FakeGate(), l = AppLock(g);
    var now = DateTime(2026, 10, 20, 9);
    l.clock = () => now;
    g.answers.add(const LockAnswer(LockOutcome.no, 'Too many tries – wait a little, or use the phone\'s PIN.'));
    await l.unlock('x');
    expect(l.said, 'Too many tries – wait a little, or use the phone\'s PIN.');
    l.asking = true;
    l.away0();
    now = now.add(const Duration(minutes: 3));
    l.back();
    l.asking = false;
    await l.unlock('x');
    expect(l.locked, false);
    l.away0();
    now = now.add(const Duration(minutes: 3));
    l.back();
    expect(l.locked, true);
    l.signedIn();
    expect(l.locked, false, reason: 'the password was typed just now');
  });

  test('a phone with no screen lock: open, with the red line; the phone cannot ask twice: open too (the work never stops)', () async {
    final g = FakeGate()..answers.add(const LockAnswer(LockOutcome.noLock));
    final l = AppLock(g);
    await l.unlock('x');
    expect(l.locked, false);
    expect(l.noLock, true);
    final g2 = FakeGate()..answers.addAll(const [LockAnswer(LockOutcome.error, 'x'), LockAnswer(LockOutcome.error, 'x')]);
    final l2 = AppLock(g2);
    await l2.unlock('x');
    expect(l2.locked, true);
    expect(l2.said, 'The phone could not open its lock – press Unlock to try again.');
    await l2.unlock('x');
    expect(l2.locked, false);
    expect(l2.noLock, true);
    final g3 = FakeGate()..answers.add(const LockAnswer(LockOutcome.busy));
    final l3 = AppLock(g3);
    await l3.unlock('x');
    expect(l3.locked, true);
    expect(l3.said, '');
  });

  test('(3.41.0) the app\'s own camera / file box open: not "away" – 3 minutes taking photos, no lock; open more than 10 minutes: locked', () async {
    final g = FakeGate(), l = AppLock(g);
    var now = DateTime(2026, 10, 25, 9);
    l.clock = () => now;
    await l.unlock('Unlock RCL ERP');
    expect(l.locked, false);
    final photo = AppLock.whileOutside(() async {
      l.away0(); // (the camera app comes in front of RCL ERP)
      now = now.add(const Duration(minutes: 3));
      l.back(); // (the photo is taken, RCL ERP is in front again – before the picker's answer)
      return 'photo';
    });
    expect(await photo, 'photo');
    expect(l.locked, false, reason: 'the process is not cut in the middle');
    expect(AppLock.outside, 0);
    await AppLock.whileOutside(() async {
      l.away0();
      now = now.add(const Duration(minutes: 11));
      l.back();
    });
    expect(l.locked, true, reason: 'left open too long: locked');
    await l.unlock('Unlock RCL ERP');
    l.away0(); // another app, not the app's own box
    now = now.add(const Duration(minutes: 2));
    l.back();
    expect(l.locked, true, reason: 'away in another app: as before');
  });

  // (3.92.0, asked 09-11-2026: "iphone madhe finer nahi face login aste … face login haway") the words of the lock for this phone
  test('(3.92.0) the lock says Face ID on an iPhone with Face ID, Touch ID with Touch ID; an Android phone what it has; learnt once', () async {
    expect([lockHow('face', true), lockButton('face', true)], ["Use Face ID or the iPhone's passcode.", 'Unlock with Face ID']);
    expect([lockHow('finger', true), lockButton('finger', true)], ["Use Touch ID or the iPhone's passcode.", 'Unlock with Touch ID']);
    expect([lockHow('', true), lockButton('', true)], ["Use the iPhone's passcode.", 'Unlock']);
    expect([lockHow('face', false), lockHow('finger', false), lockHow('', false)], ["Use your face or the phone's PIN.", "Use your fingerprint or the phone's PIN.", "Use your fingerprint, face or the phone's PIN."]);
    expect([lockButton('face', false), lockButton('finger', false)], ['Unlock', 'Unlock'], reason: 'Android: its own box says face / fingerprint');
    final g = FakeGate()..has = 'face';
    g.answers.add(const LockAnswer(LockOutcome.no));
    final l = AppLock(g);
    expect(l.kind, '');
    await l.unlock('Unlock RCL ERP');
    expect(l.kind, 'face');
    await l.unlock('Unlock RCL ERP');
    expect([l.locked, g.kinds], [false, 1], reason: 'asked of the phone once');
  });
}
