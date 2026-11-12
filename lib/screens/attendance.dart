/* HR – MY ATTENDANCE, the app's own screen (3.103.0, rcl-hr; asked 12-11-2026: "PURN HR MODUAL … WEB AND APP"): Home → HR.
 * A person marks his own attendance, today only:
 *   1. the phone is asked where it is – a fresh reading; outside his work places nothing happens ("GEOFENCE BAHER KAHICH NHI HONAR");
 *   2. a selfie – proof only, nothing reads it;
 *   3. the punch is written on the phone, then sent. No network: it stays on the phone exactly as taken and is sent later –
 *      the same punch, never a new one.
 * One phone a person: another phone is refused by the server until the HR Admin releases the old one. Developer Options ON or a
 * made-up location: no punch (only here – the rest of the app works). Its own sign-in: a ticket of the Portal for 'hr' (the HR
 * office's people) or 'hrme' ("My HR", an employee for himself) – api.hrOpen. The rules are in core/attend.dart; the server
 * (rcl-hr) checks every one of them again. */
import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/api.dart' show ApiError;
import '../core/attend.dart';
import '../core/attend_remind.dart';
import '../core/session.dart';
import '../ui/attend_look.dart';
import '../ui/hr_look.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attend_reqs.dart';
import 'face_screens.dart';
import 'leave.dart';

Future<void> openAttendance(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AttendanceScreen()));

/// (a test) the selfie without a camera; null = the real camera screen.
Future<Uint8List?> Function(BuildContext context)? attendSelfieForTest;

/// HR's module of the site for this person: the HR office's ('hr') when he has it, else "My HR" ('hrme'); null = none.
Module? hrModule(Session s) => s.site?.module('hr') ?? s.site?.module('hrme');

String _or(Object? v) {
  final t = '${v ?? ''}';
  return t.isEmpty ? '–' : t;
}

/// (3.107.0, the clean screens he approved: "je required nahi te text kadhayche … app purn english") ONE language on these
/// screens: English while none is chosen, the app's own Marathi words when Marathi is (Me → Language).
String _t(String en, String mr) => Lang.i.pair(en, mr);

