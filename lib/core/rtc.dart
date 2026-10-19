/* CALLS – THE APP AND THE WEB TOGETHER (3.26.0, asked 19-10-2026: "JR SAMAJ EK USER APP WAR AAHE ANI EK USER WEB WAR TRI SUDHA
 * CONNECT HOYLA HAW TE PN PROPER"; his answers: everything – a call comes in, call a web user, show the phone's camera, show the
 * phone's screen; the Android phone first; the ring with the app closed comes later). The web's screen share (Mechanical's
 * App.html, rtc…) spoken by the app – nothing of the server is changed:
 *   – a note goes through Mechanical: rtcSend {t, to, call, d: {…, dev}}; the heartbeat ("sync") says up to which note this phone has
 *     read ({r}, as the web's rtcBeatArg) and brings the notes for this person (rtc: {r, top, m});
 *   – who / here (who is at the app), ring / answer / decline / cancel / busy / bye, re (a dropped line made again) – as the web;
 *   – the host offers with every way to reach it written in (the ring's d.sdp), the guest answers; then everything goes over the
 *     data channel 'rcl' with the web's messages: sdp · ice · share {sid, uid, name, kind, face} · chat {txt | img} · low · roster ·
 *     page · bye;
 *   – one person, several devices (d.dev, todev, butdev): a ring reaches his web and his phone; the one that answers keeps it.
 * The app calls ONE person (a phone cannot pass one guest's picture on to another, as the web's host does); it joins a call of the
 * web with up to 3. The media and the connections are behind [RtcKit]: flutter_webrtc on the phone (rtc_kit.dart), a pretend one in
 * the tests. */
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef RtcRpc = Future<dynamic> Function(String fn, List<dynamic> args);

/// The media and the connections of a call (flutter_webrtc on the phone; the tests give a pretend one).
abstract class RtcKit {
  /// This phone can show its screen (Android).
  bool get canScreen;
  Future<RtcPc> peer(List<Map<String, dynamic>> ice);
  /// The microphone (null: not allowed).
  Future<RtcLocal?> mic();
  /// A camera: 'user' (the front one – a face) or 'environment' (the back one – a machine, a meter, a paper). Throws when not allowed.
  Future<RtcLocal> camera(String facing);
  /// The phone's screen (asks the person first; null: he did not allow it).
  Future<RtcLocal?> screen();
  Future<void> speaker(bool on);
  /// While a call is on the phone keeps it going (Android: a notification "Call is on" – also when another app is opened).
  Future<void> keep(bool on, {bool mic = false, bool cam = false, bool screen = false, String title = '', String text = ''});
  /// The ringtone of a call that comes in.
  Future<void> ring(bool on, {String title = '', String text = ''});
  /// A picture on the screen.
  Widget view(RtcMedia media, {bool mirror = false, bool cover = false});
}

/// A picture or a voice: mine ([RtcLocal]) or one that came ([RtcIn]).
abstract class RtcMedia {
  String get id;
}

abstract class RtcLocal implements RtcMedia {
  Future<void> stop();
  Future<void> enable(bool on);
  /// The phone's other camera (false: it has none).
  Future<bool> flip();
  Future<bool> torch(bool on);
}

class RtcIn implements RtcMedia {
  RtcIn(this.id, this.trackId, this.handle);
  @override
  final String id;
  final String trackId;
  final Object handle;
}

abstract class RtcDc {
  void Function()? onOpen, onClose;
  void Function(String text)? onText;
  bool get open;
  void send(String text);
}

abstract class RtcPc {
  void Function(String kind, RtcIn media)? onTrack;
  void Function(String streamId, String trackId)? onTrackGone;
  /// new / connecting / connected / disconnected / failed / closed
  void Function(String state)? onState;
  void Function()? onNegotiation;
  void Function(Map<String, dynamic> candidate)? onIce;
  void Function(RtcDc dc)? onChannel;
  Future<RtcDc> channel(String label);
  /// Sends [media] (a voice or a picture); the answer is its sender.
  Future<Object> add(RtcLocal media);
  Future<void> drop(Object sender);
  /// No microphone here: the other side can still be heard.
  Future<void> recvAudio();
  /// Made and set as mine: {type, sdp}.
  Future<Map<String, dynamic>> offer({bool restart = false});
  Future<Map<String, dynamic>> answer();
  Future<void> remote(Map<String, dynamic> d);
  Future<void> rollback();
  /// My offer / answer with every way to reach this phone written in (waits at most [ms]; with a relay until its way is there).
  Future<String> sdpWhenReady(int ms, bool relay);
  /// stable / have-local-offer / have-remote-offer …
  String get signaling;
  Future<void> addIce(Map<String, dynamic> c);
  /// 'direct' / 'relay' / '' (asked once it is connected)
  Future<String> way();
  /// (round trip in seconds, voice packets lost, voice packets received)
  Future<(double, int, int)> quality();
  /// What a picture / the voice may use: [kind] screen / cam / audio; [low]: low data.
  Future<void> limit(Object sender, String kind, bool low);
  Future<void> close();
}

const rtcReplies = {1: 'I will call you back in 5 minutes.', 2: 'I am in a meeting – later, please.', 3: 'Please call me on the phone.'};

class RtcUser {
  RtcUser(this.uid, this.name, this.admin);
  final String uid, name;
  final bool admin;
}

class RtcShare {
  RtcShare(this.uid, this.name, this.kind, this.face, this.at);
  final String uid, name, kind;
  final bool face;
  final int at;
}

class RtcVid {
  RtcVid(this.media, this.via, this.at);
  final RtcIn media;
  final String via;
  final int at;
}

class RtcMsg {
  RtcMsg(this.name, this.text, this.img, this.mine, this.at);
  final String name, text;
  final Uint8List? img;
  final bool mine;
  final int at;
}

/// A face at the side: another's camera, or mine ("You").
class RtcFace {
  RtcFace(this.sid, this.name, this.media, this.me, this.mirror);
  final String sid, name;
  final RtcMedia media;
  final bool me, mirror;
}

/// A short message for the screen; [act] / [url]: a button with it (WhatsApp).
class RtcNotice {
  RtcNotice(this.text, {this.act = '', this.url = '', this.bad = false});
  final String text, act, url;
  final bool bad;
}

class RtcRing {
  RtcRing(this.call, this.from, this.name, this.dev, this.sdp, this.people, this.mode, this.help, this.at);
  final String call, from, name, dev, sdp, mode, help;
  final List<String> people;
  final int at;
  Timer? t;
}

class RtcPeer {
  RtcPeer(this.uid, this.name, this.polite, this.pc);
  final String uid;
  String name;
  final bool polite;
  final RtcPc pc;
  RtcDc? dc;
  bool making = false, ignore = false, answering = false, open = false, up = false, dirty = false, again = false, restarting = false, low = false;
  String dev = '', state = 'ringing', via = '', reply = '', cs = 'new';
  Object? micS, scrS, camS;
  Timer? ringT, watchT, busyT, waT, reT, lostT;
  final rate = <String, List<int>>{};
  (int, int)? netPrev;
}

