/* CALLS ON THE PHONE (3.26.0, asked 19-10-2026: "JR SAMAJ EK USER APP WAR AAHE ANI EK USER WEB WAR TRI SUDHA CONNECT HOYLA HAW TE PN
 * PROPER"; "SAGLE KAHI KARTA YAW" – a call comes in, call a web user, show the phone's camera, show the phone's screen). The app's own
 * screens (never the web's) for the web's screen share (lib/core/rtc.dart):
 *   – Home → the call button: who is at the app now (as the web's list), missed calls with "Call back", Voice call · Video call ·
 *     My screen → Call;
 *   – a call that comes in (from the web or another phone): its own screen over everything, the ringtone – Accept · Decline · a
 *     short reply;
 *   – the call: the other's screen or back camera big (pinch to zoom), the faces in a row (mine "You"), the time and the way
 *     (direct / relay); Mute · Camera · My screen · Chat · More (switch camera, light, speaker, low data) · End. Back keeps the call
 *     on: a green bar on top of the app goes back to it. */
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/rtc.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _bg = Color(0xFF0B1410), _panel = Color(0xFF16231C), _btn = Color(0xFF243329), _red = Color(0xFFE53935), _blue = Color(0xFF1E88E5);

String _initials(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  return (p.first.substring(0, 1) + (p.length > 1 ? p.last.substring(0, 1) : '')).toUpperCase();
}

/// The green bar of a call that goes on behind the app, the ring's screen and the call's screen – over every screen of the app.
class CallLayer extends StatefulWidget {
  const CallLayer({super.key, required this.nav, required this.child});
  final GlobalKey<NavigatorState> nav;
  final Widget child;
  @override
  State<CallLayer> createState() => _CallLayerState();
}

class _CallLayerState extends State<CallLayer> {
  Rtc? _r;
  Route<void>? _ringR, _callR;
  RtcCall? _seen;
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = SessionScope.of(context).rtc;
    if (r != _r) {
      _r?.removeListener(_on);
      _r?.notice.removeListener(_note);
      _r = r;
      r?.addListener(_on);
      r?.notice.addListener(_note);
      WidgetsBinding.instance.addPostFrameCallback((_) => _on());
    }
  }

  @override
  void dispose() {
    _r?.removeListener(_on);
    _r?.notice.removeListener(_note);
    _tick?.cancel();
    super.dispose();
  }

  // (a change that comes while the screens are being drawn – a site closed – is done right after)
  bool get _drawing => SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks;

  void _on() {
    if (!mounted) return;
    if (_drawing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _on());
      return;
    }
    final r = _r, nav = widget.nav.currentState;
    if (nav == null) return;
    // a ring: its own screen over everything
    if (r?.ring != null && _ringR == null) {
      final route = _ringR = MaterialPageRoute<void>(builder: (_) => RingScreen(rtc: r!), fullscreenDialog: true);
      nav.push(route);
    } else if (r?.ring == null && _ringR != null) {
      final route = _ringR!;
      _ringR = null;
      if (route.isActive) nav.removeRoute(route);
    }
    // a call that has just begun: its screen opens
    final c = r?.call;
    if (c != null && c != _seen) {
      _seen = c;
      _open();
    } else if (c == null && _seen != null) {
      _seen = null;
      final route = _callR;
      _callR = null;
      if (route != null && route.isActive) nav.removeRoute(route);
    }
    final bar = c != null && _callR == null;
    if (bar && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!bar) {
      _tick?.cancel();
      _tick = null;
    }
    setState(() {});
  }

  void _open() {
    final r = _r, nav = widget.nav.currentState;
    if (r == null || nav == null || r.call == null || (_callR?.isActive ?? false)) return;
    final route = _callR = MaterialPageRoute<void>(builder: (_) => CallScreen(rtc: r));
    nav.push(route).then((_) {
      if (_callR == route) _callR = null; // Back: the call goes on – the green bar
      _on();
    });
    setState(() {});
  }

  void _note() {
    if (_drawing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _note());
      return;
    }
    final n = _r?.notice.value;
    final ctx = widget.nav.currentContext;
    if (n == null || ctx == null) return;
    final m = ScaffoldMessenger.maybeOf(ctx);
    if (m == null) return;
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(n.text),
        backgroundColor: n.bad ? C.red : C.ink,
        duration: Duration(seconds: n.act.isNotEmpty ? 12 : (n.text.length > 80 ? 7 : 4)),
        action: n.act.isEmpty ? null : SnackBarAction(label: tr(n.act), textColor: const Color(0xFF7CE495), onPressed: () => launchUrl(Uri.parse(n.url), mode: LaunchMode.externalApplication)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r, c = r?.call, bar = c != null && _callR == null;
    final m = MediaQuery.of(context);
    // (the shape stays the same with or without the bar: the screens below keep their place)
    return Column(children: [
      if (r != null && c != null && _callR == null)
        Material(
          color: C.green,
          child: InkWell(
            key: const Key('call-bar'),
            onTap: _open,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, m.padding.top + 6, 8, 6),
              child: Row(children: [
                const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${r.people.isEmpty ? tr('Call') : r.people.join(', ')} · ${tr(r.status())} – ${tr('tap to return')}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                IconButton(
                  key: const Key('call-bar-mic'), // (no tooltip: the bar is above the app's screens, where no tooltip can be drawn)
                  onPressed: r.toggleMic,
                  icon: Icon(c.micOn ? Icons.mic_rounded : Icons.mic_off_rounded, color: Colors.white),
                ),
                IconButton(
                  key: const Key('call-bar-end'),
                  onPressed: () => r.end(),
                  icon: const CircleAvatar(radius: 16, backgroundColor: _red, child: Icon(Icons.call_end_rounded, color: Colors.white, size: 18)),
                ),
              ]),
            ),
          ),
        )
      else
        const SizedBox.shrink(),
      Expanded(child: MediaQuery(data: bar ? m.removePadding(removeTop: true) : m, child: widget.child)),
    ]);
  }
}