String _dmy(String ymd) => ymd.length >= 10 ? '${ymd.substring(8, 10)}-${ymd.substring(5, 7)}-${ymd.substring(0, 4)}' : ymd;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.quick = false});

  /// (3.105.0) opened by Home's strip: a punch the server took is said big, once – then back to Home by itself.
  final bool quick;
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? me; // the server's answer (myAttend) – or the one kept on the phone when there is no network
  List<KeptPunch> kept = [];
  PlaceHit? hit; // where he was at the last look
  AttendFix? fix;
  String err = '', done = '';
  List<String> refused = []; // what the server said to kept punches it did not take
  bool loading = true, started = false, busy = false, offline = false, dev = false, looking = false;
  int teamWait = 0; // the requests of the people who report to him that wait for him (rcl-hr step 5)
  double slide = 0; // how far the punch bar's sun is pulled
  AttendStore? store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // back in the app (he may have switched Developer Options off, or the network is back): read again
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !busy && !loading) _load(quiet: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<Map<String, dynamic>> _hr(Map<String, dynamic> body) {
    final s = SessionScope.read(context), m = hrModule(s);
    if (s.site == null || m == null) throw StateError('none');
    return s.api.hr(s.site!.code, m.url, m.key, body);
  }

  /// (3.111.0, rcl-hr step 9) the face for attendance – its own endpoint of the HR server, the same sign-in.
  Future<Map<String, dynamic>> _face(Map<String, dynamic> body) {
    final s = SessionScope.read(context), m = hrModule(s);
    if (s.site == null || m == null) throw StateError('none');
    return s.api.hr(s.site!.code, m.url, m.key, body, path: 'face');
  }

  /// the site's rule: no attendance without the registered face (as the server said last – also while a reading is going on)
  Map<String, dynamic>? _seen;
  bool _faceIn = false;
  bool get _faceOn => (_seen ?? me)?['face'] == true;

  /// His face is registered – now, when it is not yet (once: he agrees, five pictures, the server takes them when they are all
  /// of one person). false = he went back, or it was refused (said in [err]).
  Future<bool> _faceReady() async {
    if (_faceIn) return true; // (the server said so already, this time the page is open)
    final st = await _face({'action': 'faceState'});
    if (st['enrolled'] == true) {
      _faceIn = true;
      return true;
    }
    if (!mounted) return false;
    final shots = await FaceKit.kit.enrol(context);
    if (shots == null || !mounted) return false;
    final s = SessionScope.read(context), u = await _face({'action': 'faceEnrolUrls'});
    for (final p in (u['pictures'] as List? ?? const []).whereType<Map>()) {
      final jpg = shots['${p['pose']}'];
      if (jpg == null) throw ApiError('A picture of the registration is missing – register again.', code: 'picture');
      await s.api.hrPhoto('${p['url']}', jpg);
    }
    final info = await AttendKit.kit.info();
    await _face({'action': 'faceEnrol', 'token': u['token'], 'device': {'id': info['id'], 'model': info['model']}});
    _faceIn = true;
    if (mounted) toast(context, _t('Your face is registered.', 'तुमचा चेहरा नोंदवला.'));
    return true;
  }

  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context);
    store ??= AttendStore('${s.email}|${s.site?.code ?? ''}');
    if (!quiet) {
      setState(() {
        loading = true;
        err = '';
      });
    }
    final d = await AttendKit.kit.devOptions();
    var k = await store!.kept();
    try {
      final info = await AttendKit.kit.info();
      var j = await _hr({'action': 'myAttend', 'device_id': info['id']});
      _seen = j;
      unawaited(AttendRemind.set(j));
      await store!.keep(j, await AttendKit.kit.elapsed());
      if (k.isNotEmpty) {
        // the network is there: what was kept goes now, in the order it was taken
        await _sendKept(k);
        k = await store!.kept();
        j = await _hr({'action': 'myAttend', 'device_id': info['id']});
        _seen = j;
        unawaited(AttendRemind.set(j));
        await store!.keep(j, await AttendKit.kit.elapsed());
      }
      if (!mounted) return;
      setState(() {
        me = j;
        kept = k;
        dev = d;
        offline = false;
        loading = false;
        err = '';
      });
      _team();
    } catch (e) {
      final last = e is ApiError && e.code == 'net' ? await store!.last() : null;
      if (!mounted) return;
      setState(() {
        dev = d;
        kept = k;
        loading = false;
        if (last != null) {
          me = last;
          offline = true;
          err = '';
        } else {
          offline = e is ApiError && e.code == 'net';
          err = e is StateError ? 'You have no HR on this site – the Super Admin gives it in the Portal.' : errText(e);
        }
      });
    }
  }

  // the requests of his team that wait for him – asked quietly: a server without them (before its step 5) simply shows nothing
  Future<void> _team() async {
    try {
      final t = await _hr({'action': 'teamRegs'});
      if (!mounted) return;
      setState(() => teamWait = (t['rows'] as List? ?? const []).length);
    } catch (_) {/* nothing to show */}
  }

  /// One kept punch to the server: its photo first (unless it is there already), then the punch. [live] = just taken, the network
  /// was there. Throws ApiError – code 'net' = not sent (it stays kept), anything else = the server's answer.
  Future<Map<String, dynamic>> _send(KeptPunch p, {required bool live}) async {
    final s = SessionScope.read(context);
    final u = await _hr({'action': 'selfieUrl', 'client_id': p.cid});
    if (u['there'] != true) {
      final jpg = await store!.photo(p.cid);
      if (jpg == null) throw ApiError('The photo of this punch is not on the phone any more.', code: 'selfie');
      await s.api.hrPhoto('${u['url']}', jpg);
    }
    // (3.111.0) the site asks for the face: this punch's own photo is compared with his registered face – not his: refused
    // here, nothing of the punch is saved
    if (_faceOn) await _face({'action': 'faceCheck', 'client_id': p.cid});
    return _hr(p.body(live: live).cast<String, dynamic>());
  }

  Future<void> _sendKept(List<KeptPunch> list) async {
    for (final p in list) {
      try {
        await _send(p, live: false);
        await store!.remove(p.cid);
      } on ApiError catch (e) {
        if (e.code == 'net') return; // still no network: the rest waits too, in its order
        await store!.remove(p.cid);
        refused.add('${p.kind == 'in' ? 'IN' : 'OUT'} ${indiaTime(p.atDevice)} – ${e.message}');
      }
    }
  }

  List<WorkPlace> get _places => [for (final x in (me?['places'] as List? ?? const [])) WorkPlace.fromJson(x)].whereType<WorkPlace>().toList();
  double get _maxAcc => (me?['max_accuracy'] is num) ? (me!['max_accuracy'] as num).toDouble() : 100;
  String get _next => nextKind('${me?['next'] ?? 'in'}', kept);

  /// (3.110.0, rcl-hr step 8 – "user 1 day madhe fkt ekadach sign in and sign out") the site's rule "once a day": today has its
  /// IN (and its OUT, or it was closed by itself) – the server takes no punch any more today.
  bool get _dayDone => kept.isEmpty && '${me?['next'] ?? ''}' == 'done';

  /// the time today was closed by itself because OUT was not marked ('' = it was not)
  String get _closed => '${me?['closed'] ?? ''}';

  /// Where am I – a fresh reading against his places. Throws AttendProblem.
  Future<PlaceHit> _where() async {
    if (await AttendKit.kit.devOptions()) {
      if (mounted) setState(() => dev = true);
      throw AttendProblem('Developer Options are ON in this phone: switch them off (Settings › Developer options) to mark attendance.', 'या phone मध्ये Developer Options चालू आहेत: हजेरीसाठी ते बंद करा (Settings › Developer options).', 'devoptions');
    }
    final places = _places;
    if (places.isEmpty) throw AttendProblem('No work place is set for you yet – ask the HR office.', 'तुमच्यासाठी अजून work place ठरवलेले नाही – HR office ला सांगा.', 'noplace');
    final f = await AttendKit.kit.where();
    if (f.mocked) throw AttendProblem('This phone gives a made-up location: attendance cannot be marked.', 'हा phone खोटे location देत आहे: हजेरी लावता येणार नाही.', 'mock');
    if (!(f.acc >= 0) || f.acc > _maxAcc) {
      throw AttendProblem('Your location is not exact enough yet (${f.acc.round()} m): stand in the open for a moment and try again.', 'तुमचे location अजून नेमके नाही (${f.acc.round()} m): थोडा वेळ मोकळ्या जागेत उभे राहून पुन्हा करा.', 'accuracy');
    }
    final h = nearestPlace(places, f.lat, f.lng)!;
    fix = f;
    if (mounted) setState(() => hit = h);
    if (!h.inside) {
      throw AttendProblem('You are outside your work place (${h.place.name} – ${h.distance} m away). Attendance is marked only inside.', 'तुम्ही work place च्या बाहेर आहात (${h.place.name} – ${h.distance} m). हजेरी फक्त आत लागते.', 'outside');
    }
    return h;
  }

  Future<void> _look() async {
    if (busy || looking) return;
    setState(() {
      looking = true;
      err = '';
      done = '';
    });
    try {
      await _where();
    } on AttendProblem catch (e) {
      if (mounted) setState(() => err = _t(e.en, e.mr));
    } catch (_) {
      if (mounted) setState(() => err = 'Your location could not be read – try again.');
    }
    if (mounted) setState(() => looking = false);
  }

  Future<void> _punch() async {
    if (busy || me == null) return;
    final kind = _next;
    setState(() {
      busy = true;
      err = '';
      done = '';
    });
    try {
      final h = await _where(), f = fix!;
      if (!mounted) return;
      // (3.111.0) the face is needed: registered first (once); then the living face – straight, a blink – gives the proof photo
      final Uint8List? raw;
      if (_faceOn) {
        if (!await _faceReady() || !mounted) return;
        raw = await FaceKit.kit.check(context, stamp: '${_dmy('${me?['day'] ?? ''}')} · ${h.place.name}');
      } else {
        raw = attendSelfieForTest != null ? await attendSelfieForTest!(context) : await Navigator.of(context).push<Uint8List>(MaterialPageRoute(builder: (_) => SelfieScreen(stamp: '${_dmy('${me?['day'] ?? ''}')} · ${h.place.name}')));
      }
      if (raw == null) return; // he went back: nothing taken
      final jpg = smallJpg(raw);
      if (jpg == null) throw AttendProblem('The photo could not be read – take it again.', 'Photo वाचता आला नाही – पुन्हा काढा.', 'selfie');
      final info = await AttendKit.kit.info(), last = await store!.last();
      final p = KeptPunch(
        cid: newPunchId(),
        kind: kind,
        lat: f.lat,
        lng: f.lng,
        acc: f.acc,
        atDevice: DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now(), isUtc: true).toIso8601String(),
        place: h.place.name,
        elapsed: await AttendKit.kit.elapsed(),
        anchorServer: last?['now'] is num ? (last!['now'] as num).toInt() : null,
        anchorElapsed: last?['anchor_elapsed'] is num ? (last!['anchor_elapsed'] as num).toInt() : null,
        deviceId: info['id'] ?? '',
        model: info['model'] ?? '',
        os: info['os'] ?? '',
      );
      await store!.add(p, jpg); // on the phone first – whatever the network does
      var okTime = '';
      try {
        final r = await _send(p, live: true);
        await store!.remove(p.cid);
        await store!.patch({'punches': r['punches'], 'next': r['next'], 'phone': 'this'});
        unawaited(AttendRemind.set({...?me, 'punches': r['punches'], 'next': r['next']})); // (the reminder of what was just marked goes; OUT's is set after IN)
        if (!mounted) return;
        final t = '${(r['punch'] as Map?)?['time'] ?? ''}';
        okTime = t.isEmpty ? indiaTime(p.atDevice) : t;
        setState(() {
          me = {...?me, 'punches': r['punches'], 'next': r['next'], 'phone': 'this'};
          offline = false;
          done = kind == 'in' ? _t('IN marked at $t – ${h.place.name}', '$t ला IN लागले – ${h.place.name}') : _t('OUT marked at $t – ${h.place.name}', '$t ला OUT लागले – ${h.place.name}');
        });
      } on ApiError catch (e) {
        if (e.code != 'net') {
          await store!.remove(p.cid); // the server said no: nothing is kept of it
          rethrow;
        }
        final k = await store!.kept();
        if (!mounted) return;
        setState(() {
          kept = k;
          offline = true;
          done = _t('No network: your ${kind == 'in' ? 'IN' : 'OUT'} of ${indiaTime(p.atDevice)} is kept on the phone and is sent by itself when the network is back.',
              'Network नाही: ${indiaTime(p.atDevice)} चे ${kind == 'in' ? 'IN' : 'OUT'} phone मध्ये ठेवले आहे – network आल्यावर आपोआप जाईल.');
        });
      }
      // (3.105.0) from Home's strip: the punch the server took is said big, once – then Home again (its strip has turned)
      if (okTime.isNotEmpty && widget.quick && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttendDone(kind: kind, time: okTime, place: h.place.name)));
        if (mounted) Navigator.of(context).pop();
      }
    } on AttendProblem catch (e) {
      if (mounted) setState(() => err = _t(e.en, e.mr));
    } on ApiError catch (e) {
      if (mounted) setState(() => err = e.message);
    } catch (_) {
      if (mounted) setState(() => err = 'Something went wrong – please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), emp = (me?['employee'] as Map?) ?? const {};
    final punches = [for (final x in (me?['punches'] as List? ?? const []).whereType<Map>()) x];
    final next = _next, phone = '${me?['phone'] ?? ''}', may = me?['may'] != false;
    final blocked = me == null || !may || dev || phone == 'other' || _places.isEmpty;
    // (3.105.0) the sky says where his day stands: dawn – not marked; day – on duty; dusk – done; grey – it cannot be marked here / now
    final sky = skyOf(any: punches.isNotEmpty || kept.isNotEmpty, next: next, stopped: blocked || (hit != null && !hit!.inside));
    return Scaffold(
      appBar: _head(context, sky, me == null ? '' : '${emp['name'] ?? s.name} · ${emp['code'] ?? ''}', next, punches),
      bottomNavigationBar: me == null || loading ? null : _punchBar(next, blocked || _dayDone),
      body: loading
          ? const SkeletonList(tiles: 1, rows: 4)
          : RefreshIndicator(
              onRefresh: () => _load(quiet: true),
              child: ListView(key: const Key('att-page'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                if (me != null) ...[
                  if (offline) InfoLine(_t('No network – shown as read last. A punch taken now is kept on the phone and sent later.', 'Network नाही – शेवटचे वाचलेले दाखवले आहे. आता लावलेली हजेरी phone मध्ये राहील आणि नंतर जाईल.'), icon: Icons.cloud_off_rounded, bad: true, help: false, key: const Key('att-offline')),
                  // ---- what stops a punch on this phone
                  if (!may) InfoLine(_t('Your employee record is not complete (date of birth, e-mail, mobile) – ask the HR office.', 'तुमची employee माहिती अपूर्ण आहे (जन्मतारीख, e-mail, mobile) – HR office ला सांगा.'), bad: true, help: false, key: const Key('att-incomplete')),
                  if (dev) InfoLine(_t('Developer Options are ON in this phone. Switch them off (Settings › Developer options), then come back – attendance cannot be marked until then.', 'या phone मध्ये Developer Options चालू आहेत. ते बंद करा (Settings › Developer options) आणि परत या – तोपर्यंत हजेरी लावता येणार नाही.'), bad: true, help: false, key: const Key('att-dev')),
                  if (phone == 'other')
                    InfoLine(_t('Your attendance is tied to another phone (${me?['phone_model'] ?? ''}). Only the HR Admin can release it – then this phone will work.', 'तुमची हजेरी दुसऱ्या phone ला बांधलेली आहे (${me?['phone_model'] ?? ''}). फक्त HR Admin तो सोडू शकतो – मग हा phone चालेल.'), bad: true, help: false, key: const Key('att-other')),
                  if (_places.isEmpty) InfoLine(_t('No work place is set for you yet – ask the HR office.', 'तुमच्यासाठी अजून work place ठरवलेले नाही – HR office ला सांगा.'), bad: true, help: false, key: const Key('att-noplace')),
                  // (3.110.0) once a day / closed by itself – said plainly, with what he can do
                  if (_closed.isNotEmpty)
                    InfoLine(_t('OUT was not marked: today was closed by itself at $_closed and counts as absent. Ask to set the day right (Requests).', 'OUT लावले नाही: आजचा दिवस $_closed ला आपोआप बंद झाला आणि गैरहजर धरला आहे. दुरुस्तीसाठी विनंती करा (Requests).'), bad: true, help: false, key: const Key('att-closed'))
                  else if (_dayDone)
                    InfoLine(_t('Today\'s attendance is done – one IN and one OUT a day. A mistake: ask to set the day right (Requests).', 'आजची हजेरी पूर्ण – दिवसात एकदाच IN आणि एकदाच OUT. चूक झाली असेल तर दुरुस्तीसाठी विनंती करा (Requests).'), icon: Icons.check_circle_rounded, help: false, key: const Key('att-once')),
                  const SizedBox(height: 4),
                  // ---- where I am and whose phone this is (3.107.0): two small chips. The place's chip is the "check" too – a tap
                  // looks where he stands; outside his place the drawing shows how far he is.
                  if (hit != null && !hit!.inside) ...[PlaceRadar(inside: false, distance: hit!.distance, name: hit!.place.name), const SizedBox(height: 10)],
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip(
                      key: const Key('att-where'),
                      tapKey: const Key('att-look'),
                      dot: hit == null ? C.slate : hit!.inside ? C.green : C.red,
                      text: looking
                          ? '…'
                          : hit == null
                              ? _places.map((p) => p.name).join(', ')
                              : hit!.inside
                                  ? '${hit!.place.name} · ${_t('inside', 'आत')}'
                                  : _t('Outside – ${hit!.distance} m from ${hit!.place.name}', 'बाहेर – ${hit!.place.name} पासून ${hit!.distance} m'),
                      onTap: blocked || busy || looking ? null : _look,
                    ),
                    if (phone == 'this') _chip(key: const Key('att-phone'), dot: C.green, text: _t('This phone', 'हा phone')),
                  ]),
                ],
                if (done.isNotEmpty) InfoLine(done, icon: Icons.check_circle_rounded, key: const Key('att-done')),
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('att-err')),
                for (final r in refused) InfoLine(_t('A punch kept on the phone was not taken: $r', 'Phone मध्ये ठेवलेली हजेरी घेतली गेली नाही: $r'), bad: true, help: false),
                if (me != null) ...[
                  // ---- kept on the phone
                  if (kept.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _card([
                      Text(_t('Waiting for the network (${kept.length})', 'Network ची वाट पाहत आहे (${kept.length})'), style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w700)),
                      for (final k in kept) _row(k.kind, indiaTime(k.atDevice), k.place, _t('Kept', 'ठेवले'), C.amber, C.amberSoft, Key('att-kept-${k.kind}')),
                      Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('att-send'), onPressed: busy ? null : () => _load(), icon: const Icon(Icons.cloud_upload_rounded), label: Text(_t('Send now', 'आता पाठवा')))),
                    ]),
                  ],
                  // ---- today's punches, in one card
                  const SizedBox(height: 14),
                  _card([
                    const Text('Today', mr: 'आज', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800)),
                    if (punches.isEmpty) Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Text(_t('No punch yet.', 'अजून नोंद नाही.'), style: const TextStyle(fontSize: 14, color: C.faint))),
                    for (final p in punches)
                      _row('${p['kind']}', '${p['time'] ?? ''}', _placeName('${p['place_id'] ?? ''}'), p['status'] == 'review' ? _t('To be checked', 'तपासणी') : p['offline'] == true ? _t('Sent later', 'नंतर पाठवले') : '',
                          p['status'] == 'review' ? C.amber : C.slate, p['status'] == 'review' ? C.amberSoft : C.slateSoft, Key('att-p-${p['id']}')),
                  ]),
                  // ---- his month, his leave, his requests (3.108.0: what waits for him of his team is inside "Requests")
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _tile(const Key('att-month'), '${_monthDays('${me?['day'] ?? ''}')}', C.blue, C.blueSoft, 'This month', 'हा महिना', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttendMonthScreen(ask: _hr, who: '${emp['name'] ?? s.name} · ${emp['code'] ?? ''}'))))),
                    const SizedBox(width: 10),
                    Expanded(child: _tile(const Key('att-leave'), 'L', kPurple, const Color(0xFFF1E8F6), 'Leave', 'रजा', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LeaveScreen(ask: _hr))))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _tile(const Key('att-reqs'), 'R', const Color(0xFF8A5A00), const Color(0xFFFFF3D1), 'Requests', 'विनंत्या', () async {
                      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttendRegsScreen(ask: _hr)));
                      _team();
                    }, badge: teamWait)),
                  ]),
                ],
              ]),
            ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: kSoftShadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _chip({required Key key, Key? tapKey, required Color dot, required String text, VoidCallback? onTap}) => GestureDetector(
        key: tapKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: key,
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: kSoftShadow),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(child: m.Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.ink, height: 1.25))),
          ]),
        ),
      );

  // the days of the month of [ymd] – the sign of "This month" (30)
  int _monthDays(String ymd) {
    final d = DateTime.tryParse('${ymd}T00:00:00Z') ?? DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now(), isUtc: true);
    return DateTime.utc(d.year, d.month + 1, 0).day;
  }

  Widget _tile(Key key, String sign, Color c, Color soft, String en, String mr, VoidCallback onTap, {int badge = 0}) => Press(
        key: key,
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)), child: m.Text(sign, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: c))),
            if (badge > 0) Positioned(right: -10, top: -6, child: Pill('$badge', color: Colors.white, bg: C.red)),
          ]),
          const SizedBox(height: 7),
          Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      );

  /// (3.105.0) The page's head: the sky of his day, his name and code, where today stands – and the sun (IN / OUT), the moon
  /// when today is done. Taller than the letters it holds; with very big letters the lowest line is cut, nothing overflows.
  PreferredSizeWidget _head(BuildContext context, Sky sky, String who, String next, List<Map> punches) {
    final lastP = punches.isEmpty ? null : punches.last;
    var tin = '';
    for (final p in punches.reversed) {
      if (p['kind'] == 'in') {
        tin = '${p['time'] ?? ''}';
        break;
      }
    }
    final since = sky == Sky.day && kept.isEmpty ? sinceText(tin, DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now())) : '';
    return PreferredSize(
      preferredSize: const Size.fromHeight(176),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(gradient: skyDown(sky), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
        child: SafeArea(
          bottom: false,
          child: Stack(children: [
            Positioned(right: 20, bottom: 18, child: SunDisc(size: 88, label: next == 'in' ? 'IN' : 'OUT', moon: sky == Sky.dusk, dim: sky == Sky.grey)),
            Positioned.fill(
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 52, 0),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                        const Expanded(child: Text('My attendance', mr: 'माझी हजेरी', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white))),
                      ]),
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 76, top: 2),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (who.isNotEmpty) Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: .9))),
                          const SizedBox(height: 8),
                          if (lastP == null && kept.isEmpty)
                            const Text('Not marked yet', mr: 'अजून लावलेली नाही', key: Key('att-state'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Colors.white))
                          else
                            Text(
                                kept.isNotEmpty
                                    ? '${kept.last.kind == 'in' ? 'IN' : 'OUT'} ${indiaTime(kept.last.atDevice)}'
                                    : '${lastP!['kind'] == 'in' ? 'IN' : 'OUT'} ${lastP['time'] ?? ''}',
                                key: const Key('att-state'),
                                maxLines: 1,
                                style: const TextStyle(fontFamily: 'Montserrat', fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white)),
                          if (since.isNotEmpty) Text('On duty · $since', mr: 'कामावर · $since', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .95))),
                          if (sky == Sky.dusk) Text('Today\'s attendance is done', mr: 'आजची हजेरी पूर्ण', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: .95))),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            Positioned(top: 2, right: 4, child: IconButton(tooltip: tr('Refresh'), onPressed: busy ? null : () => _load(), icon: const Icon(Icons.refresh_rounded, color: Colors.white))),
          ]),
        ),
      ),
    );
  }

  /// (3.105.0) The one button, always at the thumb: the selfie and the punch. Off (pale) when attendance cannot be marked.
  /// (3.108.0, his screens) a dark bar with the sun on its left – "Slide to mark IN / OUT": the sun is pulled to the right (past
  /// the middle), or the bar is touched; both do the same – his place is read, the selfie, the punch.
  Widget _punchBar(String next, bool blocked) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: LayoutBuilder(builder: (context, box) {
            final room = (box.maxWidth - 58).clamp(0.0, 2000.0), off = blocked || busy;
            return GestureDetector(
              onHorizontalDragUpdate: off ? null : (d) => setState(() => slide = (slide + d.delta.dx).clamp(0.0, room)),
              onHorizontalDragEnd: off
                  ? null
                  : (_) {
                      final go = slide > room * .5;
                      setState(() => slide = 0);
                      if (go) _punch();
                    },
              onHorizontalDragCancel: () {
                if (slide != 0) setState(() => slide = 0);
              },
              child: SizedBox(
                height: 58,
                child: FilledButton(
                  key: const Key('att-punch'),
                  style: FilledButton.styleFrom(shape: const StadiumBorder(), backgroundColor: kNavy, disabledBackgroundColor: C.slateSoft, padding: const EdgeInsets.all(6)),
                  onPressed: off ? null : _punch,
                  child: busy
                      ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Stack(alignment: Alignment.centerLeft, children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 62, right: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(_dayDone ? _t('Today\'s attendance is done', 'आजची हजेरी पूर्ण') : next == 'in' ? _t('Slide to mark IN', 'IN लावण्यासाठी सरकवा') : _t('Slide to mark OUT', 'OUT लावण्यासाठी सरकवा'), maxLines: 1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: blocked ? C.faint : Colors.white)),
                              ),
                            ),
                          ),
                          Transform.translate(offset: Offset(slide, 0), child: SunDisc(size: 46, label: next == 'in' ? 'IN' : 'OUT', dim: blocked)),
                        ]),
                ),
              ),
            );
          }),
        ),
      );

  String _placeName(String id) {
    for (final p in _places) {
      if (p.id == id) return p.name;
    }
    return '';
  }

  Widget _row(String kind, String time, String place, String note, Color c, Color soft, Key key) => Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Pill(kind == 'in' ? 'IN' : 'OUT', color: kind == 'in' ? C.greenDark : C.orange, bg: kind == 'in' ? C.greenSoft : C.orangeSoft),
          const SizedBox(width: 12),
          Text(time, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: C.muted))),
          // (a short note – at most 130 wide; the place's name takes the rest and is cut first)
          if (note.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxWidth: 130),
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(30)),
              child: Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c)),
            ),
        ]),
      );
}

