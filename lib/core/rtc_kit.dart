/* (3.26.0) THE MEDIA OF A CALL ON THE PHONE – flutter_webrtc (Google's WebRTC, the same as inside Chrome and Edge: the web and the app
 * speak the same). The call itself (who, the notes, the messages) is lib/core/rtc.dart.
 *   – the microphone with the phone's echo cancelling and noise removal; a camera 1280 × 720 at 24 a second, front or back;
 *   – the phone's screen (Android): the phone asks first ("Start now"); Android shows a screen only while the app has its notification
 *     "Call is on" (a foreground service – android/…/CallService.kt, started through the channel 'rcl/call'); the same notification
 *     keeps the microphone working while another app is open;
 *   – the ring: the phone's ringtone again and again until it is answered (a notification of the call, "insistent");
 *   – what a picture may use (the web's rtcLowApply): a screen sharp (2.5 Mbit/s, 15 a second, its size kept), a camera smooth
 *     (1.2 Mbit/s, 24 a second), the voice first (64 kbit/s, high priority); low data: 150 kbit/s, 5 a second, smaller. */
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'alerts.dart';
import 'lang.dart' show tr;
import 'rtc.dart';

class WebrtcKit implements RtcKit {
  static const _ch = MethodChannel('rcl/call');
  static const _ringId = 7102;
  bool _on = false, _mic = false, _cam = false, _scr = false;
  String _title = '', _text = '';

  @override
  bool get canScreen => Platform.isAndroid;

  @override
  Future<RtcPc> peer(List<Map<String, dynamic>> ice) async {
    final pc = await createPeerConnection({
      'iceServers': ice.isNotEmpty
          ? ice
          : [
              {'urls': ['stun:stun.l.google.com:19302']}
            ],
      'sdpSemantics': 'unified-plan',
    });
    return _Pc(pc);
  }

  @override
  Future<RtcLocal?> mic() async {
    try {
      final s = await navigator.mediaDevices.getUserMedia({
        'audio': {'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
        'video': false,
      });
      return _Local(s);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RtcLocal> camera(String facing) async {
    final s = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {'facingMode': facing, 'width': 1280, 'height': 720, 'frameRate': 24},
    });
    return _Local(s, onStop: () {
      _cam = false;
    });
  }

  @override
  Future<RtcLocal?> screen() async {
    if (!Platform.isAndroid) return null;
    if (!await Helper.requestCapturePermission()) return null;
    // Android 14: the notification (a foreground service "media projection") must be on BEFORE the screen is taken
    _scr = true;
    await _service();
    try {
      final s = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
      return _Local(s, onStop: () {
        _scr = false;
        _service();
      });
    } catch (e) {
      _scr = false;
      await _service();
      rethrow;
    }
  }

  @override
  Future<void> speaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {/* the phone decides */}
  }

  @override
  Future<void> keep(bool on, {bool mic = false, bool cam = false, bool screen = false, String title = '', String text = ''}) async {
    _on = on;
    if (on) {
      _mic = mic;
      _cam = cam;
      _scr = screen;
      _title = title;
      _text = text;
    } else {
      _mic = _cam = _scr = false;
    }
    await _service();
  }

  bool _awake = false;
  Future<void> _service() async {
    if (!Platform.isAndroid) return;
    try {
      if (_awake != _on) {
        _awake = _on;
        await _ch.invokeMethod<bool>('awake', {'on': _on}); // the screen stays on while a call is on
      }
      final mic = _on && _mic, cam = _on && _cam;
      if (_scr || mic || cam) {
        await _ch.invokeMethod<bool>('start', {'mic': mic, 'cam': cam, 'screen': _scr, 'title': tr(_title.isEmpty ? 'Call is on' : _title), 'text': tr(_text.isEmpty ? 'Tap to go back to the call' : _text)});
      } else {
        await _ch.invokeMethod<bool>('stop');
      }
    } catch (_) {/* an older app part: the call still works while the app is open */}
  }

