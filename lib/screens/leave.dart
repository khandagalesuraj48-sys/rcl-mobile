/* HR – LEAVE, the app's own screens (3.108.0, rcl-hr step 7; the screens he sent back on 12-11-2026: "mala same as it is screen
 * hawe aahet ya sagle leave chi pn screen"): his balance, what this month added and used, "+ Apply for leave", his requests
 * (waiting – approved – refused; a waiting one is taken back by a touch) and how his site counts leave – the policy the HR
 * office set, nothing fixed here. The form: From, To, the whole day or a half, the reason. The balance is never kept on the
 * phone and never counted here: the server (rcl-hr, lib/act_leave.js) walks it day by day and checks every request again.
 * (3.121.0, the Rule Book of HR – rcl-hr step 13; his words: "systeam auto samjel ki ya 2 ni milun leave balance ekach aahe",
 * "leave form attachment") when the server walks his leave with a Rule Book policy (book: true) the ONE balance is his Paid
 * leave and his Comp-off days together – he never chooses a type – and his ledger says where every day came from and went; a
 * request can carry papers (a photo or a PDF – never needed), attached with it or afterwards. A server without step 13 sends
 * none of this: the screen is then exactly the one of before.
 * (3.147.0, rcl-hr of 19-11-2026 – asked with the Leave screen: "user la aplela takleli leve delet pn krta yawi … leave apply krtanaach
 * attachment aswi without atchment leave apply honar nahi … status disel ki leave approval kuthh prynt geley ani kona kadhun pending
 * aahe … 5 tarkela aloy kamawar return … app error deil ani suggestions deil … swatche leve che days kami krnecha option … wadhwayche
 * astil tr approval lagel … user ni keleli changes pn diistel"; his answers: a paper for every leave, no IN on an approved or a waiting
 * leave day, longer = the extra days wait for approval) with a server that says so (myLeave "paper": true):
 *   – the form takes the paper (a photo or a PDF – camera, gallery, PDF); without one it is not sent;
 *   – a touch on a request opens it: where it stands and WHO it waits for, its history, "Change days", "Delete" (while it waits);
 *   – Change days: SHORTER is saved at once (only days from today on); LONGER – the extra days are a new request with its reason and
 *     paper, they wait for approval; "Back at work today" fills the days in one touch.
 * A server of before: the form, the list and the papers are as they were. */
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart' show ApiError;
import '../core/attend.dart';
import '../core/hr_cache.dart';
import '../ui/crest.dart' show CrestLines;
import '../ui/done_pop.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/motion.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attach_box.dart' show pickAttFiles;
import 'attend_reqs.dart';
import 'hr_me.dart' show docReady;
import 'hr_shell.dart' show initials;

String _t(String en, String mr) => Lang.i.pair(en, mr);
String _dmy(String ymd) => ymd.length >= 10 ? '${ymd.substring(8, 10)}-${ymd.substring(5, 7)}-${ymd.substring(0, 4)}' : ymd;

