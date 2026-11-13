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

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/attend.dart';
import '../core/attend_remind.dart';
import '../core/session.dart';
import '../ui/attend_look.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/widgets.dart';
import 'attend_reqs.dart';
import 'attendance.dart';
import 'hr_me.dart';
import 'leave.dart';

String _t(String en, String mr) => Lang.i.pair(en, mr);

/// His HR sign-in of this site, for the pages opened from here.
Future<Map<String, dynamic>> hrCall(BuildContext context, Map<String, dynamic> body) {
  final s = SessionScope.read(context), mod = hrModule(s);
  if (s.site == null || mod == null) throw StateError('none');
  return s.api.hr(s.site!.code, mod.url, mod.key, body);
}

/// The first letters of a name ("Babu Demo" → BD).
String initials(String name) {
  final w = name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (w.isEmpty) return '?';
  return (w.first.substring(0, 1) + (w.length > 1 ? w[1].substring(0, 1) : '')).toUpperCase();
}

class HrShell extends StatefulWidget {
  const HrShell({super.key});
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
  Timer? minute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // (3.114.0) the attendance app has its own look – the one he chose on this phone
    HrSkin.i.addListener(_skin);
    unawaited(HrSkin.i.enter());
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
    HrSkin.i.leave();
    minute?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

  // each part by itself: a part the server does not have yet (a step not run) is simply not shown
  Future<Map<String, dynamic>?> _quiet(Map<String, dynamic> body) async {
    try {
      return await _hr(body);
    } catch (_) {
      return null;
    }
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    try {
      final info = await AttendKit.kit.info();
      final d = await _hr({'action': 'myAttend', 'device_id': info['id']});
      await AttendStore('${s.email}|${s.site?.code ?? ''}').keep(d, await AttendKit.kit.elapsed());
      unawaited(AttendRemind.set(d)); // (3.113.0) the IN / OUT reminders, from his shift and where his day stands
      if (!mounted) return;
      setState(() {
        day = d;
        loading = false;
        err = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = e is StateError ? 'You have no HR on this site – the Super Admin gives it in the Portal.' : errText(e);
      });
      return;
    }
    final today = '${day?['day'] ?? indiaDay(AttendKit.kit.now())}';
    final got = await Future.wait([_quiet({'action': 'myMonth', 'month': today.substring(0, 7)}), _quiet({'action': 'myLeave'}), _quiet({'action': 'myRegs'}), _quiet({'action': 'myHr'}), _quiet({'action': 'teamRegs'})]);
    if (!mounted) return;
    setState(() {
      month = got[0];
      leave = got[1];
      regs = [for (final x in (got[2]?['rows'] as List? ?? const []).whereType<Map>()) x];
      mine = got[3];
      teamWait = (got[4]?['rows'] as List? ?? const []).length;
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
    await Navigator.of(context).push(hrRoute<void>(const AttendanceScreen(quick: true)));
    opening = false;
    if (!mounted) return;
    setState(() => gen++);
    _load();
  }

  String get _who => '${(day?['employee'] as Map?)?['name'] ?? SessionScope.read(context).name} · ${(day?['employee'] as Map?)?['code'] ?? ''}';
  void _requests() => _push(AttendRegsScreen(ask: _hr));
  void _month() => _push(AttendMonthScreen(ask: _hr, who: _who));
  void _docs() => _push(MyDocsScreen(ask: _hr));
  void _slips() => _push(SalarySlipsScreen(ask: _hr));
  Future<void> _photo() async {
    if (await setMyPhoto(context, _hr) && mounted) _load();
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
      bottomNavigationBar: _nav(),
      body: switch (tab) {
        1 => AttendanceScreen(key: ValueKey('tab-att-$gen'), embedded: true),
        2 => LeaveScreen(key: ValueKey('tab-leave-$gen'), ask: _hr, embedded: true),
        3 => HrMeTab(key: const Key('hr-me'), mine: mine, day: day, ask: _hr, onDocs: _docs, onSlips: _slips, onPhoto: _photo, reload: _load),
        _ => Container(
            decoration: BoxDecoration(gradient: sk.pageFill),
            child: SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(key: const Key('hr-home'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
                  _top(s),
                  const SizedBox(height: 14),
                  if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('hh-err')),
                  if (loading) Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: sk.accent))),
                  if (day != null) ...[
                    _hero(s),
                    const SizedBox(height: 14),
                    _week(),
                    const SizedBox(height: 14),
                    _tiles(),
                    ..._forYou(),
                  ],
                ]),
              ),
            ),
          ),
      },
    );
  }

  // ---- "Good afternoon, Babu Demo" and the bell (red dot: something waits)
  Widget _top(Session s) {
    final h = DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now() + 19800000, isUtc: true).hour;
    final name = '${(day?['employee'] as Map?)?['name'] ?? s.name}', wait = _notes().any((n) => n.onTap != null);
    return Row(children: [
      hrFace(name, '${mine?['photo'] ?? ''}', size: 48, radius: 24, bg: sk.dark ? sk.card : const Color(0xFF0F1F3D), border: const Color(0xFFDDAD40), ink: sk.dark ? sk.accent : Colors.white),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening', mr: h < 12 ? 'शुभ सकाळ' : h < 17 ? 'शुभ दुपार' : 'शुभ संध्याकाळ', key: const Key('hh-hello'), style: TextStyle(fontSize: 13, color: sk.muted)),
          m.Text(name, key: const Key('hh-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: sk.ink)),
        ]),
      ),
      hrIconBox(Icons.notifications_none_rounded, key: const Key('hh-bell'), dot: wait, onTap: _requests),
    ]);
  }

  // ---- THE DIAL: his shift as a ring, the disc that marks, IN · OUT · Hours
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
    final nowMs = AttendKit.kit.now(), india = DateTime.fromMillisecondsSinceEpoch(nowMs + 19800000, isUtc: true);
    final hhmm = '${india.hour.toString().padLeft(2, '0')}:${india.minute.toString().padLeft(2, '0')}';
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
    final (String state, String top, String big, String under) = switch (sky) {
      Sky.day => (_t('On duty since $lastIn', '$lastIn पासून कामावर'), _t('HOLD TO MARK', 'धरून लावा'), 'OUT', since.isEmpty ? '' : _t('$since at work', '$since कामावर')),
      Sky.dusk => closed
          ? (_t('Closed by itself – absent', 'आपोआप बंद – गैरहजर'), '', _t('ABSENT', 'गैरहजर'), _t('Ask to set the day right', 'दुरुस्ती मागा'))
          : (_t('Today is done', 'आजची हजेरी पूर्ण'), '', _t('DONE', 'पूर्ण'), tout.isEmpty ? 'IN $tin' : 'IN $tin · OUT $tout'),
      Sky.grey => (_t('Cannot be marked', 'लावता येत नाही'), '', '–', _t('Open Attendance', 'Attendance उघडा')),
      _ => (_t('Not marked yet', 'अजून लावलेली नाही'), _t('HOLD TO MARK', 'धरून लावा'), 'IN', _t('$hhmm now', 'आता $hhmm')),
    };
    final hours = sky == Sky.day ? since : _span(tin, tout);
    // the day done or stopped: the Attendance page says it all; else the marking page
    final VoidCallback go = sky == Sky.dusk || sky == Sky.grey ? () => _go(1) : _mark;
    Widget stat(String key, String v, String en, String mr) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(fit: BoxFit.scaleDown, child: m.Text(v.isEmpty ? '– –' : v, key: Key(key), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: v.isEmpty ? sk.faint : sk.ink))),
              const SizedBox(height: 2),
              Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .8, color: sk.faint)),
            ]),
          ),
        );
    return Container(
      key: const Key('hh-hero'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: sk.box(radius: 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(state, key: const Key('hh-big'), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink)))),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(maxWidth: 160),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on_outlined, size: 13, color: sk.muted),
              const SizedBox(width: 3),
              Flexible(child: m.Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sk.muted))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          key: const Key('hh-slide'),
          behavior: HitTestBehavior.opaque,
          onTap: go,
          onLongPress: go,
          child: ShiftDial(size: 208, now: at(india.hour * 60 + india.minute), from: at(_hm(lastIn)), out: sky == Sky.day, dim: sky == Sky.grey, done: sky == Sky.dusk, track: sk.blank, tick: sk.dark ? sk.line : const Color(0xFFCBD1DF), top: top, big: big, under: under),
        ),
        if (a != null && b0 != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 0, 30, 0),
            child: Row(children: [
              m.Text('${shift['start']}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sk.muted)),
              Expanded(child: m.Text('${shift['name'] ?? ''}', key: const Key('hh-shift'), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sk.faint))),
              m.Text('${shift['end']}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sk.muted)),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [stat('hh-in', tin, 'IN', 'IN'), const SizedBox(width: 8), stat('hh-out', tout, 'OUT', 'OUT'), const SizedBox(width: 8), stat('hh-hours', hours, 'HOURS', 'तास')]),
      ]),
    );
  }

  // ---- this week, Monday first: what each day counts as (the month's own letters); a day with nothing yet shows its date
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
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(child: Text('This week', mr: 'हा आठवडा', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink))),
          GestureDetector(key: const Key('hh-month'), behavior: HitTestBehavior.opaque, onTap: _month, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('My month', mr: 'माझा महिना', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.link)))),
        ]),
      ),
      const SizedBox(height: 4),
      Row(key: const Key('hh-week'), children: [
        for (var i = 0; i < 7; i++)
          () {
            final dt = mon.add(Duration(days: i)), d = dt.toIso8601String().substring(0, 10), c = by[d] ?? '', lk = look(c), now = d == today;
            return Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                m.Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sk.faint)),
                const SizedBox(height: 6),
                Container(
                  key: Key('hh-w-$d'),
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: now
                      ? BoxDecoration(gradient: sk.dark ? Sk.goldFill : null, color: sk.dark ? null : sk.accent, borderRadius: BorderRadius.circular(13))
                      : BoxDecoration(color: lk.$2, borderRadius: BorderRadius.circular(13)),
                  child: m.Text(c.isEmpty ? '${dt.day}' : c == 'MIS' ? '!' : c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: now ? (sk.dark ? Sk.goldInk : sk.onAccent) : lk.$1)),
                ),
              ]),
            );
          }(),
      ]),
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
      tile('hh-reqs', Icons.fact_check_outlined, const Color(0xFF8A5A00), const Color(0xFFFFF3D1), 'Requests', 'विनंत्या', waiting > 0 ? _t('$waiting waiting', '$waiting प्रलंबित') : '', _requests),
      tile('hh-docs', Icons.description_outlined, const Color(0xFF0F7A45), const Color(0xFFE3F7EC), 'Documents', 'कागदपत्रे', mine == null ? '' : miss > 0 ? _t('$miss missing', '$miss बाकी') : _t('All there', 'सर्व आहेत'), _docs),
      tile('hh-slip', Icons.payments_outlined, const Color(0xFF0B5FA5), const Color(0xFFE3EEFB), 'Salary slip', 'पगार पावती', '', _slips),
    ]);
  }

  /// What waits: his leave not decided yet, a day gone that counts as absent and can still be asked for, his team's requests –
  /// and (3.114.0, rcl-hr "coming") a paper of his that runs out within 30 days, his birthday, his years at work today.
  List<_Note> _notes() {
    const blue = Color(0xFF0B5FA5), blueSoft = Color(0xFFE3EEFB), red = Color(0xFFC22A1B), redSoft = Color(0xFFFFE6E3), amber = Color(0xFF8A5A00), amberSoft = Color(0xFFFFF3D1);
    final out = <_Note>[];
    for (final q in (leave?['requests'] as List? ?? const []).whereType<Map>()) {
      if (q['status'] == 'pending') out.add(_Note('hh-n-leave-${q['id']}', Icons.event_available_rounded, blue, blueSoft, _t('Leave on ${dayName('${q['from']}')}', '${dayName('${q['from']}')} ची रजा'), _t('Waiting for approval', 'मंजुरीची वाट'), _t('See', 'पहा'), () => _go(2)));
    }
    final today = '${month?['today'] ?? ''}', back = month?['reg_days'] is num ? (month!['reg_days'] as num).toInt() : 0, t = DateTime.tryParse('${today}T00:00:00Z');
    final asked = {for (final q in regs) if (q['status'] == 'pending') '${q['day']}'};
    if (t != null && back > 0) {
      for (final d in (month?['all'] as List? ?? const []).whereType<Map>().toList().reversed) {
        final dd = DateTime.tryParse('${d['day']}T00:00:00Z');
        if (d['code'] != 'A' || dd == null || !dd.isBefore(t) || t.difference(dd).inDays > back || asked.contains('${d['day']}')) continue;
        out.add(_Note('hh-n-day-${d['day']}', Icons.error_outline_rounded, red, redSoft, _t('${dayName('${d['day']}')} has no punch', '${dayName('${d['day']}')} ला हजेरी नाही'), _t('Ask to set it right', 'दुरुस्ती मागा'), _t('Ask', 'मागा'), () async {
          final ok = await askRegularize(context, _hr, '${d['day']}', code: 'A');
          if (!mounted) return;
          if (ok) toast(context, _t('Sent – it counts when it is approved.', 'पाठवले – मंजूर झाल्यावर धरले जाईल.'));
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

  // ---- the bar that floats: Home · Attendance · (mark) · Leave · Me
  Widget _nav() {
    final out = day != null && _next == 'out';
    Widget item(String key, IconData icon, String en, String mr, bool on, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            key: Key(key),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 26, height: 3, decoration: BoxDecoration(gradient: on ? Sk.goldFill : null, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 9),
              Icon(icon, size: 22, color: on ? sk.ink : sk.faint),
              const SizedBox(height: 3),
              FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? sk.ink : sk.faint))),
              const SizedBox(height: 9),
            ]),
          ),
        );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          height: 90,
          child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                key: const Key('hr-nav'),
                height: 66,
                decoration: sk.box(radius: 24),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  item('nav-home', Icons.home_outlined, 'Home', 'Home', tab == 0, () => _go(0)),
                  item('nav-att', Icons.calendar_today_outlined, 'Attendance', 'हजेरी', tab == 1, () => _go(1)),
                  const SizedBox(width: 78),
                  item('nav-leave', Icons.description_outlined, 'Leave', 'रजा', tab == 2, () => _go(2)),
                  item('nav-me', Icons.person_outline_rounded, 'Me', 'मी', tab == 3, () => _go(3)),
                ]),
              ),
            ),
            // the marking button, raised in the middle: gold while IN is next, red while OUT is
            Positioned(
              top: 0,
              child: GestureDetector(
                key: const Key('nav-mark'),
                behavior: HitTestBehavior.opaque,
                onTap: _mark,
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: Center(
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(gradient: out ? Sk.redFill : Sk.goldFill, borderRadius: BorderRadius.circular(17), boxShadow: [BoxShadow(color: (out ? const Color(0xFFE5484D) : const Color(0xFFDDAD40)).withValues(alpha: .45), blurRadius: 16, offset: const Offset(4, 4))]),
                        child: Transform.rotate(angle: -math.pi / 4, child: Icon(Icons.sentiment_satisfied_alt_rounded, size: 26, color: out ? Colors.white : Sk.goldInk)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
