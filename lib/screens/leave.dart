/* HR – LEAVE, the app's own screens (3.108.0, rcl-hr step 7; the screens he sent back on 12-11-2026: "mala same as it is screen
 * hawe aahet ya sagle leave chi pn screen"): his balance, what this month added and used, "+ Apply for leave", his requests
 * (waiting – approved – refused; a waiting one is taken back by a touch) and how his site counts leave – the policy the HR
 * office set, nothing fixed here. The form: From, To, the whole day or a half, the reason. The balance is never kept on the
 * phone and never counted here: the server (rcl-hr, lib/act_leave.js) walks it day by day and checks every request again.
 * (3.121.0, the Rule Book of HR – rcl-hr step 13; his words: "systeam auto samjel ki ya 2 ni milun leave balance ekach aahe",
 * "leave form attachment") when the server walks his leave with a Rule Book policy (book: true) the ONE balance is his Paid
 * leave and his Comp-off days together – he never chooses a type – and his ledger says where every day came from and went; a
 * request can carry papers (a photo or a PDF – never needed), attached with it or afterwards. A server without step 13 sends
 * none of this: the screen is then exactly the one of before. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart' show ApiError;
import '../core/attend.dart';
import '../ui/done_pop.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
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
    donePop(context, _t('Leave request sent', 'रजेचा अर्ज पाठवला'), detail: _t('It counts when it is approved.', 'मंजूर झाल्यावर धरले जाईल.'));
  }

  // (3.121.0) the papers of a request: looked at, attached, removed – then the list is read again (its count)
  Future<void> _papers(Map q) async {
    await Navigator.of(context).push<void>(hrRoute(LeavePapersScreen(ask: widget.ask, request: q)));
    if (mounted) _load();
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
                            chips: [
                              // (3.121.0) the papers of the request – only when the server keeps them (step 13); never needed
                              if (q['files'] is num && '${q['status']}' != 'cancelled') stateChip((q['files'] as num) > 0 ? _t('Papers ${_n(q['files'])}', 'कागद ${_n(q['files'])}') : _t('+ Paper', '+ कागद'), 'w', key: Key('lv-files-${q['id']}'), onTap: () => _papers(q)),
                              stateChip(s.$1, s.$2, key: waits ? Key('lv-back-${q['id']}') : null, onTap: waits ? () => _back(q) : null),
                            ],
                            last: i == reqs.length - 1);
                      }(),
                    if (reqs.any((q) => '${q['status']}' == 'pending')) Padding(padding: EdgeInsets.only(top: 6), child: Text('Touch "Waiting" to take a request back.', mr: 'विनंती मागे घ्यायला "प्रलंबित" वर touch करा.', style: TextStyle(fontSize: 12, color: sk.faint))),
                  ]),
                  if (me?['book'] == true) ...[
                    const SizedBox(height: 12),
                    hrCard(key: const Key('leave-ledger'), [
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
                    ]),
                  ],
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

/// (3.121.0) THE PAPERS OF ONE LEAVE REQUEST: a photo or a PDF – never needed. He attaches (camera, gallery, PDF), opens and –
/// while the request still waits – removes his own; a paper the HR office attached is only opened. The server keeps every one.
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
                if (files.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('No paper is attached. A paper is never needed for a leave.', mr: 'कागद जोडलेला नाही. रजेसाठी कागद कधीच सक्तीचा नाही.', style: TextStyle(fontSize: 13.5, color: sk.faint, height: 1.4))),
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
