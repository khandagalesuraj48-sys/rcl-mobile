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
import '../core/app_consent.dart';
import '../core/attend.dart';
import '../core/attend_pdf.dart';
import '../core/attend_remind.dart';
import '../core/hr_cache.dart';
import '../core/session.dart';
import '../ui/attend_look.dart';
import '../ui/done_pop.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/motion.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/files.dart' show handOver;
import 'attend_reqs.dart';
import 'consent_gate.dart' show showConsent;
import 'face_screens.dart';
import 'hr_shell.dart';
import 'leave.dart';

Future<void> openAttendance(BuildContext context) => Navigator.of(context).push(hrRoute<void>(const HrShell(inErp: true))); // (3.115.0) the attendance app itself

/// (a test) the selfie without a camera; null = the real camera screen.
Future<Uint8List?> Function(BuildContext context)? attendSelfieForTest;

/// (3.141.0, asked 18-11-2026: "user HO cha aahe ani app madhe to VTR madhe aahe tyala HO la jaychi garaj naswi direct VTR madhun
/// pn mhanje other site madhun pn sign in kru shakel") HIS HR SITE: this site when he has HR here; else the site of his own HR –
/// "My HR" first (an HO employee working in VTR's ERP: Head Office), then the HR office's. His attendance is marked, his leave and
/// slips are seen from any of his sites, without changing site; the HR server decides as always (his record, his work places).
SiteChoice? hrSite(Session s) {
  bool has(SiteChoice x) => x.module('hr') != null || x.module('hrme') != null;
  final here = s.site;
  if (here != null && has(here)) return here;
  for (final key in const ['hrme', 'hr']) {
    for (final x in s.sites) {
      if (x.module(key) != null) return x;
    }
  }
  return null;
}

/// HR's module of his HR site: the HR office's ('hr') when he has it there, else "My HR" ('hrme'); null = none.
Module? hrModule(Session s) {
  final x = hrSite(s);
  return x?.module('hr') ?? x?.module('hrme');
}

String _or(Object? v) {
  final t = '${v ?? ''}';
  return t.isEmpty ? '–' : t;
}

/// (3.107.0, the clean screens he approved: "je required nahi te text kadhayche … app purn english") ONE language on these
/// screens: English while none is chosen, the app's own Marathi words when Marathi is (Me → Language).
String _t(String en, String mr) => Lang.i.pair(en, mr);

