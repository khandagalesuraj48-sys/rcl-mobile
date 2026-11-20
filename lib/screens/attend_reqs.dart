/* HR – REGULARIZATION: to set an old day right (3.103.0, rcl-hr step 5; the web's "Requests"): a person who forgot IN or OUT, or
 * whose phone was dead, asks for a day already gone – the IN and / or OUT time and what happened. It counts only when approved: by
 * the HR office, or first by the person he reports to (the HR office's setting). Today is never asked for – today is marked with
 * the phone.
 * (3.156.0, his choice of 21-11-2026 from the pictures – "approved … he ask to set he name nay thewaych, ethe regularization as")
 * The page is called REGULARIZATION. On top the navy card with "+ New" and how many wait / are approved / are rejected; the parts
 * "My requests" and – for a person others report to – "To approve" (their requests and their leave: Reject / Approve). Every
 * request is a card with its road (Sent → Verification by the reporting person → Approval by the HR office) and in words who
 * it is with; a touch opens it. The form is "Regularize a day". Nothing new is asked of the server (rcl-hr, lib/act_muster.js,
 * lib/act_leave.js) – it checks everything again. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/api.dart' show ApiError;
import '../core/attend.dart';
import '../core/hr_cache.dart';
import '../ui/done_pop.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'leave.dart' show LeaveRoad, leaveHero, leaveTrack, roadFace, roadTone;

typedef HrAsk = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

String _t(String en, String mr) => Lang.i.pair(en, mr);
String _dmy(String ymd) => ymd.length >= 10 ? '${ymd.substring(8, 10)}-${ymd.substring(5, 7)}-${ymd.substring(0, 4)}' : ymd;
const _week = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// "IN 09:00 · OUT 18:00" of a request (only what was asked).
String _times(Map q) => [
      if ('${q['in_time'] ?? ''}'.isNotEmpty) 'IN ${q['in_time']}',
      if ('${q['out_time'] ?? ''}'.isNotEmpty) 'OUT ${q['out_time']}${q['out_next_day'] == true ? ' (+1)' : ''}',
    ].join(' · ');

/// The last word written by a person who decided ('' = none).
String _note(Map q) {
  for (final p in (q['steps'] as List? ?? const []).whereType<Map>().toList().reversed) {
    if ('${p['note'] ?? ''}'.isNotEmpty) return '${p['note']}';
  }
  return '${q['note'] ?? ''}';
}

/// The chip and the small line of a request (his own): waiting – with whom; approved; refused – why.
(String, String, String) reqState(Map q, String reason) {
  final st = '${q['status']}';
  if (st == 'approved') return (_t('Approved', 'मंजूर'), 'a', [if (reason.isNotEmpty) reason, _t('approved by HR office', 'HR office ने मंजूर केले')].join(' · '));
  if (st == 'refused') return (_t('Refused', 'नाकारले'), 'x', '${_t('Refused', 'नाकारले')}: ${_note(q)}');
  if (st == 'cancelled') return (_t('Taken back', 'मागे घेतले'), 's', reason);
  return (_t('Waiting', 'प्रलंबित'), 'w', [if (reason.isNotEmpty) reason, q['level'] == 1 ? _t('waits for reporting person', 'reporting person कडे') : _t('waits for HR office', 'HR office कडे')].join(' · '));
}

/// The form for [day] (yyyy-MM-dd; '' = he chooses the day). true = sent.
Future<bool> askRegularize(BuildContext context, HrAsk ask, String day, {String inNow = '', String outNow = '', String code = ''}) async =>
    await Navigator.of(context).push<bool>(hrRoute<bool>(RegAskScreen(ask: ask, day: day, inNow: inNow, outNow: outNow, code: code, known: day.isNotEmpty))) ?? false;

/// REGULARIZE A DAY – the form: the day, what it counts as now, IN, OUT, the reason.
class RegAskScreen extends StatefulWidget {
  const RegAskScreen({super.key, required this.ask, this.day = '', this.inNow = '', this.outNow = '', this.code = '', this.known = false});
  final HrAsk ask;
  final String day, inNow, outNow, code;

  /// the day's state was given by the page that opened the form (else it is read when a day is chosen)
  final bool known;
  @override
  State<RegAskScreen> createState() => _RegAskScreenState();
}

class _RegAskScreenState extends State<RegAskScreen> {
  late final tin = TextEditingController(text: widget.inNow), tout = TextEditingController(text: widget.outNow);
  final why = TextEditingController();
  late String day = widget.day, code = widget.code, inNow = widget.inNow, outNow = widget.outNow;
  late bool known = widget.known;
  bool next = false, busy = false;
  String err = '';

  @override
  void dispose() {
    tin.dispose();
    tout.dispose();
    why.dispose();
    super.dispose();
  }

  Future<void> _time(TextEditingController c) async {
    final x = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(c.text.trim());
    final t = await showTimePicker(context: context, initialTime: x == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: int.parse(x.group(1)!) % 24, minute: int.parse(x.group(2)!) % 60));
    if (t != null && mounted) setState(() => c.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  // the day is chosen here (opened by "+ New"): a day gone, not today – how far back is the server's
  Future<void> _pickDay() async {
    final today = DateTime.parse('${indiaDay(AttendKit.kit.now())}T00:00:00'), last = today.subtract(const Duration(days: 1));
    final d = await showDatePicker(context: context, initialDate: DateTime.tryParse('${day}T00:00:00') ?? last, firstDate: today.subtract(const Duration(days: 366)), lastDate: last);
    if (d == null || !mounted) return;
    final ymd = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() {
      day = ymd;
      known = false;
      code = '';
    });
    try {
      final j = await widget.ask({'action': 'myMonth', 'month': ymd.substring(0, 7)});
      if (!mounted || day != ymd) return;
      for (final x in (j['all'] as List? ?? const []).whereType<Map>()) {
        if ('${x['day']}' == ymd) {
          setState(() {
            known = true;
            code = '${x['code'] ?? ''}';
            inNow = '${x['in'] ?? ''}';
            outNow = '${x['out'] ?? ''}';
            if (tin.text.isEmpty) tin.text = inNow;
            if (tout.text.isEmpty) tout.text = outNow;
          });
        }
      }
    } catch (_) {/* what it counts as is simply not said */}
  }

  Future<void> _send() async {
    if (busy) return;
    if (day.isEmpty) {
      setState(() => err = _t('Choose the day first.', 'आधी दिवस निवडा.'));
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await widget.ask({'action': 'regAsk', 'day': day, 'in_time': tin.text.trim(), 'out_time': tout.text.trim(), 'out_next_day': next, 'reason': why.text.trim()});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = e is ApiError ? e.message : 'Something went wrong – please try again.';
        });
      }
    }
  }

  String get _now {
    const names = {'P': 'present', 'HD': 'half day', 'A': 'absent', 'WO': 'weekly off', 'H': 'holiday', 'WOP': 'worked on off', 'HP': 'worked on holiday', 'MIS': 'no OUT', 'L': 'leave'};
    final t = [if (inNow.isNotEmpty) 'IN $inNow', if (outNow.isNotEmpty) 'OUT $outNow'].join(' · ');
    return '${t.isEmpty ? 'no punch' : t}${names[code] == null ? '' : ' – ${names[code]}'}';
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse('${day}T00:00:00Z');
    Widget time(String key, TextEditingController c) => TextField(
          key: Key(key),
          controller: c,
          keyboardType: TextInputType.datetime,
          style: const TextStyle(fontSize: 15),
          decoration: hrInput(hint: '09:00', suffix: IconButton(icon: Icon(Icons.schedule_rounded, size: 20, color: sk.faint), onPressed: () => _time(c))),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kAskSky, title: 'Regularize a day', mr: 'दिवस Regularize करा', height: 64),
      body: SingleChildScrollView(
        key: const Key('reg-page'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          hrField(
            'Day',
            'दिवस',
            GestureDetector(
              key: const Key('reg-day'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.day.isNotEmpty || busy ? null : _pickDay,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: sk.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: sk.line)),
                child: Row(children: [
                  Expanded(child: d == null ? Text('Choose the day', mr: 'दिवस निवडा', style: TextStyle(fontSize: 15, color: sk.faint)) : Text('${_dmy(day)} · ${_week[d.weekday - 1]}', style: TextStyle(fontSize: 15, color: sk.ink))),
                  if (widget.day.isEmpty) Icon(Icons.calendar_month_rounded, size: 20, color: sk.faint),
                ]),
              ),
            ),
          ),
          if (known && day.isNotEmpty) ...[const SizedBox(height: 12), hrNote(_t('What counts now: $_now', 'आता धरलेले: $_now'), warm: false, key: const Key('reg-now'))],
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: hrField('IN', '', time('reg-in', tin))),
            const SizedBox(width: 10),
            Expanded(child: hrField('OUT', '', time('reg-out', tout))),
          ]),
          GestureDetector(
            key: const Key('reg-next'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => next = !next),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                Icon(next ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 22, color: next ? sk.accent : sk.faint),
                const SizedBox(width: 8),
                Expanded(child: Text('OUT was on the next day (night)', mr: 'OUT दुसऱ्या दिवशी (रात्रपाळी)', style: TextStyle(fontSize: 13.5, color: sk.muted))),
              ]),
            ),
          ),
          hrField('Reason', 'कारण', TextField(key: const Key('reg-why'), controller: why, maxLines: 3, minLines: 3, maxLength: 200, style: const TextStyle(fontSize: 15), decoration: hrInput(hint: _t('What happened', 'काय झाले')).copyWith(counterText: ''))),
          const SizedBox(height: 12),
          hrNote(_t('Goes for approval – your reporting person (when you have one), then the HR office.', 'मंजुरीसाठी जाते – reporting person (असल्यास), मग HR office.')),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, key: const Key('reg-err'), style: const TextStyle(color: C.red, fontSize: 13.5, height: 1.35))),
          const SizedBox(height: 14),
          hrButton('Send', 'पाठवा', key: const Key('reg-send'), onTap: _send, busy: busy),
        ]),
      ),
    );
  }
}