num _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

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

  /// (3.154.0) what was read the last time is shown at once; the server's answer takes its place (core/hr_cache.dart)
  Future<void> _load() async {
    if (me == null) {
      final k = await HrCache.read('myLeave');
      if (!mounted) return;
      if (k != null && me == null) {
        setState(() {
          me = k;
          loading = false;
        });
      }
    }
    try {
      final j = await widget.ask({'action': 'myLeave'});
      HrCache.put('myLeave', j);
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
    final j = await Navigator.of(context).push<Map<String, dynamic>>(hrRoute(LeaveAskScreen(ask: widget.ask, today: '${me?['today'] ?? indiaDay(AttendKit.kit.now())}', available: me?['available'], paper: me?['paper'] == true)));
    if (j == null || !mounted) return;
    setState(() => me = j);
    donePop(context, _t('Leave request sent', 'रजेचा अर्ज पाठवला'), detail: _t('It counts when it is approved.', 'मंजूर झाल्यावर धरले जाईल.'));
  }

  // (3.121.0) the papers of a request: looked at, attached, removed – then the list is read again (its count)
  Future<void> _papers(Map q) async {
    await Navigator.of(context).push<void>(hrRoute(LeavePapersScreen(ask: widget.ask, request: q)));
    if (mounted) _load();
  }

  // (3.147.0) a request opened: where it stands, its history, change its days, delete it – then the list is read again
  Future<void> _open(Map q) async {
    final said = await Navigator.of(context).push<String>(hrRoute(LeaveDetailScreen(ask: widget.ask, request: q, today: '${me?['today'] ?? indiaDay(AttendKit.kit.now())}', paper: me?['paper'] == true)));
    if (!mounted) return;
    await _load();
    if (!mounted || said == null || said.isEmpty) return;
    donePop(context, said);
  }

  /// How his site counts leave – said from the policy of today (the HR office's), never from a number of the app.
  String _how(Map? p) {
    if (p == null && me?['book'] == true) return _t('Your leave is counted by the leave policy the HR office gave you. Paid leave and Comp-off days are one balance – a leave takes the Comp-off days first.', 'तुमची रजा HR office ने दिलेल्या रजा policy प्रमाणे मोजली जाते. Paid रजा आणि Comp-off दिवस मिळून एकच balance – रजा आधी Comp-off मधून जाते.');
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
    final ledger = [for (final x in (me?['ledger'] as List? ?? const []).whereType<Map>()) x], book = me?['book'] == true;
    final part = !book && tabIn == 1 ? 0 : tabIn;
    // one number of the card's strip: it counts up to its value
    Widget stat(String key, Object? v, String en, String mr) => Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            me == null ? m.Text('–', key: Key('leave-$key'), style: _heroNum) : CountUp(value: _num(v), ms: 500, textKey: Key('leave-$key'), text: (x) => _n(x), style: _heroNum),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE)))),
          ]),
        );
    Widget bar() => Container(width: 1, height: 30, color: const Color(0x33FFFFFF));
    Widget tab(int i, String key, String en, String mr, {int? n}) => Expanded(
          child: GestureDetector(
            key: Key('leave-t-$key'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => tabIn = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: part == i ? sk.blank : Colors.transparent, borderRadius: BorderRadius.circular(99), border: Border.all(color: part == i ? const Color(0xFFDDAD40).withValues(alpha: .75) : Colors.transparent, width: 1.2)),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: part == i ? sk.ink : sk.faint)),
                  if (n != null && n > 0) Padding(padding: const EdgeInsets.only(left: 5), child: m.Text('$n', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: sk.link))),
                ]),
              ),
            ),
          ),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'Leave', mr: 'रजा', pill: headPill(monthName(today)), height: 64, back: !widget.embedded),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('leave-page'), padding: EdgeInsets.fromLTRB(16, 6, 16, 40 + MediaQuery.paddingOf(context).bottom), children: [ // (3.154.0: its end stands clear of the bar that floats over the page)
                // (3.155.0, his choice of 21-11-2026 – "b ok ahe he fix") THE CARD: his balance large in gold, "+ Apply" on it, and
                // in one strip what was added this month, what was used, how many requests
                leaveHero(
                  key: const Key('leave-hero'),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          const Text('Leave balance', mr: 'रजा शिल्लक', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE))),
                          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBEBB5), Color(0xFFE6B94E), Color(0xFFB8860B)], stops: <double>[0, .6, 1]).createShader(r),
                              child: me == null ? m.Text('–', key: const Key('leave-bal'), style: _heroBig) : CountUp(value: _num(me?['balance']), ms: 500, textKey: const Key('leave-bal'), text: (x) => _n(x), style: _heroBig),
                            ),
                            const SizedBox(width: 7),
                            const Text('days', mr: 'दिवस', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE))),
                          ]),
                          if (book) m.Text(_t('Paid leave ${_n(me?['paid'])} · Comp-off ${_n(me?['comp'])}', 'Paid रजा ${_n(me?['paid'])} · Comp-off ${_n(me?['comp'])}'), key: const Key('leave-two'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFF3D889))),
                        ]),
                      ),
                      if (me != null)
                        GestureDetector(
                          key: const Key('leave-new'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _new,
                          child: Bounce(
                            to: .94,
                            child: Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(gradient: Sk.goldFill, borderRadius: BorderRadius.circular(21), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 14, offset: Offset(0, 7))]),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.add_rounded, size: 19, color: Sk.goldInk),
                                const SizedBox(width: 4),
                                Text('Apply', mr: 'अर्ज', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w800, color: Sk.goldInk)),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
                      decoration: BoxDecoration(color: const Color(0x17FFFFFF), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0x29FFFFFF))),
                      child: Row(children: [
                        stat('add', month['credit'], 'Added this month', 'या महिन्यात जमा'),
                        bar(),
                        stat('used', month['used'], 'Used', 'वापरली'),
                        bar(),
                        stat('n', reqs.length, 'Requests', 'विनंत्या'),
                      ]),
                    ),
                  ]),
                ),
                if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true, help: false, key: const Key('leave-err'))),
                if (me != null) ...[
                  // the parts of the page: his requests, the ledger (a person with a leave policy), how it is counted
                  Container(
                    margin: const EdgeInsets.only(top: 16, bottom: 12),
                    padding: const EdgeInsets.all(5),
                    decoration: sk.box(radius: 99),
                    child: Row(children: [
                      tab(0, 'req', 'Requests', 'विनंत्या', n: reqs.length),
                      if (book) tab(1, 'led', 'Ledger', 'हिशोब'),
                      tab(2, 'how', 'Rules', 'नियम'),
                    ]),
                  ),
                  if (part == 0)
                    Column(key: const Key('leave-mine'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (reqs.isEmpty) hrCard([Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('No request yet.', mr: 'अजून विनंती नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint)))]),
                      for (final (i, q) in reqs.indexed)
                        // (3.147.0) a touch opens the request: where it stands and who it waits for, its history, change, delete
                        Rise(
                          order: i < 4 ? i : 4,
                          child: GestureDetector(
                            key: Key('lv-open-${q['id']}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _open(q),
                            child: leaveCard(q, key: Key('lv-${q['id']}'), onPapers: () => _papers(q)),
                          ),
                        ),
                    ]),
                  if (part == 1)
                    hrCard(key: const Key('leave-ledger'), [
                      hrTitle('My leave ledger', 'माझ्या रजेचा हिशोब'),
                      if (ledger.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Nothing added or used yet.', mr: 'अजून काही जमा किंवा वापर नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint))),
                      for (final (i, l) in ledger.indexed)
                        reqRow(
                            key: Key('lg-$i'),
                            main: '${l['text'] ?? ''}'.isEmpty ? _t('Leave', 'रजा') : '${l['text']}',
                            small: '${_dmy('${l['day'] ?? ''}')} · ${'${l['bucket']}' == 'comp' ? 'Comp-off' : _t('Paid leave', 'Paid रजा')}',
                            chips: [stateChip('${_num(l['days']) > 0 ? '+' : ''}${_n(l['days'])}', _num(l['days']) > 0 ? 'a' : 'x')],
                            last: i == ledger.length - 1),
                    ]),
                  if (part == 2)
                    Container(
                      key: const Key('leave-how'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFFDDAD40).withValues(alpha: .08), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDDAD40).withValues(alpha: .55))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.info_outline_rounded, size: 19, color: sk.link),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text('How it is counted', mr: 'कशी मोजली जाते', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink)),
                            const SizedBox(height: 3),
                            m.Text(_how(me?['policy'] as Map?), style: TextStyle(fontSize: 13, color: sk.muted, height: 1.5)),
                          ]),
                        ),
                      ]),
                    ),
                ],
              ]),
            ),
    );
  }

  /// the part of the page that is open: 0 his requests, 1 the ledger, 2 how it is counted
  int tabIn = 0;
  static const _heroNum = TextStyle(fontFamily: 'Montserrat', fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF7DE8E), height: 1.15);
  static const _heroBig = TextStyle(fontFamily: 'Montserrat', fontSize: 46, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1);
}

/// APPLY FOR LEAVE – the form. Gives the server's answer (his leave, read again) when it was sent.
class LeaveAskScreen extends StatefulWidget {
  const LeaveAskScreen({super.key, required this.ask, required this.today, this.available, this.paper = false});
  final HrAsk ask;
  final String today;
  final Object? available;

  /// (3.147.0) the server asks a paper with every leave
  final bool paper;
  @override
  State<LeaveAskScreen> createState() => _LeaveAskScreenState();
}

class _LeaveAskScreenState extends State<LeaveAskScreen> {
  late String from = widget.today, to = widget.today;
  String part = 'full', err = '';
  final why = TextEditingController();
  final papers = <LeavePaper>[];
  bool busy = false;

  @override
  void dispose() {
    why.dispose();
    super.dispose();
  }

  Future<void> _addPaper() async {
    if (busy || papers.length >= 5) return;
    try {
      final p = await pickLeavePaper(context);
      if (p != null && mounted) setState(() => papers.add(p));
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
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
      if (widget.paper && papers.isEmpty) throw ApiError(_t('Attach a paper (a photo or a PDF) – a leave is not sent without it.', 'कागद जोडा (photo किंवा PDF) – त्याशिवाय रजा पाठवली जात नाही.'));
      final files = widget.paper ? await sendLeavePapers(context, widget.ask, papers) : null;
      final j = await widget.ask({'action': 'leaveAsk', 'from': from, 'to': to, 'part': part, 'reason': why.text.trim(), if (files != null) 'files': files});
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
              decoration: BoxDecoration(color: part == v ? sk.blank : sk.card, borderRadius: BorderRadius.circular(99), border: Border.all(color: part == v ? const Color(0xFFDDAD40) : sk.line, width: part == v ? 1.4 : 1)),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(en, mr: mr, maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: part == v ? sk.ink : sk.faint))),
            ),
          ),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'Apply for leave', mr: 'रजेसाठी अर्ज', height: 64),
      body: SingleChildScrollView(
        key: const Key('leave-ask-page'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          // (3.155.0) his balance now and what it is after approval, at the top – it follows the days he chooses
          leaveHero(
            key: const Key('leave-after'),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                const Text('Balance now', mr: 'आत्ताची शिल्लक', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE))),
                m.Text(_n(have), key: const Key('la-now'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
              ]),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFFF2CC62)),
                  m.Text('− ${_n(days)} ${_t(days == 1 || days == .5 ? 'day' : 'days', 'दिवस')}', key: const Key('la-days'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFF3D889))),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                const Text('After approval', mr: 'मंजुरीनंतर', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE))),
                m.Text(_n(have - days), key: const Key('la-after'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFF2CC62), height: 1.15)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
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
              '${_t('${_n(days)} ${days == 1 || days == .5 ? 'day' : 'days'}', '${_n(days)} दिवस')}'
              '${to != from ? ' · ${_t('a weekly off or a holiday inside is not counted.', 'मधली साप्ताहिक सुट्टी किंवा holiday मोजली जात नाही.')}' : ''}'),
          // (3.147.0) the paper – needed with every leave
          if (widget.paper) ...[
            const SizedBox(height: 14),
            leavePaperBox(papers: papers, busy: busy, onAdd: _addPaper, onRemove: (i) => setState(() => papers.removeAt(i))),
          ],
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, key: const Key('leave-err'), style: const TextStyle(color: C.red, fontSize: 13.5, height: 1.35))),
          const SizedBox(height: 14),
          hrButton('Send', 'पाठवा', key: const Key('leave-send'), onTap: _send, busy: busy),
        ]),
      ),
    );
  }
}

