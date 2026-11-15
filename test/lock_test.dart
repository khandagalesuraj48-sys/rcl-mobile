// (3.27.0) The app lock (lib/core/applock.dart). (3.127.0, asked 15-11-2026: "app lock … setting madhe asel … user tharwel pin
// thewaych ki password ki only finger ki only face – mhanje phone lock cha nahi") off unless the person turns it on; his own PIN /
// password (kept only as a salted fingerprint) or only his fingerprint / face; locked again after a minute away; a typed sign-in is
// not asked again; 5 wrong tries → he signs in again; nothing about a screen lock of the phone.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart' show MemoryKeep;
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

  /// (3.127.0) what the pretend phone can open with
  Set<String> can = {'finger', 'face'};
  @override
  Future<Set<String>> bios() async => can;
}

void main() {
  test('off by itself: nothing chosen → the lock never closes the app (also after a long time away)', () async {
    final l = AppLock(FakeGate(), keep: MemoryKeep());
    await l.open();
    l.user = 'sujit@rcl.test';
    expect([l.loaded, l.choice, l.closed], [true, null, false]);
    var now = DateTime(2026, 11, 15, 9);
    l.clock = () => now;
    l.locked = false;
    l.away0();
    now = now.add(const Duration(minutes: 30));
    l.back();
    expect(l.closed, false, reason: 'no lock chosen');
    final l2 = AppLock(FakeGate(), keep: MemoryKeep());
    l2.user = 'sujit@rcl.test';
    expect(l2.closed, true, reason: 'until the choices are read: the lock\'s ground, nothing of the ERP');
  });

  test('his own PIN: kept only as a salted fingerprint, on this phone, for him; right → open; wrong → said; 5 wrong → too many', () async {
    final keep = MemoryKeep(), l = AppLock(FakeGate(), keep: keep);
    await l.open();
    l.user = 'Sujit@RCL.test';
    await l.choose('pin', '4826');
    expect(l.locked, false, reason: 'he is in the app');
    final kept = jsonDecode(keep.data[AppLock.kKey]!) as Map;
    expect(kept.keys, ['sujit@rcl.test']);
    expect((kept['sujit@rcl.test'] as Map)['how'], 'pin');
    expect(keep.data[AppLock.kKey], isNot(contains('4826')), reason: 'never the PIN itself');
    // the next start: read from the phone; another person on the same phone has no lock
    final l2 = AppLock(FakeGate(), keep: keep);
    await l2.open();
    l2.user = 'sujit@rcl.test';
    expect([l2.closed, l2.choice?.how], [true, 'pin']);
    expect(await l2.tryCode('1111'), false);
    expect(l2.said, 'Wrong PIN.');
    expect(await l2.tryCode('4826'), true);
    expect([l2.locked, l2.closed, l2.said, l2.wrong], [false, false, '', 0]);
    l2.user = 'asha@rcl.test';
    l2.locked = true;
    expect(l2.closed, false, reason: 'her own choice: none');
    l2.user = 'sujit@rcl.test';
    for (var i = 0; i < 5; i++) {
      expect(await l2.tryCode('0000'), false);
    }
    expect(l2.tooMany, true);
    l2.signedIn();
    expect([l2.locked, l2.wrong, l2.tooMany], [false, 0, false], reason: 'signed in again with his password');
    // forgot it: gone (he sets a new one after the sign-in)
    await l2.forget();
    expect(l2.choice, null);
    expect(keep.data.containsKey(AppLock.kKey), false);
  });

  test('his own password; fingerprint only: the phone\'s popup – cancelled: still locked, nothing said; not set: said', () async {
    final g = FakeGate(), l = AppLock(g, keep: MemoryKeep());
    await l.open();
    l.user = 'sujit@rcl.test';
    await l.choose('password', 'site-48');
    l.locked = true;
    expect(await l.tryCode('site-47'), false);
    expect(l.said, 'Wrong password.');
    expect(await l.tryCode('site-48'), true);
    await l.choose('finger');
    l.locked = true;
    g.answers.add(const LockAnswer(LockOutcome.no));
    await l.unlock('Unlock Sketchline');
    expect([g.reason, l.locked, l.said], ['Unlock Sketchline', true, '']);
    g.answers.add(const LockAnswer(LockOutcome.noLock));
    await l.unlock('Unlock Sketchline');
    expect(l.locked, true, reason: 'never opened without him');
    expect(l.said, 'No fingerprint or face is set on this phone – use your password.');
    g.answers.add(const LockAnswer(LockOutcome.error, 'x'));
    await l.unlock('Unlock Sketchline');
    expect([l.locked, l.said], [true, 'The phone could not ask – press Unlock to try again.']);
    await l.unlock('Unlock Sketchline');
    expect([l.locked, l.said], [false, '']);
  });

  test('away 40 s → open; away 61 s → locked; while the phone asks the app is not "away"; a typed sign-in is not asked again', () async {
    final g = FakeGate(), l = AppLock(g, keep: MemoryKeep());
    await l.open();
    l.user = 'sujit@rcl.test';
    await l.choose('face');
    var now = DateTime(2026, 11, 15, 9);
    l.clock = () => now;
    l.away0();
    now = now.add(const Duration(seconds: 40));
    l.back();
    expect(l.locked, false, reason: 'less than a minute away');
    l.away0();
    now = now.add(const Duration(seconds: 61));
    l.back();
    expect([l.locked, l.closed], [true, true], reason: 'more than a minute away');
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

  test('(3.41.0) the app\'s own camera / file box open: not "away" – 3 minutes taking photos, no lock; open more than 10 minutes: locked', () async {
    final l = AppLock(FakeGate(), keep: MemoryKeep());
    await l.open();
    l.user = 'sujit@rcl.test';
    await l.choose('finger');
    var now = DateTime(2026, 10, 25, 9);
    l.clock = () => now;
    final photo = AppLock.whileOutside(() async {
      l.away0(); // (the camera app comes in front of the app)
      now = now.add(const Duration(minutes: 3));
      l.back(); // (the photo is taken, the app is in front again – before the picker's answer)
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
    await l.unlock('Unlock Sketchline');
    l.away0(); // another app, not the app's own box
    now = now.add(const Duration(minutes: 2));
    l.back();
    expect(l.locked, true, reason: 'away in another app: as before');
  });

  test('what is kept on the phone is read safely: something broken → off; the words of each way', () async {
    final keep = MemoryKeep()..data[AppLock.kKey] = '{"a@b.c":{"how":"pin"},"d@e.f":{"how":"x"},"g@h.i":{"how":"finger"}';
    final l = AppLock(FakeGate(), keep: keep);
    await l.open();
    expect(l.loaded, true);
    l.user = 'g@h.i';
    expect(l.choice, null, reason: 'not readable at all: nothing');
    keep.data[AppLock.kKey] = '{"a@b.c":{"how":"pin"},"d@e.f":{"how":"x"},"g@h.i":{"how":"finger"}}';
    final l2 = AppLock(FakeGate(), keep: keep);
    await l2.open();
    for (final (u, how) in [('a@b.c', null), ('d@e.f', null), ('g@h.i', 'finger')]) {
      l2.user = u;
      expect(l2.choice?.how, how, reason: u);
    }
    expect([lockWay(''), lockWay('pin'), lockWay('password'), lockWay('finger'), lockWay('face')], ['Off', 'PIN', 'Password', 'Fingerprint only', 'Face only']);
  });
}