// ---------------------------------------------------------------- the list to call from ----------------------------------------------------------------
Future<void> openCallPick(BuildContext context, {String to = ''}) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CallPickScreen(to: to)));

class CallPickScreen extends StatefulWidget {
  const CallPickScreen({super.key, this.to = ''});
  final String to;
  @override
  State<CallPickScreen> createState() => _CallPickScreenState();
}

class _CallPickScreenState extends State<CallPickScreen> {
  Rtc? r;
  bool loading = true, busy = false;
  String err = '', sel = '', mode = 'voice', q = '';
  List<Map<String, dynamic>> missed = [];
  Timer? _t;

  @override
  void initState() {
    super.initState();
    sel = widget.to;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {}); // "checking…" → "not at the app now" after a few seconds
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    r?.removeListener(_changed);
    r?.closePick();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final rr = r = SessionScope.read(context).rtc;
    if (rr == null) {
      setState(() {
        loading = false;
        err = 'Calls are on the Android phone app.';
      });
      return;
    }
    rr.addListener(_changed);
    try {
      missed = await rr.openPick();
      if (!mounted) return;
      setState(() {
        loading = false;
        err = rr.off ? 'Screen share is switched off for you – the Admin can switch it on in Users & Access.' : rr.users.isEmpty ? 'There is no other user to call yet – the Admin adds users in Users & Access.' : '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _call() async {
    final rr = r;
    if (rr == null || busy) return;
    if (sel.isEmpty) {
      toast(context, 'Pick the person to call.', bad: true);
      return;
    }
    setState(() => busy = true);
    final why = await rr.start(sel, mode);
    if (!mounted) return;
    setState(() => busy = false);
    if (why.isNotEmpty) {
      toast(context, why, bad: true);
      return;
    }
    // this list goes (the call's screen is already over it)
    final me = ModalRoute.of(context);
    if (me != null && me.isActive) Navigator.of(context).removeRoute(me);
  }

  @override
  Widget build(BuildContext context) {
    final rr = r;
    final list = rr == null ? <RtcUser>[] : rr.users.where((u) => q.isEmpty || u.name.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: const Text('Call', mr: 'कॉल')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : err.isNotEmpty
              ? EmptyState(err, '', pic: 'mobile_phone')
              : ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 120), children: [
                  if (missed.isNotEmpty) ...[
                    Row(children: [
                      const Expanded(child: Text('Missed calls', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.red))),
                      TextButton(
                          key: const Key('call-miss-clear'),
                          onPressed: () async {
                            await rr!.clearMissed();
                            if (mounted) setState(() => missed = []);
                          },
                          child: const Text('Clear')),
                    ]),
                    for (final m in missed.take(5))
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(16)),
                        child: Row(children: [
                          const Icon(Icons.phone_missed_rounded, color: C.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${m['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              Text(_when(m['at']), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                            ]),
                          ),
                          if (m['can'] == true)
                            FilledButton.tonal(
                              key: Key('call-back-${m['from']}'),
                              // (the app's buttons are as wide as the screen: this one only as wide as its words)
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              onPressed: () => setState(() => sel = '${m['from']}'),
                              child: const Text('Call back'),
                            ),
                        ]),
                      ),
                    const SizedBox(height: 10),
                  ],
                  const Text('Pick who to call – you can talk to each other. Nothing is recorded.', style: TextStyle(color: C.muted)),
                  const SizedBox(height: 8),
                  if ((rr?.users.length ?? 0) > 8)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        key: const Key('call-q'),
                        decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Search a name'), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                        onChanged: (v) => setState(() => q = v.trim()),
                      ),
                    ),
                  for (final u in list) _person(rr!, u),
                  const SizedBox(height: 14),
                  const Text('What to show', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _mode('voice', Icons.call_rounded, 'Voice call'),
                    _mode('video', Icons.videocam_rounded, 'Video call'),
                    if (rr?.kit.canScreen ?? false) _mode('screen', Icons.screen_share_rounded, 'My screen'),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      mode == 'screen'
                          ? 'The phone asks next – press "Start now". The others see your phone\'s screen; open any app, the call goes on.'
                          : mode == 'video'
                              ? 'Your front camera. In the call you can switch to the back camera (a machine, a meter, a paper) and show your screen too.'
                              : 'Voice only. In the call you can show your camera or your screen any time.',
                      style: const TextStyle(color: C.muted, fontSize: 13)),
                ]),
      bottomNavigationBar: loading || err.isNotEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: FilledButton.icon(
                  key: const Key('call-go'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: C.green),
                  onPressed: busy ? null : _call,
                  icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Icon(Icons.call_rounded),
                  label: Text(sel.isEmpty ? 'Call' : 'Call ${rr?.nameOf(sel) ?? ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
    );
  }

  String _when(dynamic at) {
    final ms = at is num ? at.toInt() : int.tryParse('$at') ?? 0;
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _person(Rtc rr, RtcUser u) {
    final st = rr.presence(u.uid), on = st == 'at the app now', bz = st == 'in another call', me = sel == u.uid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Press(
        key: Key('call-u-${u.uid}'),
        onTap: () => setState(() => sel = me ? '' : u.uid),
        border: me ? C.green : null,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(radius: 22, backgroundColor: C.greenSoft, child: Text(_initials(u.name), style: const TextStyle(color: C.greenDark, fontWeight: FontWeight.w800))),
            Positioned(right: 0, bottom: 0, child: Container(width: 13, height: 13, decoration: BoxDecoration(shape: BoxShape.circle, color: on ? const Color(0xFF22C55E) : bz ? C.amber : C.faint, border: Border.all(color: Colors.white, width: 2)))),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                if (u.admin) const Padding(padding: EdgeInsets.only(left: 6), child: Pill('Admin', color: C.blue, bg: C.blueSoft)),
              ]),
              Text(st, key: Key('call-st-${u.uid}'), style: TextStyle(fontSize: 12.5, color: on ? C.green : bz ? C.amber : C.muted)),
            ]),
          ),
          Icon(me ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: me ? C.green : C.faint),
        ]),
      ),
    );
  }

  Widget _mode(String k, IconData ic, String label) {
    final on = mode == k;
    return ChoiceChip(
      key: Key('call-mode-$k'),
      selected: on,
      showCheckmark: false,
      avatar: Icon(ic, size: 18, color: on ? Colors.white : C.ink),
      label: Text(label, style: TextStyle(color: on ? Colors.white : C.ink, fontWeight: FontWeight.w700)),
      selectedColor: C.green,
      backgroundColor: Colors.white,
      onSelected: (_) => setState(() => mode = k),
    );
  }
}