/// The selfie of a punch: the front camera, one button. Proof only – nothing reads the face. Gives the camera's picture, or
/// nothing when he goes back.
class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key, this.stamp = ''});

  /// (3.105.0) shown under the picture: the day and the work place of this punch (on the screen only – the punch itself carries
  /// its time and place; nothing is written into the photo).
  final String stamp;
  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen> {
  CameraController? cam;
  String err = '';
  bool taking = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final all = await availableCameras();
      if (all.isEmpty) throw StateError('none');
      final lens = all.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => all.first);
      final c = CameraController(lens, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => cam = c);
    } catch (_) {
      if (mounted) setState(() => err = bi('The camera could not be opened – allow the camera for the app (Settings › Apps › RCL ERP › Permissions).', 'Camera उघडला नाही – app ला camera ची परवानगी द्या (Settings › Apps › RCL ERP › Permissions).', '\n'));
    }
  }

  @override
  void dispose() {
    cam?.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    final c = cam;
    if (c == null || taking) return;
    setState(() => taking = true);
    try {
      final f = await c.takePicture();
      final b = await f.readAsBytes();
      if (mounted) Navigator.of(context).pop(b);
    } catch (_) {
      if (mounted) {
        setState(() {
          taking = false;
          err = bi('The photo could not be taken – try again.', 'Photo काढता आला नाही – पुन्हा करा.', '\n');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(bi('Selfie – proof of the punch', 'Selfie – हजेरीचा पुरावा'), style: const TextStyle(color: Colors.white, fontSize: 17))),
        body: Column(children: [
          Expanded(
              child: Center(
                  child: cam == null
                      ? (err.isEmpty ? const CircularProgressIndicator(color: Colors.white) : Padding(padding: const EdgeInsets.all(24), child: Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4))))
                      : Stack(alignment: Alignment.center, children: [
                          ClipRRect(borderRadius: BorderRadius.circular(24), child: CameraPreview(cam!)),
                          // (3.105.0) where the face goes
                          IgnorePointer(child: Container(width: 220, height: 290, decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 3), borderRadius: const BorderRadius.all(Radius.elliptical(110, 145))))),
                        ]))),
          if (cam != null && widget.stamp.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(24, 10, 24, 0), child: Text(widget.stamp, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
          if (cam != null && err.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: SizedBox(
              width: 84,
              height: 84,
              child: FilledButton(
                key: const Key('selfie-take'),
                style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: const Color(0xFFFFC93C), padding: EdgeInsets.zero),
                onPressed: cam == null || taking ? null : _take,
                child: taking ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 34),
              ),
            ),
          ),
        ]),
      );
}