/// REQUESTS: his own requests to set a day right, the newest first – and what waits for him of the people who report to him.
class AttendRegsScreen extends StatefulWidget {
  const AttendRegsScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<AttendRegsScreen> createState() => _AttendRegsScreenState();
}

class _AttendRegsScreenState extends State<AttendRegsScreen> {
  List<Map> rows = [], team = [], teamLeave = [];
  int people = 0;
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map> _rows(Map<String, dynamic> j) => [for (final x in (j['rows'] as List? ?? const []).whereType<Map>()) x];

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myRegs'});
      if (!mounted) return;
      setState(() {
        rows = _rows(j);
        loading = false;
        err = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
      return;
    }
    // his team's – asked quietly: a server without them, or a person nobody reports to, simply shows nothing
    try {
      final t = await widget.ask({'action': 'teamRegs'});
      if (!mounted) return;
      setState(() {
        people = t['team'] is num ? (t['team'] as num).toInt() : 0;
        team = _rows(t);
      });
      if (people > 0) {
        final l = await widget.ask({'action': 'teamLeaves'});
        if (mounted) setState(() => teamLeave = _rows(l));
      }
    } catch (_) {/* nothing to show */}
  }

  Future<void> _new() async {
    final ok = await askRegularize(context, widget.ask, '');
    if (!ok || !mounted) return;
    donePop(context, _t('Request sent', 'विनंती पाठवली'), detail: _t('It counts when it is approved.', 'मंजूर झाल्यावर धरले जाईल.'));
    _load();
  }

