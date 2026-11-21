/* THE APP OF A PERSON WITH HR ONLY (3.108.0 – asked 12-11-2026: "home screen new deesign kr non erp user sathi … me madhe
 * employee details astil document upload astil salary slips", and the eight screens he sent back: "mala same as it is screen
 * hawe aahet"). Nobody gave him Mechanical at this site: the app is his attendance –
 *   Home        – good morning, his day in the sky (on duty since …) with "Slide to mark IN / OUT", this week, four tiles
 *                 (Leave, Requests, Documents, Salary slip) and "For you": what waits for him or of him
 *   Attendance  – My attendance (screens/attendance.dart – the same page as everybody's)
 *   Leave       – screens/leave.dart
 *   Me          – who he is, how complete his profile is; my details, my documents, salary slips, my phone; the language,
 *                 e-mail and password, sign out (screens/hr_me.dart)
 * The bar at the bottom: Home · Attendance · Leave · Me (Attendance and Leave open as pages with their own way back).
 * Everything is asked of the HR server (rcl-hr) with his "My HR" sign-in; nothing of Mechanical is asked here.
 * (3.114.0 – the two looks he approved on 12-11-2026: "ok he final 2 ni thew user je haw te switch kru shakel") "Pearl" and
 * "Midnight Gold" (ui/hr_skin.dart; chosen in Me → Look):
 *   Home – THE DIAL: his shift as a ring from its start to its end, a dot where "now" stands, red from his IN once he is at
 *          work; the disc in its middle marks (gold IN, red OUT – a touch or a hold opens the same marking page as before:
 *          his place, the selfie, the punch); IN · OUT · Hours; this week; the four tiles; "For you" – also his papers that
 *          run out within 30 days, his birthday and his years at work (rcl-hr "coming")
 *   the bar – floats, on all four pages: Home · Attendance · (the marking button, raised in its middle) · Leave · Me.
 *          Attendance and Leave are pages of the bar now (no way back needed); the pages behind them open as before.
 * Nothing of what may be done changes – only how it looks. */
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/api.dart' show ApiError;
import '../core/app_consent.dart';
import '../core/attend.dart';
import '../core/attend_remind.dart';
import '../core/hr_cache.dart';
import '../core/hr_track.dart';
import '../core/session.dart';
import '../core/update.dart' show checkUpdate, offerUpdate, updateOfferAgain;
import '../ui/attend_look.dart';
import '../ui/done_pop.dart';
import '../ui/hr_look.dart';
import '../ui/home_dial.dart';
import '../ui/hr_skin.dart';
import '../ui/motion.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/widgets.dart';
import 'attend_reqs.dart';
import 'attendance.dart';
import 'hr_me.dart';
import 'hr_places.dart';
import 'leave.dart';

String _t(String en, String mr) => Lang.i.pair(en, mr);

/// His HR sign-in of his HR site (this site, or – 3.141.0 – the site of his own HR: Head Office for an HO employee in VTR's ERP),
/// for the pages opened from here.
Future<Map<String, dynamic>> hrCall(BuildContext context, Map<String, dynamic> body) => hrAsk(SessionScope.read(context), body);

/// (3.149.0) the same with the session itself – for what goes on after the page is closed (his location for HR while on duty).
Future<Map<String, dynamic>> hrAsk(Session s, Map<String, dynamic> body) {
  final h = hrSite(s), mod = hrModule(s);
  if (h == null || mod == null) throw StateError('none');
  return s.api.hr(h.code, mod.url, mod.key, body);
}

/// The first letters of a name ("Babu Demo" → BD).
String initials(String name) {
  final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (w.isEmpty) return '?';
  return (w.first.substring(0, 1) + (w.length > 1 ? w[1].substring(0, 1) : '')).toUpperCase();
}

class HrShell extends StatefulWidget {
  const HrShell({super.key, this.inErp = false});

  /// (3.115.0, his word of 13-11-2026: a person with the ERP and attendance sees "same view as it is … jasa normal attendace
  /// user cha ahe") opened from the full app's Home: the same four pages over the ERP, with the way back to it; the look's
  /// theme is around this page only (hrRoute) and what belongs to the whole app (e-mail and password, update, site, sign
  /// out) stays in the ERP's own Me.
  final bool inErp;
  @override
  State<HrShell> createState() => _HrShellState();
}

/// One line of "For you".
class _Note {
  const _Note(this.key, this.icon, this.c, this.soft, this.title, this.sub, this.go, this.onTap);
  final String key, title, sub, go;
  final IconData icon;
  final Color c, soft;
  final VoidCallback? onTap;
}

int? _hm(Object? v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${v ?? ''}');
  if (m == null) return null;
  final h = int.parse(m.group(1)!), n = int.parse(m.group(2)!);
  return h < 24 && n < 60 ? h * 60 + n : null;
}

/// "8 h 05 m" from [a] to [b] (HH:mm; past midnight when b is before a); '' when it cannot be said.
String _span(String a, String b) {
  final x = _hm(a), y = _hm(b);
  if (x == null || y == null) return '';
  final d = y >= x ? y - x : y + 1440 - x;
  return '${d ~/ 60} h ${(d % 60).toString().padLeft(2, '0')} m';
}

class _HrShellState extends State<HrShell> with WidgetsBindingObserver {
  int tab = 0; // 0 Home · 1 Attendance · 2 Leave · 3 Me
  int gen = 0; // (the Attendance and Leave pages of the bar are read again after a punch)
  Map<String, dynamic>? day, month, leave, mine; // myAttend, myMonth, myLeave, myHr
  List<Map> regs = [];
  int teamWait = 0;
  String err = '';
  bool loading = true, started = false, opening = false;
  Timer? minute, gps;
  bool _gpsAsked = false; // (the box "Location is off" is shown once; the place's chip asks again)

