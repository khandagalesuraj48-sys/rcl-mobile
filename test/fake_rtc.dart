/* (3.26.0) A pretend phone for the calls (no camera, no network): what the call engine (lib/core/rtc.dart) asks of the media and the
 * connections is kept here, and the tests play the other side (the web) – its notes, its data channel messages, its pictures. */
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rcl_mobile/core/rtc.dart';

class FakeLocal implements RtcLocal {
  FakeLocal(this.id);
  @override
  final String id;
  bool stopped = false, on = true, flipped = false;
  @override
  Future<void> stop() async {
    stopped = true;
  }
  @override
  Future<void> enable(bool v) async {
    on = v;
  }
  @override
  Future<bool> flip() async {
    flipped = !flipped;
    return true;
  }

  @override
  Future<bool> torch(bool v) async => true;
}

class FakeDc extends RtcDc {
  bool _open = false;
  final sent = <Map<String, dynamic>>[];
  @override
  bool get open => _open;
  @override
  void send(String text) => sent.add((jsonDecode(text) as Map).cast<String, dynamic>());
  void openNow() {
    _open = true;
    onOpen?.call();
  }

  /// A message of the other side.
  void recv(Map<String, dynamic> m) => onText?.call(jsonEncode(m));
  List<Map<String, dynamic>> of(String t) => sent.where((m) => m['t'] == t).toList();
}

class FakePc extends RtcPc {
  String sig = 'stable';
  final added = <String>[], limits = <String>[];
  final remotes = <Map<String, dynamic>>[];
  int offers = 0, answers = 0, rollbacks = 0;
  bool closed = false, recvOnly = false;
  FakeDc? dc;
  @override
  Future<RtcDc> channel(String label) async => dc = FakeDc();
  @override
  Future<Object> add(RtcLocal media) async {
    added.add(media.id);
    return 's:${media.id}';
  }

  @override
  Future<void> drop(Object sender) async {
    added.remove('$sender'.substring(2));
  }
  @override
  Future<void> recvAudio() async {
    recvOnly = true;
  }
  @override
  Future<Map<String, dynamic>> offer({bool restart = false}) async {
    offers++;
    sig = 'have-local-offer';
    return {'type': 'offer', 'sdp': 'v=0 app-offer${restart ? ' restart' : ''}'};
  }

  @override
  Future<Map<String, dynamic>> answer() async {
    answers++;
    sig = 'stable';
    return {'type': 'answer', 'sdp': 'v=0 app-answer'};
  }

  @override
  Future<void> remote(Map<String, dynamic> d) async {
    remotes.add(d);
    sig = d['type'] == 'offer' ? 'have-remote-offer' : 'stable';
  }

  @override
  Future<void> rollback() async {
    rollbacks++;
    sig = 'stable';
  }

  @override
  Future<String> sdpWhenReady(int ms, bool relay) async => sig == 'have-local-offer' ? 'v=0 app-offer' : 'v=0 app-answer';
  @override
  String get signaling => sig;
  @override
  Future<void> addIce(Map<String, dynamic> c) async {}
  @override
  Future<String> way() async => 'direct';
  @override
  Future<(double, int, int)> quality() async => (0.05, 0, 100);
  @override
  Future<void> limit(Object sender, String kind, bool low) async {
    limits.add('$kind:$low');
  }
  @override
  Future<void> close() async {
    closed = true;
  }

  /// The other side connected, its channel open (the guest's: it comes from the host).
  void connect({bool channelFromOther = false}) {
    if (channelFromOther) {
      final d = FakeDc();
      dc = d;
      onChannel?.call(d);
      d.openNow();
    } else {
      dc?.openNow();
    }
    onState?.call('connected');
  }

  /// A picture of the other side comes ([sid] = its stream).
  void picture(String sid) => onTrack?.call('video', RtcIn(sid, 't-$sid', sid));
}

class FakeKit implements RtcKit {
  final pcs = <FakePc>[];
  final keeps = <String>[];
  final rings = <bool>[];
  bool screenOk = true, camOk = true, micOk = true;
  int cams = 0;
  bool speakerOn = false;
  @override
  bool get canScreen => true;
  @override
  Future<RtcPc> peer(List<Map<String, dynamic>> ice) async {
    final p = FakePc();
    pcs.add(p);
    return p;
  }

  @override
  Future<RtcLocal?> mic() async => micOk ? FakeLocal('mic-1') : null;
  @override
  Future<RtcLocal> camera(String facing) async {
    if (!camOk) throw Exception('NotAllowedError');
    cams++;
    return FakeLocal('cam-$cams');
  }

  @override
  Future<RtcLocal?> screen() async => screenOk ? FakeLocal('scr-1') : null;
  @override
  Future<void> speaker(bool on) async {
    speakerOn = on;
  }
  @override
  Future<void> keep(bool on, {bool mic = false, bool cam = false, bool screen = false, String title = '', String text = ''}) async {
    keeps.add(on ? 'on mic:$mic cam:$cam screen:$screen $title' : 'off');
  }
  @override
  Future<void> ring(bool on, {String title = '', String text = ''}) async {
    rings.add(on);
  }

  /// A pretend picture: a screen (a page with lines), a face (a round head) – the same every run.
  @override
  Widget view(RtcMedia media, {bool mirror = false, bool cover = false}) {
    final id = media.id, face = id.startsWith('cam') || id.startsWith('face');
    return Container(
      key: ValueKey('fake-view-$id'),
      color: face ? const Color(0xFF3B4A5A) : const Color(0xFFF4F6F8),
      alignment: Alignment.center,
      child: face
          ? const Icon(Icons.face_rounded, size: 64, color: Color(0xFFE8C9A8))
          : Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 220, height: 26, color: const Color(0xFF17803D)),
              for (var i = 0; i < 6; i++) Container(margin: const EdgeInsets.only(top: 10), width: 220, height: 12, color: const Color(0xFFD5DCE3)),
            ]),
    );
  }
}
