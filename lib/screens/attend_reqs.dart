/* HR – REQUESTS to set an old day right (3.103.0, rcl-hr step 5; the web's "Requests"): a person who forgot IN or OUT, or whose
 * phone was dead, asks for a day already gone – the IN and / or OUT time and what happened. It counts only when approved: by the
 * HR office, or first by the person he reports to (the HR office's setting). Today is never asked for – today is marked with the
 * phone.
 * (3.108.0 – the screens he sent back on 12-11-2026, "mala same as it is screen hawe aahet") ONE page "Requests": the button
 * "+ Ask to set a day right", "My requests", and for a person others report to "To approve · my team" (their requests to set
 * a day right and their leave – approve / refuse). The form is a page of its own ("Set a day right").
 * The server (rcl-hr, lib/act_muster.js, lib/act_leave.js) checks everything again. */
import 'package:flutter/material.dart' hide Text;

import '../core/api.dart' show ApiError;
import '../core/attend.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

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

/// SET A DAY RIGHT – the form: the day, what it counts as now, IN, OUT, the reason.
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

  // the day is chosen here (opened by "+ Ask to set a day right"): a day gone, not today – how far back is the server's
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
      appBar: hrHead(context, sky: kAskSky, title: 'Set a day right', mr: 'दिवस दुरुस्त करा', height: 64),
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
    toast(context, _t('Sent – it counts when it is approved.', 'पाठवले – मंजूर झाल्यावर धरले जाईल.'));
    _load();
  }

  Future<void> _decide(Map q, bool yes, {bool leave = false}) async {
    if (busy) return;
    var note = '';
    if (!yes) {
      final n = await askNote(context, _t('Refuse this request', 'ही विनंती नाकारा'), label: _t('Why', 'का'), ok: _t('Refuse', 'नाकारा'), danger: true, max: 200);
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
      toast(context, yes ? _t('Passed to the HR office.', 'HR office कडे पाठवले.') : _t('Refused.', 'नाकारले.'));
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wait = team.length + teamLeave.length;
    List<Widget> yesNo(Map q, String p, {bool leave = false}) => [
          stateChip('Approve', 'a', key: Key('$p-yes-${q['id']}'), onTap: busy ? null : () => _decide(q, true, leave: leave)),
          stateChip('Refuse', 'x', key: Key('$p-no-${q['id']}'), onTap: busy ? null : () => _decide(q, false, leave: leave)),
        ];
    return Scaffold(
      appBar: hrHead(context, sky: kAskSky, title: 'Requests', mr: 'विनंत्या', height: 124, below: [
        Text('Forgot IN or OUT? Ask to set an old day right.\nIt counts only when approved.', mr: 'IN किंवा OUT राहिले? जुना दिवस दुरुस्त करायला सांगा.\nमंजूर झाल्यावरच धरले जाते.', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, height: 1.3, color: sk.onHeadSoft)),
      ]),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('regs-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                hrButton('+ Ask to set a day right', '+ दिवस दुरुस्त करायला सांगा', key: const Key('regs-new'), onTap: _new),
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false),
                const SizedBox(height: 12),
                hrCard(key: const Key('regs-mine'), [
                  hrTitle('My requests', 'माझ्या विनंत्या'),
                  if (rows.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('No request yet.', mr: 'अजून विनंती नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint))),
                  for (final (i, q) in rows.indexed)
                    () {
                      final s = reqState(q, '${q['reason'] ?? ''}');
                      return reqRow(key: Key('reg-${q['id']}'), main: [dayName('${q['day']}'), _times(q)].where((x) => x.isNotEmpty).join(' · '), small: s.$3, chips: [stateChip(s.$1, s.$2)], last: i == rows.length - 1);
                    }(),
                ]),
                if (people > 0) ...[
                  const SizedBox(height: 12),
                  hrCard(key: const Key('regs-team'), [
                    hrTitle('To approve · my team', 'मंजुरीसाठी · माझी टीम', side: wait > 0 ? '$wait' : ''),
                    if (wait == 0) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Nothing is waiting.', mr: 'काही प्रलंबित नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint))),
                    for (final (i, q) in team.indexed)
                      reqRow(key: Key('reg-${q['id']}'), main: '${q['name'] ?? ''} · ${dayName('${q['day']}')}', small: [_times(q), '${q['reason'] ?? ''}'].where((x) => x.isNotEmpty).join(' · '), chips: yesNo(q, 'team'), last: teamLeave.isEmpty && i == team.length - 1),
                    for (final (i, q) in teamLeave.indexed)
                      reqRow(key: Key('lv-${q['id']}'), main: '${q['name'] ?? ''} · ${_t('Leave', 'रजा')} ${leaveDays(q)}', small: '${q['reason'] ?? ''}', chips: yesNo(q, 'tl', leave: true), last: i == teamLeave.length - 1),
                  ]),
                ],
              ]),
            ),
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
