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
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart' hide Text;

import '../core/api.dart' show ApiError;
import '../core/attend.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attend_reqs.dart';

Future<void> openAttendance(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AttendanceScreen()));

/// (a test) the selfie without a camera; null = the real camera screen.
Future<Uint8List?> Function(BuildContext context)? attendSelfieForTest;

/// HR's module of the site for this person: the HR office's ('hr') when he has it, else "My HR" ('hrme'); null = none.
Module? hrModule(Session s) => s.site?.module('hr') ?? s.site?.module('hrme');

String _or(Object? v) {
  final t = '${v ?? ''}';
  return t.isEmpty ? '–' : t;
}

String _dmy(String ymd) => ymd.length >= 10 ? '${ymd.substring(8, 10)}-${ymd.substring(5, 7)}-${ymd.substring(0, 4)}' : ymd;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
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
  int team = 0, teamWait = 0; // the people who report to him, and their requests that wait for him (rcl-hr step 5)
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
      await store!.keep(j, await AttendKit.kit.elapsed());
      if (k.isNotEmpty) {
        // the network is there: what was kept goes now, in the order it was taken
        await _sendKept(k);
        k = await store!.kept();
        j = await _hr({'action': 'myAttend', 'device_id': info['id']});
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
      setState(() {
        team = t['team'] is num ? (t['team'] as num).toInt() : 0;
        teamWait = (t['rows'] as List? ?? const []).length;
      });
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
      if (mounted) setState(() => err = bi(e.en, e.mr, '\n'));
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
      final raw = attendSelfieForTest != null ? await attendSelfieForTest!(context) : await Navigator.of(context).push<Uint8List>(MaterialPageRoute(builder: (_) => const SelfieScreen()));
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
      try {
        final r = await _send(p, live: true);
        await store!.remove(p.cid);
        await store!.patch({'punches': r['punches'], 'next': r['next'], 'phone': 'this'});
        if (!mounted) return;
        final t = '${(r['punch'] as Map?)?['time'] ?? ''}';
        setState(() {
          me = {...?me, 'punches': r['punches'], 'next': r['next'], 'phone': 'this'};
          offline = false;
          done = kind == 'in' ? bi('IN marked at $t – ${h.place.name}', '$t ला IN लागले – ${h.place.name}', '\n') : bi('OUT marked at $t – ${h.place.name}', '$t ला OUT लागले – ${h.place.name}', '\n');
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
          done = bi('No network: your ${kind == 'in' ? 'IN' : 'OUT'} of ${indiaTime(p.atDevice)} is kept on the phone and is sent by itself when the network is back.',
              'Network नाही: ${indiaTime(p.atDevice)} चे ${kind == 'in' ? 'IN' : 'OUT'} phone मध्ये ठेवले आहे – network आल्यावर आपोआप जाईल.', '\n');
        });
      }
    } on AttendProblem catch (e) {
      if (mounted) setState(() => err = bi(e.en, e.mr, '\n'));
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
    final lastP = punches.isEmpty ? null : punches.last;
    final blocked = me == null || !may || dev || phone == 'other' || _places.isEmpty;
    return Scaffold(
      appBar: moduleBar(context, Tone.hr, en: 'My attendance', mr: 'माझी हजेरी', pic: 'calendar', line: me == null ? '' : '${emp['name'] ?? s.name} · ${emp['code'] ?? ''}',
          actions: [IconButton(tooltip: tr('Refresh'), onPressed: busy ? null : () => _load(), icon: const Icon(Icons.refresh_rounded))]),
      body: loading
          ? const SkeletonList(tiles: 1, rows: 4)
          : RefreshIndicator(
              onRefresh: () => _load(quiet: true),
              child: ListView(key: const Key('att-page'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
                if (me != null) ...[
                  // ---- today
                  Container(
                    key: const Key('att-today'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.line)),
                    child: Row(children: [
                      Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(bi('Today', 'आज') + ' · ${_dmy('${me?['day'] ?? ''}')}', style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        if (lastP == null && kept.isEmpty)
                          const TwoLang('Not marked yet', 'अजून लावलेली नाही', key: Key('att-state'), size: 22, weight: FontWeight.w800)
                        else
                          Text(
                            kept.isNotEmpty
                                ? '${kept.last.kind == 'in' ? 'IN' : 'OUT'} ${indiaTime(kept.last.atDevice)}'
                                : '${lastP!['kind'] == 'in' ? 'IN' : 'OUT'} ${lastP['time'] ?? ''}',
                            key: const Key('att-state'),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                      ])),
                      Pill(next == 'in' ? bi('Next: IN', 'पुढे: IN') : bi('Next: OUT', 'पुढे: OUT'), color: next == 'in' ? C.greenDark : C.orange, bg: next == 'in' ? C.greenSoft : C.orangeSoft),
                    ]),
                  ),
                  if (offline) InfoLine(bi('No network – shown as read last. A punch taken now is kept on the phone and sent later.', 'Network नाही – शेवटचे वाचलेले दाखवले आहे. आता लावलेली हजेरी phone मध्ये राहील आणि नंतर जाईल.', '\n'), icon: Icons.cloud_off_rounded, bad: true, help: false, key: const Key('att-offline')),
                  // ---- what stops a punch on this phone
                  if (!may) InfoLine(bi('Your employee record is not complete (date of birth, e-mail, mobile) – ask the HR office.', 'तुमची employee माहिती अपूर्ण आहे (जन्मतारीख, e-mail, mobile) – HR office ला सांगा.', '\n'), bad: true, help: false, key: const Key('att-incomplete')),
                  if (dev) InfoLine(bi('Developer Options are ON in this phone. Switch them off (Settings › Developer options), then come back – attendance cannot be marked until then.', 'या phone मध्ये Developer Options चालू आहेत. ते बंद करा (Settings › Developer options) आणि परत या – तोपर्यंत हजेरी लावता येणार नाही.', '\n'), bad: true, help: false, key: const Key('att-dev')),
                  if (phone == 'other')
                    InfoLine(bi('Your attendance is tied to another phone (${me?['phone_model'] ?? ''}). Only the HR Admin can release it – then this phone will work.', 'तुमची हजेरी दुसऱ्या phone ला बांधलेली आहे (${me?['phone_model'] ?? ''}). फक्त HR Admin तो सोडू शकतो – मग हा phone चालेल.', '\n'), bad: true, help: false, key: const Key('att-other')),
                  if (_places.isEmpty) InfoLine(bi('No work place is set for you yet – ask the HR office.', 'तुमच्यासाठी अजून work place ठरवलेले नाही – HR office ला सांगा.', '\n'), bad: true, help: false, key: const Key('att-noplace')),
                  const SizedBox(height: 14),
                  // ---- where I am
                  Container(
                    key: const Key('att-where'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: hit == null ? C.slateSoft : hit!.inside ? C.greenSoft : C.redSoft, borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      Icon(hit == null ? Icons.my_location_rounded : hit!.inside ? Icons.verified_rounded : Icons.wrong_location_rounded, color: hit == null ? C.slate : hit!.inside ? C.greenDark : C.red, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(
                              hit == null
                                  ? bi('Your work places: ${_places.map((p) => p.name).join(', ')}', 'तुमची work places: ${_places.map((p) => p.name).join(', ')}', '\n')
                                  : hit!.inside
                                      ? bi('Inside: ${hit!.place.name}', 'आत आहात: ${hit!.place.name}', '\n')
                                      : bi('Outside – ${hit!.distance} m from ${hit!.place.name}', 'बाहेर – ${hit!.place.name} पासून ${hit!.distance} m', '\n'),
                              style: TextStyle(fontSize: 14.5, height: 1.35, fontWeight: FontWeight.w600, color: hit == null ? C.ink : hit!.inside ? C.greenDark : C.red))),
                      TextButton(key: const Key('att-look'), onPressed: blocked || busy || looking ? null : _look, child: Text(looking ? '…' : bi('Check', 'तपासा'))),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  // ---- the punch
                  Center(
                    child: SizedBox(
                      width: 190,
                      height: 190,
                      child: FilledButton(
                        key: const Key('att-punch'),
                        style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: next == 'in' ? C.green : C.orange, disabledBackgroundColor: C.slateSoft, padding: EdgeInsets.zero),
                        onPressed: blocked || busy ? null : _punch,
                        child: busy
                            ? const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(next == 'in' ? Icons.login_rounded : Icons.logout_rounded, size: 44, color: blocked ? C.faint : Colors.white),
                                const SizedBox(height: 6),
                                Text(next == 'in' ? 'Mark IN' : 'Mark OUT', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: blocked ? C.faint : Colors.white)),
                                Text(next == 'in' ? 'हजेरी लावा' : 'बाहेर पडा', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 14, color: blocked ? C.faint : Colors.white.withValues(alpha: .9))),
                              ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(child: Text(bi('Location + a selfie as proof · today only', 'Location + पुराव्यासाठी selfie · फक्त आज', '\n'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35))),
                ],
                if (done.isNotEmpty) InfoLine(done, icon: Icons.check_circle_rounded, key: const Key('att-done')),
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('att-err')),
                for (final r in refused) InfoLine(bi('A punch kept on the phone was not taken: $r', 'Phone मध्ये ठेवलेली हजेरी घेतली गेली नाही: $r', '\n'), bad: true, help: false),
                if (me != null) ...[
                  // ---- kept on the phone
                  if (kept.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(bi('Waiting for the network (${kept.length})', 'Network ची वाट पाहत आहे (${kept.length})'), style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w700)),
                    for (final k in kept) _row(k.kind, indiaTime(k.atDevice), k.place, bi('On the phone', 'Phone मध्ये'), C.amber, C.amberSoft, Key('att-kept-${k.kind}')),
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('att-send'), onPressed: busy ? null : () => _load(), icon: const Icon(Icons.cloud_upload_rounded), label: Text(bi('Send now', 'आता पाठवा')))),
                  ],
                  // ---- today's punches
                  const SizedBox(height: 18),
                  Text(bi('Today\'s punches', 'आजच्या नोंदी'), style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w700)),
                  if (punches.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(bi('None yet.', 'अजून नाही.'), style: const TextStyle(fontSize: 14, color: C.faint))),
                  for (final p in punches)
                    _row('${p['kind']}', '${p['time'] ?? ''}', _placeName('${p['place_id'] ?? ''}'), p['status'] == 'review' ? bi('To be looked at', 'तपासणीसाठी') : p['offline'] == true ? bi('Sent later', 'नंतर पाठवले') : '', p['status'] == 'review' ? C.amber : C.slate,
                        p['status'] == 'review' ? C.amberSoft : C.slateSoft, Key('att-p-${p['id']}')),
                  if (team > 0) ...[
                    const SizedBox(height: 14),
                    Press(
                      key: const Key('att-team'),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TeamRegsScreen(ask: _hr)));
                        _team();
                      },
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.how_to_reg_rounded, color: C.amber, size: 24)),
                        const SizedBox(width: 12),
                        const Expanded(child: TwoLang('My team\'s requests', 'माझ्या टीमच्या विनंत्या', size: 16, weight: FontWeight.w700)),
                        if (teamWait > 0) Pill('$teamWait', color: Colors.white, bg: C.red),
                        const Icon(Icons.chevron_right_rounded, color: C.faint),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Press(
                    key: const Key('att-month'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttendMonthScreen(ask: _hr))),
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(width: 44, height: 44, decoration: BoxDecoration(color: Tone.hr.soft, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.calendar_month_rounded, color: Tone.hr.b, size: 24)),
                      const SizedBox(width: 12),
                      const Expanded(child: TwoLang('This month', 'हा महिना', size: 16, weight: FontWeight.w700)),
                      const Icon(Icons.chevron_right_rounded, color: C.faint),
                    ]),
                  ),
                ],
              ]),
            ),
    );
  }

  String _placeName(String id) {
    for (final p in _places) {
      if (p.id == id) return p.name;
    }
    return '';
  }

  Widget _row(String kind, String time, String place, String note, Color c, Color soft, Key key) => Container(
        key: key,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Row(children: [
          Pill(kind == 'in' ? 'IN' : 'OUT', color: kind == 'in' ? C.greenDark : C.orange, bg: kind == 'in' ? C.greenSoft : C.orangeSoft),
          const SizedBox(width: 12),
          Text(time, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: C.muted))),
          if (note.isNotEmpty) Pill(note, color: c, bg: soft),
        ]),
      );
}

