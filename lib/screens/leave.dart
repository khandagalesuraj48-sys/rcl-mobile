/* HR – LEAVE, the app's own screens (3.108.0, rcl-hr step 7; the screens he sent back on 12-11-2026: "mala same as it is screen
 * hawe aahet ya sagle leave chi pn screen"): his balance, what this month added and used, "+ Apply for leave", his requests
 * (waiting – approved – refused; a waiting one is taken back by a touch) and how his site counts leave – the policy the HR
 * office set, nothing fixed here. The form: From, To, the whole day or a half, the reason. The balance is never kept on the
 * phone and never counted here: the server (rcl-hr, lib/act_leave.js) walks it day by day and checks every request again. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/api.dart' show ApiError;
import '../core/attend.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attend_reqs.dart';

String _t(String en, String mr) => Lang.i.pair(en, mr);
String _dmy(String ymd) => ymd.length >= 10 ? '${ymd.substring(8, 10)}-${ymd.substring(5, 7)}-${ymd.substring(0, 4)}' : ymd;

/// 3, 2.5 – a count of days without a needless ".0".
String _n(Object? v) {
  final n = v is num ? v : num.tryParse('${v ?? ''}') ?? 0;
  return n == n.roundToDouble() ? '${n.round()}' : '$n';
}

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key, required this.ask, this.embedded = false});
  final HrAsk ask;

  /// (3.114.0) a tab of the attendance app: no way back in its head
  final bool embedded;
  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  Map<String, dynamic>? me;
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myLeave'});
      if (!mounted) return;
      setState(() {
        me = j;
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
    }
  }

  Future<void> _new() async {
    final j = await Navigator.of(context).push<Map<String, dynamic>>(hrRoute(LeaveAskScreen(ask: widget.ask, today: '${me?['today'] ?? indiaDay(AttendKit.kit.now())}', available: me?['available'])));
    if (j == null || !mounted) return;
    setState(() => me = j);
    toast(context, _t('Sent – it counts when it is approved.', 'पाठवले – मंजूर झाल्यावर धरले जाईल.'));
  }

  // a request that still waits is taken back by its owner
  Future<void> _back(Map q) async {
    if (busy || !await ask(context, _t('Take this request back?', 'ही विनंती मागे घ्यायची?'), leaveDays(q), yes: _t('Take back', 'मागे घ्या'), danger: true) || !mounted) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final j = await widget.ask({'action': 'leaveCancel', 'id': q['id']});
      if (mounted) setState(() => me = j);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  /// How his site counts leave – said from the policy of today (the HR office's), never from a number of the app.
  String _how(Map? p) {
    if (p == null) return _t('No leave policy is set for your site yet – ask the HR office.', 'तुमच्या site साठी अजून रजा policy ठरवलेली नाही – HR office ला सांगा.');
    final per = _n(p['per_month']);
    return [
      _t('$per leaves are added every month.', 'दर महिन्याला $per रजा जमा होतात.'),
      if (p['auto_absent'] == true) _t('A day off – an absent day too – takes one from the balance.', 'सुट्टीचा दिवस – गैरहजर दिवसही – balance मधून एक घेतो.') else _t('An approved leave day takes one from the balance.', 'मंजूर रजेचा दिवस balance मधून एक घेतो.'),
      if (p['carry'] == true) _t('What is left goes on to the next month.', 'उरलेली रजा पुढच्या महिन्यात जाते.') else _t('What is left ends with the month.', 'उरलेली रजा महिन्याबरोबर संपते.'),
    ].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final month = (me?['month'] as Map?) ?? const {}, reqs = [for (final x in (me?['requests'] as List? ?? const []).whereType<Map>()) x];
    final today = '${me?['today'] ?? indiaDay(AttendKit.kit.now())}';
    Widget box(String key, Object? v, String en, String mr) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 10),
            decoration: BoxDecoration(color: sk.headGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: sk.headGlassLine), boxShadow: sk.classic ? null : sk.shadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              m.Text(me == null ? '–' : _n(v), key: Key('leave-$key'), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.w800, color: sk.onHead, height: 1.15)),
              Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: sk.onHeadSoft)),
            ]),
          ),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'Leave', mr: 'रजा', pill: headPill(monthName(today)), height: 150, back: !widget.embedded, below: [
        Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [box('bal', me?['balance'], 'Balance', 'शिल्लक'), box('add', month['credit'], 'This month', 'हा महिना'), box('used', month['used'], 'Used', 'वापरली')])),
      ]),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('leave-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (me != null) hrButton('+ Apply for leave', '+ रजेसाठी अर्ज', key: const Key('leave-new'), onTap: _new),
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('leave-err')),
                if (me != null) ...[
                  const SizedBox(height: 12),
                  hrCard(key: const Key('leave-mine'), [
                    hrTitle('My requests', 'माझ्या विनंत्या'),
                    if (reqs.isEmpty) Padding(padding: EdgeInsets.only(bottom: 6), child: Text('No request yet.', mr: 'अजून विनंती नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint))),
                    for (final (i, q) in reqs.indexed)
                      () {
                        final s = reqState(q, '${q['reason'] ?? ''}'), waits = '${q['status']}' == 'pending';
                        return reqRow(
                            key: Key('lv-${q['id']}'),
                            main: leaveDays(q),
                            small: '${q['status']}' == 'approved' ? _t('Approved by HR office', 'HR office ने मंजूर केले') : s.$3,
                            chips: [stateChip(s.$1, s.$2, key: waits ? Key('lv-back-${q['id']}') : null, onTap: waits ? () => _back(q) : null)],
                            last: i == reqs.length - 1);
                      }(),
                    if (reqs.any((q) => '${q['status']}' == 'pending')) Padding(padding: EdgeInsets.only(top: 6), child: Text('Touch "Waiting" to take a request back.', mr: 'विनंती मागे घ्यायला "प्रलंबित" वर touch करा.', style: TextStyle(fontSize: 12, color: sk.faint))),
                  ]),
                  const SizedBox(height: 12),
                  hrCard(key: const Key('leave-how'), [
                    hrTitle('How it is counted', 'कशी मोजली जाते'),
                    m.Text(_how(me?['policy'] as Map?), style: TextStyle(fontSize: 13, color: sk.muted, height: 1.5)),
                  ]),
                ],
              ]),
            ),
    );
  }
}

/// APPLY FOR LEAVE – the form. Gives the server's answer (his leave, read again) when it was sent.
class LeaveAskScreen extends StatefulWidget {
  const LeaveAskScreen({super.key, required this.ask, required this.today, this.available});
  final HrAsk ask;
  final String today;
  final Object? available;
  @override
  State<LeaveAskScreen> createState() => _LeaveAskScreenState();
}

class _LeaveAskScreenState extends State<LeaveAskScreen> {
  late String from = widget.today, to = widget.today;
  String part = 'full', err = '';
  final why = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    why.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isFrom) async {
    final t = DateTime.parse('${widget.today}T00:00:00'), first = isFrom ? t : DateTime.parse('${from}T00:00:00');
    final d = await showDatePicker(context: context, initialDate: DateTime.parse('${isFrom ? from : to}T00:00:00'), firstDate: first, lastDate: t.add(const Duration(days: 366)));
    if (d == null || !mounted) return;
    final ymd = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    setState(() {
      if (isFrom) {
        from = ymd;
        if (to.compareTo(from) < 0 || part != 'full') to = from;
      } else {
        to = ymd;
        if (to != from) part = 'full'; // a half day is for one day
      }
    });
  }

  Future<void> _send() async {
    if (busy) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final j = await widget.ask({'action': 'leaveAsk', 'from': from, 'to': to, 'part': part, 'reason': why.text.trim()});
      if (mounted) Navigator.of(context).pop(j);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = e is ApiError ? e.message : 'Something went wrong – please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = DateTime.parse('${from}T00:00:00Z'), b = DateTime.parse('${to}T00:00:00Z');
    final num days = part == 'full' ? b.difference(a).inDays + 1 : .5, have = widget.available is num ? widget.available as num : 0;
    Widget day(String key, String ymd, bool isFrom) => GestureDetector(
          key: Key(key),
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : () => _pick(isFrom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: sk.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: sk.line)),
            child: Row(children: [Expanded(child: m.Text(_dmy(ymd), style: TextStyle(fontSize: 15, color: sk.ink))), Icon(Icons.calendar_month_rounded, size: 19, color: sk.faint)]),
          ),
        );
    Widget seg(String v, String en, String mr) => Expanded(
          child: GestureDetector(
            key: Key('leave-part-$v'),
            behavior: HitTestBehavior.opaque,
            onTap: busy
                ? null
                : () => setState(() {
                      part = v;
                      if (v != 'full') to = from;
                    }),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: part == v ? sk.accent : sk.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: part == v ? sk.accent : sk.line)),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: part == v ? sk.onAccent : sk.ink))),
            ),
          ),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'Apply for leave', mr: 'रजेसाठी अर्ज', height: 64),
      body: SingleChildScrollView(
        key: const Key('leave-ask-page'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: hrField('From', 'पासून', day('leave-from', from, true))),
            const SizedBox(width: 10),
            Expanded(child: hrField('To', 'पर्यंत', day('leave-to', to, false))),
          ]),
          const SizedBox(height: 14),
          Row(children: [seg('full', 'Full day', 'पूर्ण दिवस'), seg('first', 'First half', 'पहिला अर्धा'), seg('second', 'Second half', 'दुसरा अर्धा')]),
          const SizedBox(height: 14),
          hrField('Reason', 'कारण', TextField(key: const Key('leave-why'), controller: why, maxLines: 3, minLines: 3, maxLength: 200, style: const TextStyle(fontSize: 15), decoration: hrInput(hint: _t('Why', 'का')).copyWith(counterText: ''))),
          const SizedBox(height: 12),
          hrNote(
              key: const Key('leave-note'),
              '${_t('${_n(days)} ${days == 1 || days == .5 ? 'day' : 'days'}', '${_n(days)} दिवस')} · ${_t('balance ${_n(have)} → ${_n(have - days)} after approval', 'मंजुरीनंतर balance ${_n(have)} → ${_n(have - days)}')}'
              '${to != from ? '\n${_t('A weekly off or a holiday inside is not counted.', 'मधली साप्ताहिक सुट्टी किंवा holiday मोजली जात नाही.')}' : ''}'),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, key: const Key('leave-err'), style: const TextStyle(color: C.red, fontSize: 13.5, height: 1.35))),
          const SizedBox(height: 14),
          hrButton('Send', 'पाठवा', key: const Key('leave-send'), onTap: _send, busy: busy),
        ]),
      ),
    );
  }
}