  Future<void> _decide(Map q, bool yes, {bool leave = false}) async {
    if (busy) return;
    var note = '';
    if (!yes) {
      final n = await askNote(context, _t('Reject this request', 'ही विनंती नाकारा'), label: _t('Why', 'का'), ok: _t('Reject', 'नाकारा'), danger: true, max: 200);
      if (n == null) return;
      note = n;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final j = await widget.ask({'action': leave ? 'teamLeaveDecide' : 'teamRegDecide', 'id': q['id'], 'decision': yes ? 'approved' : 'refused', 'note': note});
      if (!mounted) return;
      setState(() {
        if (leave) {
          teamLeave = _rows(j);
        } else {
          team = _rows(j);
        }
        busy = false;
      });
      if (yes) {
        donePop(context, _t('Passed to the HR office', 'HR office कडे पाठवले'));
      } else {
        toast(context, _t('Rejected.', 'नाकारले.'));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  /// the part of the page that is open: 0 his own, 1 what waits for him of his team
  int part = 0;

  @override
  Widget build(BuildContext context) {
    final wait = team.length + teamLeave.length, open = people > 0 ? part : 0;
    int n(String st) => rows.where((q) => (st == 'pending' ? '${q['status']}' != 'approved' && '${q['status']}' != 'refused' && '${q['status']}' != 'cancelled' : '${q['status']}' == st)).length;
    const gold = Color(0xFFDDAD40);
    Widget stat(String key, int v, String en, String mr) => Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            m.Text('$v', key: Key('regs-n-$key'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF7DE8E), height: 1.15)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE)))),
          ]),
        );
    Widget bar() => Container(width: 1, height: 30, color: const Color(0x33FFFFFF));
    Widget tab(int i, String key, String en, String mr, int count) => Expanded(
          child: GestureDetector(
            key: Key('regs-t-$key'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => part = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: open == i ? sk.blank : Colors.transparent, borderRadius: BorderRadius.circular(99), border: Border.all(color: open == i ? gold.withValues(alpha: .75) : Colors.transparent, width: 1.2)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: open == i ? sk.ink : sk.faint)),
                  if (count > 0) Padding(padding: const EdgeInsets.only(left: 5), child: m.Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sk.link))),
                ]),
              ),
            ),
          ),
        );
    Widget why(String text) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(12)),
          child: m.Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.3)),
        );
    // a request of his team: who, what he asked, why – Reject / Approve
    Widget mine(Map q, String p, String asked, {bool leave = false}) => Container(
          key: Key('${leave ? 'lv' : 'reg'}-${q['id']}'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: sk.box(radius: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              roadFace('${q['name'] ?? ''}', size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  m.Text('${q['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 14.5, fontWeight: FontWeight.w800, color: sk.ink)),
                  m.Text(['${q['code'] ?? ''}', leave ? _t('Leave', 'रजा') : dayName('${q['day']}', week: true)].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted)),
                ]),
              ),
            ]),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
              decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(15)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Asked', mr: 'मागितले', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: sk.muted)),
                const SizedBox(height: 2),
                m.Text(asked, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sk.ink, height: 1.25)),
              ]),
            ),
            if ('${q['reason'] ?? ''}'.isNotEmpty) why('${q['reason']}'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 10,
                child: FilledButton.icon(
                  key: Key('$p-no-${q['id']}'),
                  onPressed: busy ? null : () => _decide(q, false, leave: leave),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), elevation: 0, backgroundColor: sk.dark ? const Color(0xFF2A1A28) : const Color(0xFFFBE4E1), foregroundColor: sk.dark ? const Color(0xFFFF7A70) : C.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  icon: const Icon(Icons.close_rounded, size: 17),
                  label: const Text('Reject', mr: 'नाकारा', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 13,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: Sk.goldFill, borderRadius: BorderRadius.circular(16)),
                  child: FilledButton.icon(
                    key: Key('$p-yes-${q['id']}'),
                    onPressed: busy ? null : () => _decide(q, true, leave: leave),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), elevation: 0, backgroundColor: Colors.transparent, disabledBackgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Sk.goldInk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Approve', mr: 'मंजूर करा', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ]),
          ]),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kAskSky, title: 'Regularization', mr: 'Regularization', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('regs-page'), padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), children: [
                leaveHero(
                  key: const Key('regs-hero'),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          const Text('Attendance', mr: 'हजेरी', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE))),
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBEBB5), Color(0xFFE6B94E), Color(0xFFB8860B)], stops: <double>[0, .6, 1]).createShader(r),
                            child: const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('Regularization', mr: 'Regularization', maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25))),
                          ),
                          const Text('Forgot IN or OUT? It counts only when approved.', mr: 'IN किंवा OUT राहिले? मंजूर झाल्यावरच धरले जाते.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFF3D889), height: 1.3)),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        key: const Key('regs-new'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _new,
                        child: Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(gradient: Sk.goldFill, borderRadius: BorderRadius.circular(21), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 7))]),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_rounded, size: 19, color: Sk.goldInk),
                            SizedBox(width: 4),
                            Text('New', mr: 'नवीन', style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w800, color: Sk.goldInk)),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                      decoration: BoxDecoration(color: const Color(0x17FFFFFF), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0x29FFFFFF))),
                      child: Row(children: [stat('wait', n('pending'), 'Waiting', 'प्रलंबित'), bar(), stat('ok', n('approved'), 'Approved', 'मंजूर'), bar(), stat('no', n('refused'), 'Rejected', 'नाकारले')]),
                    ),
                  ]),
                ),
                if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true, help: false)),
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 12),
                  padding: const EdgeInsets.all(5),
                  decoration: sk.box(radius: 99),
                  child: Row(children: [tab(0, 'mine', 'My requests', 'माझ्या विनंत्या', rows.length), if (people > 0) tab(1, 'team', 'To approve', 'मंजुरीसाठी', wait)]),
                ),
                if (open == 0)
                  Column(key: const Key('regs-mine'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (rows.isEmpty) hrCard([Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('No request yet.', mr: 'अजून विनंती नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint)))]),
                    for (final q in rows)
                      GestureDetector(
                        key: Key('reg-open-${q['id']}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).push(hrRoute<void>(RegDetailScreen(request: q))),
                        child: regCard(q, key: Key('reg-${q['id']}')),
                      ),
                  ]),
                if (open == 1)
                  Column(key: const Key('regs-team'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (wait == 0) hrCard([Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Nothing is waiting.', mr: 'काही प्रलंबित नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint)))]),
                    for (final q in team) mine(q, 'team', _times(q)),
                    for (final q in teamLeave) mine(q, 'tl', '${_t('Leave', 'रजा')} · ${leaveDays(q)}', leave: true),
                  ]),
              ]),
            ),
    );
  }
}