/// (3.121.0) THE PAPERS OF ONE LEAVE REQUEST: a photo or a PDF. He attaches (camera, gallery, PDF), opens and – while the request
/// still waits – removes his own (3.147.0: never the last one – the server says so); a paper the HR office attached is only opened.
class LeavePapersScreen extends StatefulWidget {
  const LeavePapersScreen({super.key, required this.ask, required this.request});
  final HrAsk ask;
  final Map request;
  @override
  State<LeavePapersScreen> createState() => _LeavePapersScreenState();
}

class _LeavePapersScreenState extends State<LeavePapersScreen> {
  Map<String, dynamic>? got;
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myLeaveFiles', 'request': widget.request['id']});
      if (!mounted) return;
      setState(() {
        got = j;
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

  Future<void> _add() async {
    if (busy) return;
    final how = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const Key('lf-camera'), leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo', mr: 'Photo काढा'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(key: const Key('lf-gallery'), leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose a photo', mr: 'Photo निवडा'), onTap: () => Navigator.pop(c, 'gallery')),
          ListTile(key: const Key('lf-pdf'), leading: const Icon(Icons.picture_as_pdf_rounded), title: const Text('Choose a PDF', mr: 'PDF निवडा'), onTap: () => Navigator.pop(c, 'pdf')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (how == null || !mounted) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final files = await pickAttFiles(how, 1);
      if (files.isNotEmpty) {
        final f = docReady(files.first.name, files.first.bytes);
        if (f == null) throw ApiError('This file could not be read – a photo or a PDF.');
        final u = await widget.ask({'action': 'myLeaveFileUrl', 'request': widget.request['id'], 'type': f.$2, 'bytes': f.$1.length});
        if (!mounted) return;
        await SessionScope.read(context).api.hrFile('${u['url']}', f.$1, f.$2);
        await widget.ask({'action': 'myLeaveFileAdd', 'request': widget.request['id'], 'path': u['path'], 'name': files.first.name, 'bytes': f.$1.length});
        await _load();
        if (mounted) donePop(context, _t('Paper attached', 'कागद जोडला'));
      }
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _open(Map f) async {
    try {
      final j = await widget.ask({'action': 'myLeaveFileLink', 'file': f['id']});
      await launchUrl(Uri.parse('${j['url']}'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  Future<void> _remove(Map f) async {
    if (busy || !await ask(context, _t('Remove this paper?', 'हा कागद काढायचा?'), '${f['name'] ?? ''}', yes: _t('Remove', 'काढा'), danger: true) || !mounted) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await widget.ask({'action': 'myLeaveFileRemove', 'file': f['id']});
      await _load();
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final files = [for (final x in (got?['files'] as List? ?? const []).whereType<Map>()) x];
    final max = _num(got?['max']), room = got?['canAdd'] == true && files.length < max;
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'Papers of the leave', mr: 'रजेचे कागद', pill: headPill(leaveDays(widget.request)), height: 96),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 3)
          : ListView(key: const Key('lf-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
              if (room) hrButton('+ Attach a paper', '+ कागद जोडा', key: const Key('lf-add'), onTap: _add, busy: busy),
              if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('lf-err')),
              const SizedBox(height: 12),
              hrCard(key: const Key('lf-list'), [
                hrTitle('Attached', 'जोडलेले'),
                if (files.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('No paper is attached.', mr: 'कागद जोडलेला नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint, height: 1.4))),
                for (final (i, f) in files.indexed)
                  reqRow(
                      key: Key('lf-${f['id']}'),
                      main: '${f['name'] ?? ''}'.isEmpty ? ('${f['mime']}' == 'application/pdf' ? 'PDF' : 'Photo') : '${f['name']}',
                      small: '${'${f['mime']}' == 'application/pdf' ? 'PDF' : 'Photo'} · ${_dmy('${f['added_at'] ?? ''}')}',
                      chips: [
                        stateChip(_t('Open', 'उघडा'), 'w', key: Key('lf-open-${f['id']}'), onTap: () => _open(f)),
                        if (f['canRemove'] == true) stateChip(_t('Remove', 'काढा'), 'x', key: Key('lf-rm-${f['id']}'), onTap: () => _remove(f)),
                      ],
                      last: i == files.length - 1),
              ]),
              if (got != null && !room && got?['canAdd'] == true) Padding(padding: const EdgeInsets.only(top: 10), child: Text('This request holds ${_n(max)} papers – no more can be attached.', mr: 'या अर्जाला ${_n(max)} कागद आहेत – आणखी जोडता येत नाही.', style: TextStyle(fontSize: 12.5, color: sk.faint))),
            ]),
    );
  }
}


/* ───────────── (3.147.0) the request, its paper, its days ───────────── */

/// (a test) the upload of a paper without the network; null = the HR server's place (api.hrFile).
Future<void> Function(String url, Uint8List bytes, String type)? leaveUploadForTest;

/// A paper chosen for a request still to be sent – sent once (a second try sends what is kept).
class LeavePaper {
  LeavePaper(this.name, this.bytes, this.type);
  final String name;
  final Uint8List bytes;
  final String type;
  Map<String, dynamic>? sent;
}

/// The camera, the gallery or a PDF – one paper; null when he went back. Throws ApiError when it is not a photo or a PDF.
Future<LeavePaper?> pickLeavePaper(BuildContext context) async {
  final how = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(key: const Key('lp-camera'), leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo', mr: 'Photo काढा'), onTap: () => Navigator.pop(c, 'camera')),
        ListTile(key: const Key('lp-gallery'), leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose a photo', mr: 'Photo निवडा'), onTap: () => Navigator.pop(c, 'gallery')),
        ListTile(key: const Key('lp-pdf'), leading: const Icon(Icons.picture_as_pdf_rounded), title: const Text('Choose a PDF', mr: 'PDF निवडा'), onTap: () => Navigator.pop(c, 'pdf')),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (how == null) return null;
  final files = await pickAttFiles(how, 1);
  if (files.isEmpty) return null;
  final f = docReady(files.first.name, files.first.bytes);
  if (f == null) throw ApiError(_t('This file could not be read – a photo or a PDF.', 'ही file वाचता आली नाही – photo किंवा PDF द्या.'));
  return LeavePaper(files.first.name, f.$1, f.$2);
}

/// The papers to the HR server's place (myLeavePaperUrl), each once → what leaveAsk / leaveChange send as "files".
Future<List<Map<String, dynamic>>> sendLeavePapers(BuildContext context, HrAsk ask, List<LeavePaper> list) async {
  final up = leaveUploadForTest ?? SessionScope.read(context).api.hrFile;
  for (final p in list) {
    if (p.sent != null) continue;
    final u = await ask({'action': 'myLeavePaperUrl', 'type': p.type, 'bytes': p.bytes.length});
    await up('${u['url']}', p.bytes, p.type);
    p.sent = {'path': u['path'], 'name': p.name, 'bytes': p.bytes.length};
  }
  return [for (final p in list) p.sent!];
}

/// The paper part of a form: what is chosen, "+ Attach a paper" – needed with every leave.
Widget leavePaperBox({required List<LeavePaper> papers, required bool busy, required VoidCallback onAdd, required void Function(int) onRemove}) => hrField(
    'Paper (needed)',
    'कागद (आवश्यक)',
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      for (final (i, p) in papers.indexed)
        Container(
          key: Key('lp-$i'),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(color: sk.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: sk.line)),
          child: Row(children: [
            Icon(p.type == 'application/pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 20, color: sk.muted),
            const SizedBox(width: 8),
            Expanded(child: m.Text(p.name.isEmpty ? (p.type == 'application/pdf' ? 'PDF' : 'Photo') : p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: sk.ink))),
            m.Text(p.bytes.length >= 1048576 ? '${(p.bytes.length / 1048576).toStringAsFixed(1)} MB' : '${(p.bytes.length / 1024).ceil()} KB', style: TextStyle(fontSize: 12, color: sk.faint)),
            IconButton(key: Key('lp-rm-$i'), tooltip: _t('Remove', 'काढा'), onPressed: busy ? null : () => onRemove(i), icon: Icon(Icons.close_rounded, size: 20, color: sk.muted)),
          ]),
        ),
      if (papers.length < 5)
        OutlinedButton.icon(
          key: const Key('lp-add'),
          onPressed: busy ? null : onAdd,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), side: BorderSide(color: papers.isEmpty ? C.red : sk.line)),
          icon: Icon(Icons.attach_file_rounded, size: 19, color: sk.ink),
          label: Text('+ Attach a paper', mr: '+ कागद जोडा', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: sk.ink)),
        ),
      if (papers.isEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('A photo or a PDF – a doctor\'s note, a card, a ticket. A leave is not sent without it.', mr: 'Photo किंवा PDF – डॉक्टरची चिठ्ठी, पत्रिका, तिकीट. त्याशिवाय रजा पाठवली जात नाही.', style: TextStyle(fontSize: 12, color: sk.faint, height: 1.35))),
    ]));

