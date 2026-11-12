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
 * Everything is asked of the HR server (rcl-hr) with his "My HR" sign-in; nothing of Mechanical is asked here. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/attend.dart';
import '../core/session.dart';
import '../ui/attend_look.dart';
import '../ui/hr_look.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
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

class _HrShellState extends State<HrShell> with WidgetsBindingObserver {
  int tab = 0; // 0 Home · 1 Me
  Map<String, dynamic>? day, month, leave, mine; // myAttend, myMonth, myLeave, myHr
  List<Map> regs = [];
  int teamWait = 0;
  String err = '';
  bool loading = true, started = false, opening = false;
  double slide = 0;
  Timer? minute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // on duty: the hours since IN move on by themselves
    minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _load();
  }

  Future<void> _mark() async {
    if (opening) return;
    opening = true;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AttendanceScreen(quick: true)));
    opening = false;
    if (!mounted) return;
    setState(() => slide = 0);
    _load();
  }

  String get _who => '${(day?['employee'] as Map?)?['name'] ?? SessionScope.read(context).name} · ${(day?['employee'] as Map?)?['code'] ?? ''}';
  void _attendance() => _push(const AttendanceScreen());
  void _leave() => _push(LeaveScreen(ask: _hr));
  void _requests() => _push(AttendRegsScreen(ask: _hr));
  void _month() => _push(AttendMonthScreen(ask: _hr, who: _who));
  void _docs() => _push(MyDocsScreen(ask: _hr));
  void _slips() => _push(const SalarySlipsScreen());
  Future<void> _photo() async {
    if (await setMyPhoto(context, _hr) && mounted) _load();
  }


  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    LangScope.of(context); // the words here follow the language chosen in Me
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F1),
      bottomNavigationBar: _nav(),
      body: tab == 1
          ? HrMeTab(key: const Key('hr-me'), mine: mine, day: day, ask: _hr, onDocs: _docs, onSlips: _slips, onPhoto: _photo, reload: _load)
          : SafeArea(
              bottom: false,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(key: const Key('hr-home'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
                  _top(s),
                  const SizedBox(height: 12),
                  if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('hh-err')),
                  if (loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                  if (day != null) ...[
                    _hero(s),
                    const SizedBox(height: 12),
                    _week(),
                    const SizedBox(height: 12),
                    _tiles(),
                    ..._forYou(),
                  ],
                ]),
              ),
            ),
    );
  }

  // ---- "Good afternoon, Babu Demo" and the bell (red dot: something waits)
  Widget _top(Session s) {
    final h = DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now() + 19800000, isUtc: true).hour;
    final name = '${(day?['employee'] as Map?)?['name'] ?? s.name}', wait = _notes().isNotEmpty;
    return Row(children: [
      hrFace(name, '${mine?['photo'] ?? ''}', size: 46, radius: 15),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening', mr: h < 12 ? 'शुभ सकाळ' : h < 17 ? 'शुभ दुपार' : 'शुभ संध्याकाळ', key: const Key('hh-hello'), style: const TextStyle(fontSize: 13, color: C.muted)),
          m.Text(name, key: const Key('hh-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: C.ink)),
        ]),
      ),
      GestureDetector(
        key: const Key('hh-bell'),
        behavior: HitTestBehavior.opaque,
        onTap: _requests,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: kSoftShadow),
          child: Stack(children: [
            const Center(child: Icon(Icons.notifications_none_rounded, size: 22, color: kNavy)),
            if (wait) Positioned(right: 9, top: 9, child: Container(key: const Key('hh-dot'), width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle))),
          ]),
        ),
      ),
    ]);
  }

  // ---- his day in the sky, and the bar that marks it
  Widget _hero(Session s) {
    final punches = [for (final x in (day?['punches'] as List? ?? const []).whereType<Map>()) x];
    final next = punches.isEmpty ? 'in' : ('${day?['next'] ?? 'in'}' == 'out' ? 'out' : 'in');
    final stopped = day?['may'] == false || '${day?['phone'] ?? ''}' == 'other' || (day?['places'] as List? ?? const []).isEmpty;
    final sky = skyOf(any: punches.isNotEmpty, next: next, stopped: stopped);
    var tin = '', tout = '';
    for (final p in punches) {
      if (p['kind'] == 'in' && tin.isEmpty) tin = '${p['time'] ?? ''}';
      if (p['kind'] == 'out') tout = '${p['time'] ?? ''}';
    }
    var lastIn = '';
    for (final p in punches.reversed) {
      if (p['kind'] == 'in') {
        lastIn = '${p['time'] ?? ''}';
        break;
      }
    }
    final since = sky == Sky.day ? sinceText(lastIn, DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now())) : '';
    final (String small, String smallMr, String big, String under) = switch (sky) {
      Sky.day => ('On duty since', 'कामावर', lastIn, since.isEmpty ? '' : _t('$since today', 'आज $since')),
      Sky.dusk => ('Today is done', 'आजची हजेरी पूर्ण', tout, 'IN $tin · OUT $tout'),
      Sky.grey => ('Attendance', 'हजेरी', _t('Cannot be marked', 'लावता येत नाही'), _t('Open Attendance to see why', 'कारण पाहण्यासाठी Attendance उघडा')),
      _ => ('Today', 'आज', _t('Not marked yet', 'अजून लावलेली नाही'), ''),
    };
    return Container(
      key: const Key('hh-hero'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: skyDown(sky), borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: Color(0x4D0B5FA5), blurRadius: 26, offset: Offset(0, 12))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(small, mr: smallMr, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .95)))),
          Container(
            constraints: const BoxConstraints(maxWidth: 170),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .22), borderRadius: BorderRadius.circular(12)),
            child: m.Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: m.Text(big, key: const Key('hh-big'), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: sky == Sky.day || sky == Sky.dusk ? 36 : 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2))),
        if (under.isNotEmpty) m.Text(under, key: const Key('hh-under'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .95))),
        const SizedBox(height: 14),
        if (sky == Sky.dusk)
          hrGlass(GestureDetector(key: const Key('hh-open'), behavior: HitTestBehavior.opaque, onTap: _attendance, child: const SizedBox(height: 40, child: Center(child: Text('See today', mr: 'आज पहा', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white))))))
        else
          LayoutBuilder(builder: (context, box) {
            final room = (box.maxWidth - 52).clamp(0.0, 2000.0);
            return GestureDetector(
              key: const Key('hh-slide'),
              behavior: HitTestBehavior.opaque,
              onTap: _mark,
              onHorizontalDragUpdate: (d) => setState(() => slide = (slide + d.delta.dx).clamp(0.0, room)),
              onHorizontalDragEnd: (_) {
                final go = slide > room * .5;
                setState(() => slide = 0);
                if (go) _mark();
              },
              child: Container(
                height: 52,
                width: double.infinity,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: const Color(0x59092854), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white.withValues(alpha: .35))),
                child: Stack(alignment: Alignment.centerLeft, children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 56, right: 8),
                    child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(stopped ? _t('Open Attendance', 'Attendance उघडा') : next == 'in' ? _t('Slide to mark IN', 'IN लावण्यासाठी सरकवा') : _t('Slide to mark OUT', 'OUT लावण्यासाठी सरकवा'), key: const Key('hh-slide-text'), maxLines: 1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white))),
                  ),
                  Transform.translate(offset: Offset(slide, 0), child: SunDisc(size: 42, label: next == 'in' ? 'IN' : 'OUT', dim: stopped)),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  // ---- this week, Monday first: what each day counts as (the month's own letters)
  Widget _week() {
    final today = '${day?['day'] ?? indiaDay(AttendKit.kit.now())}', t = DateTime.parse('${today}T00:00:00Z'), mon = t.subtract(Duration(days: t.weekday - 1));
    final by = <String, String>{for (final d in (month?['all'] as List? ?? const []).whereType<Map>()) '${d['day']}': '${d['code'] ?? ''}'};
    (Color, Color) look(String c) => switch (c) {
          'P' || 'WOP' || 'HP' || 'IN' => (const Color(0xFF146C2E), const Color(0xFFDDF3E4)),
          'HD' => (const Color(0xFF8A5A00), const Color(0xFFFFF3D1)),
          'A' || 'MIS' => (const Color(0xFFC22A1B), const Color(0xFFFFE6E3)),
          'L' => (kPurple, const Color(0xFFF1E8F6)),
          'WO' || 'H' => (const Color(0xFF7B839C), const Color(0xFFE4E7F0)),
          _ => (const Color(0xFFB3B9C9), const Color(0xFFF3F5FA)),
        };
    return hrCard(key: const Key('hh-week'), [
      Row(children: [
        const Expanded(child: Text('This week', mr: 'हा आठवडा', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: C.ink))),
        GestureDetector(key: const Key('hh-month'), behavior: HitTestBehavior.opaque, onTap: _month, child: const Padding(padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Text('Month', mr: 'महिना', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.blue)))),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 7; i++)
          () {
            final d = mon.add(Duration(days: i)).toIso8601String().substring(0, 10), c = by[d] ?? '', lk = look(c);
            return Column(mainAxisSize: MainAxisSize.min, children: [
              m.Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.muted)),
              const SizedBox(height: 5),
              Container(
                key: Key('hh-w-$d'),
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: lk.$2, borderRadius: BorderRadius.circular(12), border: d == today ? Border.all(color: kNavy, width: 2) : null),
                child: m.Text(c == 'MIS' ? '!' : c, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: lk.$1)),
              ),
            ]);
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
    Widget tile(String key, String sign, Color c, Color soft, String en, String mr, String sub, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Press(
              key: Key(key),
              onTap: onTap,
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: m.Text(sign, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: c))),
                const SizedBox(height: 7),
                FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.ink))),
                FittedBox(fit: BoxFit.scaleDown, child: m.Text(sub.isEmpty ? ' ' : sub, key: Key('$key-sub'), maxLines: 1, style: const TextStyle(fontSize: 11, color: C.muted))),
              ]),
            ),
          ),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      tile('hh-leave', 'L', kPurple, const Color(0xFFF1E8F6), 'Leave', 'रजा', left, _leave),
      tile('hh-reqs', 'R', const Color(0xFF8A5A00), const Color(0xFFFFF3D1), 'Requests', 'विनंत्या', waiting > 0 ? _t('$waiting waiting', '$waiting प्रलंबित') : '', _requests),
      tile('hh-docs', 'D', const Color(0xFF0F7A45), const Color(0xFFE3F7EC), 'Documents', 'कागदपत्रे', mine == null ? '' : miss > 0 ? _t('$miss missing', '$miss बाकी') : _t('All there', 'सर्व आहेत'), _docs),
      tile('hh-slip', '₹', const Color(0xFF0B5FA5), const Color(0xFFE3EEFB), 'Salary slip', 'पगार पावती', '', _slips),
    ]);
  }

  /// What waits: his leave not decided yet, a day gone that counts as absent and can still be asked for, his team's requests.
  List<({String key, String sign, Color c, Color soft, String title, String sub, String go, VoidCallback onTap})> _notes() {
    final out = <({String key, String sign, Color c, Color soft, String title, String sub, String go, VoidCallback onTap})>[];
    for (final q in (leave?['requests'] as List? ?? const []).whereType<Map>()) {
      if (q['status'] == 'pending') out.add((key: 'hh-n-leave-${q['id']}', sign: 'L', c: const Color(0xFF0B5FA5), soft: const Color(0xFFE3EEFB), title: _t('Leave on ${dayName('${q['from']}')}', '${dayName('${q['from']}')} ची रजा'), sub: _t('Waiting for approval', 'मंजुरीची वाट'), go: _t('See', 'पहा'), onTap: _leave));
    }
    final today = '${month?['today'] ?? ''}', back = month?['reg_days'] is num ? (month!['reg_days'] as num).toInt() : 0, t = DateTime.tryParse('${today}T00:00:00Z');
    final asked = {for (final q in regs) if (q['status'] == 'pending') '${q['day']}'};
    if (t != null && back > 0) {
      for (final d in (month?['all'] as List? ?? const []).whereType<Map>().toList().reversed) {
        final dd = DateTime.tryParse('${d['day']}T00:00:00Z');
        if (d['code'] != 'A' || dd == null || !dd.isBefore(t) || t.difference(dd).inDays > back || asked.contains('${d['day']}')) continue;
        out.add((key: 'hh-n-day-${d['day']}', sign: '!', c: const Color(0xFFC22A1B), soft: const Color(0xFFFFE6E3), title: _t('${dayName('${d['day']}')} has no punch', '${dayName('${d['day']}')} ला हजेरी नाही'), sub: _t('Ask to set it right', 'दुरुस्ती मागा'), go: _t('Ask', 'मागा'), onTap: () async {
          final ok = await askRegularize(context, _hr, '${d['day']}', code: 'A');
          if (!mounted) return;
          if (ok) toast(context, _t('Sent – it counts when it is approved.', 'पाठवले – मंजूर झाल्यावर धरले जाईल.'));
          _load();
        }));
        break; // the newest such day; the others are in "This month"
      }
    }
    if (teamWait > 0) out.add((key: 'hh-n-team', sign: 'R', c: const Color(0xFF8A5A00), soft: const Color(0xFFFFF3D1), title: _t('$teamWait of your team wait for you', 'तुमच्या टीमच्या $teamWait विनंत्या'), sub: _t('Approve or refuse', 'मंजूर करा किंवा नाकारा'), go: _t('Open', 'उघडा'), onTap: _requests));
    return out;
  }

  List<Widget> _forYou() {
    final notes = _notes();
    if (notes.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      hrCard(key: const Key('hh-for'), [
        hrTitle('For you', 'तुमच्यासाठी'),
        for (final n in notes)
          GestureDetector(
            key: Key(n.key),
            behavior: HitTestBehavior.opaque,
            onTap: n.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: n.soft, borderRadius: BorderRadius.circular(12)), child: m.Text(n.sign, style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w800, color: n.c))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    m.Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink)),
                    m.Text(n.sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
                m.Text(n.go, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.blue)),
              ]),
            ),
          ),
      ]),
    ];
  }

  // ---- Home · Attendance · Leave · Me
  Widget _nav() {
    Widget item(String key, String en, String mr, bool on, VoidCallback onTap) => GestureDetector(
          key: Key(key),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: on ? 16 : 8, vertical: 9),
            decoration: on ? BoxDecoration(color: const Color(0xFFE3F7EC), borderRadius: BorderRadius.circular(22)) : null,
            child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? const Color(0xFF0F7A45) : C.muted)),
          ),
        );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Container(
          key: const Key('hr-nav'),
          height: 58,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x24141E3C), blurRadius: 20, offset: Offset(0, 6))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            item('nav-home', 'Home', 'Home', tab == 0, () => setState(() => tab = 0)),
            item('nav-att', 'Attendance', 'हजेरी', false, _attendance),
            item('nav-leave', 'Leave', 'रजा', false, _leave),
            item('nav-me', 'Me', 'मी', tab == 1, () => setState(() => tab = 1)),
          ]),
        ),
      ),
    );
  }
}