String _at(Object? at) {
  final d = DateTime.tryParse('${at ?? ''}');
  if (d == null) return '';
  final i = d.toUtc().add(const Duration(hours: 5, minutes: 30));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(i.day)}-${two(i.month)}-${i.year} ${two(i.hour)}:${two(i.minute)}';
}

/// WHERE A REQUEST STANDS, as the road of a leave (screens/leave.dart): Sent → Verification (the person he reports to – only
/// when the HR office's setting asks for it) → Approval (the HR office). From what the server says: its level (1 = with the
/// reporting person, 2 = with the HR office) and its steps (who decided, when, the note). The reporting person's NAME is his
/// own record's ("My HR" – read on Home); when it is not known: "the reporting person".
LeaveRoad regRoad(Map q, {String? boss}) {
  final st = '${q['status']}', steps = [for (final x in (q['steps'] as List? ?? const []).whereType<Map>()) x];
  final mgr = boss ?? '${((HrCache.now('myHr')?['employee'] as Map?)?['manager']) ?? ''}';
  final rp = mgr.isNotEmpty ? mgr : _t('the reporting person', 'Reporting person'), hr = _t('the HR office', 'HR office');
  Map? of(int level) => steps.where((x) => x['level'] == level).lastOrNull;
  final s1 = of(1), s2 = of(2);
  ({String name, String who, String state, String when}) step(bool verify, String who, String state, String when) => (name: verify ? 'Verification' : _t('Approval', 'मंजुरी'), who: who, state: state, when: when);
  final sent = (name: _t('Sent', 'पाठवली'), who: _t('You', 'तुम्ही'), state: 'done', when: _at(q['asked_at']));
  final verDone = s1 != null && '${s1['decision']}' == 'approved' ? step(true, rp, 'done', '${_t('Verified', 'Verify केली')} · ${_at(s1['at'])}') : null;
  switch (st) {
    case 'approved':
      return LeaveRoad([sent, if (verDone != null) verDone, step(false, hr, 'done', '${_t('Approved', 'मंजूर')}${s2 == null ? '' : ' · ${_at(s2['at'])}'}')], _t('Approved', 'मंजूर'), _t('by $hr', '$hr ने'), 'a', hr);
    case 'refused':
      final atVerify = verDone == null && s1 != null, by = atVerify ? rp : hr, last = atVerify ? s1 : s2, note = _note(q);
      final bad = step(atVerify, by, 'bad', '${_t('Rejected', 'नाकारले')}${last == null ? '' : ' · ${_at(last['at'])}'}');
      return LeaveRoad([sent, if (verDone != null) verDone, bad, if (atVerify) step(false, hr, 'todo', '')], _t('Rejected', 'नाकारले'), [_t('by $by', '$by यांनी'), if (note.isNotEmpty) '“$note”'].join(' – '), 'x', by);
    case 'cancelled':
      return LeaveRoad([sent, step(false, hr, 'todo', '')], _t('Taken back', 'मागे घेतले'), '', 's', '');
    default:
      if (q['level'] == 1) {
        return LeaveRoad([sent, step(true, rp, 'now', _t('Waiting', 'प्रलंबित')), step(false, hr, 'todo', _t('After verification', 'Verification नंतर'))], _t('In verification', 'Verification मध्ये'), _t('with $rp', '$rp कडे'), 'w', rp);
      }
      return LeaveRoad([sent, if (verDone != null) verDone, step(false, hr, 'now', _t('Waiting', 'प्रलंबित'))], _t('Pending approval', 'मंजुरीसाठी प्रलंबित'), _t('with $hr', '$hr कडे'), 'w', hr);
  }
}