// ---------------------------------------------------------------- a call comes in ----------------------------------------------------------------
class RingScreen extends StatefulWidget {
  const RingScreen({super.key, required this.rtc});
  final Rtc rtc;
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  bool _replies = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rtc.ring;
    if (r == null) return const Scaffold(backgroundColor: _bg);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: _bg,
          body: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0E5A2A), _bg])),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                child: Column(children: [
                  const Text('Incoming call', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: .5)),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, child) => Stack(alignment: Alignment.center, children: [
                      for (final k in [0.0, .5])
                        Opacity(
                          opacity: (1 - (_pulse.value + k) % 1) * .45,
                          child: Container(width: 130 + 90 * ((_pulse.value + k) % 1), height: 130 + 90 * ((_pulse.value + k) % 1), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E))),
                        ),
                      child!,
                    ]),
                    child: CircleAvatar(radius: 64, backgroundColor: Colors.white, child: Text(_initials(r.name), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: C.greenDark))),
                  ),
                  const SizedBox(height: 28),
                  Text(r.name, key: const Key('ring-name'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(Rtc.ringWhat(r), key: const Key('ring-what'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 16)),
                  if (r.help.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(14)),
                      child: Text(r.help, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Text('Call with voice · nothing is recorded', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 13)),
                  const Spacer(),
                  if (_replies)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(children: [
                        for (final e in rtcReplies.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              key: Key('ring-reply-${e.key}'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x66FFFFFF)), minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              onPressed: () => widget.rtc.decline(e.key),
                              child: Text(e.value),
                            ),
                          ),
                      ]),
                    ),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _round(const Key('ring-decline'), _red, Icons.call_end_rounded, 'Decline', () => widget.rtc.decline()),
                    _round(const Key('ring-reply'), _btn, Icons.message_rounded, 'Reply', () => setState(() => _replies = !_replies)),
                    _round(const Key('ring-accept'), const Color(0xFF22C55E), Icons.call_rounded, 'Accept', () => widget.rtc.accept()),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _round(Key key, Color bg, IconData ic, String label, VoidCallback onTap) => Column(mainAxisSize: MainAxisSize.min, children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(key: key, customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 74, height: 74, child: Icon(ic, color: Colors.white, size: 34))),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ]);
}