  // (3.153.0, "ek live watch asel digital je server la connect asel timing sathi") THE SERVER'S CLOCK: its time at the last
  // reading (myAttend's `now`), kept going by the phone since then. Home's clock, the ring's "now" and the hours at work use it –
  // a phone whose own clock is wrong still shows the right time. (No reading yet: the phone's clock.)
  int? _srv;
  int _srvAt = 0;
  int _nowMs() => _srv == null ? AttendKit.kit.now() : _srv! + (AttendKit.kit.now() - _srvAt);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // (3.114.0) the attendance app has its own look – the one he chose on this phone
    HrSkin.i.addListener(_skin);
    unawaited(widget.inErp ? HrSkin.i.load() : HrSkin.i.enter());
    // (3.122.0) the attendance app by itself asks for the newest version too – (3.145.0) offered: "Update to …?" (Update / Close)
    // once in every opening, never a screen that stops the work (core/update.dart offerUpdate)
    if (!widget.inErp) {
      void offer() {
        if (!mounted) return;
        final s = SessionScope.read(context);
        checkUpdate(s.api, beta: s.tester).then((u) {
          if (mounted) unawaited(offerUpdate(context, u));
        });
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => offer());
      updateOfferAgain = offer;
    }
    // (3.117.0, "app chalu kel kel lagech app fetch krel user location") his place is read at once and kept young while Home
    // is on the screen – IN / OUT need not wait for it; the phone's location off: asked to switch it on, here
    AttendWhere.i.addListener(_skin);
    unawaited(_place());
    gps = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && tab == 0 && !opening && AttendWhere.i.problem != 'off') AttendWhere.i.read();
    });
    // on duty: the hours since IN and the dial's dot move on by themselves
    minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _skin() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HrSkin.i.removeListener(_skin);
    if (!widget.inErp) HrSkin.i.leave();
    AttendWhere.i.removeListener(_skin);
    AttendWhere.i.clear();
    gps?.cancel();
    minute?.cancel();
    _later?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) unawaited(_place()); // (back from the phone's settings: read again)
    if (state == AppLifecycleState.resumed && mounted && !loading) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<Map<String, dynamic>> _hr(Map<String, dynamic> body) => hrCall(context, body);

  /// His place, read now; the phone's location switched off: he is asked – once – to switch it on.
  Future<void> _place() async {
    await AttendWhere.i.read();
    if (!mounted || AttendWhere.i.problem != 'off' || _gpsAsked) return;
    _gpsAsked = true;
    await _gpsAsk();
  }

  // (3.149.0, rcl-hr step 20 – his decision of 20-11-2026: "user la samjle nahi pahije ki tyachi location track keli jatey … app
  // madhe he samjnarach nahi … fkt ho hr and super admin la web warun disel") NOTHING of the location is shown in the app: no box,
  // no card on any page. The employee does not learn it from the app or from his "My HR" on the web. Only the HO HR / the Super
  // Admin see it, on the web. (The phone's own foreground notification / iOS indicator cannot be removed – the system shows it –
  // so its words are made plain "Attendance", with no mention of HR or sharing: lib/core/hr_track.dart.)

  /// "Location is off": one press switches it on in the app (Android's own box); else the phone's settings open.
  Future<void> _gpsAsk() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('gps-ask'),
        icon: Icon(Icons.location_off_rounded, size: 34, color: sk.tint(const Color(0xFFC22A1B), const Color(0xFFFFE6E3)).$1),
        title: Text('Location is off', mr: 'Location बंद आहे', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: sk.ink)),
        content: Text('Attendance is marked only inside your work place – the location of the phone must be on.', mr: 'हजेरी फक्त तुमच्या work place च्या आत लागते – phone चे location चालू हवे.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, height: 1.4, color: sk.muted)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(key: const Key('gps-later'), onPressed: () => Navigator.of(c).pop(false), child: Text('Not now', mr: 'आत्ता नाही', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sk.muted))),
          FilledButton(key: const Key('gps-on'), style: FilledButton.styleFrom(minimumSize: const Size(170, 48), backgroundColor: sk.accent, foregroundColor: sk.onAccent), onPressed: () => Navigator.of(c).pop(true), child: Text('Turn on location', mr: 'Location चालू करा', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sk.onAccent))),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await AttendKit.kit.gpsTurnOn();
    await AttendWhere.i.read();
  }

  /// (3.117.0, "jyala ji site ahe te name … location fetch zal ki te name green … match nahi zali tr te red") WHERE HE STANDS,
  /// on Home: his work place in green when the phone is inside it; in red with the metres when it is outside, when the
  /// location is off or could not be read. A press reads again (location off: asks to switch it on).
  Widget _placeChip() {
    final w = AttendWhere.i, places = [for (final x in (day?['places'] as List? ?? const [])) WorkPlace.fromJson(x)].whereType<WorkPlace>().toList();
    final f = w.fix, hit = f == null || places.isEmpty ? null : nearestPlace(places, f.lat, f.lng);
    final (String text, bool? ok) = w.problem == 'off'
        ? (_t('Location is off – turn on', 'Location बंद – चालू करा'), false)
        : places.isEmpty
            ? (_t('No work place for you', 'तुमच्यासाठी work place नाही'), false)
            : hit != null
                ? (hit.inside ? hit.place.name : _t('${hit.place.name} · ${hit.distance} m away', '${hit.place.name} · ${hit.distance} m दूर'), hit.inside)
                : w.busy || w.problem.isEmpty
                    ? (_t('Finding your place…', 'जागा शोधत आहे…'), null)
                    : (_t('Location not found – tap', 'Location मिळाले नाही – दाबा'), false);
    final (Color ink, Color bg) = ok == null ? (sk.muted, sk.blank) : ok ? sk.tint(const Color(0xFF146C2E), const Color(0xFFDDF3E4)) : sk.tint(const Color(0xFFC22A1B), const Color(0xFFFFE6E3));
    return GestureDetector(
      key: const Key('hh-place'),
      behavior: HitTestBehavior.opaque,
      onTap: () => w.problem == 'off' ? _gpsAsk() : w.read(),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok == null ? Icons.my_location_rounded : ok ? Icons.location_on_rounded : Icons.location_off_rounded, size: 14, color: ink),
          const SizedBox(width: 4),
          Flexible(child: m.Text(text, key: const Key('hh-place-text'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink))),
        ]),
      ),
    );
  }

  // each part by itself: a part the server does not have yet (a step not run) is simply not shown
  Future<Map<String, dynamic>?> _quiet(Map<String, dynamic> body) async {
    try {
      return await _hr(body);
    } catch (_) {
      return null;
    }
  }

  /// The five parts of Home under his day, put on the page (an answer of the server, or what was kept of it).
  void _parts(List<Map<String, dynamic>?> got) {
    month = got[0] ?? month;
    leave = got[1] ?? leave;
    if (got[2] != null) regs = [for (final x in (got[2]!['rows'] as List? ?? const []).whereType<Map>()) x];
    mine = got[3] ?? mine;
    if (got[4] != null) teamWait = (got[4]!['rows'] as List? ?? const []).length;
  }

  static const _kept = ['myMonth', 'myLeave', 'myRegs', 'myHr', 'teamRegs'];

  /// (3.157.0, asked 21-11-2026 with his picture of Home under "The server did not answer in time": "as sarkhe hote, he nahi aale
  /// pahije") ONE reading at a time: Home is read when it opens, when the app comes back, after every page and every tab – on a
  /// slow network these piled up, each waiting its own 40 seconds. A reading asked for while one is on its way waits for that
  /// one and is then done once more (so what was just changed is read).
  Future<void>? _reading;
  bool _again = false;
  int _tries = 0;
  bool _byHand = false;
  Timer? _later;
  Future<void> _load() {
    if (_reading != null) {
      _again = true;
      return _reading!;
    }
    return _reading = () async {
      try {
        do {
          _again = false;
          await _loadNow();
        } while (_again && mounted);
      } finally {
        _reading = null;
      }
    }();
  }

  Future<void> _loadNow() async {
    final s = SessionScope.read(context);
    // (3.154.0, asked 21-11-2026: "cache data dakhwel … new lagech disel") the first time: what was read the last time is shown
    // at once – his day only when it is TODAY's (never yesterday's IN / OUT as today's) – while the server is asked
    HrCache.who = '${s.email}|${hrSite(s)?.code ?? ''}';
    if (day == null) {
      final now = indiaDay(AttendKit.kit.now());
      final k = await HrCache.read('myAttend'), parts = [await HrCache.read('myMonth:${now.substring(0, 7)}'), for (final a in _kept.skip(1)) await HrCache.read(a)];
      if (!mounted) return;
      if (day == null && k != null && '${k['day'] ?? ''}' == now) {
        setState(() {
          day = k;
          loading = false;
          _parts(parts);
        });
      }
    }
    try {
      final info = await AttendKit.kit.info();
      final d = await _hr({'action': 'myAttend', 'device_id': info['id']});
      HrCache.put('myAttend', d);
      await AttendStore('${s.email}|${hrSite(s)?.code ?? ''}').keep(d, await AttendKit.kit.elapsed());
      unawaited(AttendRemind.set(d)); // (3.113.0) the IN / OUT reminders, from his shift and where his day stands
      if (!mounted) return;
      setState(() {
        day = d;
        _srv = d['now'] is num ? (d['now'] as num).toInt() : null;
        _srvAt = AttendKit.kit.now();
        loading = false;
        err = '';
      });
      _tries = 0;
      _byHand = false;
      // (3.149.0, rcl-hr step 20) his place shared with HR while on duty (IN → OUT) – HR's server says when; after every IN / OUT
      // and whenever Home is opened. Nothing is shown in the app (his decision of 20-11-2026): the start is silent.
      if (AppConsent.ok(s)) unawaited(HrTrack.i.sync((b) => hrAsk(s, b)));      // (20-11-2026) only with the app's location notice allowed
    } catch (e) {
      if (!mounted) return;
      // (3.157.0) his day is on the page (what was read before) and only the network did not answer: nothing red is shown – it
      // is tried again by itself, quietly, a few times; pulling the page down reads at once. Anything else the server says
      // (and a page with nothing to show) is said as before.
      final net = e is ApiError && e.code == 'net' && day != null && !_byHand;
      _byHand = false;
      setState(() {
        loading = false;
        err = net ? '' : e is StateError ? 'You have no HR on this site – the Super Admin gives it in the Portal.' : errText(e);
      });
      if (net && _tries < 3) {
        _tries++;
        _later?.cancel();
        _later = Timer(const Duration(seconds: 8), () {
          if (mounted) _load();
        });
      }
      return;
    }
    final today = '${day?['day'] ?? indiaDay(AttendKit.kit.now())}';
    final got = await Future.wait([_quiet({'action': 'myMonth', 'month': today.substring(0, 7)}), _quiet({'action': 'myLeave'}), _quiet({'action': 'myRegs'}), _quiet({'action': 'myHr'}), _quiet({'action': 'teamRegs'})]);
    // (what the server said is kept for the next opening; a part it could not say stays as it was shown)
    if (got[0] != null) HrCache.put('myMonth:${today.substring(0, 7)}', got[0]!);
    for (var i = 1; i < _kept.length; i++) {
      if (got[i] != null) HrCache.put(_kept[i], got[i]!);
    }
    if (!mounted) return;
    setState(() {
      // (a part that could not be read stays as it was shown – nothing blinks away)
      month = got[0] ?? month;
      leave = got[1] ?? leave;
      if (got[2] != null) regs = [for (final x in (got[2]!['rows'] as List? ?? const []).whereType<Map>()) x];
      mine = got[3] ?? mine;
      if (got[4] != null) teamWait = (got[4]!['rows'] as List? ?? const []).length;
    });
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(hrRoute<void>(page));
    if (mounted) _load();
  }

  /// A page of the bar. Home and Me are read again (a leave asked for, a paper attached on another page).
  void _go(int t) {
    if (t == tab) return;
    setState(() => tab = t);
    if (t == 0 || t == 3) _load();
  }

  /// The marking page – from the dial and from the bar's middle button: his place, the selfie, the punch (as it always was).
  Future<void> _mark() async {
    if (opening) return;
    opening = true;
    // (3.153.0, asked 20-11-2026: "sign out krtana confirmation gheil kharach sign out kraych aahe ka karan kahi lokanche chukun
    // sign out hot") before OUT he is asked once; IN goes straight on
    if (day != null && _punches.isNotEmpty && _next == 'out' && !await _askOut()) {
      opening = false;
      return;
    }
    if (!mounted) {
      opening = false;
      return;
    }
    await Navigator.of(context).push(hrRoute<void>(const AttendanceScreen(quick: true, auto: true)));
    opening = false;
    if (!mounted) return;
    setState(() => gen++);
    _load();
  }

  String get _who => '${(day?['employee'] as Map?)?['name'] ?? SessionScope.read(context).name} · ${(day?['employee'] as Map?)?['code'] ?? ''}';
  void _requests() => _push(AttendRegsScreen(ask: _hr));
  void _notices() => _push(MyNoticesScreen(ask: _hr)); // (3.153.0) the bell: his notifications only
  void _places() => _push(MyPlacesScreen(ask: _hr));
  void _docs() => _push(MyDocsScreen(ask: _hr));
  void _slips() => _push(SalarySlipsScreen(ask: _hr));
  Future<bool> _photo() async {
    final ok = await setMyPhoto(context, _hr);
    if (ok && mounted) await _load();
    return ok;
  }

  /// "Do you really want to sign out?" – No (stays on duty) is the big button; true only on "Yes, sign out".
  Future<bool> _askOut() async {
    final shift = day?['shift'] is Map ? day!['shift'] as Map : const {};
    var lastIn = '';
    for (final p in _punches) {
      if (p['kind'] == 'in') lastIn = '${p['time'] ?? ''}';
    }
    final worked = sinceText(lastIn, DateTime.fromMillisecondsSinceEpoch(_nowMs())), end = '${shift['end'] ?? ''}';
    final (Color red, Color redSoft) = sk.tint(const Color(0xFFC22A1B), const Color(0xFFFFE9E5));
    final yes = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: sk.card,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          key: const Key('so-ask'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 60, height: 60, alignment: Alignment.center, decoration: BoxDecoration(color: redSoft, borderRadius: BorderRadius.circular(20)), child: Icon(Icons.logout_rounded, size: 28, color: red)),
            const SizedBox(height: 14),
            Text('Do you really want to punch out?', mr: 'खरंच punch out करायचं आहे का?', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: sk.ink)),
            const SizedBox(height: 8),
            m.Text([if (worked.isNotEmpty) _t('You have worked $worked.', 'तुम्ही $worked काम केलं आहे.'), if (end.isNotEmpty) _t('Your shift ends at $end.', 'तुमची shift $end ला संपते.')].join(' '), key: const Key('so-text'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, height: 1.45, color: sk.muted)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, height: 54, child: FilledButton(key: const Key('so-no'), style: FilledButton.styleFrom(backgroundColor: sk.accent, foregroundColor: sk.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: () => Navigator.of(c).pop(false), child: Text('No, stay on duty', mr: 'नाही, कामावर आहे', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: sk.onAccent)))),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 54, child: OutlinedButton(key: const Key('so-yes'), style: OutlinedButton.styleFrom(foregroundColor: red, side: BorderSide(color: red, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), onPressed: () => Navigator.of(c).pop(true), child: Text('Yes, punch out', mr: 'हो, punch out करा', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: red)))),
          ]),
        ),
      ),
    );
    return yes == true;
  }

  List<Map> get _punches => [for (final x in (day?['punches'] as List? ?? const []).whereType<Map>()) x];

  /// 'in' or 'out' – what the next punch is (the colour of the marking button).
  String get _next => _punches.isEmpty ? 'in' : ('${day?['next'] ?? 'in'}' == 'out' ? 'out' : 'in');

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    LangScope.of(context); // the words here follow the language chosen in Me
    return Scaffold(
      backgroundColor: sk.bg,
      // (3.154.0, asked 21-11-2026: "pill shape tr aahech but tyache bajun square box zalay tr tas nay zal pahije") the page goes on
      // UNDER the bar – only the pill itself is there, nothing square round it; every page's list ends clear of it
      extendBody: true,
      bottomNavigationBar: _nav(),
      body: Builder(builder: (context) {
        final under = MediaQuery.paddingOf(context).bottom; // (the bar's own height: a list's last line stands above it)
        return TabSlide(
        index: tab, // (3.122.0) the page of the tab chosen slides in from that tab's side
        child: switch (tab) {
        // (3.116.0, "ek feture ekach thikani asaw") Attendance = the month; today and marking are Home's
        1 => AttendMonthScreen(key: ValueKey('tab-att-$gen'), ask: _hr, who: _who, embedded: true),
        2 => LeaveScreen(key: ValueKey('tab-leave-$gen'), ask: _hr, embedded: true),
        3 => HrMeTab(key: const Key('hr-me'), mine: mine, day: day, ask: _hr, onDocs: _docs, onPhoto: _photo, reload: _load, inErp: widget.inErp),
        _ => Container(
            decoration: BoxDecoration(gradient: sk.pageFill),
            child: SafeArea(
              bottom: false,
              // (3.154.0, asked 21-11-2026: "home screen khali scroll krtana warche te name notification bell as nigun jatey te jau
              // naye") his name and the bell STAY at the top; the page moves under them
              child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 10), child: _top(s)),
              Expanded(child: RefreshIndicator(
                // (pulled down by hand: what the network says is told)
                onRefresh: () {
                  _byHand = true;
                  return _load();
                },
                child: ListView(key: const Key('hr-home'), padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + under), children: [
                  if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('hh-err')),
                  if (loading) Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: sk.accent))),
                  if (day != null) ...[
                    // (3.122.0) the parts of Home come up one after the other
                    // (3.153.0) the Home he approved on 20-11-2026: who he is → the dial → his work locations → this week → the tiles
                    Rise(order: 0, child: _idCard()),
                    const SizedBox(height: 12),
                    Rise(order: 1, child: _hero(s)),
                    ..._placesCard(),
                    const SizedBox(height: 16),
                    Rise(order: 2, child: _week()),
                    const SizedBox(height: 14),
                    Rise(order: 3, child: _tiles()),
                    ..._forYou(),
                  ],
                ]),
              )),
              ]),
            ),
          ),
      },
      );
      }),
    );
  }

  // ---- "Good afternoon, Babu Demo" and the bell (red dot: something waits)
  Widget _top(Session s) {
    final h = DateTime.fromMillisecondsSinceEpoch(_nowMs() + 19800000, isUtc: true).hour;
    final name = '${(day?['employee'] as Map?)?['name'] ?? s.name}', un = (mine?['notices'] as Map?)?['unread'], wait = un is num && un > 0; // (the red dot: a notification not seen yet)
    return Row(children: [
      if (widget.inErp) Padding(padding: const EdgeInsets.only(right: 10), child: hrIconBox(Icons.arrow_back_ios_new_rounded, key: const Key('hh-back'), size: 40, icon: 17, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onTap: () => Navigator.of(context).maybePop())),
      hrFace(name, '${mine?['photo'] ?? ''}', size: 48, radius: 24, bg: sk.dark ? sk.card : const Color(0xFF0F1F3D), border: const Color(0xFFDDAD40), ink: sk.dark ? sk.accent : Colors.white),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening', mr: h < 12 ? 'शुभ सकाळ' : h < 17 ? 'शुभ दुपार' : 'शुभ संध्याकाळ', key: const Key('hh-hello'), style: TextStyle(fontSize: 13, color: sk.muted)),
          m.Text(name, key: const Key('hh-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: sk.ink)),
        ]),
      ),
      hrIconBox(Icons.notifications_none_rounded, key: const Key('hh-bell'), dot: wait, onTap: _notices),
    ]);
  }

  // ---- WHO HE IS: his code, his designation, the person he reports to (asked 20-11-2026: "employee code and designation pn
  //      disawa … reporting manager pn disel")
  Widget _idCard() {
    final e = (mine?['employee'] as Map?) ?? (day?['employee'] as Map?) ?? const {};
    final des = '${e['designation'] ?? ''}'.isNotEmpty ? '${e['designation']}' : switch ('${e['category'] ?? ''}') { 'staff' => 'Staff', 'operator' => 'Operator', 'driver' => 'Driver', 'labour' => 'Labour', _ => '' };
    Widget cell(String key, IconData icon, String en, String mr, String v, {bool first = false, int flex = 10}) => Expanded(
          flex: flex,
          child: Container(
            padding: EdgeInsets.only(left: first ? 0 : 10),
            decoration: BoxDecoration(border: first ? null : Border(left: BorderSide(color: sk.line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 15, color: sk.link)),
              const SizedBox(height: 7),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sk.muted))),
              const SizedBox(height: 2),
              // (a long designation is made a little smaller rather than cut)
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(v.isEmpty ? '–' : v, key: Key(key), maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: v.isEmpty ? sk.faint : sk.ink))),
            ]),
          ),
        );
    return Container(
      key: const Key('hh-id'),
      clipBehavior: Clip.antiAlias,
      decoration: sk.box(radius: 22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 3, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFC9960A), Color(0xFFF7DE8E), Color(0xFFC9960A)]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 12, 12),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              cell('hh-code', Icons.badge_outlined, 'Employee code', 'Employee code', '${e['code'] ?? ''}', first: true, flex: 9),
              cell('hh-desig', Icons.work_outline_rounded, 'Designation', 'पद', des),
              cell('hh-boss', Icons.person_outline_rounded, 'Reporting manager', 'Reporting manager', '${e['manager'] ?? ''}', flex: 11),
            ]),
          ),
        ),
      ]),
    );
  }

  // ---- THE DIAL: his shift as a ring with the hours on it, the disc that marks (the server's live clock, SIGN IN / SIGN OUT);
  //      Check in · Check out · Total working hours
  Widget _hero(Session s) {
    final punches = _punches, next = _next;
    // ('done' – the site's rule "once a day": nothing more today – reads as the day done)
    final stopped = day?['may'] == false || '${day?['phone'] ?? ''}' == 'other' || (day?['places'] as List? ?? const []).isEmpty;
    final sky = skyOf(any: punches.isNotEmpty, next: next, stopped: stopped);
    var tin = '', tout = '', lastIn = '';
    for (final p in punches) {
      if (p['kind'] == 'in' && tin.isEmpty) tin = '${p['time'] ?? ''}';
      if (p['kind'] == 'in') lastIn = '${p['time'] ?? ''}';
      if (p['kind'] == 'out') tout = '${p['time'] ?? ''}';
    }
    final nowMs = _nowMs(), india = DateTime.fromMillisecondsSinceEpoch(nowMs + 19800000, isUtc: true);
    final shift = day?['shift'] is Map ? day!['shift'] as Map : const {};
    final a = _hm(shift['start']), b0 = _hm(shift['end']);
    // where a time of the day stands on the ring (a night shift ends on the next day)
    double? at(int? t) {
      if (a == null || b0 == null || t == null) return null;
      final b = b0 > a ? b0 : b0 + 1440, x = t < a && b > 1440 ? t + 1440 : t;
      return ((x - a) / (b - a)).clamp(0.0, 1.0).toDouble();
    }

    final since = sky == Sky.day ? sinceText(lastIn, DateTime.fromMillisecondsSinceEpoch(nowMs)) : '';
    final closed = '${day?['closed'] ?? ''}'.isNotEmpty;
    final (String state, String big, String under) = switch (sky) {
      Sky.day => (_t('On duty since $lastIn', '$lastIn पासून कामावर'), 'PUNCH OUT', _t('Tap to mark', 'दाबा')), // (3.159.0, asked 21-11-2026: "sign in and sign out diste – tyache jagi punch in and punch out as banaw")
      Sky.dusk => closed
          ? (_t('Closed by itself – absent', 'आपोआप बंद – गैरहजर'), _t('ABSENT', 'गैरहजर'), _t('Regularize the day', 'Regularize करा'))
          : (_t('Today is done', 'आजची हजेरी पूर्ण'), _t('DONE', 'पूर्ण'), _t('See your month', 'महिना पहा')),
      Sky.grey => (_t('Cannot be marked', 'लावता येत नाही'), '–', _t('Open Attendance', 'Attendance उघडा')),
      _ => (_t('Not marked yet', 'अजून लावलेली नाही'), 'PUNCH IN', _t('Tap to mark', 'दाबा')),
    };
    final hours = sky == Sky.day ? since : _span(tin, tout);
    // the day done or stopped: the Attendance page says it all; else the marking page
    final VoidCallback go = sky == Sky.dusk || sky == Sky.grey ? () => _go(1) : _mark;
    Widget stat(String key, String v, String en, String mr, {int flex = 10}) => Expanded(
          flex: flex,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 5),
            decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(14)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(fit: BoxFit.scaleDown, child: m.Text(v.isEmpty ? '– –:– –' : v, key: Key(key), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: v.isEmpty ? sk.faint : sk.ink))),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: sk.muted))),
            ]),
          ),
        );
    return Container(
      key: const Key('hh-hero'),
      // (3.154.0, asked 21-11-2026: "sign out cha section … motha card zalay as feel yetey, tyachi size height madhe kami kr … check in
      // check out total work te sagle rahu de fkt thoda small banaw") the same card, lower: a smaller dial (the same on every
      // phone – it never grows past 256), less air round it; everything in it stays
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: sk.box(radius: 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(state, key: const Key('hh-big'), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink)))),
          const SizedBox(width: 8),
          _placeChip(),
        ]),
        const SizedBox(height: 2),
        LayoutBuilder(
          builder: (_, box) => GestureDetector(
            key: const Key('hh-slide'),
            behavior: HitTestBehavior.opaque,
            onTap: go,
            onLongPress: go,
            child: Bounce(to: .96, child: HomeDial(size: math.min(256.0, box.maxWidth), now: at(india.hour * 60 + india.minute), start: a, end: b0, dim: sky == Sky.grey || sky == Sky.dusk, clock: _nowMs, big: big, under: under, tone: sky == Sky.day ? 'out' : sky == Sky.dusk || sky == Sky.grey ? null : 'in')),
          ),
        ),
        if (a != null && b0 != null) m.Text('${shift['name'] ?? ''}', key: const Key('hh-shift'), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sk.faint)),
        const SizedBox(height: 8),
        Row(children: [stat('hh-in', tin, 'Check in', 'Check in'), const SizedBox(width: 8), stat('hh-out', tout, 'Check out', 'Check out'), const SizedBox(width: 8), stat('hh-hours', hours, 'Total working hours', 'एकूण कामाचे तास', flex: 13)]),
      ]),
    );
  }

  // ---- MY WORK LOCATIONS: a small map that stays still (a touch opens the big one), each place with where he stands
  List<Widget> _placesCard() {
    final places = shownPlaces([for (final x in (day?['places'] as List? ?? const [])) WorkPlace.fromJson(x)].whereType<WorkPlace>());
    if (places.isEmpty) return const [];
    final fix = AttendWhere.i.fix, hits = placeHits(places, fix);
    void big() => Navigator.of(context).push(hrRoute<void>(PlacesMapScreen(places: places)));
    return [
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(child: Text('My work locations', mr: 'माझी कामाची ठिकाणं', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink))),
          GestureDetector(key: const Key('hh-places'), behavior: HitTestBehavior.opaque, onTap: _places, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: m.Text(places.length == 1 ? _t('1 place', '1 ठिकाण') : _t('${places.length} places', '${places.length} ठिकाणं'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.link)))),
        ]),
      ),
      const SizedBox(height: 4),
      Container(
        key: const Key('hh-locs'),
        clipBehavior: Clip.antiAlias,
        decoration: sk.box(radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // the map of Home never moves: every touch on it opens the big map (so the page is never scrolled into the map)
          GestureDetector(
            key: const Key('hh-map-open'),
            behavior: HitTestBehavior.opaque,
            onTap: big,
            child: SizedBox(
              height: 150,
              child: Stack(children: [
                Positioned.fill(child: IgnorePointer(child: PlacesMap(places: places, fix: fix, live: false))),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: sk.accent, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6))]),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.open_in_full_rounded, size: 13, color: sk.onAccent),
                      const SizedBox(width: 6),
                      Text('Tap to open map', mr: 'Map उघडण्यासाठी दाबा', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sk.onAccent)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 14, 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < places.length; i++) placeRow(places[i], hits[places[i].id], first: i == 0)]),
          ),
        ]),
      ),
    ];
  }

  // ---- this week, Monday first (asked 20-11-2026: "this week madhe correction kr nit samajw … date ani kay aahe te nit samjaw"):
  //      the day, its date, what it counts as (the month's own letters) and the same in a word; today stands out
  Widget _week() {
    final today = '${day?['day'] ?? indiaDay(AttendKit.kit.now())}', t = DateTime.parse('${today}T00:00:00Z'), mon = t.subtract(Duration(days: t.weekday - 1));
    final by = <String, String>{for (final d in (month?['all'] as List? ?? const []).whereType<Map>()) '${d['day']}': '${d['code'] ?? ''}'};
    (Color, Color) look(String c) => switch (c) {
          'P' || 'WOP' || 'HP' || 'IN' => sk.tint(const Color(0xFF146C2E), const Color(0xFFDDF3E4)),
          'HD' => sk.tint(const Color(0xFF8A5A00), const Color(0xFFFFF3D1)),
          'A' || 'MIS' => sk.tint(const Color(0xFFC22A1B), const Color(0xFFFFE6E3)),
          'L' => sk.tint(kPurple, const Color(0xFFF1E8F6)),
          _ => (sk.muted, sk.blank),
        };
    String word(String c) => switch (c) {
          'P' => _t('Present', 'हजर'),
          'HD' => _t('Half day', 'अर्धा दिवस'),
          'A' => _t('Absent', 'गैरहजर'),
          'L' => _t('Leave', 'रजा'),
          'WO' => _t('Week off', 'सुट्टी'),
          'H' => _t('Holiday', 'सुट्टी'),
          'WOP' || 'HP' => _t('Worked', 'काम केले'),
          'IN' => _t('On duty', 'कामावर'),
          'MIS' => _t('No OUT', 'OUT नाही'),
          _ => '',
        };
    const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(child: Text('This week', mr: 'हा आठवडा', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink))),
          GestureDetector(key: const Key('hh-month'), behavior: HitTestBehavior.opaque, onTap: () => _go(1), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('My month', mr: 'माझा महिना', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.link)))),
        ]),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
        decoration: sk.box(radius: 22),
        child: Row(key: const Key('hh-week'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < 7; i++)
            () {
              final dt = mon.add(Duration(days: i)), d = dt.toIso8601String().substring(0, 10), c = by[d] ?? '', lk = look(c), now = d == today;
              final ink = now ? sk.onAccent : sk.ink, soft = now ? sk.onAccent.withValues(alpha: .78) : sk.faint;
              return Expanded(
                child: Rise(order: 2 + i, from: 14, child: Container(
                  key: Key('hh-w-$d'),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: now ? BoxDecoration(gradient: sk.dark ? Sk.goldFill : null, color: sk.dark ? null : sk.accent, borderRadius: BorderRadius.circular(14)) : null,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    m.Text(names[i], maxLines: 1, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .3, color: soft)),
                    const SizedBox(height: 2),
                    m.Text('${dt.day}', maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: c.isEmpty && !now ? sk.faint : ink)),
                    const SizedBox(height: 5),
                    Container(
                      constraints: const BoxConstraints(minWidth: 30),
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: now ? sk.onAccent.withValues(alpha: .16) : lk.$2, borderRadius: BorderRadius.circular(8)),
                      child: m.Text(c.isEmpty ? '–' : c == 'MIS' ? '!' : c, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: now ? ink : lk.$1)),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(fit: BoxFit.scaleDown, child: m.Text(word(c).isEmpty ? ' ' : word(c), maxLines: 1, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: now ? ink : c.isEmpty ? sk.faint : lk.$1))),
                  ]),
                )),
              );
            }(),
        ]),
      ),
    ]);
  }

  // ---- Leave · Requests · Documents · Salary slip
  Widget _tiles() {
    String n(Object? v) => v is num ? (v == v.roundToDouble() ? '${v.round()}' : '$v') : '';
    final left = leave == null ? '' : _t('${n(leave?['available'])} left', '${n(leave?['available'])} शिल्लक');
    final waiting = regs.where((q) => q['status'] == 'pending').length + teamWait;
    final miss = ((mine?['docs'] as Map?)?['missing'] as List? ?? const []).length;
    Widget tile(String key, IconData icon, Color c0, Color soft0, String en, String mr, String sub, VoidCallback onTap) {
      final (Color c, Color soft) = sk.tint(c0, soft0);
      return Expanded(
        child: GestureDetector(
          key: Key(key),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 11),
            decoration: sk.box(radius: 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: c)),
              const SizedBox(height: 7),
              FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sk.ink))),
              FittedBox(fit: BoxFit.scaleDown, child: m.Text(sub.isEmpty ? ' ' : sub, key: Key('$key-sub'), maxLines: 1, style: TextStyle(fontSize: 11, color: sk.muted))),
            ]),
          ),
        ),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tile('hh-leave', Icons.event_available_rounded, kPurple, const Color(0xFFF1E8F6), 'Leave', 'रजा', left, () => _go(2)),
      tile('hh-reqs', Icons.fact_check_outlined, const Color(0xFF8A5A00), const Color(0xFFFFF3D1), 'Regularization', 'Regularization', waiting > 0 ? _t('$waiting waiting', '$waiting प्रलंबित') : '', _requests),
      tile('hh-docs', Icons.description_outlined, const Color(0xFF0F7A45), const Color(0xFFE3F7EC), 'Documents', 'कागदपत्रे', mine == null ? '' : miss > 0 ? _t('$miss missing', '$miss बाकी') : _t('All there', 'सर्व आहेत'), _docs),
      tile('hh-slip', Icons.payments_outlined, const Color(0xFF0B5FA5), const Color(0xFFE3EEFB), 'Salary slip', 'पगार पावती', '', _slips),
    ]);
  }

  /// What waits: his leave not decided yet, a day gone that counts as absent and can still be asked for, his team's requests –
  /// and (3.114.0, rcl-hr "coming") a paper of his that runs out within 30 days, his birthday, his years at work today.
  List<_Note> _notes() {
    const blue = Color(0xFF0B5FA5), blueSoft = Color(0xFFE3EEFB), red = Color(0xFFC22A1B), redSoft = Color(0xFFFFE6E3), amber = Color(0xFF8A5A00), amberSoft = Color(0xFFFFF3D1);
    final out = <_Note>[];
    // (3.136.0, rcl-hr step 16) the seven-day rule: his papers due – held until they are there (first, in red)
    final dr = mine?['doc_rule'];
    if (dr is Map && (dr['missing'] as List? ?? const []).isNotEmpty) {
      final miss = (dr['missing'] as List).map((x) => tr('$x')).join(', '), due = dayName('${dr['due'] ?? ''}');
      out.add(_Note('hh-n-seven', Icons.assignment_late_outlined, red, redSoft,
          dr['blocked'] == true ? _t('Attach your papers – the app is held', 'तुमची कागदपत्रे जोडा – app थांबवलं आहे') : dr['late'] == true ? _t('Your papers were due by $due', 'तुमची कागदपत्रे $due पर्यंत हवी होती') : _t('Your papers are due by $due', 'तुमची कागदपत्रे $due पर्यंत द्यायची आहेत'),
          miss, _t('Attach', 'जोडा'), _docs));
    }
    for (final q in (leave?['requests'] as List? ?? const []).whereType<Map>()) {
      if (q['status'] == 'pending') out.add(_Note('hh-n-leave-${q['id']}', Icons.event_available_rounded, blue, blueSoft, _t('Leave on ${dayName('${q['from']}')}', '${dayName('${q['from']}')} ची रजा'), q['waits'] is Map ? leaveWaits(q) : _t('Waiting for approval', 'मंजुरीची वाट'),      // (3.147.0) who it waits for
           _t('See', 'पहा'), () => _go(2)));
    }
    final today = '${month?['today'] ?? ''}', back = month?['reg_days'] is num ? (month!['reg_days'] as num).toInt() : 0, t = DateTime.tryParse('${today}T00:00:00Z');
    final asked = {for (final q in regs) if (q['status'] == 'pending') '${q['day']}'};
    if (t != null && back > 0) {
      for (final d in (month?['all'] as List? ?? const []).whereType<Map>().toList().reversed) {
        final dd = DateTime.tryParse('${d['day']}T00:00:00Z');
        if (d['code'] != 'A' || dd == null || !dd.isBefore(t) || t.difference(dd).inDays > back || asked.contains('${d['day']}')) continue;
        out.add(_Note('hh-n-day-${d['day']}', Icons.error_outline_rounded, red, redSoft, _t('${dayName('${d['day']}')} has no punch', '${dayName('${d['day']}')} ला हजेरी नाही'), _t('Regularize it', 'Regularize करा'), _t('Regularize', 'Regularize'), () async {
          final ok = await askRegularize(context, _hr, '${d['day']}', code: 'A');
          if (!mounted) return;
          if (ok) donePop(context, _t('Request sent', 'विनंती पाठवली'), detail: _t('It counts when it is approved.', 'मंजूर झाल्यावर धरले जाईल.'));
          _load();
        }));
        break; // the newest such day; the others are in "This month"
      }
    }
    if (teamWait > 0) out.add(_Note('hh-n-team', Icons.groups_2_outlined, amber, amberSoft, _t('$teamWait of your team wait for you', 'तुमच्या टीमच्या $teamWait विनंत्या'), _t('Approve or refuse', 'मंजूर करा किंवा नाकारा'), _t('Open', 'उघडा'), _requests));
    final coming = (mine?['coming'] as Map?) ?? const {};
    for (final p in (coming['papers'] as List? ?? const []).whereType<Map>()) {
      final l = p['left'] is num ? (p['left'] as num).toInt() : 0;
      out.add(_Note('hh-n-paper-${out.length}', Icons.description_outlined, red, redSoft, tr('${p['paper'] ?? ''}'),
          l < 0 ? _t('ran out on ${dayName('${p['expires_on']}')}', '${dayName('${p['expires_on']}')} ला मुदत संपली') : l == 0 ? _t('runs out today', 'आज मुदत संपते') : _t('runs out in $l days', '$l दिवसांत मुदत संपते'), _t('Renew', 'नवीन जोडा'), _docs));
    }
    if (coming['birthday'] == true) out.add(_Note('hh-n-bday', Icons.cake_outlined, kPurple, const Color(0xFFF1E8F6), _t('Happy birthday!', 'वाढदिवसाच्या शुभेच्छा!'), _t('From all of us at work', 'आम्हा सर्वांकडून'), '', null));
    final yrs = coming['work_years'] is num ? (coming['work_years'] as num).toInt() : 0;
    if (yrs > 0) out.add(_Note('hh-n-years', Icons.workspace_premium_outlined, amber, amberSoft, _t('$yrs ${yrs == 1 ? 'year' : 'years'} with us today', 'आज आमच्यासोबत $yrs वर्षे'), _t('Thank you for your work', 'तुमच्या कामाबद्दल धन्यवाद'), '', null));
    return out;
  }

  List<Widget> _forYou() {
    final notes = _notes();
    if (notes.isEmpty) return const [];
    return [
      const SizedBox(height: 14),
      hrCard(key: const Key('hh-for'), [
        hrTitle('For you', 'तुमच्यासाठी'),
        for (final n in notes)
          () {
            final (Color c, Color soft) = sk.tint(n.c, n.soft);
            return GestureDetector(
              key: Key(n.key),
              behavior: HitTestBehavior.opaque,
              onTap: n.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: Icon(n.icon, size: 19, color: c)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      m.Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink)),
                      m.Text(n.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: sk.muted)),
                    ]),
                  ),
                  if (n.go.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)), child: m.Text(n.go, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c))),
                ]),
              ),
            );
          }(),
      ]),
    ];
  }

  // ---- THE BAR (3.153.0 – his choice of 20-11-2026: "s2 gheu ok soft gold … tab bar pn approved"): the page that is open sits
  //      in a well with a gold edge and a gold sign, and the well glides to the page chosen. Home · Attendance · Leave · Me –
  //      the marking button of the middle is gone (one thing in one place: SIGN IN / SIGN OUT is the dial's).
  //      (3.154.0, asked 21-11-2026: "pill shape ch – transparency ajun wadhaw premium feel hoil – size thodi kami kar") ONLY
  //      the pill: glass – the page shows through it, softened – a little smaller, nothing square round it.
  Widget _nav() {
    final dark = sk.dark;
    final glass = dark ? const Color(0x8C141A33) : const Color(0x99FFFFFF);
    final wellBg = dark ? const Color(0x730A0F22) : const Color(0x80E9EDF5);
    final gold = dark ? const Color(0xFFF2CC62) : const Color(0xFFC9960A), mute = dark ? const Color(0xFF8D96B8) : const Color(0xFF7E879D);
    Widget item(String key, IconData icon, String en, String mr, bool on, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            key: Key(key),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Bounce(to: .9, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedScale(scale: on ? 1.08 : 1, duration: const Duration(milliseconds: 320), curve: Curves.easeOutBack, child: Icon(icon, size: 21, color: on ? gold : mute)),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 10.5, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? sk.ink : mute))),
            ])),
          ),
        );
    const r = BorderRadius.all(Radius.circular(31));
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 4, 26, 10),
        child: Container(
          key: const Key('hr-nav'),
          height: 62,
          decoration: BoxDecoration(borderRadius: r, boxShadow: [BoxShadow(color: dark ? const Color(0x66000000) : const Color(0x29404C70), blurRadius: 22, spreadRadius: -6, offset: const Offset(0, 10))]),
          child: ClipRRect(
            borderRadius: r,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(borderRadius: r, color: glass, border: Border.all(color: dark ? const Color(0x38A9B8F0) : const Color(0xCCFFFFFF), width: 1.2)),
                child: Stack(children: [
                  // the well of the page that is open: it glides to the page chosen
                  AnimatedAlign(
                    alignment: Alignment(-1 + 2 * tab / 3, 0),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    child: FractionallySizedBox(
                      widthFactor: .25,
                      heightFactor: 1,
                      child: Container(
                        key: const Key('nav-well'),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), color: wellBg, border: Border.all(color: const Color(0xFFDDAD40).withValues(alpha: .7), width: 1.2)),
                      ),
                    ),
                  ),
                  Row(children: [
                    item('nav-home', Icons.home_outlined, 'Home', 'Home', tab == 0, () => _go(0)),
                    item('nav-att', Icons.event_available_outlined, 'Attendance', 'हजेरी', tab == 1, () => _go(1)),
                    item('nav-leave', Icons.description_outlined, 'Leave', 'रजा', tab == 2, () => _go(2)),
                    item('nav-me', Icons.person_outline_rounded, 'Me', 'मी', tab == 3, () => _go(3)),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