String _role(String r) => switch (r) { 'reporting' => _t('Reporting person', 'Reporting person'), 'site_hr' => 'Site HR Admin', 'ho_hr' => 'HO HR', 'super' => 'Super Admin', 'office' => 'HR office', _ => r };

/// Who a waiting request waits for – the server's "waits" (his leave policy, else the reporting person, then the HR office).
String leaveWaits(Map q) {
  final w = q['waits'];
  if (w is! Map) return q['level'] == 1 ? _t('Waits for the reporting person', 'Reporting person कडे थांबली आहे') : _t('Waits for the HR office', 'HR office कडे थांबली आहे');
  final who = [
    for (final x in (w['who'] as List? ?? const []).whereType<Map>())
      '${x['role']}' == 'person'
          ? '${x['name'] ?? ''}'
          : '${x['name'] ?? ''}'.isNotEmpty
              ? '${x['name']} (${_role('${x['role']}')})'
              : _role('${x['role']}')
  ].join(' / ');
  return '${w['stage']}' == 'verify' ? _t('Waits for verify: $who', 'Verify साठी थांबली आहे: $who') : _t('Waits for approval: $who', 'मंजुरीसाठी थांबली आहे: $who');
}

/// The word of a request's state and its tone.
(String, String) leaveChip(Map q) => switch ('${q['status']}') {
      'approved' => (_t('Approved', 'मंजूर'), 'a'),
      'refused' => (_t('Refused', 'नाकारली'), 'x'),
      'cancelled' => (_t('Deleted', 'Delete केली'), 's'),
      _ => (_t('Waiting', 'प्रलंबित'), 'w'),
    };

Map? _lastOf(Map q, String kind) {
  final h = [for (final x in (q['history'] as List? ?? const []).whereType<Map>()) if ('${x['kind']}' == kind) x];
  return h.isEmpty ? null : h.last;
}

/// Its line under the days: where it stands now.
String leaveSmall(Map q) {
  switch ('${q['status']}') {
    case 'pending':
      return leaveWaits(q);
    case 'approved':
      final a = _lastOf(q, 'approved');
      return a == null ? _t('Approved by HR office', 'HR office ने मंजूर केले') : _t('Approved by ${a['by']}', '${a['by']} यांनी मंजूर केली');
    case 'refused':
      return '${_t('Refused', 'नाकारली')}: ${q['note'] ?? ''}';
    default:
      final d = _lastOf(q, 'deleted');
      if (d == null) return '${q['reason'] ?? ''}';
      if (d['self'] == true) return _t('Deleted by you', 'तुम्ही Delete केली');
      return [_t('Deleted by ${d['by']}', '${d['by']} यांनी Delete केली'), if ('${d['note'] ?? ''}'.isNotEmpty) '${d['note']}'].join(' · ');
  }
}