/// The selfie of a punch: the front camera, one button. Proof only – nothing reads the face. Gives the camera's picture, or
/// nothing when he goes back.
class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key});
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
                      : ClipRRect(borderRadius: BorderRadius.circular(24), child: CameraPreview(cam!)))),
          if (cam != null && err.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: SizedBox(
              width: 84,
              height: 84,
              child: FilledButton(
                key: const Key('selfie-take'),
                style: FilledButton.styleFrom(shape: const CircleBorder(), backgroundColor: Colors.white, padding: EdgeInsets.zero),
                onPressed: cam == null || taking ? null : _take,
                child: taking ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.camera_alt_rounded, color: Colors.black, size: 34),
              ),
            ),
          ),
        ]),
      );
}

/// His month: each day with its first IN and last OUT, as the server has them.
class AttendMonthScreen extends StatefulWidget {
  const AttendMonthScreen({super.key, required this.ask});
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body) ask;
  @override
  State<AttendMonthScreen> createState() => _AttendMonthScreenState();
}

class _AttendMonthScreenState extends State<AttendMonthScreen> {
  String month = '', err = '', today = '';
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
    final y = int.parse(month.substring(0, 4)), m = int.parse(month.substring(5, 7)), d = DateTime.utc(y, m + by, 1);
    if (by > 0 && '${d.year}-${d.month.toString().padLeft(2, '0')}'.compareTo(indiaDay(AttendKit.kit.now()).substring(0, 7)) > 0) return; // not a month to come
    month = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    _load();
  }

  // a day gone that can still be asked for (the server's days back)
  bool _canAsk(String day) {
    if (regDays <= 0 || today.isEmpty || day.compareTo(today) >= 0) return false;
    final t = DateTime.tryParse('${today}T00:00:00Z'), d = DateTime.tryParse('${day}T00:00:00Z');
    return t != null && d != null && t.difference(d).inDays <= regDays;
  }

  Future<void> _ask(Map d) async {
    final ok = await askRegularize(context, widget.ask, '${d['day']}', inNow: '${d['in'] ?? ''}', outNow: '${d['out'] ?? ''}');
    if (!ok || !mounted) return;
    toast(context, bi('Sent – it counts when it is approved.', 'पाठवले – मंजूर झाल्यावर धरले जाईल.'));
  }

  static const _names = {'P': 'Present', 'HD': 'Half day', 'A': 'Absent', 'WO': 'Weekly off', 'H': 'Holiday', 'WOP': 'Worked on off', 'HP': 'Worked on holiday', 'IN': 'At work', 'MIS': 'No OUT'};
  (Color, Color) _look(String c) => switch (c) {
        'P' || 'WOP' || 'HP' => (C.greenDark, C.greenSoft),
        'HD' => (C.amber, C.amberSoft),
        'A' || 'MIS' => (C.red, C.redSoft),
        'IN' => (C.blue, C.blueSoft),
        _ => (C.slate, C.slateSoft),
      };

  @override
  Widget build(BuildContext context) {
    Widget count(String key, String label, Object? v, Color c) => Expanded(
          child: Column(children: [Text('${v ?? 0}', key: Key('att-t-$key'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)), Text(label, style: const TextStyle(fontSize: 12, color: C.muted))]),
        );
    return Scaffold(
      appBar: toneBar(Tone.hr, title: Text(bi('My month', 'माझा महिना')), actions: [
        IconButton(key: const Key('att-regs'), tooltip: bi('My requests', 'माझ्या विनंत्या'), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttendRegsScreen(ask: widget.ask))), icon: const Icon(Icons.fact_check_rounded)),
      ]),
      body: ListView(key: const Key('att-month-page'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
        Row(children: [
          IconButton(key: const Key('att-m-prev'), onPressed: loading ? null : () => _move(-1), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(child: Center(child: Text('${month.substring(5, 7)}-${month.substring(0, 4)}', key: const Key('att-m-name'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))),
          IconButton(key: const Key('att-m-next'), onPressed: loading ? null : () => _move(1), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (err.isNotEmpty) InfoLine(err, bad: true, help: false),
        if (!loading && err.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Tone.hr.soft, borderRadius: BorderRadius.circular(18)),
            child: total.isEmpty
                ? Text(bi('Days with a punch: ${days.length}', 'हजेरीचे दिवस: ${days.length}'), key: const Key('att-m-count'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Tone.hr.b))
                : Row(key: const Key('att-m-total'), children: [count('P', bi('Present', 'हजर', '\n'), total['P'], C.greenDark), count('HD', bi('Half day', 'अर्धा दिवस', '\n'), total['HD'], C.amber), count('A', bi('Absent', 'गैरहजर', '\n'), total['A'], C.red), count('late', bi('Late', 'उशीर', '\n'), total['late'], C.slate)]),
          ),
          if (regDays > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text(bi('Forgot IN or OUT on a day gone? Tap that day.', 'गेलेल्या दिवशी IN किंवा OUT राहिले? त्या दिवसावर tap करा.', '\n'), style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35))),
          if (days.isEmpty) Padding(padding: const EdgeInsets.only(top: 20), child: Center(child: Text(bi('No punch in this month.', 'या महिन्यात हजेरी नाही.'), style: const TextStyle(color: C.faint)))),
          for (final d in days) ...[
            const SizedBox(height: 8),
            Press(
              key: Key('att-d-${d['day']}'),
              onTap: _canAsk('${d['day']}') ? () => _ask(d) : null,
              radius: 16,
              shadow: false,
              border: C.line,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(child: Text(_dmy('${d['day']}'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700))),
                if ('${d['code'] ?? ''}'.isNotEmpty) ...[Pill(_names['${d['code']}'] ?? '${d['code']}', color: _look('${d['code']}').$1, bg: _look('${d['code']}').$2), const SizedBox(width: 8)],
                Text('${_or(d['in'])} – ${_or(d['out'])}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.muted)),
                if (d['late_min'] is num && (d['late_min'] as num) > 0) ...[const SizedBox(width: 6), const Icon(Icons.schedule_rounded, size: 17, color: C.amber)],
                if ((d['review'] is num) && (d['review'] as num) > 0) ...[const SizedBox(width: 6), const Icon(Icons.hourglass_top_rounded, size: 17, color: C.amber)],
              ]),
            ),
          ],
        ],
      ]),
    );
  }
}