String _dmy(String ymd) => ymd.length >= 10 ? '${ymd.substring(8, 10)}-${ymd.substring(5, 7)}-${ymd.substring(0, 4)}' : ymd;

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.quick = false, this.embedded = false, this.auto = false});

  /// (3.116.0, his word of 13-11-2026: "in out one click madhe pudhe janar jast click kraychi garaj nahiye") opened to mark at
  /// once: his place is read and the selfie opens by itself – no page to look at, nothing to slide. What stops a punch (outside
  /// his place, another phone, …) is said on this page as before, with the bar to try again.
  final bool auto;

  /// (3.114.0) a tab of the attendance app: no way back in its head and no bar to mark – the tab bar's middle button marks.
  final bool embedded;

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
  bool _autoDone = false, _autoOn = false; // (auto) tried once; going on now
  Map? _leaveErr; // (3.147.0) the server refused IN: today is a day of his leave (the leave it named)
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
    final s = SessionScope.read(context), h = hrSite(s), m = hrModule(s);
    if (h == null || m == null) throw StateError('none');
    return s.api.hr(h.code, m.url, m.key, body);
  }

  /// (3.111.0, rcl-hr step 9) the face for attendance – its own endpoint of the HR server, the same sign-in.
  Future<Map<String, dynamic>> _face(Map<String, dynamic> body) {
    final s = SessionScope.read(context), h = hrSite(s), m = hrModule(s);
    if (h == null || m == null) throw StateError('none');
    return s.api.hr(h.code, m.url, m.key, body, path: 'face');
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
    /* (3.134.0, rcl-hr step 14) HIS CONSENT: the words come from the HR server (its version is written down with his "I agree");
     * an HR server of before has none – the screen's own words then, as before */
    Map<String, dynamic>? words;
    try {
      words = await _face({'action': 'faceConsentText'});
    } on ApiError catch (e) {
      if (e.code == 'net') rethrow;
      words = null;
    }
    if (!mounted) return false;
    final shots = await FaceKit.kit.enrol(context, words: words);
    if (shots == null || !mounted) return false;
    final s = SessionScope.read(context), u = await _face({'action': 'faceEnrolUrls'});
    for (final p in (u['pictures'] as List? ?? const []).whereType<Map>()) {
      final jpg = shots['${p['pose']}'];
      if (jpg == null) throw ApiError('A picture of the registration is missing – register again.', code: 'picture');
      await s.api.hrPhoto('${p['url']}', jpg);
    }
    final info = await AttendKit.kit.info();
    await _face({'action': 'faceEnrol', 'token': u['token'], 'device': {'id': info['id'], 'model': info['model']}, if (words != null && words['version'] != null) 'consent': {'version': words['version'], 'lang': consentLang()}});
    _faceIn = true;
    if (mounted) donePop(context, _t('Your face is registered', 'तुमचा चेहरा नोंदवला'));
    return true;
  }

  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context);
    store ??= AttendStore('${s.email}|${hrSite(s)?.code ?? ''}');
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
      _auto();
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
          _autoDone = true; // (no network: the page as read last – he marks with the bar, it is kept on the phone)
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
    // (3.136.0, rcl-hr step 16) the phone's own proof for this very punch – only when the HR server asks for it
    final pj = me?['integrity'] is Map ? (me!['integrity'] as Map)['project'] : null;
    final proof = pj is num && pj > 0 ? await AttendKit.kit.integrity(pj.toInt(), 'rcl-punch|${p.cid}') : '';
    return _hr(p.body(live: live, key: await attendKey(s.api.keep), proof: proof).cast<String, dynamic>()); // (3.134.0) with the phone's own key
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
  Future<PlaceHit> _where([String kind = '']) async {
    if (await AttendKit.kit.devOptions()) {
      if (mounted) setState(() => dev = true);
      throw AttendProblem('Developer Options are ON in this phone: switch them off (Settings › Developer options) to mark attendance.', 'या phone मध्ये Developer Options चालू आहेत: हजेरीसाठी ते बंद करा (Settings › Developer options).', 'devoptions');
    }
    final places = _places;
    if (places.isEmpty) throw AttendProblem('No work place is set for you yet – ask the HR office.', 'तुमच्यासाठी अजून work place ठरवलेले नाही – HR office ला सांगा.', 'noplace');
    // (3.117.0) one press from the attendance app: its reading of a moment ago is used while it is young – else read now
    final f = (widget.auto ? AttendWhere.i.fresh() : null) ?? await AttendKit.kit.where();
    if (f.mocked) throw AttendProblem('This phone gives a made-up location: attendance cannot be marked.', 'हा phone खोटे location देत आहे: हजेरी लावता येणार नाही.', 'mock');
    if (!(f.acc >= 0) || f.acc > _maxAcc) {
      throw AttendProblem('Your location is not exact enough yet (${f.acc.round()} m): stand in the open for a moment and try again.', 'तुमचे location अजून नेमके नाही (${f.acc.round()} m): थोडा वेळ मोकळ्या जागेत उभे राहून पुन्हा करा.', 'accuracy');
    }
    // (3.135.0, rcl-hr step 15) only the places where he may mark THIS (IN or OUT) – the server checks the same
    final usable = kind.isEmpty ? places : places.where((p) => p.may(kind)).toList(), k = kind == 'out' ? 'OUT' : 'IN';
    if (usable.isEmpty) throw AttendProblem('You may not mark $k at any of your work places – ask the HR office.', 'तुमच्या कोणत्याही work place वर $k लावता येत नाही – HR office ला सांगा.', 'inout');
    final h = nearestPlace(usable, f.lat, f.lng)!;
    fix = f;
    if (mounted) setState(() => hit = h);
    if (!h.inside) {
      final any = usable.length < places.length ? nearestPlace(places, f.lat, f.lng) : null;
      if (any != null && any.inside) {
        final where = usable.take(3).map((p) => p.name).join(', ');
        throw AttendProblem('At ${any.place.name} you may not mark $k – $k is marked at: $where.', '${any.place.name} येथे $k लावता येत नाही – $k येथे लागते: $where.', 'inout');
      }
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

  /// (3.147.0, rcl-hr of 19-11-2026: "5 tarkela aloy kamawar return … sign in krayla gelo tr app error deil ani suggestions deil ki
  /// leave madhe jaun date correct kr") today is a day of his leave – approved or waiting: no IN until he makes the leave shorter.
  Map? get _onLeave {
    if (_next != 'in') return null;
    final l = me?['leave'];
    return l is Map ? l : _leaveErr;
  }

  // Leave → this leave → Change days; saved: read again – IN is open now (one press from Home: it goes on to mark)
  Future<void> _changeLeave() async {
    final lv = _onLeave;
    if (lv == null || busy) return;
    try {
      final j = await _hr({'action': 'myLeave'});
      if (!mounted) return;
      final q = [for (final x in (j['requests'] as List? ?? const []).whereType<Map>()) x].where((x) => '${x['id']}' == '${lv['id']}').firstOrNull;
      if (q == null || (q['can'] is Map && (q['can'] as Map)['change'] != true)) {
        await Navigator.of(context).push(hrRoute<void>(LeaveScreen(ask: _hr)));
      } else {
        final r = await Navigator.of(context).push<Map<String, dynamic>>(hrRoute(LeaveChangeScreen(ask: _hr, request: q, today: '${j['today'] ?? me?['day'] ?? ''}', paper: j['paper'] == true)));
        if (r == null || !mounted) return;
      }
      _leaveErr = null;
      await _load(quiet: true);
      if (!mounted) return;
      if (_onLeave == null) {
        setState(() => done = _t('Your leave is changed – mark IN now.', 'रजा बदलली – आता IN लावा.'));
        if (widget.auto) unawaited(_punch());
      }
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  /// (3.116.0) one press: the punch starts by itself, once, when nothing stops it.
  void _auto() {
    if (!widget.auto || _autoDone || me == null) return;
    _autoDone = true;
    if (me?['may'] == false || dev || '${me?['phone'] ?? ''}' == 'other' || _places.isEmpty || _dayDone || _onLeave != null) {
      setState(() {});
      return;
    }
    setState(() => _autoOn = true);
    _punch().whenComplete(() {
      if (mounted) setState(() => _autoOn = false);
    });
  }

  Future<void> _punch() async {
    if (busy || me == null) return;
    final kind = _next;
    if (_onLeave != null) return; // (3.147.0) a day of his leave: the card says what to do
    // (20-11-2026) attendance needs the app's terms / location notice to be allowed: shown here when it is not in force yet
    final s0 = SessionScope.read(context);
    if (!AppConsent.ok(s0)) {
      if (!await showConsent(context) || !mounted) return;
    }
    setState(() {
      busy = true;
      err = '';
      done = '';
    });
    try {
      final h = await _where(kind), f = fix!;
      if (!mounted) return;
      // (3.111.0) the face is needed: registered first (once); then the living face – straight, a blink – gives the proof photo
      final Uint8List? raw;
      if (_faceOn) {
        if (!await _faceReady() || !mounted) return;
        raw = await FaceKit.kit.check(context, stamp: '${_dmy('${me?['day'] ?? ''}')} · ${h.place.name}');
      } else {
        raw = attendSelfieForTest != null ? await attendSelfieForTest!(context) : await Navigator.of(context).push<Uint8List>(hrRoute(SelfieScreen(stamp: '${_dmy('${me?['day'] ?? ''}')} · ${h.place.name}')));
      }
      if (raw == null) {
        if (_autoOn && mounted) Navigator.of(context).pop(); // (one press) he went back from the selfie: where he came from
        return; // he went back: nothing taken
      }
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
        anchorSig: '${last?['anchor_sig'] ?? ''}', // (3.134.0) the server's seal of that time
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
        await Navigator.of(context).push(hrRoute<void>(AttendDone(kind: kind, time: okTime, place: h.place.name)));
        if (mounted) Navigator.of(context).pop();
      }
    } on AttendProblem catch (e) {
      if (mounted) setState(() => err = _t(e.en, e.mr));
    } on ApiError catch (e) {
      // (3.147.0) the server: today is a day of his leave – the card with "Change leave days" instead of the message
      if (mounted) {
        setState(() {
          if (e.code == 'onleave' && e.data['leave'] is Map) {
            _leaveErr = e.data['leave'] as Map;
          } else {
            err = e.message;
          }
        });
      }
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
    final blocked = me == null || !may || dev || phone == 'other' || _places.isEmpty || _onLeave != null;
    // (3.105.0) the sky says where his day stands: dawn – not marked; day – on duty; dusk – done; grey – it cannot be marked here / now
    final sky = skyOf(any: punches.isNotEmpty || kept.isNotEmpty, next: next, stopped: blocked || (hit != null && !hit!.inside));
    // (3.116.0) one press: while his place is read and the selfie is taken – only the round sign and what is going on
    if (widget.auto && (!_autoDone || _autoOn) && err.isEmpty) {
      return Scaffold(
        body: Container(
          key: const Key('att-auto'),
          width: double.infinity,
          decoration: BoxDecoration(gradient: sk.pageFill),
          child: SafeArea(
            child: Stack(children: [
              Positioned(left: 16, top: 4, child: hrIconBox(Icons.arrow_back_ios_new_rounded, size: 40, icon: 17, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop())),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  MarkDisc(size: 150, label: me == null ? '' : (next == 'in' ? 'IN' : 'OUT'), out: me != null && next != 'in'),
                  const SizedBox(height: 26),
                  Text(me == null ? 'One moment…' : 'Checking your place…', mr: me == null ? 'एक क्षण…' : 'तुमची जागा तपासत आहे…', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18, fontWeight: FontWeight.w800, color: sk.ink)),
                  const SizedBox(height: 6),
                  Text('Then your selfie – and it is marked.', mr: 'मग selfie – आणि हजेरी लागते.', style: TextStyle(fontSize: 13.5, color: sk.muted)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: _head(context, sky, me == null ? '' : '${emp['name'] ?? s.name} · ${emp['code'] ?? ''}', next, punches),
      bottomNavigationBar: me == null || loading || widget.embedded ? null : _punchBar(next, blocked || _dayDone),
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
                  if (_onLeave != null) _leaveCard(_onLeave!),
                  // (3.110.0) once a day / closed by itself – said plainly, with what he can do
                  if (_closed.isNotEmpty)
                    InfoLine(_t('OUT was not marked: today was closed by itself at $_closed and counts as absent. Regularize the day (Regularization).', 'OUT लावले नाही: आजचा दिवस $_closed ला आपोआप बंद झाला आणि गैरहजर धरला आहे. दुरुस्तीसाठी विनंती करा (Requests).'), bad: true, help: false, key: const Key('att-closed'))
                  else if (_dayDone)
                    InfoLine(_t('Today\'s attendance is done – one IN and one OUT a day. A mistake: regularize the day (Regularization).', 'आजची हजेरी पूर्ण – दिवसात एकदाच IN आणि एकदाच OUT. चूक झाली असेल तर दुरुस्तीसाठी विनंती करा (Requests).'), icon: Icons.check_circle_rounded, help: false, key: const Key('att-once')),
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
                      Text(_t('Waiting for the network (${kept.length})', 'Network ची वाट पाहत आहे (${kept.length})'), style: TextStyle(fontSize: 13, color: sk.muted, fontWeight: FontWeight.w700)),
                      for (final k in kept) _row(k.kind, indiaTime(k.atDevice), k.place, _t('Kept', 'ठेवले'), C.amber, C.amberSoft, Key('att-kept-${k.kind}')),
                      Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('att-send'), onPressed: busy ? null : () => _load(), icon: const Icon(Icons.cloud_upload_rounded), label: Text(_t('Send now', 'आता पाठवा')))),
                    ]),
                  ],
                  // ---- today's punches, in one card
                  const SizedBox(height: 14),
                  _card([
                    Text('Today', mr: 'आज', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.classic ? null : sk.ink)),
                    if (punches.isEmpty) Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Text(_t('No punch yet.', 'अजून नोंद नाही.'), style: TextStyle(fontSize: 14, color: sk.faint))),
                    for (final p in punches)
                      _row('${p['kind']}', '${p['time'] ?? ''}', _placeName('${p['place_id'] ?? ''}'), p['status'] == 'review' ? _t('To be checked', 'तपासणी') : p['offline'] == true ? _t('Sent later', 'नंतर पाठवले') : '',
                          p['status'] == 'review' ? C.amber : C.slate, p['status'] == 'review' ? C.amberSoft : C.slateSoft, Key('att-p-${p['id']}')),
                  ]),
                  // ---- his month, his leave, his requests (3.108.0: what waits for him of his team is inside "Requests")
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _tile(const Key('att-month'), '${_monthDays('${me?['day'] ?? ''}')}', C.blue, C.blueSoft, 'This month', 'हा महिना', () => Navigator.of(context).push(hrRoute<void>(AttendMonthScreen(ask: _hr, who: '${emp['name'] ?? s.name} · ${emp['code'] ?? ''}'))))),
                    const SizedBox(width: 10),
                    Expanded(child: _tile(const Key('att-leave'), 'L', kPurple, const Color(0xFFF1E8F6), 'Leave', 'रजा', () => Navigator.of(context).push(hrRoute<void>(LeaveScreen(ask: _hr))))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _tile(const Key('att-reqs'), 'R', const Color(0xFF8A5A00), const Color(0xFFFFF3D1), 'Regularization', 'Regularization', () async {
                      await Navigator.of(context).push(hrRoute<void>(AttendRegsScreen(ask: _hr)));
                      _team();
                    }, badge: teamWait)),
                  ]),
                ],
              ]),
            ),
    );
  }

  // (3.147.0) today is a day of his leave: what it is, and the way to work today
  Widget _leaveCard(Map lv) {
    final from = '${lv['from'] ?? ''}', to = '${lv['to'] ?? from}', wait = '${lv['status']}' == 'pending';
    final span = '${_dmy(from)}${to != from ? ' – ${_dmy(to)}' : ''}';
    return Container(
      key: const Key('att-onleave'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.amber.withValues(alpha: .5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.beach_access_rounded, size: 20, color: Color(0xFF8A5A00)),
          const SizedBox(width: 8),
          Expanded(child: m.Text(_t('You are on leave today', 'आज तुमची रजा आहे'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Color(0xFF5B4A14)))),
        ]),
        const SizedBox(height: 4),
        m.Text(_t('Leave $span${wait ? ' (waiting for approval)' : ''}. To work today, make your leave shorter – then mark IN.', 'रजा $span${wait ? ' (मंजुरीसाठी प्रलंबित)' : ''}. आज कामावर हजेरीसाठी रजेचे दिवस कमी करा – मग IN लावा.'),
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF5B4A14), height: 1.35)),
        const SizedBox(height: 10),
        hrButton('Change leave days', 'रजेचे दिवस बदला', key: const Key('att-leave-change'), onTap: busy ? null : _changeLeave),
      ]),
    );
  }

  Widget _card(List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: sk.box(),
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
          decoration: sk.box(radius: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(child: m.Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: sk.ink, height: 1.25))),
          ]),
        ),
      );

  // the days of the month of [ymd] – the sign of "This month" (30)
  int _monthDays(String ymd) {
    final d = DateTime.tryParse('${ymd}T00:00:00Z') ?? DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now(), isUtc: true);
    return DateTime.utc(d.year, d.month + 1, 0).day;
  }

  Widget _tile(Key key, String sign, Color c0, Color soft0, String en, String mr, VoidCallback onTap, {int badge = 0}) {
    final (Color c, Color soft) = sk.tint(c0, soft0);
    return Press(
        key: key,
        onTap: onTap,
        radius: 18,
        color: sk.card,
        border: sk.cardLine,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(13)), child: m.Text(sign, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: c))),
            if (badge > 0) Positioned(right: -10, top: -6, child: Pill('$badge', color: Colors.white, bg: C.red)),
          ]),
          const SizedBox(height: 7),
          Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sk.classic ? null : sk.ink)),
        ]),
      );
  }

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
    if (!sk.classic) return _lookHead(context, sky, who, next, lastP, since);
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

  /// (3.114.0) The head in the attendance app: no sky – the title, who he is, and a card that says where today stands with its
  /// round sign (gold IN, red OUT, silver when today is done, pale when it cannot be marked).
  PreferredSizeWidget _lookHead(BuildContext context, Sky sky, String who, String next, Map? lastP, String since) {
    final state = lastP == null && kept.isEmpty
        ? _t('Not marked yet', 'अजून लावलेली नाही')
        : kept.isNotEmpty
            ? '${kept.last.kind == 'in' ? 'IN' : 'OUT'} ${indiaTime(kept.last.atDevice)}'
            : '${lastP!['kind'] == 'in' ? 'IN' : 'OUT'} ${lastP['time'] ?? ''}';
    final under = since.isNotEmpty ? _t('On duty · $since', 'कामावर · $since') : sky == Sky.dusk ? _t('Today\'s attendance is done', 'आजची हजेरी पूर्ण') : who;
    return PreferredSize(
      preferredSize: const Size.fromHeight(160),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [sk.bgTop, sk.bg])),
        child: SafeArea(
          bottom: false,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              maxHeight: double.infinity,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (widget.embedded) const SizedBox(width: 18, height: 48) else Padding(padding: const EdgeInsets.fromLTRB(16, 4, 12, 4), child: hrIconBox(Icons.arrow_back_ios_new_rounded, size: 40, icon: 17, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop())),
                  Expanded(child: Text('My attendance', mr: 'माझी हजेरी', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 21, fontWeight: FontWeight.w800, color: sk.ink))),
                  Padding(padding: const EdgeInsets.only(right: 16), child: hrIconBox(Icons.refresh_rounded, size: 40, icon: 20, tooltip: tr('Refresh'), onTap: busy ? null : () => _load())),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                    decoration: sk.box(radius: 22),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          if (who.isNotEmpty && under != who) m.Text(who, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted)),
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(state, key: const Key('att-state'), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 25, fontWeight: FontWeight.w800, color: sk.ink, height: 1.2))),
                          if (under.isNotEmpty) m.Text(under, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sk.muted)),
                        ]),
                      ),
                      const SizedBox(width: 10),
                      MarkDisc(size: 64, label: next == 'in' ? 'IN' : 'OUT', out: next != 'in', done: sky == Sky.dusk, dim: sky == Sky.grey),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
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
                  style: FilledButton.styleFrom(shape: const StadiumBorder(), backgroundColor: sk.classic ? sk.accent : (sk.dark ? const Color(0xFF1D2547) : const Color(0xFF0F1F3D)), disabledBackgroundColor: sk.classic ? C.slateSoft : sk.blank, padding: const EdgeInsets.all(6)),
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
                                child: Text(_dayDone ? _t('Today\'s attendance is done', 'आजची हजेरी पूर्ण') : next == 'in' ? _t('Slide to mark IN', 'IN लावण्यासाठी सरकवा') : _t('Slide to mark OUT', 'OUT लावण्यासाठी सरकवा'), maxLines: 1, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: blocked ? sk.faint : Colors.white)),
                              ),
                            ),
                          ),
                          Transform.translate(offset: Offset(slide, 0), child: sk.classic ? SunDisc(size: 46, label: next == 'in' ? 'IN' : 'OUT', dim: blocked) : MarkDisc(size: 46, label: next == 'in' ? 'IN' : 'OUT', out: next != 'in', dim: blocked)),
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

  Widget _row(String kind, String time, String place, String note, Color c0, Color soft0, Key key) {
    final (Color c, Color soft) = sk.tint(c0, soft0);
    final io = kind == 'in' ? sk.tint(C.greenDark, C.greenSoft) : sk.tint(C.orange, C.orangeSoft);
    return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Pill(kind == 'in' ? 'IN' : 'OUT', color: io.$1, bg: io.$2),
          const SizedBox(width: 12),
          Text(time, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: sk.classic ? null : sk.ink)),
          const SizedBox(width: 12),
          Expanded(child: Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: sk.muted))),
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
      if (mounted) setState(() => err = bi('The camera could not be opened – allow the camera for the app (Settings › Apps › Sketchline › Permissions).', 'Camera उघडला नाही – app ला camera ची परवानगी द्या (Settings › Apps › Sketchline › Permissions).', '\n'));
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
/// (3.117.0) The month's PDF given to the person (the phone's share sheet: save it, send it) – replaceable in a test.
Future<void> Function(Uint8List bytes, String name) attendPdfOut = (bytes, name) async {
  // (3.153.0) Android: straight into the phone's Downloads, with a notification that opens it; else the share sheet as before
  if (await AttendKit.kit.saveDownload(bytes, name, 'application/pdf', Lang.i.pair('Downloaded – touch to open', 'Download झाले – उघडण्यासाठी touch करा'))) return;
  await handOver(bytes, name, 'application/pdf');
};