/// The navy card with gold survey lines (the Leave page's balance, the form's "now → after", a request's head).
Widget leaveHero({Key? key, required Widget child, Color edge = const Color(0x8CE6B94E), EdgeInsets padding = const EdgeInsets.fromLTRB(18, 16, 16, 16)}) => Container(
      key: key,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF070D24), Color(0xFF16286A), Color(0xFF24408A)], stops: <double>[0, .62, 1]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: edge),
        boxShadow: const [BoxShadow(color: Color(0x520B1733), blurRadius: 30, offset: Offset(0, 16))],
      ),
      child: LayoutBuilder(
        builder: (_, box) => CustomPaint(
          painter: CrestLines(eddy: Offset(box.maxWidth * .84, 44), ring: 92, color: const Color(0x47E6B94E), depth: 1),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

/// (3.155.0, asked 21-11-2026: "leave status he samjaw ki verification madhe aahe konakade aahe tyach name, approval sathi pending
/// konakade tyach name") WHERE A REQUEST STANDS, as a road: Sent → Verification → Approval, each with its person, and in words –
/// "In verification · with Ravi Patil", "Pending approval · with Amit Patil", "Approved · by …", "Rejected · by … – why". All of
/// it is what the HR server says (waits: the step and its people; history: who verified, approved, refused – and when). A leave
/// with no verification step has the road Sent → Approval. The person of a step that is still to come is not known: not written.
class LeaveRoad {
  LeaveRoad(this.steps, this.title, this.sub, this.tone, this.holder);

  /// each step: its name, its person ('' = not known yet), its state – done / now / bad / todo –, its time or what it waits for
  final List<({String name, String who, String state, String when})> steps;

  /// in words: "In verification" and "with Ravi Patil"; the tone – w (waits), a (approved), x (rejected), s (deleted)
  final String title, sub, tone;

  /// the person it is with now, or who decided it ('' = nobody to name)
  final String holder;

  /// how far it is, 0 to 1
  double get far {
    final at = steps.lastIndexWhere((x) => x.state != 'todo');
    if (steps.every((x) => x.state == 'done')) return 1;
    // (the step it stands at is not done yet: a little before its dot)
    return ((at - (steps[at].state == 'done' ? 0 : .25)) / (steps.length - 1)).clamp(.06, .95).toDouble();
  }
}

LeaveRoad leaveRoad(Map q) {
  final st = '${q['status']}', w = q['waits'] is Map ? q['waits'] as Map : null;
  final asked = _lastOf(q, 'asked'), ver = _lastOf(q, 'verified');
  String names(Map? x) => [
        for (final y in (x?['who'] as List? ?? const []).whereType<Map>())
          '${y['role']}' == 'person'
              ? '${y['name'] ?? ''}'
              : '${y['name'] ?? ''}'.isNotEmpty
                  ? '${y['name']} (${_role('${y['role']}')})'
                  : _role('${y['role']}')
      ].where((n) => n.isNotEmpty).join(' / ');
  final sent = (name: _t('Sent', 'पाठवली'), who: _t('You', 'तुम्ही'), state: 'done', when: _when(q['asked_at'] ?? asked?['at']));
  ({String name, String who, String state, String when}) step(String kind, String who, String state, String when) => (name: kind == 'v' ? _t('Verification', 'Verification') : _t('Approval', 'मंजुरी'), who: who, state: state, when: when);
  final verDone = ver == null ? null : step('v', '${ver['by'] ?? ''}', 'done', '${_t('Verified', 'Verify केली')} · ${_when(ver['at'])}');
  switch (st) {
    case 'pending':
      final stage = w != null ? '${w['stage']}' : (q['level'] == 1 ? 'verify' : 'approve');
      final who = w != null ? names(w) : (q['level'] == 1 ? _t('the reporting person', 'Reporting person') : _t('the HR office', 'HR office'));
      final sub = _t('with $who', '$who कडे');
      if (stage == 'verify') {
        return LeaveRoad([sent, step('v', who, 'now', _t('Waiting', 'प्रलंबित')), step('a', '', 'todo', _t('After verification', 'Verification नंतर'))], _t('In verification', 'Verification मध्ये'), sub, 'w', who);
      }
      return LeaveRoad([sent, if (verDone != null) verDone, step('a', who, 'now', _t('Waiting', 'प्रलंबित'))], _t('Pending approval', 'मंजुरीसाठी प्रलंबित'), sub, 'w', who);
    case 'approved':
      final a = _lastOf(q, 'approved'), by = a == null ? _t('HR office', 'HR office') : '${a['by'] ?? ''}';
      return LeaveRoad([sent, if (verDone != null) verDone, step('a', by, 'done', '${_t('Approved', 'मंजूर')}${a == null ? '' : ' · ${_when(a['at'])}'}')], _t('Approved', 'मंजूर'), _t('by $by', '$by यांनी'), 'a', by);
    case 'refused':
      final r = _lastOf(q, 'refused'), by = '${r?['by'] ?? ''}', why = '${q['note'] ?? ''}';
      // refused where it stood: at the verification when nobody had verified it and it waited there, else at the approval
      final atVerify = ver == null && q['level'] == 1;
      final bad = step(atVerify ? 'v' : 'a', by, 'bad', '${_t('Rejected', 'नाकारली')}${r == null ? '' : ' · ${_when(r['at'])}'}');
      return LeaveRoad([sent, if (verDone != null) verDone, bad, if (atVerify) step('a', '', 'todo', '')], _t('Rejected', 'नाकारली'), [if (by.isNotEmpty) _t('by $by', '$by यांनी'), if (why.isNotEmpty) '“$why”'].join(' – '), 'x', by);
    default:
      return LeaveRoad([sent, if (verDone != null) verDone, step('a', '', 'todo', '')], _t('Deleted', 'Delete केली'), leaveSmall(q), 's', '');
  }
}

const _roadGold = Color(0xFFDDAD40), _roadRed = Color(0xFFE5484D);

/// The road in a row: a dot for each step, joined by a line – gold as far as it has come, red where it was rejected.
Widget leaveTrack(LeaveRoad road) {
  final n = road.steps.length;
  Color line(String state) => state == 'bad' ? _roadRed : state == 'todo' ? sk.hair : _roadGold;
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    for (final (i, x) in road.steps.indexed)
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 30,
            child: Row(children: [
              Expanded(child: Container(height: 3, color: i == 0 ? Colors.transparent : line(x.state))),
              Container(
                width: x.state == 'now' ? 26 : 22,
                height: x.state == 'now' ? 26 : 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: x.state == 'done' ? Sk.goldFill : null,
                  color: x.state == 'bad' ? _roadRed : x.state == 'done' ? null : sk.card,
                  border: Border.all(color: x.state == 'todo' ? (sk.cardLine ?? sk.line) : x.state == 'bad' ? _roadRed : _roadGold, width: 2),
                  boxShadow: x.state == 'now' ? [BoxShadow(color: _roadGold.withValues(alpha: .28), spreadRadius: 4)] : null,
                ),
                child: x.state == 'done'
                    ? const Icon(Icons.check_rounded, size: 13, color: Sk.goldInk)
                    : x.state == 'bad'
                        ? const Icon(Icons.close_rounded, size: 13, color: Colors.white)
                        : x.state == 'now'
                            ? Container(width: 9, height: 9, decoration: const BoxDecoration(color: _roadGold, shape: BoxShape.circle))
                            : null,
              ),
              Expanded(child: Container(height: 3, color: i == n - 1 ? Colors.transparent : line(road.steps[i + 1].state))),
            ]),
          ),
          const SizedBox(height: 4),
          m.Text(x.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: x.state == 'now' ? sk.link : x.state == 'bad' ? (sk.dark ? const Color(0xFFFF7A70) : const Color(0xFFC22A1B)) : x.state == 'todo' ? sk.faint : sk.ink)),
          if (x.who.isNotEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: m.Text(x.who, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, height: 1.2, fontWeight: x.state == 'now' || x.state == 'bad' ? FontWeight.w600 : FontWeight.w400, color: x.state == 'now' || x.state == 'bad' ? sk.ink : sk.muted))),
        ]),
      ),
  ]);
}

/// The first letters of the person a request is with (a role: its first letters).
Widget _roadFace(String who, {double size = 34}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF24408A), Color(0xFF0B1733)]), border: Border.all(color: _roadGold, width: 1.5)),
      child: who.isEmpty ? Icon(Icons.person_outline_rounded, size: size * .5, color: const Color(0xFFF3D889)) : m.Text(initials(who.split('(').first.split('/').first), style: TextStyle(fontFamily: 'Montserrat', fontSize: size * .35, fontWeight: FontWeight.w800, color: const Color(0xFFF3D889))),
    );