// ---------------------------------------------------------------- the call ----------------------------------------------------------------
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.rtc});
  final Rtc rtc;
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    widget.rtc.addListener(_changed);
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _changed());
  }

  @override
  void dispose() {
    _t?.cancel();
    widget.rtc.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rtc, c = r.call;
    if (c == null) return const Scaffold(backgroundColor: _bg);
    final stage = r.stage, sh = r.stageShare, faces = r.faces, names = r.people.join(', '), page = r.pageOf();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(children: [
            // ---------- who, the time ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              child: Row(children: [
                IconButton(key: const Key('call-min'), tooltip: tr('Back to the app – the call goes on'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 32)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(names.isEmpty ? tr('Call') : names, key: const Key('call-names'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(r.status(), key: const Key('call-status'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
                  ]),
                ),
                if (c.screen != null) const _Tag(Icons.screen_share_rounded, 'Your screen is shown', _blue),
              ]),
            ),
            if (page.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(alignment: Alignment.centerLeft, child: Text('On the page: $page', style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12.5))),
              ),
            // ---------- the big picture ----------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    color: Colors.black,
                    child: stage == null
                        ? _alone(r, c)
                        : Stack(fit: StackFit.expand, children: [
                            KeyedSubtree(
                              key: const Key('call-stage'),
                              // pinch to zoom (another picture: not zoomed)
                              child: InteractiveViewer(key: ValueKey('z-${c.view}'), minScale: 1, maxScale: 5, child: SizedBox.expand(child: r.kit.view(stage, cover: c.faceStage))),
                            ),
                            Positioned(
                              left: 10,
                              bottom: 10,
                              child: _Label(sh == null ? '' : sh.kind == 'screen' ? 'Screen of ${sh.name}' : sh.face ? sh.name : 'Camera of ${sh.name}'),
                            ),
                            if (c.tabs.length > 1)
                              Positioned(
                                top: 8,
                                left: 8,
                                right: 8,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(children: [
                                    for (final sid in c.tabs)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: ChoiceChip(
                                          key: Key('call-tab-$sid'),
                                          selected: sid == c.view,
                                          showCheckmark: false,
                                          label: Text('${c.shares[sid]?.name ?? ''}${c.shares[sid]?.kind == 'cam' ? ' – camera' : ''}'),
                                          onSelected: (_) => r.show(sid),
                                        ),
                                      ),
                                  ]),
                                ),
                              ),
                          ]),
                  ),
                ),
              ),
            ),
            // ---------- the faces (mine: "You") ----------
            if (faces.isNotEmpty)
              SizedBox(
                height: 138,
                child: ListView(
                  key: const Key('call-faces'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                  children: [
                    for (final f in faces)
                      GestureDetector(
                        key: Key('call-face-${f.me ? 'me' : f.sid}'),
                        onTap: f.me ? null : () => r.show(f.sid),
                        child: Container(
                          width: 96,
                          margin: const EdgeInsets.only(right: 8),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: f.me ? const Color(0x55FFFFFF) : const Color(0x22FFFFFF))),
                          child: Stack(fit: StackFit.expand, children: [
                            r.kit.view(f.media, mirror: f.mirror, cover: true),
                            Positioned(left: 6, bottom: 6, right: 6, child: _Label(f.me ? tr('You') : f.name, small: true)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
            // ---------- the buttons ----------
            Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(26)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _CallBtn(key: const Key('call-mic'), icon: c.micOn ? Icons.mic_rounded : Icons.mic_off_rounded, label: c.micOn ? 'Mute' : 'Unmute', bg: c.micOn ? _btn : _red, onTap: r.toggleMic),
                _CallBtn(key: const Key('call-cam'), icon: c.cam != null ? Icons.videocam_rounded : Icons.videocam_off_rounded, label: 'Camera', bg: c.cam != null ? _blue : _btn, onTap: r.toggleCam),
                if (r.kit.canScreen) _CallBtn(key: const Key('call-screen'), icon: c.screen != null ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded, label: c.screen != null ? 'Stop' : 'Screen', bg: c.screen != null ? _blue : _btn, onTap: r.toggleScreen),
                _CallBtn(key: const Key('call-chat'), icon: Icons.chat_rounded, label: 'Chat', bg: _btn, badge: c.unread, onTap: () => _chat(r)),
                _CallBtn(key: const Key('call-more'), icon: Icons.more_horiz_rounded, label: 'More', bg: _btn, onTap: () => _more(r)),
                _CallBtn(key: const Key('call-end'), icon: Icons.call_end_rounded, label: c.role == 'host' ? 'End call' : 'Leave', bg: _red, wide: true, onTap: () => r.end()),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // nobody shows a picture: the other's letters, as a phone call
  Widget _alone(Rtc r, RtcCall c) {
    final n = r.people.isEmpty ? '' : r.people.first;
    return Container(
      decoration: const BoxDecoration(gradient: RadialGradient(colors: [Color(0xFF184A2C), Colors.black], radius: 1.1)),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 58, backgroundColor: C.green, child: Text(_initials(n), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white))),
        const SizedBox(height: 16),
        Text(c.t1 == 0 ? r.status() : (c.mode == 'video' || c.cam != null ? 'Video call' : 'Voice call'), style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 15)),
        if (c.t1 > 0 && c.cam == null && c.screen == null)
          const Padding(
            padding: EdgeInsets.fromLTRB(30, 10, 30, 0),
            child: Text('Press Camera or Screen to show something – the others\' pictures come here.', textAlign: TextAlign.center, style: TextStyle(color: Color(0x80FFFFFF), fontSize: 13)),
          ),
      ]),
    );
  }

  Future<void> _more(Rtc r) async {
    final c = r.call;
    if (c == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          if (c.cam != null)
            _sheetItem(ctx, const Key('call-flip'), Icons.cameraswitch_rounded, c.facing == 'user' ? 'Switch to the back camera' : 'Switch to the front camera', r.flip),
          if (c.cam != null && c.facing != 'user') _sheetItem(ctx, const Key('call-torch'), c.torch ? Icons.flashlight_off_rounded : Icons.flashlight_on_rounded, c.torch ? 'Light off' : 'Light on', r.torch),
          _sheetItem(ctx, const Key('call-speaker'), c.speaker ? Icons.volume_up_rounded : Icons.hearing_rounded, c.speaker ? 'Speaker on – press for the earpiece' : 'Earpiece – press for the speaker', r.toggleSpeaker),
          _sheetItem(ctx, const Key('call-low'), Icons.network_check_rounded, c.low ? 'Low data is on – press for the best picture' : 'Low data (a weak network)', () async {
            r.setLow(!c.low);
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _sheetItem(BuildContext ctx, Key key, IconData ic, String label, Future<void> Function() f) => ListTile(
        key: key,
        leading: Icon(ic, color: Colors.white),
        title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        onTap: () {
          Navigator.of(ctx).pop();
          f();
        },
      );

  Future<void> _chat(Rtc r) async {
    r.chatSeen(true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _ChatSheet(rtc: r),
    );
    r.chatSeen(false);
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.small = false});
  final String text;
  final bool small;
  @override
  Widget build(BuildContext context) => text.isEmpty
      ? const SizedBox.shrink()
      : Container(
          padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 3 : 5),
          decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(10)),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: small ? 11.5 : 13, fontWeight: FontWeight.w700)),
        );
}

