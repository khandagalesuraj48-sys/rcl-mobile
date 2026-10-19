// (3.26.0) Calls with the web – the call engine (lib/core/rtc.dart) with a pretend phone (fake_rtc.dart) and a pretend Mechanical:
// the same notes and data channel messages as the web's screen share (Mechanical App.html rtc…), both ways.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/rtc.dart';

import 'fake_rtc.dart';

class Server {
  final calls = <(String, List<dynamic>)>[];
  List<Map<String, dynamic>> missed = [];
  Future<dynamic> rpc(String fn, List<dynamic> args) async {
    calls.add((fn, args));
    switch (fn) {
      case 'rtcUsers':
        return {
          'me': 'u-app',
          'name': 'App User',
          'users': [
            {'uid': 'u-web', 'name': 'Web Admin', 'admin': true},
            {'uid': 'u-two', 'name': 'Second User', 'admin': false},
          ],
          'ice': [
            {'urls': ['stun:stun.l.google.com:19302']}
          ],
          'relay': false,
          'max': 3,
        };
      case 'rtcSend':
        return {'ok': true, 'n': calls.length};
      case 'rtcMissed':
        return {'list': missed, 'unseen': 0};
      case 'rtcWa':
        return {'mobile': '919800000001', 'name': 'Web Admin'};
    }
    return null;
  }

  /// The notes sent (rtcSend), [t] only.
  List<Map<String, dynamic>> sent([String t = '']) => [
        for (final c in calls)
          if (c.$1 == 'rtcSend' && (t.isEmpty || (c.$2[0] as Map)['t'] == t)) (c.$2[0] as Map).cast<String, dynamic>()
      ];
}