/// His month: each day with what it counts as, its first IN and last OUT, as the server has them.
class AttendMonthScreen extends StatefulWidget {
  const AttendMonthScreen({super.key, required this.ask, this.who = ''});
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body) ask;

  /// his name and code, said in the head
  final String who;
  @override
  State<AttendMonthScreen> createState() => _AttendMonthScreenState();
}

class _AttendMonthScreenState extends State<AttendMonthScreen> {
  String month = '', err = '', today = '', sel = ''; // sel: the day opened under the calendar
  List<Map> days = [];
  Map total = const {};
  int regDays = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    month = indiaDay(AttendKit.kit.now()).substring(0, 7);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final j = await widget.ask({'action': 'myMonth', 'month': month});
      if (!mounted) return;
      setState(() {
        // (rcl-hr step 5) every day of the month with what it counts as; before it: only the days with a punch
        final all = [for (final x in (j['all'] as List? ?? const []).whereType<Map>()) x];
        today = '${j['today'] ?? indiaDay(AttendKit.kit.now())}';
        days = all.isNotEmpty ? [for (final d in all) if ('${d['code'] ?? ''}'.isNotEmpty || (d['punches'] is num && (d['punches'] as num) > 0)) d] : [for (final x in (j['days'] as List? ?? const []).whereType<Map>()) x];
        total = (j['total'] as Map?) ?? const {};
        regDays = j['reg_days'] is num ? (j['reg_days'] as num).toInt() : 0;
        loading = false;
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

  void _move(int by) {
    if (loading) return;
    final y = int.parse(month.substring(0, 4)), m = int.parse(month.substring(5, 7)), d = DateTime.utc(y, m + by, 1);
    if (by > 0 && '${d.year}-${d.month.toString().padLeft(2, '0')}'.compareTo(indiaDay(AttendKit.kit.now()).substring(0, 7)) > 0) return; // not a month to come
    month = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    sel = '';
    _load();
  }

  // a day gone that can still be asked for (the server's days back)
  bool _canAsk(String day) {
    if (regDays <= 0 || today.isEmpty || day.compareTo(today) >= 0) return false;
    final t = DateTime.tryParse('${today}T00:00:00Z'), d = DateTime.tryParse('${day}T00:00:00Z');
    return t != null && d != null && t.difference(d).inDays <= regDays;
  }

  Future<void> _ask(Map d) async {
    final ok = await askRegularize(context, widget.ask, '${d['day']}', inNow: '${d['in'] ?? ''}', outNow: '${d['out'] ?? ''}', code: '${d['code'] ?? ''}');
    if (!ok || !mounted) return;
    toast(context, _t('Sent – it counts when it is approved.', 'पाठवले – मंजूर झाल्यावर धरले जाईल.'));
  }

  static const _names = {'P': 'Present', 'HD': 'Half day', 'A': 'Absent', 'L': 'Leave', 'WO': 'Weekly off', 'H': 'Holiday', 'WOP': 'Worked on off', 'HP': 'Worked on holiday', 'IN': 'At work', 'MIS': 'No OUT'};
  static const _green = (Color(0xFF146C2E), Color(0xFFDDF3E4)), _yellow = (Color(0xFF8A5A00), Color(0xFFFFF3D1)), _red = (Color(0xFFC22A1B), Color(0xFFFFE6E3)), _leave = (kPurple, Color(0xFFF1E8F6)), _off = (Color(0xFF7B839C), Color(0xFFE4E7F0));
  (Color, Color) _look(String c) => switch (c) {
        'P' || 'WOP' || 'HP' || 'IN' => _green,
        'HD' => _yellow,
        'A' || 'MIS' => _red,
        'L' => _leave,
        _ => _off,
      };

  /// (3.107.0, asked 12-11-2026: "employee monthly bghu shakel day wise nahi month wise") THE MONTH AS A CALENDAR: a box a day in
  /// the colour of what it counts as; the counts above; a day is opened below by a touch – with "Ask to set right" for a day
  /// gone. A day to come (and a day with nothing) is an empty box that cannot be touched.
  /// (3.108.0, his screens) the head is the sky with his days for pay "9.5 days · of 11 working days so far" and the month in
  /// its pill (‹ ›); Present · Half day · Absent · Leave; the colours' names under the calendar.
  @override
  Widget build(BuildContext context) {
    final y = int.parse(month.substring(0, 4)), mo = int.parse(month.substring(5, 7));
    final first = DateTime.utc(y, mo, 1).weekday - 1, count = DateTime.utc(y, mo + 1, 0).day; // Monday first
    final byDay = <String, Map>{for (final d in days) '${d['day']}': d};
    final now = today.isEmpty ? indiaDay(AttendKit.kit.now()) : today;
    // the days that were to be worked, up to today: not a weekly off, not a holiday, not a day to come
    final work = [for (final d in days) if ('${d['code'] ?? ''}'.isNotEmpty && d['code'] != 'WO' && d['code'] != 'H' && '${d['day']}'.compareTo(now) <= 0) d].length;
    final paid = total['paid'] is num ? total['paid'] as num : null;
    Widget stat(String key, String en, String mr, Object? v, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: kSoftShadow),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${v ?? 0}', key: Key('att-t-$key'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 21, fontWeight: FontWeight.w800, color: c)),
              Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted)),
            ]),
          ),
        );
    Widget blank([String n = '']) => Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFF3F5FA), borderRadius: BorderRadius.circular(10)),
          child: n.isEmpty ? null : m.Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB3B9C9))),
        );
    Widget cell(int n) {
      final day = '$month-${n.toString().padLeft(2, '0')}', d = byDay[day];
      if (d == null) return blank('$n');
      final code = '${d['code'] ?? ''}', lk = _look(code);
      return GestureDetector(
        key: Key('att-d-$day'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => sel = day),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: lk.$2, borderRadius: BorderRadius.circular(10), border: sel == day ? Border.all(color: kNavy, width: 2) : null),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            m.Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1, color: lk.$1)),
            if (code.isNotEmpty) m.Text(code == 'MIS' ? '!' : code, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, height: 1.1, color: lk.$1)),
          ]),
        ),
      );
    }

    final cells = <Widget>[for (var i = 0; i < first; i++) blank(), for (var n = 1; n <= count; n++) cell(n)];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox(height: 38));
    }
    Widget leg(Color c, String en, String mr) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 9, height: 9, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          Text(en, mr: mr, style: const TextStyle(fontSize: 11.5, color: C.muted)),
        ]);
    Widget arrow(String key, IconData icon, int by) => GestureDetector(
          key: Key(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => _move(by),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5), child: Icon(icon, size: 18, color: Colors.white)),
        );
    final open = sel.isEmpty ? null : byDay[sel];
    final oc = open == null ? '' : '${open['code'] ?? ''}', oin = open == null ? '' : '${open['in'] ?? ''}', oout = open == null ? '' : '${open['out'] ?? ''}';
    return Scaffold(
      appBar: hrHead(context,
          sky: kDaySky,
          title: 'This month',
          mr: 'हा महिना',
          height: 158,
          pill: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              arrow('att-m-prev', Icons.chevron_left_rounded, -1),
              m.Text(monthName(month), key: const Key('att-m-name'), maxLines: 1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
              arrow('att-m-next', Icons.chevron_right_rounded, 1),
            ]),
          ),
          below: [
            if (widget.who.isNotEmpty) m.Text(widget.who, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .92))),
            if (!loading && err.isEmpty) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                m.Text(paid == null ? '${days.length}' : (paid == paid.roundToDouble() ? '${paid.round()}' : '$paid'), key: const Key('att-m-paid'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
                const SizedBox(width: 8),
                const Text('days', mr: 'दिवस', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
              if (total.isNotEmpty)
                Text(month == now.substring(0, 7) ? _t('of $work working days so far', 'आतापर्यंतच्या $work कामाच्या दिवसांपैकी') : _t('of $work working days', '$work कामाच्या दिवसांपैकी'),
                    key: const Key('att-m-work'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .95))),
            ],
          ]),
      body: ListView(key: const Key('att-month-page'), padding: const EdgeInsets.fromLTRB(12, 14, 12, 40), children: [
        if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (err.isNotEmpty) InfoLine(err, bad: true, help: false),
        if (!loading && err.isEmpty) ...[
          if (total.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(_t('Days with a punch: ${days.length}', 'हजेरीचे दिवस: ${days.length}'), key: const Key('att-m-count'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.blue)))
          else
            Row(key: const Key('att-m-total'), children: [stat('P', 'Present', 'हजर', total['P'], _green.$1), stat('HD', 'Half day', 'अर्धा दिवस', total['HD'], _yellow.$1), stat('A', 'Absent', 'गैरहजर', total['A'], _red.$1), stat('L', 'Leave', 'रजा', total['L'], kPurple)]),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: hrCard(padding: const EdgeInsets.fromLTRB(10, 12, 10, 12), [
              Row(children: [for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: m.Text(w, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: C.muted))))]),
              const SizedBox(height: 6),
              for (var r = 0; r < cells.length; r += 7)
                Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(children: [for (var c = r; c < r + 7; c++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2.5), child: cells[c]))])),
              const SizedBox(height: 4),
              Wrap(spacing: 10, runSpacing: 4, children: [leg(_green.$2, 'Present', 'हजर'), leg(_yellow.$2, 'Half day', 'अर्धा दिवस'), leg(_red.$2, 'Absent', 'गैरहजर'), leg(_leave.$2, 'Leave', 'रजा')]),
            ]),
          ),
          if (days.isEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Center(child: Text(_t('No punch in this month.', 'या महिन्यात हजेरी नाही.'), style: const TextStyle(color: C.faint)))),
          if (open != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: hrCard(key: const Key('att-day'), padding: const EdgeInsets.fromLTRB(16, 8, 8, 14), [
                Row(children: [
                  Expanded(child: m.Text(dayName(sel, week: true), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: C.ink))),
                  if (_canAsk(sel)) TextButton(key: const Key('att-ask'), onPressed: () => _ask(open), child: const Text('Ask to set right', mr: 'दुरुस्ती मागा', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.blue))) else const SizedBox(height: 44),
                ]),
                Row(children: [
                  if (oc.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _look(oc).$2, borderRadius: BorderRadius.circular(9)),
                      child: m.Text(oc == 'MIS' ? '!' : oc, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _look(oc).$1)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                      child: oin.isEmpty && oout.isEmpty
                          ? Text(oc == 'A' || oc.isEmpty ? _t('No punch on this day', 'या दिवशी हजेरी नाही') : tr(_names[oc] ?? oc), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: C.ink))
                          : m.Text('${tr(_names[oc] ?? oc)} · IN ${_or(open['in'])} · OUT ${_or(open['out'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: C.ink))),
                  if (open['late_min'] is num && (open['late_min'] as num) > 0) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.schedule_rounded, size: 17, color: C.amber)),
                  if ((open['review'] is num) && (open['review'] as num) > 0) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.hourglass_top_rounded, size: 17, color: C.amber)),
                ]),
                // (3.110.0) why the day counts so: closed by itself (OUT forgotten), or a half day by the late rule
                if (open['auto'] == true) Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Text(_t('OUT was not marked – the day was closed by itself: absent.', 'OUT लावले नाही – दिवस आपोआप बंद झाला: गैरहजर.'), key: const Key('att-day-auto'), style: const TextStyle(fontSize: 12.5, color: C.red, height: 1.3))),
                if (open['late_half'] == true) Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Text(_t('Late – counted as a half day (the late rule of your site).', 'उशीर – अर्धा दिवस धरला (तुमच्या site चा late नियम).'), key: const Key('att-day-late'), style: const TextStyle(fontSize: 12.5, color: C.amber, height: 1.3))),
              ]),
            ),
          ] else if (days.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(8, 10, 8, 0), child: Text(_t('Touch a day to open it.', 'दिवसावर touch करा.'), style: const TextStyle(fontSize: 12.5, color: C.muted))),
        ],
      ]),
    );
  }
}