(Color, Color, Color) _roadTone(String tone) => switch (tone) {
      'a' => (sk.dark ? const Color(0xFF58D68D) : const Color(0xFF0F7A45), const Color(0xFF0F7A45).withValues(alpha: sk.dark ? .16 : .1), const Color(0xFF0F7A45).withValues(alpha: .35)),
      'x' => (sk.dark ? const Color(0xFFFF7A70) : const Color(0xFFC22A1B), const Color(0xFFC22A1B).withValues(alpha: sk.dark ? .16 : .09), const Color(0xFFC22A1B).withValues(alpha: .35)),
      's' => (sk.muted, sk.blank, sk.cardLine ?? sk.line),
      _ => (sk.link, _roadGold.withValues(alpha: .13), _roadGold.withValues(alpha: .45)),
    };

/// One request on the Leave page: its days, its reason, its papers, the road, and in words who it is with.
Widget leaveCard(Map q, {Key? key, VoidCallback? onPapers}) {
  final road = leaveRoad(q), tone = _roadTone(road.tone), from = '${q['from'] ?? ''}', d = DateTime.tryParse('${from}T00:00:00Z');
  const mon = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return Container(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: sk.box(radius: 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Container(
          width: 46,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(14), border: Border.all(color: _roadGold.withValues(alpha: .45))),
          child: d == null
              ? Icon(Icons.event_rounded, size: 20, color: sk.link)
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  m.Text(d.day.toString().padLeft(2, '0'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: sk.ink, height: 1)),
                  const SizedBox(height: 2),
                  m.Text(mon[d.month - 1], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5, color: sk.link, height: 1)),
                ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            m.Text(leaveDays(q), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 14, fontWeight: FontWeight.w800, color: sk.ink)),
            if ('${q['reason'] ?? ''}'.isNotEmpty) m.Text('${q['reason']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted)),
          ]),
        ),
        // (3.121.0) the papers of the request – only when the server keeps them (step 13)
        if (q['files'] is num && '${q['status']}' != 'cancelled')
          GestureDetector(
            key: Key('lv-files-${q['id']}'),
            behavior: HitTestBehavior.opaque,
            onTap: onPapers,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.attach_file_rounded, size: 15, color: sk.muted),
                m.Text((q['files'] as num) > 0 ? _t('Papers ${_n(q['files'])}', 'कागद ${_n(q['files'])}') : _t('+ Paper', '+ कागद'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sk.muted)),
              ]),
            ),
          ),
        Icon(Icons.chevron_right_rounded, size: 20, color: sk.blankInk),
      ]),
      Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 10), child: leaveTrack(road)),
      Container(
        key: Key('lv-state-${q['id']}'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: tone.$2, borderRadius: BorderRadius.circular(16), border: Border.all(color: tone.$3)),
        child: Row(children: [
          _roadFace(road.holder),
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

String _when(Object? at) {
  final d = DateTime.tryParse('${at ?? ''}');
  if (d == null) return '';
  final i = d.toUtc().add(const Duration(hours: 5, minutes: 30));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(i.day)}-${two(i.month)}-${i.year} ${two(i.hour)}:${two(i.minute)}';
}

String _range(Object? from, Object? to, Object? days) {
  final a = '${from ?? ''}', b = '${to ?? a}';
  if (a.isEmpty) return '';
  return '${_dmy(a)}${b != a && b.isNotEmpty ? ' – ${_dmy(b)}' : ''}${days != null ? ' (${_n(days)})' : ''}';
}

/// One line of the history: (what, who · when · the days).
(String, String) leaveLine(Map h) {
  final k = '${h['kind']}';
  final what = switch (k) {
    'asked' => _t('Asked', 'अर्ज केला'),
    'extension' => _t('Asked – the extra days of a leave', 'अर्ज – रजेचे वाढीव दिवस'),
    'verified' => _t('Verified', 'Verify केली'),
    'approved' => _t('Approved', 'मंजूर केली'),
    'refused' => _t('Refused', 'नाकारली'),
    'shortened' => _t('Made shorter', 'दिवस कमी केले'),
    'extended' => _t('Made longer – the extra days asked', 'दिवस वाढवले – वाढीव दिवसांचा अर्ज'),
    'edited' => _t('Changed by the HR office', 'HR office ने बदलली'),
    'deleted' => _t('Deleted', 'Delete केली'),
    _ => k,
  };
  final was = h['was'] is Map ? h['was'] as Map : null;
  final days = switch (k) {
    'asked' || 'extension' => _range(h['from'], h['to'], h['days']),
    'shortened' || 'edited' => '${_range(was?['from'], was?['to'], was?['days'])} → ${_range(h['from'], h['to'], h['days'])}',
    'extended' => '+ ${_range(h['from'], h['to'], h['days'])}',
    _ => '',
  };
  final who = h['self'] == true ? _t('you', 'तुम्ही') : '${h['by'] ?? ''}';
  return (what, [who, _when(h['at']), days, if (k != 'asked' && k != 'extension' && '${h['note'] ?? ''}'.isNotEmpty) '${h['note']}'].where((x) => x.isNotEmpty).join(' · '));
}

/// ONE REQUEST OF HIS: where it stands and who it waits for, its history; Change days, Delete, its papers. Pops with what to say.
class LeaveDetailScreen extends StatefulWidget {
  const LeaveDetailScreen({super.key, required this.ask, required this.request, required this.today, this.paper = false});
  final HrAsk ask;
  final Map request;
  final String today;
  final bool paper;
  @override
  State<LeaveDetailScreen> createState() => _LeaveDetailScreenState();
}

class _LeaveDetailScreenState extends State<LeaveDetailScreen> {
  late Map q = widget.request;
  bool busy = false;
  String err = '';

  // a server of before has no "can": a waiting one is deleted; the days are not changed there
  Map get _can => q['can'] is Map ? q['can'] as Map : {'delete': '${q['status']}' == 'pending', 'change': false};

  Future<void> _delete() async {
    if (busy || !await ask(context, _t('Delete this leave?', 'ही रजा Delete करायची?'), leaveDays(q), yes: _t('Delete', 'Delete करा'), danger: true) || !mounted) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await widget.ask({'action': 'leaveCancel', 'id': q['id']});
      if (mounted) Navigator.of(context).pop(_t('Leave deleted', 'रजा Delete केली'));
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _change() async {
    final j = await Navigator.of(context).push<Map<String, dynamic>>(hrRoute(LeaveChangeScreen(ask: widget.ask, request: q, today: widget.today, paper: widget.paper)));
    if (j == null || !mounted) return;
    final c = j['changed'] is Map ? j['changed'] as Map : const {};
    Navigator.of(context).pop('${c['kind']}' == 'longer' ? _t('The extra days are sent for approval', 'वाढीव दिवस मंजुरीसाठी पाठवले') : _t('Leave made shorter', 'रजेचे दिवस कमी केले'));
  }

  Future<void> _papers() async {
    await Navigator.of(context).push<void>(hrRoute(LeavePapersScreen(ask: widget.ask, request: q)));
  }

  @override
  Widget build(BuildContext context) {
    final hist = [for (final x in (q['history'] as List? ?? const []).whereType<Map>()) x], road = leaveRoad(q), tone = _roadTone(road.tone);
    final bad = road.tone == 'x';
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'My leave', mr: 'माझी रजा', pill: headPill(leaveDays(q)), height: 96),
      body: ListView(key: const Key('lvd-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        // (3.155.0) WHO IT IS WITH NOW – his name large –, and how far it has come
        leaveHero(
          key: const Key('lvd-stand'),
          edge: bad ? const Color(0xB3E5484D) : const Color(0x8CE6B94E),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: _roadGold.withValues(alpha: .2), spreadRadius: 5)]), child: _roadFace(road.holder, size: 54)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  m.Text(road.title.toUpperCase(), key: const Key('lvd-state'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: bad ? const Color(0xFFFF9A92) : const Color(0xFFF3D889))),
                  const SizedBox(height: 2),
                  m.Text(road.sub.isEmpty ? road.title : '${road.sub[0].toUpperCase()}${road.sub.substring(1)}', key: const Key('lvd-waits'), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
                  if ('${q['reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: m.Text('${_t('Reason', 'कारण')}: ${q['reason']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xFFC9D3EE), height: 1.3))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 7, color: const Color(0x24FFFFFF)),
                FractionallySizedBox(widthFactor: road.far, child: Container(height: 7, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFC9960A), bad ? _roadRed : const Color(0xFFF7DE8E)]), borderRadius: BorderRadius.circular(4)))),
              ]),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final x in road.steps) m.Text(x.name, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFC9D3EE)))]),
          ]),
        ),
        const SizedBox(height: 14),
        // the road, step by step: the person of each step and its time
        hrCard(key: const Key('lvd-road'), [
          hrTitle('Where it stands', 'सध्याची स्थिती'),
          for (final (i, x) in road.steps.indexed)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Column(children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: x.state == 'done' ? Sk.goldFill : null, color: x.state == 'bad' ? _roadRed : x.state == 'done' ? null : sk.card, border: Border.all(color: x.state == 'todo' ? (sk.cardLine ?? sk.line) : x.state == 'bad' ? _roadRed : _roadGold, width: 2)),
                    child: Icon(x.state == 'done' ? Icons.check_rounded : x.state == 'bad' ? Icons.close_rounded : x.state == 'now' ? Icons.schedule_rounded : Icons.more_horiz_rounded, size: 14, color: x.state == 'done' ? Sk.goldInk : x.state == 'bad' ? Colors.white : x.state == 'now' ? sk.link : sk.faint),
                  ),
                  if (i < road.steps.length - 1) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: x.state == 'done' ? _roadGold.withValues(alpha: .6) : sk.hair)),
                ]),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 3, bottom: i < road.steps.length - 1 ? 16 : 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      m.Text(x.name, style: TextStyle(fontFamily: 'Montserrat', fontSize: 13.5, fontWeight: FontWeight.w800, color: x.state == 'todo' ? sk.faint : x.state == 'bad' ? tone.$1 : sk.ink)),
                      if (i > 0 && x.who.isNotEmpty)
                        Container(
                          key: Key('lvd-who-$i'),
                          margin: const EdgeInsets.only(top: 7, bottom: 5),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: x.state == 'now' ? _roadGold.withValues(alpha: .1) : x.state == 'bad' ? _roadRed.withValues(alpha: .08) : sk.blank, borderRadius: BorderRadius.circular(14), border: x.state == 'now' ? Border.all(color: _roadGold.withValues(alpha: .5)) : x.state == 'bad' ? Border.all(color: _roadRed.withValues(alpha: .35)) : null),
                          child: Row(children: [_roadFace(x.who, size: 32), const SizedBox(width: 10), Expanded(child: m.Text(x.who, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sk.ink, height: 1.25)))]),
                        ),
                      if (x.when.isNotEmpty) m.Text(i == 0 ? '${x.when} · ${_t('by you', 'तुम्ही')}' : x.when, style: TextStyle(fontSize: 12, height: 1.3, fontWeight: x.state == 'now' || x.state == 'bad' ? FontWeight.w600 : FontWeight.w400, color: x.state == 'now' ? sk.link : x.state == 'bad' ? tone.$1 : sk.muted)),
                      if (x.state == 'bad' && '${q['note'] ?? ''}'.isNotEmpty) m.Text('“${q['note']}”', style: TextStyle(fontSize: 12.5, height: 1.3, color: tone.$1)),
                    ]),
                  ),
                ),
              ]),
            ),
        ]),
        if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('lvd-err')),
        const SizedBox(height: 12),
        if (_can['change'] == true) ...[hrButton('Change days', 'दिवस बदला', key: const Key('lvd-change'), onTap: busy ? null : _change), const SizedBox(height: 10)],
        if (_can['delete'] == true)
          FilledButton.icon(
            key: const Key('lvd-delete'),
            onPressed: busy ? null : _delete,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), elevation: 0, backgroundColor: sk.dark ? const Color(0xFF2A1A28) : const Color(0xFFFBE4E1), foregroundColor: sk.dark ? const Color(0xFFFF7A70) : C.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete this leave', mr: 'ही रजा Delete करा', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        if ('${q['status']}' == 'approved' && _can['delete'] != true) Padding(padding: const EdgeInsets.only(top: 4), child: Text('An approved leave is deleted by the HR office.', mr: 'मंजूर रजा HR office Delete करते.', style: TextStyle(fontSize: 12.5, color: sk.faint))),
        if (q['files'] is num && '${q['status']}' != 'cancelled') ...[
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: stateChip((q['files'] as num) > 0 ? _t('Papers ${_n(q['files'])}', 'कागद ${_n(q['files'])}') : _t('+ Paper', '+ कागद'), 'w', key: const Key('lvd-files'), onTap: _papers)),
        ],
        const SizedBox(height: 12),
        hrCard(key: const Key('lvd-history'), [
          hrTitle('History', 'इतिहास'),
          if (hist.isEmpty) reqRow(key: const Key('lvh-0'), main: _t('Asked', 'अर्ज केला'), small: [_when(q['asked_at']), leaveDays(q)].where((x) => x.isNotEmpty).join(' · '), chips: const [], last: true),
          for (final (i, h) in hist.indexed)
            () {
              final l = leaveLine(h);
              return reqRow(key: Key('lvh-$i'), main: l.$1, small: l.$2, chips: const [], last: i == hist.length - 1);
            }(),
        ]),
      ]),
    );
  }
}