  @override
  Future<void> ring(bool on, {String title = '', String text = ''}) async {
    final n = FlutterLocalNotificationsPlugin();
    try {
      if (!on) {
        await n.cancel(_ringId);
        return;
      }
      await Alerts.init();
      await n.show(
          _ringId,
          tr(title),
          tr(text),
          NotificationDetails(
              android: AndroidNotificationDetails('rcl_calls', 'Calls',
                  channelDescription: 'A call that comes in (the web or the app)',
                  importance: Importance.max,
                  priority: Priority.high,
                  category: AndroidNotificationCategory.call,
                  ongoing: true,
                  autoCancel: false,
                  playSound: true,
                  sound: const UriAndroidNotificationSound('content://settings/system/ringtone'),
                  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
                  enableVibration: true,
                  timeoutAfter: 80000,
                  additionalFlags: Int32List.fromList(<int>[4])), // FLAG_INSISTENT: the ringtone again and again until answered
              iOS: const DarwinNotificationDetails(),
              windows: const WindowsNotificationDetails()));
    } catch (_) {/* no notifications here: the ring is still on the screen */}
  }

  @override
  Widget view(RtcMedia media, {bool mirror = false, bool cover = false}) {
    final s = media is _Local ? media.s : (media is RtcIn && media.handle is MediaStream ? media.handle as MediaStream : null);
    if (s == null) return const SizedBox.shrink();
    return _View(key: ValueKey('v-${s.id}'), stream: s, mirror: mirror, cover: cover);
  }
}

class _Local implements RtcLocal {
  _Local(this.s, {this.onStop});
  final MediaStream s;
  final void Function()? onStop;
  bool _stopped = false;
  @override
  String get id => s.id;
  MediaStreamTrack? get track => s.getVideoTracks().isNotEmpty ? s.getVideoTracks().first : (s.getAudioTracks().isNotEmpty ? s.getAudioTracks().first : null);