/// (3.118.0) The logo of the PDF's head (the app's own picture, read and made a JPEG) – replaceable in a test.
Future<PdfLogo?> Function(String company) attendPdfLogo = pdfLogo;

class AttendMonthScreen extends StatefulWidget {
  const AttendMonthScreen({super.key, required this.ask, this.who = '', this.embedded = false});

  /// (3.116.0, "ek feture ekach thikani asaw") the Attendance page of the attendance app's bar: the month and nothing else –
  /// no way back in its head, and the way to his requests (to set a day right) under the calendar.
  final bool embedded;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body) ask;

  /// his name and code, said in the head
  final String who;
  @override
  State<AttendMonthScreen> createState() => _AttendMonthScreenState();
}

class _AttendMonthScreenState extends State<AttendMonthScreen> {
  String month = '', err = '', today = '', sel = ''; // sel: the day opened under the calendar
  List<String> rules = []; // (3.118.0) the site's rules in words, as the HR server says them – the PDF's note
  List<Map> days = [], every = []; // (every: each day of the month as the server said it – the PDF's rows)
  Map total = const {};
  int regDays = 0;
  bool loading = true, making = false;

  @override
  void initState() {
    super.initState();
    month = indiaDay(AttendKit.kit.now()).substring(0, 7);
    _load();
  }

