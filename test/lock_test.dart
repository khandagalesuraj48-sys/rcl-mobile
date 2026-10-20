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
    expect(l2.said, 'The phone could not ask for the fingerprint – press Unlock to try again.');
    await l2.unlock('x');
    expect(l2.locked, false);
    expect(l2.noLock, true);
    final g3 = FakeGate()..answers.add(const LockAnswer(LockOutcome.busy));
    final l3 = AppLock(g3);
    await l3.unlock('x');
    expect(l3.locked, true);
    expect(l3.said, '');
  });
}