  @override
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    for (final t in s.getTracks()) {
      try {
        await t.stop();
      } catch (_) {/* stopped */}
    }
    try {
      await s.dispose();
    } catch (_) {/* gone */}
    onStop?.call();
  }

  @override
  Future<void> enable(bool on) async {
    for (final t in s.getAudioTracks()) {
      t.enabled = on;
    }
  }

  @override
  Future<bool> flip() async {
    final v = s.getVideoTracks();
    if (v.isEmpty) return false;
    try {
      return await Helper.switchCamera(v.first);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> torch(bool on) async {
    final v = s.getVideoTracks();
    if (v.isEmpty) return false;
    try {
      if (!await v.first.hasTorch()) return false;
      await v.first.setTorch(on);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class _Dc extends RtcDc {
  _Dc(this.dc, {bool open = false}) : _open = open {
    dc.onDataChannelState = (st) {
      if (st == RTCDataChannelState.RTCDataChannelOpen) {
        _open = true;
        onOpen?.call();
      } else if (st == RTCDataChannelState.RTCDataChannelClosed || st == RTCDataChannelState.RTCDataChannelClosing) {
        _open = false;
        onClose?.call();
      }
    };
    dc.onMessage = (m) {
      if (!m.isBinary) onText?.call(m.text);
    };
  }
  final RTCDataChannel dc;
  bool _open;
  @override
  bool get open => _open;
  @override
  void send(String text) {
    dc.send(RTCDataChannelMessage(text)).catchError((Object e) {
      debugPrint('call: $e');
    });
  }
}

class _Pc extends RtcPc {
  _Pc(this.pc) {
    pc.onConnectionState = (s) => onState?.call(switch (s) {
          RTCPeerConnectionState.RTCPeerConnectionStateConnected => 'connected',
          RTCPeerConnectionState.RTCPeerConnectionStateConnecting => 'connecting',
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => 'disconnected',
          RTCPeerConnectionState.RTCPeerConnectionStateFailed => 'failed',
          RTCPeerConnectionState.RTCPeerConnectionStateClosed => 'closed',
          _ => 'new',
        });
    pc.onSignalingState = (s) => _sig = switch (s) {
          RTCSignalingState.RTCSignalingStateHaveLocalOffer => 'have-local-offer',
          RTCSignalingState.RTCSignalingStateHaveRemoteOffer => 'have-remote-offer',
          RTCSignalingState.RTCSignalingStateClosed => 'closed',
          RTCSignalingState.RTCSignalingStateStable => 'stable',
          _ => _sig,
        };
    pc.onRenegotiationNeeded = () => onNegotiation?.call();
    pc.onIceGatheringState = (s) {
      if (s == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _complete = true;
        _gatDone();
      } else if (s == RTCIceGatheringState.RTCIceGatheringStateGathering) {
        _complete = false;
      }
    };
    pc.onIceCandidate = (c) {
      final cand = c.candidate ?? '';
      if (cand.isEmpty) return;
      if (cand.contains(' typ relay') && _gat != null && _relayWait) _relayT ??= Timer(const Duration(milliseconds: 500), _gatDone); // (the relay answered: half a second more, then go)
      if (cand.contains(' typ relay')) _relaySeen = true;
      onIce?.call({'candidate': cand, 'sdpMid': c.sdpMid, 'sdpMLineIndex': c.sdpMLineIndex});
    };
    pc.onTrack = (e) {
      final s = e.streams.isNotEmpty ? e.streams.first : null;
      if (s == null) return;
      onTrack?.call(e.track.kind ?? '', RtcIn(s.id, e.track.id ?? '', s));
    };
    pc.onRemoveTrack = (s, t) => onTrackGone?.call(s.id, t.id ?? '');
    pc.onDataChannel = (dc) => onChannel?.call(_Dc(dc, open: true));
  }
  final RTCPeerConnection pc;
  String _sig = 'stable';
  bool _complete = false, _relaySeen = false, _relayWait = false;
  Completer<void>? _gat;
  Timer? _relayT;

  void _gatDone() {
    final c = _gat;
    if (c != null && !c.isCompleted) c.complete();
  }

  @override
  String get signaling => _sig;

  @override
  Future<RtcDc> channel(String label) async => _Dc(await pc.createDataChannel(label, RTCDataChannelInit()
    ..id = -1
    ..protocol = ''));

  @override
  Future<Object> add(RtcLocal media) async {
    final l = media as _Local, t = l.track;
    if (t == null) throw StateError('nothing to send');
    return pc.addTrack(t, l.s);
  }

  @override
  Future<void> drop(Object sender) async {
    await pc.removeTrack(sender as RTCRtpSender);
  }

  @override
  Future<void> recvAudio() async {
    await pc.addTransceiver(kind: RTCRtpMediaType.RTCRtpMediaTypeAudio, init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly));
  }

  @override
  Future<Map<String, dynamic>> offer({bool restart = false}) async {
    if (restart) {
      _complete = false;
      _relaySeen = false;
    }
    final o = await pc.createOffer(restart
        ? {
            'mandatory': {'IceRestart': true},
            'optional': []
          }
        : <String, dynamic>{});
    await pc.setLocalDescription(o);
    _sig = 'have-local-offer';
    return {'type': o.type, 'sdp': o.sdp};
  }

  @override
  Future<Map<String, dynamic>> answer() async {
    final a = await pc.createAnswer(<String, dynamic>{});
    await pc.setLocalDescription(a);
    _sig = 'stable';
    return {'type': a.type, 'sdp': a.sdp};
  }

  @override
  Future<void> remote(Map<String, dynamic> d) async {
    final type = '${d['type'] ?? ''}';
    await pc.setRemoteDescription(RTCSessionDescription('${d['sdp'] ?? ''}', type));
    _sig = type == 'offer' ? 'have-remote-offer' : 'stable';
  }

  @override
  Future<void> rollback() async {
    await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
    _sig = 'stable';
  }

  @override
  Future<String> sdpWhenReady(int ms, bool relay) async {
    if (!_complete) {
      final c = _gat = Completer<void>();
      _relayWait = relay;
      final t = Timer(Duration(milliseconds: relay ? math.max(ms, 6000) : ms), _gatDone);
      if (relay && _relaySeen) _relayT ??= Timer(const Duration(milliseconds: 500), _gatDone);
      await c.future;
      t.cancel();
      _relayT?.cancel();
      _relayT = null;
      _gat = null;
    }
    final d = await pc.getLocalDescription();
    return d?.sdp ?? '';
  }

  @override
  Future<void> addIce(Map<String, dynamic> c) async {
    final cand = '${c['candidate'] ?? ''}';
    if (cand.isEmpty) return;
    final idx = c['sdpMLineIndex'];
    await pc.addCandidate(RTCIceCandidate(cand, c['sdpMid'] == null ? null : '${c['sdpMid']}', idx is num ? idx.toInt() : int.tryParse('${idx ?? ''}')));
  }

  Future<Map<String, Map<dynamic, dynamic>>> _stats() async {
    final by = <String, Map<dynamic, dynamic>>{};
    for (final r in await pc.getStats()) {
      by[r.id] = {...r.values, 'type': r.type};
    }
    return by;
  }

  Map<dynamic, dynamic>? _pair(Map<String, Map<dynamic, dynamic>> by) {
    for (final r in by.values) {
      if (r['type'] == 'transport' && '${r['selectedCandidatePairId'] ?? ''}'.isNotEmpty) return by['${r['selectedCandidatePairId']}'];
    }
    for (final r in by.values) {
      if (r['type'] == 'candidate-pair' && r['nominated'] == true && r['state'] == 'succeeded') return r;
    }
    return null;
  }

  @override
  Future<String> way() async {
    final by = await _stats(), cp = _pair(by);
    if (cp == null) return '';
    final loc = by['${cp['localCandidateId']}'], rem = by['${cp['remoteCandidateId']}'];
    if (loc == null || rem == null) return '';
    return loc['candidateType'] == 'relay' || rem['candidateType'] == 'relay' ? 'relay' : 'direct';
  }

  @override
  Future<(double, int, int)> quality() async {
    final by = await _stats(), cp = _pair(by);
    num n(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
    var lost = 0, got = 0;
    for (final r in by.values) {
      if (r['type'] == 'inbound-rtp' && r['kind'] == 'audio') {
        lost += n(r['packetsLost']).toInt();
        got += n(r['packetsReceived']).toInt();
      }
    }
    return (cp == null ? 0.0 : n(cp['currentRoundTripTime']).toDouble(), lost, got);
  }

  @override
  Future<void> limit(Object sender, String kind, bool low) async {
    final s = sender as RTCRtpSender, prm = s.parameters;
    final enc = (prm.encodings == null || prm.encodings!.isEmpty) ? RTCRtpEncoding() : prm.encodings!.first;
    if (kind == 'audio') {
      enc.maxBitrate = low ? 32000 : 64000;
      enc.priority = RTCPriorityType.high;
      enc.networkPriority = RTCPriorityType.high;
    } else if (low) {
      enc.maxBitrate = 150000;
      enc.maxFramerate = 5;
      enc.scaleResolutionDownBy = 1.5;
      enc.priority = RTCPriorityType.low;
    } else {
      enc.maxBitrate = kind == 'screen' ? 2500000 : 1200000;
      enc.maxFramerate = kind == 'screen' ? 15 : 24;
      enc.scaleResolutionDownBy = 1.0;
      enc.priority = kind == 'screen' ? RTCPriorityType.medium : RTCPriorityType.low;
    }
    prm.encodings = [enc];
    if (kind != 'audio') prm.degradationPreference = kind == 'screen' ? RTCDegradationPreference.MAINTAIN_RESOLUTION : RTCDegradationPreference.BALANCED;
    await s.setParameters(prm);
  }

  @override
  Future<void> close() async {
    _gatDone();
    _relayT?.cancel();
    try {
      await pc.close();
    } catch (_) {/* closed */}
    try {
      await pc.dispose();
    } catch (_) {/* gone */}
  }
}

/// One picture: its own renderer, given the stream once it is ready (and freed when it goes).
class _View extends StatefulWidget {
  const _View({super.key, required this.stream, required this.mirror, required this.cover});
  final MediaStream stream;
  final bool mirror, cover;
  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _r = RTCVideoRenderer();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _r.initialize().then((_) {
      if (!mounted) return;
      _r.srcObject = widget.stream;
      setState(() => _ready = true);
    }, onError: (Object e) {});
  }

  @override
  void didUpdateWidget(_View old) {
    super.didUpdateWidget(old);
    if (_ready && old.stream != widget.stream) _r.srcObject = widget.stream;
  }

  @override
  void dispose() {
    try {
      _r.srcObject = null;
    } catch (_) {/* not ready */}
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ready
      ? RTCVideoView(_r, mirror: widget.mirror, objectFit: widget.cover ? RTCVideoViewObjectFit.RTCVideoViewObjectFitCover : RTCVideoViewObjectFit.RTCVideoViewObjectFitContain)
      : const SizedBox.expand();
}