/// CHANGE THE DAYS OF HIS LEAVE: shorter – saved at once (only days from today on); longer at one end – the extra days are a new
/// request (reason and paper) that waits for approval. "Back at work today" fills the days in one touch. Pops with the server's answer.
class LeaveChangeScreen extends StatefulWidget {
  const LeaveChangeScreen({super.key, required this.ask, required this.request, required this.today, this.paper = false});
  final HrAsk ask;
  final Map request;
  final String today;
  final bool paper;
  @override
  State<LeaveChangeScreen> createState() => _LeaveChangeScreenState();
}

class _LeaveChangeScreenState extends State<LeaveChangeScreen> {
  late final String f0 = '${widget.request['from']}', t0 = '${widget.request['to'] ?? widget.request['from']}';
  late String from = f0, to = t0;
  String err = '';
  bool busy = false;
  final why = TextEditingController();
  final papers = <LeavePaper>[];

  @override
  void dispose() {
    why.dispose();
    super.dispose();
  }

  static String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String _add(String ymd, int n) => _ymd(DateTime.parse('${ymd}T00:00:00Z').add(Duration(days: n)));

  // what the new days are: same / shorter / longer / mixed
  String get _kind {
    if (from == f0 && to == t0) return 'same';
    if (from.compareTo(f0) >= 0 && to.compareTo(t0) <= 0) return 'shorter';
    if (from.compareTo(f0) <= 0 && to.compareTo(t0) >= 0 && !(from.compareTo(f0) < 0 && to.compareTo(t0) > 0)) return 'longer';
    return 'mixed';
  }

