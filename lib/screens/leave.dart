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
    final ledger = [for (final x in (me?['ledger'] as List? ?? const []).whereType<Map>()) x];
    Widget box(String key, Object? v, String en, String mr) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            padding: const EdgeInsets.fromLTRB(12, 9, 8, 10),
            decoration: BoxDecoration(color: sk.headGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: sk.headGlassLine), boxShadow: sk.classic ? null : sk.shadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // (3.122.0) the number counts up to its value
              me == null ? m.Text('–', key: Key('leave-$key'), maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.w800, color: sk.onHead, height: 1.15)) : CountUp(value: _num(v), ms: 500, textKey: Key('leave-$key'), text: (x) => _n(x), style: TextStyle(fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.w800, color: sk.onHead, height: 1.15)),
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
              child: ListView(key: const Key('leave-page'), padding: EdgeInsets.fromLTRB(16, 14, 16, 40 + MediaQuery.paddingOf(context).bottom), children: [ // (3.154.0: its end stands clear of the bar that floats over the page)
                if (me != null) hrButton('+ Apply for leave', '+ रजेसाठी अर्ज', key: const Key('leave-new'), onTap: _new),
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('leave-err')),
                if (me != null) ...[
                  const SizedBox(height: 12),
                  Rise(order: 0, child: hrCard(key: const Key('leave-mine'), [
                    hrTitle('My requests', 'माझ्या विनंत्या'),
                    if (reqs.isEmpty) Padding(padding: EdgeInsets.only(bottom: 6), child: Text('No request yet.', mr: 'अजून विनंती नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint))),
                    for (final (i, q) in reqs.indexed)
                      () {
                        final s = leaveChip(q);
                        // (3.147.0) a touch opens the request: where it stands and who it waits for, its history, change, delete
                        return GestureDetector(
                          key: Key('lv-open-${q['id']}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _open(q),
                          child: reqRow(
                              key: Key('lv-${q['id']}'),
                              main: leaveDays(q),
                              small: leaveSmall(q),
                              chips: [
                                // (3.121.0) the papers of the request – only when the server keeps them (step 13)
                                if (q['files'] is num && '${q['status']}' != 'cancelled') stateChip((q['files'] as num) > 0 ? _t('Papers ${_n(q['files'])}', 'कागद ${_n(q['files'])}') : _t('+ Paper', '+ कागद'), 'w', key: Key('lv-files-${q['id']}'), onTap: () => _papers(q)),
                                stateChip(s.$1, s.$2, key: Key('lv-state-${q['id']}'), onTap: () => _open(q)),
                              ],
                              last: i == reqs.length - 1),
                        );
                      }(),
                    if (reqs.isNotEmpty) Padding(padding: EdgeInsets.only(top: 6), child: Text('Touch a request: where it stands, its history, change its days or delete it.', mr: 'विनंतीला touch करा: ती कुठे आहे, तिचा इतिहास, दिवस बदला किंवा Delete करा.', style: TextStyle(fontSize: 12, color: sk.faint))),
                  ])),
                  if (me?['book'] == true) ...[
                    const SizedBox(height: 12),
                    Rise(order: 1, child: hrCard(key: const Key('leave-ledger'), [
                      hrTitle('My leave ledger', 'माझ्या रजेचा हिशोब'),
                      m.Text(_t('Paid leave ${_n(me?['paid'])} · Comp-off ${_n(me?['comp'])} – one balance of ${_n(me?['balance'])}', 'Paid रजा ${_n(me?['paid'])} · Comp-off ${_n(me?['comp'])} – मिळून balance ${_n(me?['balance'])}'), key: const Key('leave-two'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sk.muted, height: 1.4)),
                      const SizedBox(height: 4),
                      if (ledger.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Nothing added or used yet.', mr: 'अजून काही जमा किंवा वापर नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint))),
                      for (final (i, l) in ledger.indexed)
                        reqRow(
                            key: Key('lg-$i'),
                            main: '${l['text'] ?? ''}'.isEmpty ? _t('Leave', 'रजा') : '${l['text']}',
                            small: '${_dmy('${l['day'] ?? ''}')} · ${'${l['bucket']}' == 'comp' ? 'Comp-off' : _t('Paid leave', 'Paid रजा')}',
                            chips: [stateChip('${_num(l['days']) > 0 ? '+' : ''}${_n(l['days'])}', _num(l['days']) > 0 ? 'a' : 'x')],
                            last: i == ledger.length - 1),
                    ])),
                  ],
                  const SizedBox(height: 12),
                  Rise(order: 2, child: hrCard(key: const Key('leave-how'), [
                    hrTitle('How it is counted', 'कशी मोजली जाते'),
                    m.Text(_how(me?['policy'] as Map?), style: TextStyle(fontSize: 13, color: sk.muted, height: 1.5)),
                  ])),
                ],
              ]),
            ),
    );
  }
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
    final st = leaveChip(q), hist = [for (final x in (q['history'] as List? ?? const []).whereType<Map>()) x];
    return Scaffold(
      appBar: hrHead(context, sky: kLeaveSky, title: 'My leave', mr: 'माझी रजा', pill: headPill(leaveDays(q)), height: 96),
      body: ListView(key: const Key('lvd-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        hrCard(key: const Key('lvd-stand'), [
          hrTitle('Where it stands', 'सध्याची स्थिती'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            stateChip(st.$1, st.$2),
            const SizedBox(width: 10),
            Expanded(child: m.Text(leaveSmall(q), key: const Key('lvd-waits'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sk.ink, height: 1.35))),
          ]),
          if ('${q['reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: m.Text('${_t('Reason', 'कारण')}: ${q['reason']}', style: TextStyle(fontSize: 13, color: sk.muted, height: 1.35))),
        ]),
        if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('lvd-err')),
        const SizedBox(height: 12),
        if (_can['change'] == true) ...[hrButton('Change days', 'दिवस बदला', key: const Key('lvd-change'), onTap: busy ? null : _change), const SizedBox(height: 10)],
        if (_can['delete'] == true)
          OutlinedButton.icon(
            key: const Key('lvd-delete'),
            onPressed: busy ? null : _delete,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: const BorderSide(color: C.red)),
            icon: const Icon(Icons.delete_outline_rounded, color: C.red),
            label: const Text('Delete this leave', mr: 'ही रजा Delete करा', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.red)),
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