/// (3.105.0) MARKED JUST NOW – said big, once (after a punch from Home's strip): the sun with a tick and the time for IN, the
/// moon for OUT. It closes by itself after a moment, or with OK.
class AttendDone extends StatefulWidget {
  const AttendDone({super.key, required this.kind, required this.time, required this.place});
  final String kind, time, place;
  @override
  State<AttendDone> createState() => _AttendDoneState();
}

class _AttendDoneState extends State<AttendDone> {
  Timer? _back;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _back = Timer(const Duration(milliseconds: 2600), _close);
  }

  void _close() {
    if (_gone || !mounted) return;
    _gone = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _back?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inn = widget.kind == 'in', sky = inn ? Sky.day : Sky.dusk;
    return Scaffold(
      body: Container(
        key: const Key('att-ok-page'),
        width: double.infinity,
        decoration: BoxDecoration(gradient: skyDown(sky)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SunDisc(size: 168, tick: true, moon: !inn),
              const SizedBox(height: 30),
              Text(inn ? bi('IN marked', 'हजेरी लागली') : bi('OUT marked', 'OUT लागले'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 4),
              Text(widget.time, key: const Key('att-ok-time'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 54, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
              if (widget.place.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(widget.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, color: Colors.white.withValues(alpha: .92)))),
              const SizedBox(height: 34),
              FilledButton(
                key: const Key('att-ok'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: skyInk(sky), minimumSize: const Size(160, 52), shape: const StadiumBorder()),
                onPressed: _close,
                child: Text('OK', mr: 'ठीक आहे', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: skyInk(sky))),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