Widget _dateTile(String day) {
  final d = DateTime.tryParse('${day}T00:00:00Z');
  const mon = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return Container(
    width: 46,
    height: 50,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDDAD40).withValues(alpha: .45))),
    child: d == null
        ? Icon(Icons.event_rounded, size: 20, color: sk.link)
        : Column(mainAxisSize: MainAxisSize.min, children: [
            m.Text(d.day.toString().padLeft(2, '0'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: sk.ink, height: 1)),
            const SizedBox(height: 2),
            m.Text(mon[d.month - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5, color: sk.link, height: 1)),
          ]),
  );
}

/// One request on the page: the day, the times asked, the reason, its road, and in words who it is with.
Widget regCard(Map q, {Key? key}) {
  final road = regRoad(q), tone = roadTone(road.tone);
  return Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: sk.box(radius: 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        _dateTile('${q['day']}'),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            m.Text(dayName('${q['day']}', week: true), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w800, color: sk.ink)),
            m.Text(_times(q), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, size: 20, color: sk.blankInk),
      ]),
      if ('${q['reason'] ?? ''}'.isNotEmpty)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(12)),
          child: m.Text('${q['reason']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.3)),
        ),
      Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 10), child: leaveTrack(road)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: tone.$2, borderRadius: BorderRadius.circular(16), border: Border.all(color: tone.$3)),
        child: Row(children: [
          roadFace(road.holder),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              m.Text(road.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: tone.$1)),
              if (road.sub.isNotEmpty) m.Text(road.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.25)),
            ]),
          ),
        ]),
      ),
    ]),
  );
}