class _CallBtn extends StatelessWidget {
  const _CallBtn({super.key, required this.icon, required this.label, required this.bg, required this.onTap, this.badge = 0, this.wide = false});
  final IconData icon;
  final String label;
  final Color bg;
  final int badge;
  final bool wide;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Flexible(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Material(
              color: bg,
              shape: wide ? const StadiumBorder() : const CircleBorder(),
              child: InkWell(
                customBorder: wide ? const StadiumBorder() : const CircleBorder(),
                onTap: onTap == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onTap!();
                      },
                child: SizedBox(width: wide ? 64 : 50, height: 50, child: Icon(icon, color: Colors.white, size: 25)),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

// ---------------------------------------------------------------- the chat ----------------------------------------------------------------
class _ChatSheet extends StatefulWidget {
  const _ChatSheet({required this.rtc});
  final Rtc rtc;
  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _txt = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.rtc.addListener(_changed);
  }

  @override
  void dispose() {
    widget.rtc.removeListener(_changed);
    _txt.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _send() {
    final v = _txt.text.trim();
    if (v.isEmpty) return;
    if (widget.rtc.chatSend(txt: v)) _txt.clear();
  }

  Future<void> _photo(bool camera) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final x = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 75);
      if (x == null) return;
      final s = await compute(chatJpg, await x.readAsBytes());
      if (s.isEmpty) {
        if (mounted) toast(context, 'The photo could not be made small enough to send.', bad: true);
        return;
      }
      widget.rtc.chatSend(img: s);
    } catch (e) {
      if (mounted) toast(context, 'That file could not be read as a photo.', bad: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.rtc.call, list = c?.chat ?? const <RtcMsg>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .62,
        child: Column(children: [
          const SizedBox(height: 14),
          const Text('Chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const Text('Only for this call – nothing is kept.', style: TextStyle(color: C.muted, fontSize: 12.5)),
          const Divider(),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No message yet.', style: TextStyle(color: C.muted)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      return Align(
                        alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          decoration: BoxDecoration(color: m.mine ? C.greenSoft : C.slateSoft, borderRadius: BorderRadius.circular(16)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.mine ? tr('You') : m.name, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            if (m.img != null) ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(m.img!, fit: BoxFit.contain)) else SelectableText(m.text, style: const TextStyle(fontSize: 15)),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(children: [
                IconButton(key: const Key('chat-cam'), tooltip: tr('Take a photo'), onPressed: () => _photo(true), icon: const Icon(Icons.photo_camera_rounded, color: C.green)),
                IconButton(key: const Key('chat-pic'), tooltip: tr('A photo from the gallery'), onPressed: () => _photo(false), icon: const Icon(Icons.image_rounded, color: C.green)),
                Expanded(
                  child: TextField(
                    key: const Key('chat-txt'),
                    controller: _txt,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(counterText: '', hintText: tr('Write a message'), filled: true, fillColor: C.bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  ),
                ),
                IconButton(key: const Key('chat-send'), onPressed: _send, icon: const Icon(Icons.send_rounded, color: C.green)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A photo for the chat: a jpeg as data:image/jpeg;base64,… of at most 200 000 letters (the web's limit), longest side ≤ 1280 px – '' if
/// it cannot be made so small.
String chatJpg(Uint8List raw) {
  final im = img.decodeImage(raw);
  if (im == null) return '';
  var scale = math.min(1.0, 1280 / math.max(im.width, im.height));
  for (var i = 0; i < 6; i++) {
    final out = scale < 1 ? img.copyResize(im, width: math.max(1, (im.width * scale).round()), height: math.max(1, (im.height * scale).round()), interpolation: img.Interpolation.average) : im;
    final s = 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(out, quality: 70))}';
    if (s.length <= 200000) return s;
    scale *= .75;
  }
  return '';
}