class RtcCall {
  RtcCall(this.id, this.role, this.mode, this.t0);
  final String id, role, mode;
  final int t0;
  final peers = <String, RtcPeer>{};
  RtcLocal? mic, cam, screen;
  bool micOn = true, torch = false, speaker = true, low = false, lowSet = false, chatOpen = false, faceStage = false;
  String facing = 'user', net = '', pin = '', view = '', newest = '';
  int t1 = 0, poorN = 0, unread = 0;
  final met = <String>{};
  final shares = <String, RtcShare>{};
  final vids = <String, RtcVid>{};
  final pages = <String, String>{};
  Map<String, dynamic>? roster;
  final chat = <RtcMsg>[];
  List<String> tabs = [];
}

int _int(dynamic v, [int or = 0]) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? or;
Map<String, dynamic> _json(dynamic s) {
  try {
    final j = s is String ? (s.isEmpty ? <String, dynamic>{} : jsonDecode(s)) : s;
    return j is Map ? j.cast<String, dynamic>() : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

String _short(Object e) {
  final s = '$e'.replaceFirst(RegExp(r'^(Exception|PlatformException|Error)[:(]\s*'), '');
  return s.length > 80 ? s.substring(0, 80) : s;
}

/// The camera could not be started: why, in the words the web uses.
String rtcCamErr(Object e) {
  final s = '$e';
  if (RegExp(r'NotAllowed|denied|permission', caseSensitive: false).hasMatch(s)) return 'The camera is not allowed – allow it for RCL ERP (the phone\'s Settings → Apps → RCL ERP → Permissions → Camera).';
  if (RegExp(r'NotFound|Overconstrained|no camera', caseSensitive: false).hasMatch(s)) return 'The camera was not found on this phone.';
  return 'The camera could not be started (${_short(e)}).';
}

class Rtc extends ChangeNotifier {
  Rtc(this.rpc, this.kit, {this.onBeat, Random? rnd}) : _rnd = rnd ?? Random() {
    dev = 'a${_id(10)}';
  }
  final RtcRpc rpc;
  final RtcKit kit;
  /// The heartbeat (Session.liveTick) – asked more often while a call is set up or on.
  Future<void> Function()? onBeat;
  final Random _rnd;
  late final String dev;
  int Function() now = () => DateTime.now().millisecondsSinceEpoch;

  String me = '', myName = '';
  List<RtcUser> users = [];
  List<Map<String, dynamic>> ice = [];
  bool relay = false, off = false, closed = false;
  /// At most this many people in a call of the web (the app itself calls one).
  int most = 3;
  /// Up to which note this phone has read (null: just opened).
  int? since;
  int _stuckR = -1, _stuckAt = 0;
  final _seen = <String>{};
  /// Who answered "here" (uid → (when, in another call)).
  final here = <String, (int, bool)>{};
  final _hereTo = <String, int>{}, _busyTo = <String, int>{};
  RtcCall? call;
  RtcRing? ring;
  bool picking = false;
  int pickAt = 0, missN = 0;
  bool _starting = false;
  final notice = ValueNotifier<RtcNotice?>(null);
  final _timers = <Timer>{};
  Timer? _beatT, _netT;
  int _gap = 0;

  String _id(int n) {
    const a = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(List.generate(n, (_) => a.codeUnitAt(_rnd.nextInt(a.length))));
  }

  Timer _after(int ms, void Function() f) {
    late final Timer t;
    t = Timer(Duration(milliseconds: ms), () {
      _timers.remove(t);
      if (!closed) f();
    });
    _timers.add(t);
    return t;
  }

  void _say(String text, {String act = '', String url = '', bool bad = false}) => notice.value = RtcNotice(text, act: act, url: url, bad: bad);
  void _changed() {
    _pace();
    if (!closed) notifyListeners();
  }

  /// A call is set up / rings / is reconnecting: the heartbeat every 1.5 s (the web's rtcFast); a call is on: every 3 s.
  bool get fast => picking || ring != null || _stuckAt > 0 || (call?.peers.values.any((p) => !p.up || p.state == 'reconnecting') ?? false);
  bool get busy => call != null || ring != null;
  void _pace() {
    final gap = closed ? 0 : fast ? 1500 : call != null ? 3000 : 0;
    if (gap == _gap) return;
    _beatT?.cancel();
    _beatT = null;
    _gap = gap;
    if (gap > 0) _beatT = Timer.periodic(Duration(milliseconds: gap), (_) => onBeat?.call());
  }

  /// What the heartbeat sends (the web's rtcBeatArg).
  Map<String, dynamic> beatArg() => {'r': since, if (_stuckAt > 0 && now() - _stuckAt > 5000) 'skip': true};

  Future<dynamic> _send(String t, List<String> to, String callId, Map<String, dynamic> d) => rpc('rtcSend', [
        {'t': t, 'to': to, 'call': callId, 'd': {...d, 'dev': dev}}
      ]);
  void _note(String t, List<String> to, String callId, [Map<String, dynamic> d = const {}]) {
    _send(t, to, callId, d).catchError((Object e) {
      debugPrint('call: $e');
    });
  }

  /// The heartbeat's answer (rtc: {r, top, m}).
  void inbox(dynamic x) {
    if (x is! Map || closed) return;
    final r = x['r'], top = x['top'];
    if (r is num) {
      if (top is num && r < top) {
        if (_stuckR != r.toInt()) {
          _stuckR = r.toInt();
          _stuckAt = now();
        }
      } else {
        _stuckR = -1;
        _stuckAt = 0;
      }
      since = r.toInt();
    }
    for (final m in (x['m'] as List? ?? const []).whereType<Map>()) {
      final id = '${m['id'] ?? ''}';
      if (id.isEmpty || _seen.contains(id)) continue;
      _seen.add(id);
      if (_seen.length > 500) _seen.remove(_seen.first);
      try {
        _onNote(m.cast<String, dynamic>());
      } catch (e) {
        debugPrint('call: $e');
      }
    }
    _pace();
  }

  void _onNote(Map<String, dynamic> m) {
    final c = call, d = _json(m['d']), t = '${m['t'] ?? ''}', from = '${m['from'] ?? ''}', cid = '${m['call'] ?? ''}', name = '${m['name'] ?? ''}';
    final todev = '${d['todev'] ?? ''}', butdev = '${d['butdev'] ?? ''}', ddev = '${d['dev'] ?? ''}';
    if ((todev.isNotEmpty && todev != dev) || (butdev.isNotEmpty && butdev == dev)) return; // for another device of this person
    if (t == 'who') {
      if (now() - (_hereTo[from] ?? 0) > 8000) {
        _hereTo[from] = now();
        _note('here', [from], '', {'busy': busy, 'share': kit.canScreen});
      }
      return;
    }
    if (t == 'here') {
      here[from] = (now(), d['busy'] == true);
      _changed();
      return;
    }
    if (t == 'ring') {
      if ((c != null && c.id == cid) || (ring != null && ring!.call == cid)) return;
      if (c != null || ring != null) {
        if (now() - (_busyTo[from] ?? 0) > 4000) {
          _busyTo[from] = now();
          _note('busy', [from], cid, {'why': 'busy', 'todev': ddev});
        }
        return;
      }
      _incoming(m, d);
      return;
    }
    if ((t == 'cancel' || t == 'bye') && ring != null && ring!.call == cid && ring!.from == from) {
      _ringClose();
      if (d['why'] == 'elsewhere') {
        _say('That call was answered on another device of yours.');
      } else if (d['why'] != 'declined') {
        missN++;
        _say('Missed call from $name.');
      }
      _changed();
      return;
    }
    if (t == 'answer') {
      final p = c != null && c.id == cid ? c.peers[from] : null;
      if (p == null) {
        _note('bye', [from], cid, {'todev': ddev, 'why': 'over'}); // the call is over here: the one who answered is told at once
        return;
      }
      if (p.dev.isNotEmpty && p.dev != ddev) {
        _note('bye', [from], cid, {'todev': ddev, 'why': 'elsewhere'}); // his other device answered first
        return;
      }
      if (p.dev.isEmpty) {
        p.dev = ddev;
        p.busyT?.cancel();
        _note('cancel', [from], cid, {'butdev': ddev, 'why': 'elsewhere'}); // his other devices stop ringing
      }
      _answered(p, d);
      return;
    }
    if (c == null || c.id != cid) return;
    final p = c.peers[from];
    if (p == null) return;
    if (t == 're') {
      _onRe(p, d).catchError((Object e) {
        debugPrint('call: $e');
      });
    } else if (t == 'decline') {
      _note('cancel', [from], cid, {'butdev': ddev, 'why': 'declined'});
      p.reply = rtcReplies[_int(d['reply'])] ?? '';
      _gone(p, 'declined');
    } else if (t == 'busy') {
      if (p.dev.isEmpty && p.busyT == null) {
        p.busyT = _after(6000, () {
          if (p.dev.isEmpty && call == c && c.peers[p.uid] == p) {
            _note('cancel', [p.uid], c.id, {'why': 'declined'});
            _gone(p, d['why'] == 'browser' ? 'browser' : 'busy');
          }
        });
      }
    } else if (t == 'bye' || t == 'cancel') {
      _gone(p, d['why'] == 'over' ? 'over' : d['why'] == 'elsewhere' ? 'elsewhere' : 'left');
    }
  }

  // ---------------- the people ----------------
  Future<void> loadUsers() async {
    final x = await rpc('rtcUsers', const []);
    if (x is! Map) return;
    me = '${x['me'] ?? ''}';
    myName = '${x['name'] ?? ''}';
    users = [for (final u in (x['users'] as List? ?? const []).whereType<Map>()) RtcUser('${u['uid'] ?? ''}', '${u['name'] ?? ''}', u['admin'] == true)];
    ice = [for (final s in (x['ice'] as List? ?? const []).whereType<Map>()) s.cast<String, dynamic>()];
    relay = x['relay'] == true;
    most = _int(x['max'], 3);
    off = x['off'] == true;
  }

  /// The list to pick from opens: the people, my missed calls, and "who is at the app?" asked now, after 9 s and after 18 s.
  Future<List<Map<String, dynamic>>> openPick() async {
    await loadUsers();
    picking = true;
    pickAt = now();
    here.clear();
    _changed();
    if (off) return [];
    _note('who', const [], '');
    for (final ms in [9000, 18000]) {
      _after(ms, () {
        if (picking) _note('who', const [], '');
      });
    }
    try {
      final x = await rpc('rtcMissed', [{'seen': true}]);
      missN = 0;
      _changed();
      return [for (final m in (x is Map ? x['list'] as List? ?? const [] : const []).whereType<Map>()) m.cast<String, dynamic>()];
    } catch (_) {
      return [];
    }
  }

  void closePick() {
    picking = false;
    _changed();
  }

  /// In the list: "at the app now" / "in another call" / "not at the app now" / "checking…" (the web's rtcPickDraw).
  String presence(String uid) {
    final h = here[uid];
    if (h != null && now() - h.$1 < 30000) return h.$2 ? 'in another call' : 'at the app now';
    return now() - pickAt > 4500 ? 'not at the app now – the ring waits a minute' : 'checking…';
  }

  Future<void> clearMissed() async {
    try {
      await rpc('rtcMissed', [{'clear': true}]);
    } catch (_) {/* only the list */}
  }

  // ---------------- a call comes in ----------------
  void _incoming(Map<String, dynamic> m, Map<String, dynamic> d) {
    final sdp = '${d['sdp'] ?? ''}';
    if (sdp.isEmpty) return;
    final h = d['help'] is Map ? (d['help'] as Map) : null;
    final help = h == null ? '' : ('${h['title'] ?? ''}'.isNotEmpty ? '${h['title']}: ' : '') + '${h['msg'] ?? ''}';
    final r = ring = RtcRing('${m['call']}', '${m['from']}', '${m['name'] ?? ''}', '${d['dev'] ?? ''}', sdp, [for (final x in (d['people'] as List? ?? const [])) '$x'],
        '${d['mode'] ?? ''}', help.length > 320 ? help.substring(0, 320) : help, now());
    r.t = _after(max(5000, 78000 - _int(m['age'])), () {
      if (ring != r) return;
      _ringClose();
      missN++;
      _say('Missed call from ${r.name}.');
      _changed();
    });
    kit.ring(true, title: '${r.name} is calling', text: ringWhat(r));
    _changed();
  }

  /// What the one who calls wants (the web's words of the ring).
  static String ringWhat(RtcRing r) {
    final what = switch (r.mode) { 'cam' => 'wants to show you a camera', 'page' => 'wants to show you a page of the app', 'voice' => 'Voice call', 'video' => 'Video call', _ => 'wants to show you a screen' };
    final more = r.people.length > 1 ? ' (with ${r.people.length - 1} more)' : '';
    return r.help.isNotEmpty ? 'needs help – $what$more' : '$what$more';
  }

  void _ringClose() {
    final r = ring;
    r?.t?.cancel();
    ring = null;
    if (r != null) kit.ring(false);
  }

  /// Declined, with one of the short replies (1–3) or none.
  void decline([int reply = 0]) {
    final r = ring;
    if (r == null) return;
    _ringClose();
    _note('decline', [r.from], r.call, {'todev': r.dev, 'reply': rtcReplies.containsKey(reply) ? reply : 0, 'ep': ''});
    if (rtcReplies.containsKey(reply)) _say('Sent to ${r.name}: "${rtcReplies[reply]}"');
    _changed();
  }

  Future<void> accept() async {
    final r = ring;
    if (r == null || call != null) return;
    _ringClose();
    final c = call = RtcCall(r.call, 'guest', r.mode, now());
    _start(c);
    try {
      if (me.isEmpty || ice.isEmpty) await loadUsers();
      if (call != c) return;
      final p = RtcPeer(r.from, r.name, true, await kit.peer(ice));
      p.state = 'connecting';
      p.dev = r.dev;
      c.peers[r.from] = p;
      _wire(p);
      _changed();
      c.mic = await kit.mic();
      if (call != c) {
        await _drop(c);
        return;
      }
      if (c.mic == null) _say('The microphone is not allowed – the others cannot hear you (you can hear them).', bad: true);
      await kit.speaker(c.speaker);
      await _keep();
      await p.pc.remote({'type': 'offer', 'sdp': r.sdp});
      if (c.mic != null) p.micS = await p.pc.add(c.mic!);
      await p.pc.answer();
      final sdp = await p.pc.sdpWhenReady(3000, relay);
      if (call != c) return;
      await _send('answer', [r.from], r.call, {'sdp': sdp, 'todev': r.dev, 'ep': ''});
      _watch(p);
    } catch (e) {
      if (call == c) {
        _note('bye', [r.from], r.call, {'todev': r.dev});
        end(quiet: true, say: 'The call of ${r.name} could not be joined (${_short(e)}).');
      }
    }
  }

  // ---------------- a call from this phone (to ONE person) ----------------
  /// [mode]: 'voice' · 'video' (my front camera) · 'screen' (my phone's screen). The answer: '' = it rings; else what is wrong.
  Future<String> start(String uid, String mode) async {
    if (_starting) return '';
    if (call != null) return 'A call is already on.';
    if (ring != null) return 'Answer or decline the call that is ringing first.';
    if (off) return 'Screen share is switched off for you – the Admin can switch it on in Users & Access.';
    RtcUser? u;
    for (final x in users) {
      if (x.uid == uid) u = x;
    }
    if (u == null) return 'Pick the person to call.';
    _starting = true;
    try {
      RtcLocal? first;
      if (mode == 'screen') {
        if (!kit.canScreen) return 'This phone cannot show its screen.';
        try {
          first = await kit.screen();
        } catch (e) {
          return 'The screen could not be shown (${_short(e)}).';
        }
        if (first == null) return 'The screen was not shared – press Start now in the box of the phone.';
      } else if (mode == 'video') {
        try {
          first = await kit.camera('user');
        } catch (e) {
          return rtcCamErr(e);
        }
      }
      if (call != null || ring != null) {
        await first?.stop();
        return 'Answer or decline the call that is ringing first.';
      }
      final c = call = RtcCall('c${now().toRadixString(36)}${_id(6)}', 'host', mode, now());
      if (mode == 'screen') c.screen = first;
      if (mode == 'video') c.cam = first;
      picking = false;
      _start(c);
      c.mic = await kit.mic();
      if (call != c) {
        await _drop(c);
        return '';
      }
      if (c.mic == null) _say('The microphone is not allowed – the others cannot hear you (they can still be heard).', bad: true);
      await kit.speaker(c.speaker);
      final p = RtcPeer(u.uid, u.name, false, await kit.peer(ice));
      c.peers[u.uid] = p;
      _wire(p);
      _changed();
      await _keep();
      try {
        _wireDc(p, await p.pc.channel('rcl'));
        await _addLocal(c, p);
        await p.pc.offer();
        final sdp = await p.pc.sdpWhenReady(3000, relay);
        if (call != c || c.peers[p.uid] != p) return '';
        await _send('ring', [p.uid], c.id, {'sdp': sdp, 'people': [u.name], 'mode': mode});
        // (a page in a background tab may hear of the ring only after a minute)
        p.ringT = _after(80000, () {
          if (!p.up && p.state == 'ringing') {
            _note('cancel', [p.uid], c.id);
            _gone(p, 'none');
          }
        });
        p.waT = _after(15000, () {
          if (call == c && c.peers[p.uid] == p && !p.up && p.state == 'ringing') _waOffer(c.id, p, '${p.name} has not answered yet.');
        });
      } catch (e) {
        debugPrint('call: $e');
        _gone(p, 'send');
      }
      return '';
    } finally {
      _starting = false;
    }
  }

  void _start(RtcCall c) {
    _netT?.cancel();
    _netT = Timer.periodic(const Duration(seconds: 3), (_) => _netCheck());
    _changed();
  }

  Future<void> _addLocal(RtcCall c, RtcPeer p) async {
    if (c.mic != null) {
      p.micS = await p.pc.add(c.mic!);
    } else if (!p.polite) {
      await p.pc.recvAudio(); // (no microphone here: the other side can still be heard)
    }
    if (c.screen != null) p.scrS = await p.pc.add(c.screen!);
    if (c.cam != null) p.camS = await p.pc.add(c.cam!);
  }

  // ---------------- one connection ----------------
  void _wire(RtcPeer p) {
    final pc = p.pc;
    pc.onTrack = (kind, media) => _onTrack(p, kind, media);
    pc.onTrackGone = (sid, tid) {
      final c = call, v = c?.vids[sid];
      if (c != null && v != null && v.media.trackId == tid) {
        c.vids.remove(sid);
        _pick();
        _changed();
      }
    };
    pc.onState = (st) => _onState(p, st);
    pc.onNegotiation = () => _negotiate(p);
    pc.onIce = (cand) {
      if (p.open) _dc(p, {'t': 'ice', 'd': cand});
    };
    pc.onChannel = (dc) => _wireDc(p, dc);
  }

  void _wireDc(RtcPeer p, RtcDc dc) {
    p.dc = dc;
    dc.onOpen = () {
      if (p.open) return;
      p.open = true;
      _hello(p);
      if (p.dirty) {
        p.dirty = false;
        _negotiate(p);
      }
      _changed();
    };
    dc.onText = (s) {
      dynamic j;
      try {
        j = jsonDecode(s);
      } catch (_) {
        return;
      }
      if (j is! Map) return;
      try {
        _onDc(p, j.cast<String, dynamic>());
      } catch (e) {
        debugPrint('call: $e');
      }
    };
    dc.onClose = () => p.open = false;
    if (dc.open) dc.onOpen!(); // (the other side's channel comes open)
  }

  bool _dc(RtcPeer p, Map<String, dynamic> m) {
    try {
      final dc = p.dc;
      if (dc != null && dc.open) {
        dc.send(jsonEncode(m));
        return true;
      }
    } catch (e) {
      debugPrint('call: $e');
    }
    return false;
  }

  void _tellAll(Map<String, dynamic> m, [RtcPeer? but]) {
    for (final p in call?.peers.values.toList() ?? const <RtcPeer>[]) {
      if (p != but) _dc(p, m);
    }
  }

  // a change after the first connection (a picture switched on …) is agreed over the data channel; when both sides start at the
  // same moment the guest gives way
  Future<void> _negotiate(RtcPeer p) async {
    if (!p.open) {
      p.dirty = true;
      return;
    }
    if (p.making || p.pc.signaling != 'stable') {
      p.again = true;
      return;
    }
    try {
      p.making = true;
      final o = await p.pc.offer();
      _dc(p, {'t': 'sdp', 'd': o});
    } catch (e) {
      p.again = true;
      debugPrint('call: $e');
    } finally {
      p.making = false;
    }
    _after(1500, _lowApply);
  }

  Future<void> _onSdp(RtcPeer p, Map<String, dynamic> d) async {
    final type = '${d['type'] ?? ''}';
    final ready = !p.making && (p.pc.signaling == 'stable' || p.answering), clash = type == 'offer' && !ready;
    p.ignore = !p.polite && clash;
    if (p.ignore) return;
    if (clash) {
      try {
        await p.pc.rollback();
      } catch (_) {/* nothing of mine to take back */}
      p.again = true;
    }
    p.answering = type == 'answer';
    try {
      await p.pc.remote({'type': type, 'sdp': '${d['sdp'] ?? ''}'});
    } finally {
      p.answering = false;
    }
    if (type == 'offer') {
      final a = await p.pc.answer();
      _dc(p, {'t': 'sdp', 'd': a});
    }
    if (p.again && p.pc.signaling == 'stable') {
      p.again = false;
      _after(200, () => _negotiate(p));
    }
  }

  // what a person who has just been connected must know: who is in the call, whose pictures are on
  void _hello(RtcPeer p) {
    final c = call;
    if (c == null) return;
    if (c.role == 'host') {
      _roster();
      c.shares.forEach((sid, s) {
        if (s.uid != p.uid) _dc(p, {'t': 'share', 'on': true, 'sid': sid, 'uid': s.uid, 'name': s.name, 'ptr': false, 'kind': s.kind, 'face': s.face});
      });
    }
    if (c.screen != null) _dc(p, {'t': 'share', 'on': true, 'sid': c.screen!.id, 'uid': me, 'name': myName, 'ptr': false, 'kind': 'screen'});
    if (c.cam != null) _dc(p, {'t': 'share', 'on': true, 'sid': c.cam!.id, 'uid': me, 'name': myName, 'ptr': false, 'kind': 'cam', 'face': c.facing == 'user'});
    if (c.low) _dc(p, {'t': 'low', 'on': true});
  }

  void _roster() {
    final c = call;
    if (c == null || c.role != 'host') return;
    _tellAll({
      't': 'roster',
      'host': {'uid': me, 'name': myName},
      'people': [for (final p in c.peers.values) {'uid': p.uid, 'name': p.name, 'up': p.up}]
    });
  }

  void _onTrack(RtcPeer p, String kind, RtcIn media) {
    final c = call;
    if (c == null || kind != 'video') return; // (a voice is heard by itself)
    c.vids[media.id] = RtcVid(media, p.uid, now());
    _pick();
    _changed();
  }

  void _onState(RtcPeer p, String st) {
    p.cs = st;
    final c = call;
    if (c == null || c.peers[p.uid] != p) return;
    if (st == 'connected') {
      if (!p.up) {
        p.up = true;
        c.met.add(p.uid);
        if (c.t1 == 0) c.t1 = now();
        p.watchT?.cancel();
        p.ringT?.cancel();
        p.waT?.cancel();
        _roster();
      }
      p.reT?.cancel();
      p.lostT?.cancel();
      p.reT = p.lostT = null;
      if (p.restarting) {
        p.restarting = false;
        _say('Connected again with ${p.name}.');
      }
      p.state = 'on';
      p.pc.way().then((w) {
        p.via = w;
        _changed();
      }, onError: (Object e) {});
      _after(800, _lowApply);
    } else if (st == 'disconnected') {
      if (p.up) {
        p.state = 'weak';
        if (c.role == 'host' && p.reT == null && !p.restarting) {
          p.reT = _after(4000, () {
            p.reT = null;
            if (call == c && c.peers[p.uid] == p && p.cs != 'connected') _restart(p);
          });
        }
      }
    } else if (st == 'failed') {
      if (!p.up) {
        _gone(p, 'nc');
        return;
      }
      if (c.role == 'host') {
        _restart(p);
      } else {
        _await(p);
      }
    }
    _changed();
  }

  void _answered(RtcPeer p, Map<String, dynamic> d) {
    final sdp = '${d['sdp'] ?? ''}';
    if (sdp.isEmpty || p.pc.signaling != 'have-local-offer') return;
    p.ringT?.cancel();
    p.busyT?.cancel();
    p.waT?.cancel();
    p.state = 'connecting';
    _changed();
    () async {
      try {
        await p.pc.remote({'type': 'answer', 'sdp': sdp});
        _watch(p);
      } catch (e) {
        debugPrint('call: $e');
        _gone(p, 'nc');
      }
    }();
  }

  void _watch(RtcPeer p) {
    p.watchT?.cancel();
    p.watchT = _after(25000, () {
      if (!p.up) _gone(p, 'nc');
    });
  }

  void _onDc(RtcPeer p, Map<String, dynamic> m) {
    final c = call;
    if (c == null) return;
    final host = c.role == 'host', t = '${m['t'] ?? ''}';
    if (host && (t == 'share' || t == 'page' || t == 'chat')) {
      m['uid'] = p.uid; // a guest speaks for himself only
      if (t != 'page') m['name'] = p.name;
    }
    switch (t) {
      case 'sdp':
        _onSdp(p, _json(m['d'])).catchError((Object e) {
          debugPrint('call: $e');
        });
      case 'ice':
        final cand = _json(m['d']);
        if (cand.isNotEmpty) {
          p.pc.addIce(cand).catchError((Object e) {
            if (!p.ignore) debugPrint('call: $e');
          });
        }
      case 'share':
        final sid = '${m['sid'] ?? ''}';
        if (sid.isEmpty) return;
        if (m['on'] == true) {
          final was = c.shares[sid], kind = m['kind'] == 'cam' ? 'cam' : 'screen';
          c.shares[sid] = RtcShare('${m['uid'] ?? p.uid}', '${m['name'] ?? p.name}', kind, kind == 'cam' && m['face'] == true, was?.at ?? now());
        } else {
          c.shares.remove(sid);
        }
        if (host) _tellAll(m, p);
        _pick();
        _changed();
      case 'page':
        final uid = '${m['uid'] ?? p.uid}', title = '${m['title'] ?? ''}';
        c.pages[uid] = title.length > 80 ? title.substring(0, 80) : title;
        if (host) _tellAll(m, p);
        _changed();
      case 'chat':
        if (!_rate(p, 'chat', 15, 10000)) return;
        if (_chatIn(m, false) && host) _tellAll(m, p);
      case 'low':
        p.low = m['on'] == true;
        _lowApply();
      case 'roster':
        if (!host) {
          c.roster = m;
          _changed();
        }
      case 'bye':
        _gone(p, m['end'] == true ? 'ended' : 'left');
      // 'ptr' / 'pen' (a ring or a line on a computer's screen): nothing on a phone
    }
  }

  bool _rate(RtcPeer p, String k, int n, int ms) {
    final t = now(), l = (p.rate[k] ?? <int>[])..removeWhere((x) => t - x >= ms);
    p.rate[k] = l;
    if (l.length >= n) return false;
    l.add(t);
    return true;
  }

  // ---------------- a person out of the call ----------------
  String _goneSay(RtcPeer p, String why) => switch (why) {
        'declined' => '${p.name} declined the call${p.reply.isNotEmpty ? ': "${p.reply}"' : '.'}',
        'busy' => '${p.name} is in another call.',
        'browser' => '${p.name}\'s browser cannot join a call.',
        'left' => '${p.name} left the call.',
        'ended' => '${p.name} ended the call.',
        'none' => '${p.name} did not answer – the app may be closed there.',
        'lost' => 'The connection to ${p.name} was lost.',
        'over' => 'The call of ${p.name} was already over.',
        'elsewhere' => 'That call was answered on another device of yours.',
        'nc' => 'Could not connect to ${p.name}. If ${p.name} has closed the app, call again. If it happens every time: ${relay ? 'the relay could not be reached from one of the two networks.' : 'the two networks do not let the devices reach each other directly.'}',
        'send' => 'The ring could not be sent to ${p.name} – check the network and try again.',
        _ => '',
      };

  void _gone(RtcPeer p, String why) {
    final c = call;
    if (c == null || c.peers[p.uid] != p) return;
    for (final t in [p.ringT, p.watchT, p.busyT, p.waT, p.reT, p.lostT]) {
      t?.cancel();
    }
    c.peers.remove(p.uid);
    p.pc.close().catchError((Object e) {});
    c.vids.removeWhere((_, v) => v.via == p.uid);
    for (final sid in c.shares.keys.toList()) {
      if (c.shares[sid]!.uid == p.uid) {
        c.shares.remove(sid);
        if (c.role == 'host') _tellAll({'t': 'share', 'on': false, 'sid': sid, 'uid': p.uid});
      }
    }
    c.pages.remove(p.uid);
    final say = _goneSay(p, why);
    if (why == 'none' && c.role == 'host') _waOffer(c.id, p, say);
    if (c.peers.isEmpty) {
      end(say: why == 'none' && c.role == 'host' ? '' : say, quiet: true, bad: why == 'nc' || why == 'send');
      return;
    }
    if (say.isNotEmpty && !(why == 'none' && c.role == 'host')) _say(say);
    _roster();
    _pick();
    _changed();
  }

  /// "Ask on WhatsApp": the mobile number of the one rung, when he has set it (Settings) – the web's rtcWaOffer.
  Future<void> _waOffer(String callId, RtcPeer p, String text) async {
    try {
      final x = await rpc('rtcWa', [{'uid': p.uid, 'call': callId}]);
      final mob = x is Map ? '${x['mobile'] ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '') : '';
      if (mob.isNotEmpty) {
        final msg = '$myName is calling you in the RCL ERP app (a call with voice). Please open the app.';
        _say(text, act: 'Ask on WhatsApp', url: 'https://wa.me/$mob?text=${Uri.encodeComponent(msg)}');
        return;
      }
      _say(text + (x is Map && x['none'] == true ? ' (${p.name} has no mobile number in his Settings, so WhatsApp cannot be offered.)' : ''));
    } catch (_) {
      _say(text);
    }
  }

  // ---------------- my microphone, camera, screen; the end ----------------
  Future<void> toggleMic() async {
    final c = call;
    if (c == null) return;
    if (c.mic == null) {
      _say('The microphone is not allowed – allow it for RCL ERP (the phone\'s Settings → Apps → RCL ERP → Permissions), then call again.', bad: true);
      return;
    }
    c.micOn = !c.micOn;
    await c.mic!.enable(c.micOn);
    _changed();
  }

  Future<void> toggleCam() async {
    final c = call;
    if (c == null) return;
    if (c.cam != null) return _stopMine('cam');
    RtcLocal s;
    try {
      s = await kit.camera(c.facing);
    } catch (e) {
      _say(rtcCamErr(e), bad: true);
      return;
    }
    await _showMine(c, s, 'cam');
  }

  Future<void> toggleScreen() async {
    final c = call;
    if (c == null) return;
    if (c.screen != null) return _stopMine('screen');
    if (!kit.canScreen) {
      _say('This phone cannot show its screen.');
      return;
    }
    RtcLocal? s;
    try {
      s = await kit.screen();
    } catch (e) {
      _say('The screen could not be shown (${_short(e)}).', bad: true);
      return;
    }
    if (s == null) return; // he did not allow it
    await _showMine(c, s, 'screen');
    _say('Your phone\'s screen is shown. Open any app – the call goes on (the notification brings you back).');
  }

  // a camera or the screen goes to everybody in the call (each on its own – one does not stop the other)
  Future<void> _showMine(RtcCall c, RtcLocal s, String kind) async {
    if (call != c) {
      await s.stop();
      return;
    }
    final cam = kind == 'cam';
    if (cam ? c.cam != null : c.screen != null) await _stopMine(kind, quiet: true);
    if (cam) {
      c.cam = s;
      c.torch = false;
    } else {
      c.screen = s;
    }
    for (final p in c.peers.values.toList()) {
      try {
        final sn = await p.pc.add(s);
        if (cam) {
          p.camS = sn;
        } else {
          p.scrS = sn;
        }
        if (!p.open) p.dirty = true;
      } catch (e) {
        debugPrint('call: $e');
      }
    }
    _tellAll({'t': 'share', 'on': true, 'sid': s.id, 'uid': me, 'name': myName, 'ptr': false, 'kind': cam ? 'cam' : 'screen', 'face': cam && c.facing == 'user'});
    await _keep();
    _changed();
  }

  Future<void> _stopMine(String kind, {bool quiet = false}) async {
    final c = call, cam = kind == 'cam';
    if (c == null) return;
    final s = cam ? c.cam : c.screen;
    if (s == null) return;
    if (cam) {
      c.cam = null;
      c.torch = false;
    } else {
      c.screen = null;
    }
    for (final p in c.peers.values.toList()) {
      final sn = cam ? p.camS : p.scrS;
      if (sn == null) continue;
      try {
        await p.pc.drop(sn);
      } catch (_) {/* the connection is closing */}
      if (cam) {
        p.camS = null;
      } else {
        p.scrS = null;
      }
      if (!p.open) p.dirty = true;
    }
    await s.stop();
    _tellAll({'t': 'share', 'on': false, 'sid': s.id, 'uid': me});
    if (!quiet) {
      await _keep();
      _changed();
    }
  }

  /// The phone's other camera (front ↔ back); a face (front) is shown at the side, the back camera big.
  Future<void> flip() async {
    final c = call, s = call?.cam;
    if (c == null || s == null) return;
    if (!await s.flip()) {
      _say('This phone has no other camera.');
      return;
    }
    c.facing = c.facing == 'user' ? 'environment' : 'user';
    c.torch = false;
    _tellAll({'t': 'share', 'on': true, 'sid': s.id, 'uid': me, 'name': myName, 'ptr': false, 'kind': 'cam', 'face': c.facing == 'user'});
    _changed();
  }

  Future<void> torch() async {
    final c = call, s = call?.cam;
    if (c == null || s == null) return;
    if (!await s.torch(!c.torch)) {
      _say('This camera has no light.');
      return;
    }
    c.torch = !c.torch;
    _changed();
  }

  Future<void> toggleSpeaker() async {
    final c = call;
    if (c == null) return;
    c.speaker = !c.speaker;
    await kit.speaker(c.speaker);
    _changed();
  }

  /// Low data: the pictures smaller and slower (the voice stays) – told to the others too, as the web does.
  void setLow(bool on, {bool auto = false}) {
    final c = call;
    if (c == null) return;
    c.low = on;
    if (!auto) c.lowSet = true;
    _tellAll({'t': 'low', 'on': c.low});
    _lowApply();
    if (auto) _say('The network is weak: low data is on – the picture is smaller and slower, the voice stays. (More → Low data switches it off.)');
    _changed();
  }

  void _lowApply() {
    final c = call;
    if (c == null) return;
    for (final p in c.peers.values) {
      final low = c.low || p.low;
      for (final (sn, kind) in [(p.scrS, 'screen'), (p.camS, 'cam'), (p.micS, 'audio')]) {
        if (sn != null) {
          p.pc.limit(sn, kind, low).catchError((Object e) {
            debugPrint('call: $e');
          });
        }
      }
    }
  }

  // the network every 3 s: weak / poor (poor for 6 s: low data by itself, once – the person decides after that)
  Future<void> _netCheck() async {
    final c = call;
    if (c == null) return;
    final ups = c.peers.values.where((p) => p.up && p.state != 'reconnecting').toList();
    if (ups.isEmpty) {
      if (c.net.isNotEmpty) {
        c.net = '';
        _changed();
      }
      return;
    }
    var worst = 0;
    for (final p in ups) {
      (double, int, int) q;
      try {
        q = await p.pc.quality();
      } catch (_) {
        continue;
      }
      final prev = p.netPrev ?? (q.$2, q.$3);
      p.netPrev = (q.$2, q.$3);
      final dl = max(0, q.$2 - prev.$1), dg = max(0, q.$3 - prev.$2), loss = dl + dg > 0 ? dl / (dl + dg) : 0.0;
      worst = max(worst, q.$1 > 0.8 || loss > 0.1 ? 2 : q.$1 > 0.35 || loss > 0.03 ? 1 : 0);
    }
    if (call != c) return;
    final net = const ['good', 'weak', 'poor'][worst];
    c.poorN = worst == 2 ? c.poorN + 1 : 0;
    if (c.poorN >= 2 && !c.low && !c.lowSet) setLow(true, auto: true);
    if (net != c.net) {
      c.net = net;
      _changed();
    }
  }

  // a line that dropped is made again (the host offers anew; the guest waits up to 40 s)
  Future<void> _restart(RtcPeer p) async {
    final c = call;
    if (c == null || c.peers[p.uid] != p || p.restarting) return;
    p.restarting = true;
    _await(p);
    try {
      await p.pc.offer(restart: true);
      final sdp = await p.pc.sdpWhenReady(3000, relay);
      if (call != c || c.peers[p.uid] != p) return;
      await _send('re', [p.uid], c.id, {'type': 'offer', 'sdp': sdp, 'todev': p.dev});
    } catch (e) {
      debugPrint('call: $e');
    }
  }

  void _await(RtcPeer p) {
    final c = call;
    p.state = 'reconnecting';
    _changed();
    if (p.lostT != null) return;
    p.lostT = _after(40000, () {
      p.lostT = null;
      if (call == c && c?.peers[p.uid] == p && p.cs != 'connected') _gone(p, 'lost');
    });
  }

  Future<void> _onRe(RtcPeer p, Map<String, dynamic> d) async {
    final c = call, sdp = '${d['sdp'] ?? ''}';
    if (c == null || sdp.isEmpty || sdp.length > 60000) return;
    if (d['type'] == 'offer' && c.role == 'guest') {
      p.restarting = true;
      _await(p);
      await p.pc.remote({'type': 'offer', 'sdp': sdp});
      await p.pc.answer();
      final a = await p.pc.sdpWhenReady(3000, relay);
      if (call == c) await _send('re', [p.uid], c.id, {'type': 'answer', 'sdp': a, 'todev': p.dev});
      _reCheck(p);
    } else if (d['type'] == 'answer' && c.role == 'host' && p.pc.signaling == 'have-local-offer') {
      await p.pc.remote({'type': 'answer', 'sdp': sdp});
      _reCheck(p);
    }
  }

  // a line that had not quite dropped stays "connected" through the restart – look again
  void _reCheck(RtcPeer p) {
    for (final ms in [1500, 4000, 8000]) {
      _after(ms, () {
        final c = call;
        if (c != null && c.peers[p.uid] == p && p.restarting && p.cs == 'connected') _onState(p, 'connected');
      });
    }
  }

  // ---------------- the chat ----------------
  static final _img = RegExp(r'^data:image/jpeg;base64,[A-Za-z0-9+/=]+$');
  bool _chatIn(Map<String, dynamic> m, bool mine) {
    final c = call;
    if (c == null) return false;
    final t0 = m['txt'] is String ? m['txt'] as String : '', txt = t0.length > 500 ? t0.substring(0, 500) : t0;
    Uint8List? img;
    final s = m['img'];
    if (s is String && s.length <= 220000 && _img.hasMatch(s)) {
      try {
        img = base64Decode(s.substring(23));
      } catch (_) {
        img = null;
      }
    }
    if (txt.trim().isEmpty && img == null) return false;
    final who0 = mine ? 'You' : '${m['name'] ?? ''}'.isNotEmpty ? '${m['name']}' : nameOf('${m['uid'] ?? ''}');
    final who = who0.isEmpty ? 'Someone' : (who0.length > 40 ? who0.substring(0, 40) : who0);
    c.chat.add(RtcMsg(who, txt, img, mine, now()));
    while (c.chat.length > 100) {
      c.chat.removeAt(0);
    }
    if (!mine && !c.chatOpen) {
      c.unread++;
      _say('New message from $who – press Chat.');
    }
    _changed();
    return true;
  }

  /// A message ([txt]) or a photo ([img]: a jpeg as data:image/jpeg;base64,…) to everybody connected.
  bool chatSend({String txt = '', String img = ''}) {
    final c = call;
    if (c == null) return false;
    final m = <String, dynamic>{'t': 'chat', 'id': _id(8), 'uid': me, 'name': myName, if (txt.isNotEmpty) 'txt': txt.length > 500 ? txt.substring(0, 500) : txt, if (img.isNotEmpty) 'img': img};
    var sent = 0;
    for (final p in c.peers.values) {
      if (p.open && _dc(p, m)) sent++;
    }
    if (sent == 0) {
      _say(c.peers.isEmpty ? 'Not sent – nobody is in the call.' : 'Not sent – nobody is connected yet.');
      return false;
    }
    _chatIn(m, true);
    return true;
  }

  void chatSeen(bool open) {
    final c = call;
    if (c == null) return;
    c.chatOpen = open;
    if (open) c.unread = 0;
    _changed();
  }

  // ---------------- what is shown: the big picture and the faces (the web's rtcViewPick / rtcFaces) ----------------
  String nameOf(String uid) {
    for (final u in users) {
      if (u.uid == uid) return u.name;
    }
    return uid == me ? myName : '';
  }

  List<String> _live(RtcCall c) => [for (final sid in c.vids.keys) if (c.shares[sid] != null && c.shares[sid]!.uid != me) sid];
  bool _isFace(RtcCall c, String sid) => c.shares[sid]?.kind == 'cam' && c.shares[sid]!.face;

  void _pick([String want = '']) {
    final c = call;
    if (c == null) return;
    final live = _live(c);
    int at(String x) => c.shares[x]!.at;
    final big = live.where((x) => !_isFace(c, x)).toList()
      ..sort((a, b) {
        final ka = c.shares[a]!.kind == 'cam' ? 1 : 0, kb = c.shares[b]!.kind == 'cam' ? 1 : 0;
        return ka != kb ? ka - kb : at(a) - at(b);
      });
    final scr = big.where((x) => c.shares[x]!.kind != 'cam').toList();
    final newest = scr.isNotEmpty ? scr.last : (big.isNotEmpty ? big.last : '');
    if (want.isNotEmpty && live.contains(want)) c.pin = _isFace(c, want) ? want : '';
    if (c.pin.isNotEmpty && (!live.contains(c.pin) || c.newest != newest)) c.pin = '';
    var sid = c.pin.isNotEmpty ? c.pin : (want.isNotEmpty && big.contains(want)) ? want : (big.contains(c.view) && c.newest == newest) ? c.view : newest;
    // (the phone) nothing big: the other's face fills the screen, as in a phone's video call
    final faces = live.where((x) => _isFace(c, x)).toList()..sort((a, b) => at(a) - at(b));
    c.faceStage = sid.isEmpty && faces.isNotEmpty;
    if (c.faceStage) sid = faces.first;
    c.newest = newest;
    c.view = sid;
    c.tabs = [...big, if (c.pin.isNotEmpty) c.pin];
  }

  /// A face tapped (big until another is tapped, it goes or a new screen comes), or a tab of the pictures.
  void show(String sid) {
    _pick(sid);
    _changed();
  }

  RtcIn? get stage => call?.vids[call!.view]?.media;
  RtcShare? get stageShare => call?.shares[call!.view];

  List<RtcFace> get faces {
    final c = call;
    if (c == null) return [];
    final l = _live(c).where((x) => _isFace(c, x) && x != c.view).toList()..sort((a, b) => c.shares[a]!.at - c.shares[b]!.at);
    return [
      for (final sid in l) RtcFace(sid, c.shares[sid]!.name, c.vids[sid]!.media, false, false),
      if (c.cam != null) RtcFace(c.cam!.id, 'You', c.cam!, true, c.facing == 'user'),
    ];
  }

  /// The others of the call, by name.
  List<String> get people {
    final c = call;
    if (c == null) return [];
    final r = c.roster;
    if (c.role == 'guest' && r != null) {
      final h = r['host'] is Map ? r['host'] as Map : const {};
      return [
        if ('${h['uid'] ?? ''}' != me && '${h['name'] ?? ''}'.isNotEmpty) '${h['name']}',
        for (final x in (r['people'] as List? ?? const []).whereType<Map>())
          if ('${x['uid'] ?? ''}' != me) '${x['name'] ?? ''}',
      ];
    }
    return [for (final p in c.peers.values) p.name];
  }

  /// One line for the top of the call: ringing / connecting / the time and the way.
  String status() {
    final c = call;
    if (c == null) return '';
    final ps = c.peers.values.toList();
    if (ps.any((p) => p.state == 'reconnecting')) return 'Connecting again…';
    if (c.t1 == 0) {
      if (c.role == 'host' && ps.isNotEmpty && ps.every((p) => p.state == 'ringing')) return 'Ringing…';
      return 'Connecting…';
    }
    final s = ((now() - c.t1) / 1000).floor(), mm = '${s ~/ 60}'.padLeft(2, '0'), ss = '${s % 60}'.padLeft(2, '0');
    final via = ps.any((p) => p.via == 'relay') ? ' · through the relay' : ps.any((p) => p.via == 'direct') ? ' · direct connection' : '';
    final net = c.net == 'weak' ? ' · weak network' : c.net == 'poor' ? ' · poor network' : '';
    return '$mm:$ss$via$net';
  }

  /// The page of the app the other person is on (the web says it while he shows his screen).
  String pageOf() {
    final c = call;
    if (c == null || c.pages.isEmpty) return '';
    final sh = stageShare;
    return (sh != null ? c.pages[sh.uid] : null) ?? c.pages.values.first;
  }

  Future<void> _keep() async {
    final c = call;
    if (c == null) return;
    final names = people.join(', ');
    await kit.keep(true, mic: c.mic != null, cam: c.cam != null, screen: c.screen != null, title: names.isEmpty ? 'Call is on' : 'Call with $names', text: 'Tap to go back to the call');
  }

  /// The call is over on this side (pressed here, or nobody is left).
  void end({String say = '', bool quiet = false, bool bad = false}) {
    final c = call;
    if (c == null) return;
    call = null;
    _netT?.cancel();
    _netT = null;
    final ringing = [for (final p in c.peers.values) if (!p.up && p.state == 'ringing') p.uid];
    for (final p in c.peers.values) {
      _dc(p, {'t': 'bye', 'end': c.role == 'host'});
    }
    if (c.role == 'host' && ringing.isNotEmpty) _note('cancel', ringing, c.id);
    if (c.role == 'guest' && !quiet) {
      for (final p in c.peers.values) {
        if (!p.open) _note('bye', [p.uid], c.id, {'todev': p.dev});
      }
    }
    if (c.role == 'host' && c.t1 > 0 && c.met.isNotEmpty) {
      rpc('rtcSend', [
        {'t': 'end', 'to': c.met.toList(), 'call': c.id, 'secs': ((now() - c.t1) / 1000).round()}
      ]).catchError((Object e) => null); // one line for the Activity Log
    }
    for (final p in c.peers.values) {
      for (final t in [p.ringT, p.watchT, p.busyT, p.waT, p.reT, p.lostT]) {
        t?.cancel();
      }
    }
    _after(250, () => _drop(c)); // (a moment for the "bye" to leave)
    kit.keep(false);
    if (say.isNotEmpty) {
      _say(say, bad: bad);
    } else if (!quiet) {
      _say('The call has ended.');
    }
    _changed();
  }

  Future<void> _drop(RtcCall c) async {
    for (final s in [c.screen, c.cam, c.mic]) {
      try {
        await s?.stop();
      } catch (_) {/* stopped */}
    }
    for (final p in c.peers.values) {
      try {
        await p.pc.close();
      } catch (_) {/* closed */}
    }
  }

  /// Signed out / another site: everything stops.
  void close() {
    if (closed) return;
    if (ring != null) {
      final r = ring!;
      _ringClose();
      _note('decline', [r.from], r.call, {'todev': r.dev, 'reply': 0, 'ep': ''});
    }
    final c = call;
    end(quiet: true);
    closed = true;
    for (final t in _timers.toList()) {
      t.cancel();
    }
    _timers.clear();
    _beatT?.cancel();
    _netT?.cancel();
    if (c != null) _drop(c);
    kit.keep(false);
  }
}