/// A REQUEST OPENED: who it is with now and how far it has come; each step with its person and its time; what he asked.
class RegDetailScreen extends StatelessWidget {
  const RegDetailScreen({super.key, required this.request});
  final Map request;
  @override
  Widget build(BuildContext context) {
    final q = request, road = regRoad(q), tone = roadTone(road.tone), bad = road.tone == 'x';
    const gold = Color(0xFFDDAD40), red = Color(0xFFE5484D);
    return Scaffold(
      appBar: hrHead(context, sky: kAskSky, title: 'Regularization', mr: 'Regularization', pill: headPill(dayName('${q['day']}', week: true)), height: 96),
      body: ListView(key: const Key('regd-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        leaveHero(
          key: const Key('regd-stand'),
          edge: bad ? const Color(0xB3E5484D) : const Color(0x8CE6B94E),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              roadFace(road.holder, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  m.Text(road.title.toUpperCase(), key: const Key('regd-state'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: bad ? const Color(0xFFFF9A92) : const Color(0xFFF3D889))),
                  const SizedBox(height: 2),
                  m.Text(road.sub.isEmpty ? road.title : '${road.sub[0].toUpperCase()}${road.sub.substring(1)}', key: const Key('regd-waits'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
                  Padding(padding: const EdgeInsets.only(top: 3), child: m.Text(_times(q), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFC9D3EE)))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 7, color: const Color(0x24FFFFFF)),
                FractionallySizedBox(widthFactor: road.far, child: Container(height: 7, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFC9960A), bad ? red : const Color(0xFFF7DE8E)]), borderRadius: BorderRadius.circular(4)))),
              ]),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final x in road.steps) m.Text(x.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE)))]),
          ]),
        ),
        const SizedBox(height: 14),
        hrCard(key: const Key('regd-road'), [
          hrTitle('Where it stands', 'सध्याची स्थिती'),
          for (final (i, x) in road.steps.indexed)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: x.state == 'done' ? Sk.goldFill : null, color: x.state == 'bad' ? red : x.state == 'done' ? null : sk.card, border: Border.all(color: x.state == 'todo' ? (sk.cardLine ?? sk.line) : x.state == 'bad' ? red : gold, width: 2)),
                    child: Icon(x.state == 'done' ? Icons.check_rounded : x.state == 'bad' ? Icons.close_rounded : x.state == 'now' ? Icons.schedule_rounded : Icons.more_horiz_rounded, size: 14, color: x.state == 'done' ? Sk.goldInk : x.state == 'bad' ? Colors.white : x.state == 'now' ? sk.link : sk.faint),
                  ),
                  if (i < road.steps.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: x.state == 'done' ? gold.withValues(alpha: .6) : sk.hair)),
                ]),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 3, bottom: i < road.steps.length - 1 ? 16 : 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      m.Text(x.name, style: TextStyle(fontFamily: 'Montserrat', fontSize: 13.5, fontWeight: FontWeight.w800, color: x.state == 'todo' ? sk.faint : x.state == 'bad' ? tone.$1 : sk.ink)),
                      if (i > 0 && x.who.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 7, bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: x.state == 'now' ? gold.withValues(alpha: .1) : x.state == 'bad' ? red.withValues(alpha: .08) : sk.blank, borderRadius: BorderRadius.circular(14), border: x.state == 'now' ? Border.all(color: gold.withValues(alpha: .5)) : x.state == 'bad' ? Border.all(color: red.withValues(alpha: .35)) : null),
                          child: Row(children: [roadFace(x.who, size: 32), const SizedBox(width: 10), Expanded(child: m.Text(x.who, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sk.ink, height: 1.25)))]),
                        ),
                      if (x.when.isNotEmpty) m.Text(i == 0 ? '${x.when} · ${_t('by you', 'तुम्ही')}' : x.when, style: TextStyle(fontSize: 12, height: 1.3, fontWeight: x.state == 'now' || x.state == 'bad' ? FontWeight.w600 : FontWeight.w400, color: x.state == 'now' ? sk.link : x.state == 'bad' ? tone.$1 : sk.muted)),
                      if (x.state == 'bad' && _note(q).isNotEmpty) m.Text('“${_note(q)}”', style: TextStyle(fontSize: 12.5, height: 1.3, color: tone.$1)),
                    ]),
                  ),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        hrCard(key: const Key('regd-asked'), [
          hrTitle('What you asked', 'तुम्ही काय मागितले'),
          reqRow(key: const Key('regd-day'), main: dayName('${q['day']}', week: true), small: _dmy('${q['day']}'), chips: const []),
          reqRow(key: const Key('regd-times'), main: _times(q), small: _t('The times asked', 'मागितलेल्या वेळा'), chips: const [], last: '${q['reason'] ?? ''}'.isEmpty),
          if ('${q['reason'] ?? ''}'.isNotEmpty) reqRow(key: const Key('regd-why'), main: '${q['reason']}', small: _t('Reason', 'कारण'), chips: const [], last: true),
        ]),
      ]),
    );
  }
}

/// "15 Nov · 1 day", "15 – 17 Nov · 3 days", "3 Nov · half day" of a leave request.
String leaveDays(Map q) {
  final from = '${q['from'] ?? ''}', to = '${q['to'] ?? from}', n = q['days'] is num ? q['days'] as num : 0;
  final days = '${q['part'] ?? 'full'}' != 'full' ? _t('half day', 'अर्धा दिवस') : n == 1 ? _t('1 day', '1 दिवस') : _t('${n == n.roundToDouble() ? n.round() : n} days', '${n == n.roundToDouble() ? n.round() : n} दिवस');
  final span = to == from || to.isEmpty
      ? dayName(from)
      : from.substring(0, 7) == to.substring(0, 7)
          ? '${int.tryParse(from.substring(8, 10)) ?? ''} – ${dayName(to)}'
          : '${dayName(from)} – ${dayName(to)}';
  return '$span · $days';
}