  // "Back at work today": the leave ends yesterday – or, begun today, starts tomorrow; null when nothing of it is left then
  (String, String)? get _back {
    final today = widget.today;
    if (f0.compareTo(today) < 0 && t0.compareTo(today) >= 0) return (f0, _add(today, -1));
    if (f0 == today && t0.compareTo(today) > 0) return (_add(today, 1), t0);
    return null;
  }

  Future<void> _pick(bool isFrom) async {
    final t = DateTime.parse('${widget.today}T00:00:00'), y = t.subtract(const Duration(days: 1)), f = DateTime.parse('${from}T00:00:00');
    final first = isFrom ? t : (f.isAfter(y) ? f : y);
    final cur = DateTime.parse('${isFrom ? from : to}T00:00:00');
    final d = await showDatePicker(context: context, initialDate: cur.isBefore(first) ? first : cur, firstDate: first, lastDate: (isFrom ? t : f).add(Duration(days: isFrom ? 366 : 61)));
    if (d == null || !mounted) return;
    setState(() {
      if (isFrom) {
        from = _ymd(d);
        if (to.compareTo(from) < 0) to = from;
      } else {
        to = _ymd(d);
      }
      err = '';
    });
  }

  Future<void> _save() async {
    if (busy) return;
    final k = _kind;
    if (k == 'same' || k == 'mixed') {
      setState(() => err = k == 'same' ? _t('Choose the new days first.', 'आधी नवे दिवस निवडा.') : _t('Make it shorter, or longer – one at a time.', 'दिवस कमी करा किंवा वाढवा – एका वेळी एकच.'));
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      List<Map<String, dynamic>>? files;
      if (k == 'longer' && widget.paper) {
        if (papers.isEmpty) throw ApiError(_t('Attach a paper (a photo or a PDF) – the extra days are not sent without it.', 'कागद जोडा (photo किंवा PDF) – त्याशिवाय वाढीव दिवस पाठवले जात नाहीत.'));
        files = await sendLeavePapers(context, widget.ask, papers);
      }
      final j = await widget.ask({'action': 'leaveChange', 'id': widget.request['id'], 'from': from, 'to': to, if (k == 'longer') 'reason': why.text.trim(), if (files != null) 'files': files});
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
    final k = _kind, back = _back, approved = '${widget.request['status']}' == 'approved', begun = f0.compareTo(widget.today) < 0;
    final ex = k == 'longer' ? (from.compareTo(f0) < 0 ? _range(from, _add(f0, -1), null) : _range(_add(t0, 1), to, null)) : '';
    Widget day(String key, String ymd, bool isFrom, bool on) => GestureDetector(
          key: Key(key),
          behavior: HitTestBehavior.opaque,
          onTap: busy || !on ? null : () => _pick(isFrom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(color: on ? sk.card : sk.line.withValues(alpha: .35), borderRadius: BorderRadius.circular(14), border: Border.all(color: sk.line)),
            child: Row(children: [Expanded(child: m.Text(_dmy(ymd), style: TextStyle(fontSize: 15, color: on ? sk.ink : sk.faint))), Icon(on ? Icons.calendar_month_rounded : Icons.lock_outline_rounded, size: 19, color: sk.faint)]),
          ),
        );
    final note = switch (k) {
      'shorter' => approved ? _t('Shorter – saved at once. It stays approved; the days taken off are work days again.', 'कमी – लगेच save होईल. रजा मंजूरच राहते; काढलेले दिवस परत कामाचे होतात.') : _t('Shorter – saved at once. It still waits for approval.', 'कमी – लगेच save होईल. रजा अजून मंजुरीसाठी थांबलेलीच राहते.'),
      'longer' => _t('Longer – the extra days $ex are a new request: it waits for approval. The days you have now stay as they are.', 'वाढ – वाढीव दिवस $ex हा नवा अर्ज: तो मंजुरीसाठी थांबेल. आताचे दिवस आहेत तसेच राहतात.'),
      'mixed' => _t('Make it shorter, or longer – one at a time.', 'दिवस कमी करा किंवा वाढवा – एका वेळी एकच.'),
      _ => _t('Choose the new days. A day gone stays as it is.', 'नवे दिवस निवडा. गेलेला दिवस आहे तसाच राहतो.'),
    };
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'Change days', mr: 'दिवस बदला', pill: headPill(_range(f0, t0, null)), height: 96),
      body: SingleChildScrollView(
        key: const Key('lc-page'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          // his case: "1 to 10, back on the 5th" – one touch
          if (back != null) ...[
            OutlinedButton.icon(
              key: const Key('lc-back'),
              onPressed: busy ? null : () => setState(() {
                from = back.$1;
                to = back.$2;
                err = '';
              }),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: sk.accent)),
              icon: Icon(Icons.work_history_rounded, color: sk.ink),
              label: m.Text(_t('Back at work today – leave ${_range(back.$1, back.$2, null)}', 'आज कामावर परत – रजा ${_range(back.$1, back.$2, null)}'), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: sk.ink)),
            ),
            const SizedBox(height: 14),
          ],
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: hrField('From', 'पासून', day('lc-from', from, true, !begun))),
            const SizedBox(width: 10),
            Expanded(child: hrField('To', 'पर्यंत', day('lc-to', to, false, true))),
          ]),
          const SizedBox(height: 12),
          hrNote(note, key: const Key('lc-note'), warm: k != 'shorter'),
          if (k == 'longer') ...[
            const SizedBox(height: 14),
            hrField('Reason for the extra days', 'वाढीव दिवसांचे कारण', TextField(key: const Key('lc-why'), controller: why, maxLines: 2, minLines: 2, maxLength: 200, style: const TextStyle(fontSize: 15), decoration: hrInput(hint: _t('Why', 'का')).copyWith(counterText: ''))),
            if (widget.paper) ...[
              const SizedBox(height: 12),
              leavePaperBox(
                  papers: papers,
                  busy: busy,
                  onAdd: () async {
                    try {
                      final p = await pickLeavePaper(context);
                      if (p != null && mounted) setState(() => papers.add(p));
                    } catch (e) {
                      if (mounted) setState(() => err = errText(e));
                    }
                  },
                  onRemove: (i) => setState(() => papers.removeAt(i))),
            ],
          ],
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, key: const Key('lc-err'), style: const TextStyle(color: C.red, fontSize: 13.5, height: 1.35))),
          const SizedBox(height: 14),
          hrButton(k == 'longer' ? 'Send the extra days' : 'Save', k == 'longer' ? 'वाढीव दिवस पाठवा' : 'Save करा', key: const Key('lc-save'), onTap: _save, busy: busy),
        ]),
      ),
    );
  }
}