Map<String, dynamic> note(String id, String t, String from, String call, Map<String, dynamic> d, {String name = 'Web Admin', int age = 300}) =>
    {'id': id, 'n': 1, 'from': from, 'name': name, 't': t, 'call': call, 'd': jsonEncode(d), 'age': age};

Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late Server srv;
  late FakeKit kit;
  late Rtc rtc;
  setUp(() {
    srv = Server();
    kit = FakeKit();
    rtc = Rtc(srv.rpc, kit);
  });
  tearDown(() => rtc.close());

  test('the heartbeat: "just opened" (r null) → then up to the note read; a note waited for → skip after 5 s; a note is taken once', () async {
    expect(rtc.beatArg(), {'r': null});
    rtc.inbox({'r': 12, 'top': 12, 'm': []});
    expect(rtc.beatArg(), {'r': 12});
    var t = 1000000;
    rtc.now = () => t;
    rtc.inbox({'r': 13, 'top': 15, 'm': []}); // a note (14) not written yet
    expect(rtc.beatArg(), {'r': 13});
    expect(rtc.fast, true, reason: 'asked every 1.5 s while a note is waited for');
    t += 6000;
    expect(rtc.beatArg(), {'r': 13, 'skip': true});
    rtc.inbox({'r': 15, 'top': 15, 'm': []});
    expect(rtc.beatArg(), {'r': 15});
    rtc.inbox({'r': 16, 'top': 16, 'm': [note('w1', 'who', 'u-web', '', {'dev': 'dW'})]});
    rtc.inbox({'r': 16, 'top': 16, 'm': [note('w1', 'who', 'u-web', '', {'dev': 'dW'})]});
    await flush();
    expect(srv.sent('here').length, 1, reason: 'the same note twice is taken once');
    expect(srv.sent('here').single['to'], ['u-web']);
    expect((srv.sent('here').single['d'] as Map)['busy'], false);
    expect((srv.sent('here').single['d'] as Map)['dev'], rtc.dev, reason: 'every note says which device wrote it');
  });

  test('a call of the WEB comes in (its screen): rings → Accept → the answer with every way → connected; its screen big, its face and mine at the side; chat; low data; Leave', () async {
    final offer = {'sdp': 'v=0 web-offer', 'people': ['App User'], 'mode': 'screen', 'dev': 'dW'};
    rtc.inbox({'r': 20, 'top': 20, 'm': [note('r1', 'ring', 'u-web', 'c1', offer)]});
    expect(rtc.ring?.name, 'Web Admin');
    expect(Rtc.ringWhat(rtc.ring!), 'wants to show you a screen');
    expect(kit.rings, [true], reason: 'the ringtone');
    // a second ring of another call meanwhile: "busy" (softly – the web waits for another device)
    rtc.inbox({'r': 21, 'top': 21, 'm': [note('r2', 'ring', 'u-two', 'c9', {'sdp': 'v=0', 'dev': 'd2'}, name: 'Second User')]});
    await flush();
    expect(srv.sent('busy').single['to'], ['u-two']);
    expect((srv.sent('busy').single['d'] as Map)['todev'], 'd2');

    await rtc.accept();
    expect(kit.rings.last, false, reason: 'the ringtone stops');
    final pc = kit.pcs.single;
    expect(pc.remotes.first, {'type': 'offer', 'sdp': 'v=0 web-offer'});
    expect(pc.added, ['mic-1'], reason: 'my voice');
    final ans = srv.sent('answer').single;
    expect(ans['to'], ['u-web']);
    expect(ans['call'], 'c1');
    expect((ans['d'] as Map)['sdp'], 'v=0 app-answer');
    expect((ans['d'] as Map)['todev'], 'dW', reason: 'the answer is for the web page that rang');
    expect(kit.keeps.last, startsWith('on mic:true'), reason: '"Call is on" – the microphone keeps working with another app open');
    expect(rtc.status(), 'Connecting…');

    pc.connect(channelFromOther: true);
    await flush();
    expect(rtc.call!.peers['u-web']!.up, true);
    expect(rtc.status(), startsWith('00:00'));
    // the web shows its screen and its camera (a face)
    final dc = pc.dc!;
    dc.recv({'t': 'roster', 'host': {'uid': 'u-web', 'name': 'Web Admin'}, 'people': [{'uid': 'u-app', 'name': 'App User', 'up': true}]});
    dc.recv({'t': 'share', 'on': true, 'sid': 'S1', 'uid': 'u-web', 'name': 'Web Admin', 'ptr': false, 'kind': 'screen'});
    pc.picture('S1');
    dc.recv({'t': 'share', 'on': true, 'sid': 'face-1', 'uid': 'u-web', 'name': 'Web Admin', 'ptr': false, 'kind': 'cam', 'face': true});
    pc.picture('face-1');
    dc.recv({'t': 'page', 'uid': 'u-web', 'tab': 'diesel', 'title': 'Diesel Issue', 'follow': false, 'sy': 0});
    expect(rtc.people, ['Web Admin']);
    expect(rtc.call!.view, 'S1', reason: 'a screen is big');
    expect(rtc.faces.map((f) => f.sid), ['face-1'], reason: 'a face at the side');
    expect(rtc.pageOf(), 'Diesel Issue');
    // my camera (the front one): a face at the others' side too, "You" here
    await rtc.toggleCam();
    expect(pc.added, ['mic-1', 'cam-1']);
    final sh = dc.of('share').last;
    expect(sh['kind'], 'cam');
    expect(sh['face'], true);
    expect(sh['sid'], 'cam-1');
    expect(rtc.faces.map((f) => f.name), ['Web Admin', 'You']);
    expect(rtc.faces.last.mirror, true);
    // the change is agreed over the data channel (the guest offers; the host answers)
    pc.onNegotiation!();
    await flush();
    expect(dc.of('sdp').last['d'], {'type': 'offer', 'sdp': 'v=0 app-offer'});
    dc.recv({'t': 'sdp', 'd': {'type': 'answer', 'sdp': 'v=0 web-answer'}});
    await flush();
    expect(pc.remotes.last, {'type': 'answer', 'sdp': 'v=0 web-answer'});
    // the back camera: shown big at the others (not a face)
    await rtc.flip();
    expect(dc.of('share').last['face'], false);
    // a tapped face is big until another picture is picked
    rtc.show('face-1');
    expect(rtc.call!.view, 'face-1');
    rtc.show('S1');
    expect(rtc.call!.view, 'S1');
    // the web stops its screen: its face fills the screen (a phone's video call)
    dc.recv({'t': 'share', 'on': false, 'sid': 'S1', 'uid': 'u-web'});
    expect(rtc.call!.view, 'face-1');
    expect(rtc.call!.faceStage, true);
    // chat both ways
    dc.recv({'t': 'chat', 'id': 'm1', 'uid': 'u-web', 'name': 'Web Admin', 'txt': 'Can you see it?'});
    expect(rtc.call!.chat.single.text, 'Can you see it?');
    expect(rtc.call!.unread, 1);
    expect(rtc.chatSend(txt: 'Yes, clearly'), true);
    expect(dc.of('chat').single['txt'], 'Yes, clearly');
    expect(rtc.call!.chat.last.mine, true);
    // the web asks for low data: my pictures smaller (the voice stays)
    dc.recv({'t': 'low', 'on': true});
    expect(pc.limits, containsAll(['cam:true', 'audio:true']));
    // Leave
    rtc.end();
    expect(dc.of('bye').single, {'t': 'bye', 'end': false});
    expect(rtc.call, isNull);
    expect(kit.keeps.last, 'off');
    expect(srv.sent('end'), isEmpty, reason: 'the line of the Activity Log is written by the host');
  });

  test('the APP calls a web user (voice): who is at the app → the ring with the offer → his web answers (his phone stops ringing) → connected; my screen; End writes the Activity Log line', () async {
    srv.missed = [
      {'call': 'c0', 'from': 'u-web', 'name': 'Web Admin', 'at': 1760000000000, 'can': true}
    ];
    final miss = await rtc.openPick();
    expect(miss.single['name'], 'Web Admin');
    expect(rtc.users.map((u) => u.name), ['Web Admin', 'Second User']);
    await flush();
    expect(srv.sent('who').length, 1);
    var t = 2000000;
    rtc.now = () => t;
    rtc.pickAt = t;
    expect(rtc.presence('u-web'), 'checking…');
    rtc.inbox({'r': 30, 'top': 30, 'm': [note('h1', 'here', 'u-web', '', {'busy': false, 'share': true, 'dev': 'dW'})]});
    expect(rtc.presence('u-web'), 'at the app now');
    t += 5000;
    expect(rtc.presence('u-two'), 'not at the app now – the ring waits a minute');

    expect(await rtc.start('u-web', 'voice'), '');
    final pc = kit.pcs.single;
    expect(pc.dc, isNotNull, reason: 'the data channel "rcl" is made by the host');
    expect(pc.added, ['mic-1']);
    final ring = srv.sent('ring').single;
    expect(ring['to'], ['u-web']);
    final d = ring['d'] as Map;
    expect(d['sdp'], 'v=0 app-offer');
    expect(d['mode'], 'voice');
    expect(d['people'], ['Web Admin']);
    expect(rtc.status(), 'Ringing…');
    final cid = rtc.call!.id;
    // his web page answers
    rtc.inbox({'r': 31, 'top': 31, 'm': [note('a1', 'answer', 'u-web', cid, {'sdp': 'v=0 web-answer', 'todev': rtc.dev, 'dev': 'dW'})]});
    await flush();
    expect(pc.remotes.single, {'type': 'answer', 'sdp': 'v=0 web-answer'});
    final cancel = srv.sent('cancel').single;
    expect((cancel['d'] as Map)['butdev'], 'dW', reason: 'his other devices stop ringing');
    expect((cancel['d'] as Map)['why'], 'elsewhere');
    pc.connect();
    await flush();
    expect(pc.dc!.of('roster').last['people'], [{'uid': 'u-web', 'name': 'Web Admin', 'up': true}], reason: 'who is in the call (again once connected)');
    // my phone's screen
    await rtc.toggleScreen();
    expect(pc.added, ['mic-1', 'scr-1']);
    expect(pc.dc!.of('share').last, {'t': 'share', 'on': true, 'sid': 'scr-1', 'uid': 'u-app', 'name': 'App User', 'ptr': false, 'kind': 'screen', 'face': false});
    expect(kit.keeps.last, startsWith('on mic:true cam:false screen:true'));
    await rtc.toggleScreen();
    expect(pc.added, ['mic-1']);
    expect(pc.dc!.of('share').last, {'t': 'share', 'on': false, 'sid': 'scr-1', 'uid': 'u-app'});
    // a second answer of another device of his: told "answered elsewhere"
    rtc.inbox({'r': 32, 'top': 32, 'm': [note('a2', 'answer', 'u-web', cid, {'sdp': 'v=0', 'todev': rtc.dev, 'dev': 'dPhone'})]});
    await flush();
    expect((srv.sent('bye').single['d'] as Map)['why'], 'elsewhere');
    rtc.end();
    await flush();
    expect(pc.dc!.of('bye').single, {'t': 'bye', 'end': true});
    final end = srv.sent('end').single;
    expect(end['to'], ['u-web']);
    expect(end['call'], cid);
  });

  test('Decline with a reply; a ring stopped by the caller = missed; answered on my other device; "who" answered as busy in a call', () async {
    rtc.inbox({'r': 1, 'top': 1, 'm': [note('r1', 'ring', 'u-web', 'c1', {'sdp': 'v=0', 'mode': 'voice', 'dev': 'dW'})]});
    expect(Rtc.ringWhat(rtc.ring!), 'Voice call');
    rtc.decline(2);
    await flush();
    final dec = srv.sent('decline').single;
    expect((dec['d'] as Map)['reply'], 2);
    expect((dec['d'] as Map)['todev'], 'dW');
    expect(rtc.notice.value?.text, 'Sent to Web Admin: "I am in a meeting – later, please."');
    expect(rtc.ring, isNull);

    rtc.inbox({'r': 2, 'top': 2, 'm': [note('r2', 'ring', 'u-web', 'c2', {'sdp': 'v=0', 'mode': 'video', 'dev': 'dW'})]});
    expect(Rtc.ringWhat(rtc.ring!), 'Video call');
    rtc.inbox({'r': 3, 'top': 3, 'm': [note('x2', 'cancel', 'u-web', 'c2', {'dev': 'dW'})]});
    expect(rtc.ring, isNull);
    expect(rtc.missN, 1);
    expect(rtc.notice.value?.text, 'Missed call from Web Admin.');

    rtc.inbox({'r': 4, 'top': 4, 'm': [note('r3', 'ring', 'u-web', 'c3', {'sdp': 'v=0', 'dev': 'dW'})]});
    rtc.inbox({'r': 5, 'top': 5, 'm': [note('x3', 'cancel', 'u-web', 'c3', {'why': 'elsewhere', 'dev': 'dW'})]});
    expect(rtc.ring, isNull);
    expect(rtc.missN, 1, reason: 'answered on another device: not missed');
    expect(rtc.notice.value?.text, 'That call was answered on another device of yours.');

    // a note for another device of mine is left alone
    rtc.inbox({'r': 6, 'top': 6, 'm': [note('r4', 'ring', 'u-web', 'c4', {'sdp': 'v=0', 'dev': 'dW', 'butdev': rtc.dev})]});
    expect(rtc.ring, isNull);

    // in a call: "here" says busy
    rtc.inbox({'r': 7, 'top': 7, 'm': [note('r5', 'ring', 'u-web', 'c5', {'sdp': 'v=0', 'dev': 'dW'})]});
    await rtc.accept();
    rtc.inbox({'r': 8, 'top': 8, 'm': [note('w1', 'who', 'u-two', '', {'dev': 'd2'}, name: 'Second User')]});
    await flush();
    expect((srv.sent('here').single['d'] as Map)['busy'], true);
  });

  test('the one called declines with a reply → the call ends and says it; nobody answers → WhatsApp offered; both offer at once → the app (the guest) gives way', () async {
    await rtc.loadUsers();
    expect(await rtc.start('u-web', 'video'), '');
    expect(kit.pcs.single.added, ['mic-1', 'cam-1']);
    final cid = rtc.call!.id;
    rtc.inbox({'r': 1, 'top': 1, 'm': [note('d1', 'decline', 'u-web', cid, {'reply': 1, 'todev': rtc.dev, 'dev': 'dW'})]});
    await flush();
    expect(rtc.call, isNull);
    expect(rtc.notice.value?.text, 'Web Admin declined the call: "I will call you back in 5 minutes."');
    expect((srv.sent('cancel').single['d'] as Map)['why'], 'declined', reason: 'his other devices stop ringing');

    // the guest: an offer of the host comes while this phone is itself offering → it takes its own back and answers
    rtc.inbox({'r': 2, 'top': 2, 'm': [note('r9', 'ring', 'u-web', 'c9', {'sdp': 'v=0 web-offer', 'dev': 'dW'})]});
    await rtc.accept();
    final pc = kit.pcs.last;
    pc.connect(channelFromOther: true);
    pc.sig = 'have-local-offer'; // (my offer is out)
    pc.dc!.recv({'t': 'sdp', 'd': {'type': 'offer', 'sdp': 'v=0 web-offer-2'}});
    await flush();
    expect(pc.rollbacks, 1);
    expect(pc.remotes.last, {'type': 'offer', 'sdp': 'v=0 web-offer-2'});
    expect(pc.dc!.of('sdp').last['d'], {'type': 'answer', 'sdp': 'v=0 app-answer'});
  });

  test('a dropped line: the host offers anew ("re"), the guest answers; nothing works without the person: no microphone → told, the call still on', () async {
    kit.micOk = false;
    rtc.inbox({'r': 1, 'top': 1, 'm': [note('r1', 'ring', 'u-web', 'c1', {'sdp': 'v=0 web-offer', 'dev': 'dW'})]});
    await rtc.accept();
    expect(rtc.notice.value?.bad, true);
    expect(rtc.notice.value?.text, startsWith('The microphone is not allowed'));
    final pc = kit.pcs.single;
    pc.connect(channelFromOther: true);
    rtc.inbox({'r': 2, 'top': 2, 'm': [note('re1', 're', 'u-web', 'c1', {'type': 'offer', 'sdp': 'v=0 web-restart', 'todev': rtc.dev, 'dev': 'dW'})]});
    await flush();
    expect(pc.remotes.last, {'type': 'offer', 'sdp': 'v=0 web-restart'});
    final re = srv.sent('re').single;
    expect(re['d'], {'type': 'answer', 'sdp': 'v=0 app-answer', 'todev': 'dW', 'dev': rtc.dev});
    expect(rtc.status(), 'Connecting again…');
    pc.onState!('connected');
    expect(rtc.notice.value?.text, 'Connected again with Web Admin.');
    expect(rtc.status(), startsWith('00:'));
    // the host ends: the call ends here
    pc.dc!.recv({'t': 'bye', 'end': true});
    expect(rtc.call, isNull);
    expect(rtc.notice.value?.text, 'Web Admin ended the call.');
  });
}