  /// The server's answer for a month, put on the page.
  void _take(Map<String, dynamic> j) {
    // (rcl-hr step 5) every day of the month with what it counts as; before it: only the days with a punch
    final all = [for (final x in (j['all'] as List? ?? const []).whereType<Map>()) x];
    today = '${j['today'] ?? indiaDay(AttendKit.kit.now())}';
    every = all.isNotEmpty ? all : [for (final x in (j['days'] as List? ?? const []).whereType<Map>()) x];
    rules = [for (final x in (j['rules'] as List? ?? const [])) '$x'];
    days = all.isNotEmpty ? [for (final d in all) if ('${d['code'] ?? ''}'.isNotEmpty || (d['punches'] is num && (d['punches'] as num) > 0)) d] : [for (final x in (j['days'] as List? ?? const []).whereType<Map>()) x];
    total = (j['total'] as Map?) ?? const {};
    regDays = j['reg_days'] is num ? (j['reg_days'] as num).toInt() : 0;
    loading = false;
  }

  /// (3.154.0, asked 21-11-2026: "attendance tab nehmi server kadhun data ghetoy … cache data dakhwel … new lagech disel") the
  /// month as it was read the last time is shown at once; the server is asked in the same moment and its answer takes its place.
  Future<void> _load() async {
    final asked = month, key = 'myMonth:$asked', kept = HrCache.now(key);
    setState(() {
      err = '';
      if (kept != null) {
        _take(kept);
      } else {
        loading = true;
      }
    });
    if (kept == null) {
      final k = await HrCache.read(key);
      if (!mounted) return;
      if (k != null && loading && month == asked) setState(() => _take(k));
    }
    try {
      final j = await widget.ask({'action': 'myMonth', 'month': asked});
      HrCache.put(key, j);
      if (!mounted || month != asked) return; // (he went on to another month meanwhile)
      setState(() => _take(j));
    } catch (e) {
      if (mounted && month == asked) {
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
    donePop(context, _t('Request sent', 'विनंती पाठवली'), detail: _t('It counts when it is approved.', 'मंजूर झाल्यावर धरले जाईल.'));
  }

  /// (3.117.0, "user application madhun attednnce pdf download kru shakel … kontya hi month chi") the month shown, as a PDF:
  /// the company and the site, the month and its period, every day in a row, the month's count under it.
  Future<void> _pdf() async {
    if (making || loading) return;
    setState(() => making = true);
    try {
      final s = SessionScope.read(context), who = widget.who.split(' · ');
      final name = who.first.trim().isEmpty ? s.name : who.first.trim(), code = who.length > 1 ? who.last.trim() : '';
      final hs = hrSite(s) ?? s.site, company = (hs?.company ?? '').isNotEmpty ? hs!.company : (s.company.isNotEmpty ? s.company : 'Attendance');
      final now = DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now() + 19800000, isUtc: true).toIso8601String();
      final bytes = await attendancePdf(company: company, site: hs?.name ?? s.siteName, name: name, code: code, month: month, days: every, total: total, rules: rules, logo: await attendPdfLogo(company), made: '${now.substring(8, 10)}/${now.substring(5, 7)}/${now.substring(0, 4)} ${now.substring(11, 16)}');
      await attendPdfOut(bytes, 'Attendance_${code.isEmpty ? name : code}_$month.pdf');
    } catch (_) {
      if (mounted) toast(context, _t('The PDF could not be made – try again.', 'PDF बनली नाही – पुन्हा करा.'));
    }
    if (mounted) setState(() => making = false);
  }

  static const _names = {'P': 'Present', 'HD': 'Half day', 'A': 'Absent', 'L': 'Leave', 'WO': 'Weekly off', 'H': 'Holiday', 'WOP': 'Worked on off', 'HP': 'Worked on holiday', 'IN': 'At work', 'MIS': 'No OUT'};
  static const _green = (Color(0xFF146C2E), Color(0xFFDDF3E4)), _yellow = (Color(0xFF8A5A00), Color(0xFFFFF3D1)), _red = (Color(0xFFC22A1B), Color(0xFFFFE6E3)), _leave = (kPurple, Color(0xFFF1E8F6)), _off = (Color(0xFF7B839C), Color(0xFFE4E7F0));
  (Color, Color) _look(String c) {
    final p = switch (c) {
      'P' || 'WOP' || 'HP' || 'IN' => _green,
      'HD' => _yellow,
      'A' || 'MIS' => _red,
      'L' => _leave,
      _ => _off,
    };
    return sk.tint(p.$1, p.$2); // (3.114.0) on the dark look: the same colour, lighter, on a thin tile of itself
  }

  /// (3.107.0, asked 12-11-2026: "employee monthly bghu shakel day wise nahi month wise") THE MONTH AS A CALENDAR: a box a day in
  /// the colour of what it counts as; the counts above; a day is opened below by a touch – with "Ask to set right" for a day
  /// gone. A day to come (and a day with nothing) is an empty box that cannot be touched.
  /// (3.108.0, his screens) the head is the sky with his days for pay "9.5 days · of 11 working days so far" and the month in
  /// its pill (‹ ›); Present · Half day · Absent · Leave; the colours' names under the calendar.
  /// 0 the calendar, 1 the list of days; the list's filter ('' all, a code, 'late')
  int view = 0;
  String filt = '';

  static int? _hm(Object? v) {
    final t = '${v ?? ''}', i = t.indexOf(':');
    if (i < 1) return null;
    final h = int.tryParse(t.substring(0, i)), mi = int.tryParse(t.substring(i + 1, (i + 3).clamp(0, t.length)));
    return h == null || mi == null ? null : h * 60 + mi;
  }

  /// the minutes worked on a day: its IN to its OUT (an OUT of the next morning counts on)
  static int? _worked(Map d) {
    final a = _hm(d['in']), b = _hm(d['out']);
    if (a == null || b == null) return null;
    final x = b - a + (d['next_day'] == true ? 1440 : 0);
    return x <= 0 ? null : x; // (an OUT before the IN that is not said to be of the next day: not counted)
  }

  static String _span(int mins) => '${mins ~/ 60} h ${(mins % 60).toString().padLeft(2, '0')} m';

  /// (3.156.0, his choice of 21-11-2026 from the pictures: "ok he attendance che design approved ahe") THE MONTH: a navy card –
  /// how much of the month he was there (a gold ring), his days for pay "13.5 days · of 17 working days so far", Present · Half
  /// day · Absent · Leave; three small tiles – late days, his average IN, the hours worked (counted here from the days the server
  /// gave: nothing new is asked of it); the calendar (round days in the colour of what they count as, today in a gold ring, a
  /// dot on a late day) or the same days as a list with a filter; a day opened by a touch: check in, check out, total hours, how
  /// late, where it was marked – and "Regularize" for a day gone. A day to come cannot be touched.
  @override
  Widget build(BuildContext context) {
    final y = int.parse(month.substring(0, 4)), mo = int.parse(month.substring(5, 7));
    final first = DateTime.utc(y, mo, 1).weekday - 1, count = DateTime.utc(y, mo + 1, 0).day; // Monday first
    final byDay = <String, Map>{for (final d in days) '${d['day']}': d};
    final now = today.isEmpty ? indiaDay(AttendKit.kit.now()) : today;
    // the days that were to be worked, up to today: not a weekly off, not a holiday, not a day to come
    final work = [for (final d in days) if ('${d['code'] ?? ''}'.isNotEmpty && d['code'] != 'WO' && d['code'] != 'H' && '${d['day']}'.compareTo(now) <= 0) d].length;
    final paid = total['paid'] is num ? total['paid'] as num : null;
    final pct = paid == null || work <= 0 ? null : (paid / work).clamp(0.0, 1.0).toDouble();
    bool late(Map d) => d['late_min'] is num && (d['late_min'] as num) > 0;
    final lates = days.where(late).length, ins = [for (final d in days) if (_hm(d['in']) != null) _hm(d['in'])!], hrs = [for (final d in days) if (_worked(d) != null) _worked(d)!];
    final avgIn = ins.isEmpty ? null : (ins.reduce((x, z) => x + z) / ins.length).round(), sum = hrs.isEmpty ? 0 : hrs.reduce((x, z) => x + z);
    const gold = Color(0xFFDDAD40);

    Widget stat(String key, String en, String mr, Object? v, Color c) => Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${v ?? 0}', key: Key('att-t-$key'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 18, fontWeight: FontWeight.w800, color: c, height: 1.15)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE)))),
          ]),
        );
    Widget bar() => Container(width: 1, height: 30, color: const Color(0x33FFFFFF));
    Widget tile(String key, IconData icon, String v, String en, String mr) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: sk.box(radius: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 17, color: sk.link),
              const SizedBox(height: 5),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(v, key: Key('att-i-$key'), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: sk.ink))),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sk.muted))),
            ]),
          ),
        );
    Widget seg(int i, String key, IconData icon, String en, String mr) => Expanded(
          child: GestureDetector(
            key: Key('att-v-$key'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => view = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: view == i ? sk.blank : Colors.transparent, borderRadius: BorderRadius.circular(99), border: Border.all(color: view == i ? gold.withValues(alpha: .75) : Colors.transparent, width: 1.2)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 16, color: view == i ? sk.ink : sk.faint),
                const SizedBox(width: 7),
                Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: view == i ? sk.ink : sk.faint)),
              ]),
            ),
          ),
        );
    // a day of the calendar: round, in the colour of what it counts as; today in a gold ring; the day opened: navy
    Widget cell(int n) {
      final day = '$month-${n.toString().padLeft(2, '0')}', d = byDay[day];
      if (d == null) {
        return SizedBox(height: 40, child: Center(child: m.Text('$n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: sk.blankInk))));
      }
      final code = '${d['code'] ?? ''}', lk = _look(code), on = sel == day, off = code == 'WO' || code == 'H' || code.isEmpty;
      return GestureDetector(
        key: Key('att-d-$day'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => sel = day),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: on ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF24408A), Color(0xFF0B1733)]) : null,
                  color: on || off ? null : lk.$2,
                  border: day == now ? Border.all(color: gold, width: 2) : null,
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  m.Text('$n', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.1, color: on ? const Color(0xFFF7DE8E) : off ? sk.faint : lk.$1)),
                  if (code.isNotEmpty) Container(width: 5, height: 5, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: on ? const Color(0xFFF7DE8E) : code == 'H' ? const Color(0xFF3D7BE0) : lk.$1, shape: BoxShape.circle)),
                ]),
              ),
              if (late(d)) Positioned(right: -1, top: -1, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFE6A417), shape: BoxShape.circle, border: Border.all(color: sk.card, width: 2)))),
            ]),
          ),
        ),
      );
    }

    // (3.122.0) the days turn in, a row after a row (again when another month is opened)
    final cells = <Widget>[for (var i = 0; i < first; i++) const SizedBox(height: 40), for (var n = 1; n <= count; n++) Rise(key: ValueKey('turn-$month-$n'), order: (first + n - 1) ~/ 4, flip: true, child: cell(n))];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox(height: 40));
    }
    Widget leg(Color c, String en, String mr) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5), decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          Text(en, mr: mr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sk.muted)),
        ]);
    Widget arrow(String key, IconData icon, int by) => GestureDetector(
          key: Key(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => _move(by),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5), child: Icon(icon, size: 18, color: sk.onHead)),
        );
    Widget dateTile(String day) {
      final d = DateTime.tryParse('${day}T00:00:00Z');
      const wd = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
      return Container(
        width: 46,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(14), border: Border.all(color: gold.withValues(alpha: .45))),
        child: d == null
            ? null
            : Column(mainAxisSize: MainAxisSize.min, children: [
                m.Text('${d.day}', style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: sk.ink, height: 1)),
                const SizedBox(height: 2),
                m.Text(wd[d.weekday - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5, color: sk.link, height: 1)),
              ]),
      );
    }

    Widget chip(String text, Color fg, Color bg) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)), child: m.Text(text, maxLines: 1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)));
    Widget three(IconData icon, String v, String en, String mr) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
            decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(15)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: sk.link),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(v, maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink))),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: sk.muted))),
            ]),
          ),
        );

    final open = sel.isEmpty ? null : byDay[sel];
    // THE DAY OPENED: everything the server says of it
    Widget dayCard(Map open) {
      final oc = '${open['code'] ?? ''}', oin = '${open['in'] ?? ''}', oout = '${open['out'] ?? ''}', mins = _worked(open), place = '${open['place'] ?? ''}', shift = open['shift'] is String ? '${open['shift']}' : '';
      final d = DateTime.tryParse('${sel}T00:00:00Z'), lk = _look(oc);
      const amber = Color(0xFFE6A417);
      return Container(
        key: const Key('att-day'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: sk.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: gold.withValues(alpha: .6), width: 1.3), boxShadow: sk.shadow),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            dateTile(sel),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                m.Text(d == null ? sel : '${_t(_weekFull[d.weekday - 1], _weekFull[d.weekday - 1])}, ${dayName(sel)}', key: const Key('att-day-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w800, color: sk.ink)),
                if (shift.isNotEmpty) m.Text(shift, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted)),
              ]),
            ),
            if (late(open))
              chip(_t('Late ${open['late_min']} min', 'उशीर ${open['late_min']} मि'), sk.dark ? const Color(0xFFF2CC62) : const Color(0xFF9A6B00), amber.withValues(alpha: .18))
            else if (oc.isNotEmpty)
              chip(tr(_names[oc] ?? oc), lk.$1, lk.$2),
          ]),
          const SizedBox(height: 12),
          if (oin.isEmpty && oout.isEmpty)
            Text(oc == 'A' || oc.isEmpty ? _t('No punch on this day', 'या दिवशी हजेरी नाही') : tr(_names[oc] ?? oc), key: const Key('att-day-none'), style: TextStyle(fontSize: 14, color: sk.ink))
          else ...[
            Row(children: [
              three(Icons.login_rounded, _or(open['in']), 'Check in', 'Check in'),
              const SizedBox(width: 8),
              three(Icons.logout_rounded, _or(open['out']), 'Check out', 'Check out'),
              const SizedBox(width: 8),
              three(Icons.schedule_rounded, mins == null ? '–' : _span(mins), 'Total hours', 'एकूण तास'),
            ]),
            if (place.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFF0F7A45).withValues(alpha: sk.dark ? .16 : .09), borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  Icon(Icons.location_on_outlined, size: 16, color: sk.dark ? const Color(0xFF58D68D) : const Color(0xFF0F7A45)),
                  const SizedBox(width: 7),
                  Expanded(child: m.Text(place, key: const Key('att-day-place'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sk.dark ? const Color(0xFF58D68D) : const Color(0xFF0F7A45)))),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            for (final (i, x) in [if (oin.isNotEmpty) (_t('Signed in', 'Sign in केले'), oin), if (oout.isNotEmpty) (_t('Signed out', 'Sign out केले'), '$oout${open['next_day'] == true ? ' (+1)' : ''}')].indexed)
              Padding(
                padding: EdgeInsets.only(left: 4, top: i == 0 ? 0 : 9),
                child: Row(children: [
                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: gold, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  m.Text(x.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sk.ink)),
                  const SizedBox(width: 8),
                  m.Text(x.$2, style: TextStyle(fontSize: 12.5, color: sk.muted)),
                ]),
              ),
          ],
          if ((open['review'] is num) && (open['review'] as num) > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(Icons.hourglass_top_rounded, size: 16, color: C.amber), const SizedBox(width: 6), Expanded(child: Text('A punch of this day waits for the HR office.', mr: 'या दिवसाची एक हजेरी HR office कडे थांबली आहे.', style: TextStyle(fontSize: 12.5, color: sk.muted)))])),
          // (3.110.0) why the day counts so: closed by itself (OUT forgotten), or a half day by the late rule
          if (open['auto'] == true) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_t('OUT was not marked – the day was closed by itself: absent.', 'OUT लावले नाही – दिवस आपोआप बंद झाला: गैरहजर.'), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35))),
          if (open['late_half'] == true) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_t('Late – counted as a half day (the late rule of your site).', 'उशीर – अर्धा दिवस धरला (तुमच्या site चा उशिराचा नियम).'), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35))),
          if (_canAsk(sel)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('att-ask'),
              onPressed: () => _ask(open),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: sk.ink, side: BorderSide(color: gold.withValues(alpha: .8), width: 1.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17))),
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Regularize', mr: 'Regularize', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      );
    }

    // the list of days: the newest first; what he chose to see
    final listed = [for (final d in days.reversed) if (filt.isEmpty || (filt == 'late' ? late(d) : filt == 'P' ? const ['P', 'WOP', 'HP', 'IN'].contains('${d['code']}') : filt == 'A' ? const ['A', 'MIS'].contains('${d['code']}') : '${d['code']}' == filt)) d];
    Widget pick(String v, String en, String mr) => GestureDetector(
          key: Key('att-f-${v.isEmpty ? 'all' : v}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => filt = v),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: filt == v ? sk.blank : sk.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: filt == v ? gold.withValues(alpha: .8) : (sk.cardLine ?? sk.line))),
            child: Text(en, mr: mr, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: filt == v ? sk.ink : sk.muted)),
          ),
        );
    Widget row(Map d, bool last) {
      final day = '${d['day']}', code = '${d['code'] ?? ''}', lk = _look(code), mins = _worked(d), has = '${d['in'] ?? ''}'.isNotEmpty || '${d['out'] ?? ''}'.isNotEmpty;
      return GestureDetector(
        key: Key('att-r-$day'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => sel = sel == day ? '' : day),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: sk.hair))),
          child: Row(children: [
            dateTile(day),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                m.Text(has ? '${_or(d['in'])} – ${_or(d['out'])}' : tr(_names[code] ?? code), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink)),
                m.Text([if (mins != null) _span(mins), if (late(d)) _t('late ${d['late_min']} min', 'उशीर ${d['late_min']} मि'), if ('${d['place'] ?? ''}'.isNotEmpty) '${d['place']}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: sk.muted)),
              ]),
            ),
            if (code.isNotEmpty) chip(tr(_names[code] ?? code), lk.$1, lk.$2),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: hrHead(context,
          sky: kDaySky,
          title: widget.embedded ? 'Attendance' : 'This month',
          mr: widget.embedded ? 'हजेरी' : 'हा महिना',
          back: !widget.embedded,
          height: 64,
          pill: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: sk.classic ? Colors.white.withValues(alpha: .22) : sk.headGlass, borderRadius: BorderRadius.circular(14), border: sk.classic ? null : Border.all(color: sk.headGlassLine)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              arrow('att-m-prev', Icons.chevron_left_rounded, -1),
              m.Text(monthName(month), key: const Key('att-m-name'), maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sk.onHead)),
              arrow('att-m-next', Icons.chevron_right_rounded, 1),
            ]),
          )),
      body: ListView(key: const Key('att-month-page'), padding: EdgeInsets.fromLTRB(16, 6, 16, 40 + MediaQuery.paddingOf(context).bottom), children: [ // (3.154.0: its end stands clear of the bar that floats over the page)
        if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (err.isNotEmpty) InfoLine(err, bad: true, help: false),
        if (!loading && err.isEmpty) ...[
          leaveHero(
            key: const Key('att-hero'),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                if (pct != null) ...[
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(width: 84, height: 84, child: CircularProgressIndicator(value: pct, strokeWidth: 8, strokeCap: StrokeCap.round, backgroundColor: const Color(0x24FFFFFF), color: const Color(0xFFF2CC62))),
                      m.Text('${(pct * 100).round()}%', key: const Key('att-m-pct'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    if (widget.who.isNotEmpty) m.Text(widget.who, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE))),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBEBB5), Color(0xFFE6B94E), Color(0xFFB8860B)], stops: <double>[0, .6, 1]).createShader(r),
                        child: m.Text(paid == null ? '${days.length}' : (paid == paid.roundToDouble() ? '${paid.round()}' : '$paid'), key: const Key('att-m-paid'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                      ),
                      const SizedBox(width: 7),
                      const Text('days', mr: 'दिवस', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE))),
                    ]),
                    if (total.isNotEmpty)
                      Text(month == now.substring(0, 7) ? _t('of $work working days so far', 'आतापर्यंतच्या $work कामाच्या दिवसांपैकी') : _t('of $work working days', '$work कामाच्या दिवसांपैकी'),
                          key: const Key('att-m-work'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFF3D889)))
                    else
                      Text(_t('Days with a punch: ${days.length}', 'हजेरीचे दिवस: ${days.length}'), key: const Key('att-m-count'), maxLines: 1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFF3D889))),
                  ]),
                ),
              ]),
              if (total.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  key: const Key('att-m-total'),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                  decoration: BoxDecoration(color: const Color(0x17FFFFFF), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0x29FFFFFF))),
                  child: Row(children: [
                    stat('P', 'Present', 'हजर', total['P'], const Color(0xFF7BE3A7)),
                    bar(),
                    stat('HD', 'Half day', 'अर्धा दिवस', total['HD'], const Color(0xFFF7DE8E)),
                    bar(),
                    stat('A', 'Absent', 'गैरहजर', total['A'], const Color(0xFFFF9A92)),
                    bar(),
                    stat('L', 'Leave', 'रजा', total['L'], const Color(0xFFC9B6FF)),
                  ]),
                ),
              ],
            ]),
          ),
          if (days.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              tile('late', Icons.timer_outlined, '$lates', 'Late days', 'उशिराचे दिवस'),
              const SizedBox(width: 10),
              tile('in', Icons.login_rounded, avgIn == null ? '–' : '${(avgIn ~/ 60).toString().padLeft(2, '0')}:${(avgIn % 60).toString().padLeft(2, '0')}', 'Average in', 'सरासरी IN'),
              const SizedBox(width: 10),
              tile('hours', Icons.schedule_rounded, '${sum ~/ 60} h', 'Worked', 'काम केले'),
            ]),
          ],
          Container(
            margin: const EdgeInsets.only(top: 14, bottom: 12),
            padding: const EdgeInsets.all(5),
            decoration: sk.box(radius: 99),
            child: Row(children: [seg(0, 'cal', Icons.calendar_month_outlined, 'Calendar', 'Calendar'), seg(1, 'list', Icons.format_list_bulleted_rounded, 'Day list', 'दिवसांची यादी')]),
          ),
          if (view == 0) ...[
            hrCard(padding: const EdgeInsets.fromLTRB(8, 14, 8, 12), [
              Row(children: [for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Expanded(child: Center(child: m.Text(w, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sk.faint))))]),
              const SizedBox(height: 6),
              for (var r = 0; r < cells.length; r += 7) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [for (var c = r; c < r + 7; c++) Expanded(child: cells[c])])),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Wrap(spacing: 12, runSpacing: 5, children: [
                  for (final (c, en, mr) in const [('P', 'Present', 'हजर'), ('HD', 'Half day', 'अर्धा दिवस'), ('A', 'Absent', 'गैरहजर'), ('L', 'Leave', 'रजा'), ('WO', 'Week off', 'साप्ताहिक सुट्टी')]) leg(_look(c).$1, en, mr),
                  leg(const Color(0xFF3D7BE0), 'Holiday', 'Holiday'),
                  leg(const Color(0xFFE6A417), 'Late', 'उशीर'),
                ]),
              ),
            ]),
            if (days.isEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Center(child: Text(_t('No punch in this month.', 'या महिन्यात हजेरी नाही.'), style: TextStyle(color: sk.faint)))),
            if (open != null) ...[const SizedBox(height: 12), dayCard(open)] else if (days.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(6, 10, 6, 0), child: Text(_t('Touch a day to open it.', 'दिवसावर touch करा.'), style: TextStyle(fontSize: 12.5, color: sk.muted))),
          ] else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [pick('', 'All', 'सर्व'), pick('P', 'Present', 'हजर'), pick('A', 'Absent', 'गैरहजर'), pick('HD', 'Half day', 'अर्धा दिवस'), pick('L', 'Leave', 'रजा'), pick('late', 'Late', 'उशीर')]),
            ),
            const SizedBox(height: 12),
            if (open != null) ...[dayCard(open), const SizedBox(height: 12)],
            hrCard(key: const Key('att-list'), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), [
              if (listed.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(days.isEmpty ? _t('No punch in this month.', 'या महिन्यात हजेरी नाही.') : _t('No such day in this month.', 'या महिन्यात असा दिवस नाही.'), style: TextStyle(fontSize: 13.5, color: sk.faint))),
              for (final (i, d) in listed.indexed) row(d, i == listed.length - 1),
            ]),
          ],
          if (every.isNotEmpty) ...[
            const SizedBox(height: 14),
            hrButton('Download PDF – ${monthName(month)}', 'PDF घ्या – ${monthName(month)}', key: const Key('att-m-pdf'), busy: making, onTap: _pdf),
          ],
          if (widget.embedded) ...[
            const SizedBox(height: 12),
            GestureDetector(
              key: const Key('att-m-reqs'),
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await Navigator.of(context).push(hrRoute<void>(AttendRegsScreen(ask: widget.ask)));
                if (mounted) _load();
              },
              child: hrCard(padding: const EdgeInsets.fromLTRB(16, 12, 10, 12), [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('Regularization', mr: 'Regularization', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink)),
                      Text('Forgot IN or OUT – what I asked and what waits for me', mr: 'IN किंवा OUT राहिले – मी मागितलेले आणि माझ्याकडे आलेले', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.3)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 22, color: sk.blankInk),
                ]),
              ]),
            ),
          ],
        ],
      ]),
    );
  }

  static const _weekFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
    // (3.114.0) in the attendance app: the page of the look, the gold disc for IN and the red one for OUT
    final old = sk.classic, on = old ? Colors.white : sk.ink;
    return Scaffold(
      body: Container(
        key: const Key('att-ok-page'),
        width: double.infinity,
        decoration: BoxDecoration(gradient: old ? skyDown(sky) : sk.pageFill),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              old ? SunDisc(size: 168, tick: true, moon: !inn) : MarkDisc(size: 168, tick: true, out: !inn),
              const SizedBox(height: 30),
              Text(inn ? bi('IN marked', 'हजेरी लागली') : bi('OUT marked', 'OUT लागले'), textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: on)),
              const SizedBox(height: 4),
              Text(widget.time, key: const Key('att-ok-time'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 54, fontWeight: FontWeight.w800, color: on, height: 1.1)),
              if (widget.place.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(widget.place, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, color: old ? Colors.white.withValues(alpha: .92) : sk.muted))),
              const SizedBox(height: 34),
              FilledButton(
                key: const Key('att-ok'),
                style: FilledButton.styleFrom(backgroundColor: old ? Colors.white : sk.accent, foregroundColor: old ? skyInk(sky) : sk.onAccent, minimumSize: const Size(160, 52), shape: const StadiumBorder()),
                onPressed: _close,
                child: Text('OK', mr: 'ठीक आहे', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: old ? skyInk(sky) : sk.onAccent)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
