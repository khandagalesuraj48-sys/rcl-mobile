/* HR – REQUESTS to set an old day right (3.103.0, rcl-hr step 5; the web's "Requests"): a person who forgot IN or OUT, or whose
 * phone was dead, asks for a day already gone – the IN and / or OUT time and what happened. It counts only when approved: by the
 * HR office, or first by the person he reports to (the HR office's setting). Today is never asked for – today is marked with the
 * phone. Here: the form (askRegularize), "My requests", and for a reporting person "My team's requests" (approve / refuse).
 * The server (rcl-hr, lib/act_muster.js) checks everything again. */
import 'package:flutter/material.dart' hide Text;

import '../core/api.dart' show ApiError;
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

typedef HrAsk = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

String _or(Object? v) {
  final t = '${v ?? ''}';
  return t.isEmpty ? '–' : t;
}

String _dmy(String ymd) => ymd.length >= 10 ? '${ymd.substring(8, 10)}-${ymd.substring(5, 7)}-${ymd.substring(0, 4)}' : ymd;

/// The request's form for [day] (yyyy-MM-dd). true = sent.
Future<bool> askRegularize(BuildContext context, HrAsk ask, String day, {String inNow = '', String outNow = ''}) async {
  final tin = TextEditingController(text: inNow), tout = TextEditingController(text: outNow), why = TextEditingController();
  var next = false, busy = false, err = '';
  final sent = await popDialog<bool>(
    context: context,
    builder: (dc) => StatefulBuilder(builder: (dc, set) {
      Future<void> pick(TextEditingController c) async {
        final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(c.text.trim());
        final t = await showTimePicker(context: dc, initialTime: m == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: int.parse(m.group(1)!) % 24, minute: int.parse(m.group(2)!) % 60));
        if (t != null) set(() => c.text = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      }

      Widget time(String key, String label, TextEditingController c) => TextField(
            key: Key(key),
            controller: c,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(labelText: label, hintText: '09:05', suffixIcon: IconButton(icon: const Icon(Icons.schedule_rounded), onPressed: () => pick(c))),
          );
      return AlertDialog(
        title: Text(bi('Set ${_dmy(day)} right', '${_dmy(day)} दुरुस्त करा')),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(bi('Write the IN and / or OUT time of that day and what happened. It counts when it is approved.', 'त्या दिवसाची IN आणि / किंवा OUT वेळ आणि काय झाले ते लिहा. मंजूर झाल्यावर धरले जाईल.', '\n'), style: const TextStyle(fontSize: 13.5, color: C.muted, height: 1.35)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: time('reg-in', 'IN', tin)), const SizedBox(width: 10), Expanded(child: time('reg-out', 'OUT', tout))]),
          CheckboxListTile(key: const Key('reg-next'), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: next, onChanged: (v) => set(() => next = v == true), title: Text(bi('OUT was on the next day (night)', 'OUT दुसऱ्या दिवशी (रात्रपाळी)'), style: const TextStyle(fontSize: 14))),
          TextField(key: const Key('reg-why'), controller: why, maxLines: 3, minLines: 2, maxLength: 200, decoration: InputDecoration(labelText: bi('What happened *', 'काय झाले *'))),
          if (err.isNotEmpty) Text(err, key: const Key('reg-err'), style: const TextStyle(color: C.red, fontSize: 13.5, height: 1.35)),
        ]),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(dc, false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('reg-send'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
            onPressed: busy
                ? null
                : () async {
                    set(() {
                      busy = true;
                      err = '';
                    });
                    try {
                      await ask({'action': 'regAsk', 'day': day, 'in_time': tin.text.trim(), 'out_time': tout.text.trim(), 'out_next_day': next, 'reason': why.text.trim()});
                      if (dc.mounted) Navigator.pop(dc, true);
                    } catch (e) {
                      set(() {
                        busy = false;
                        err = e is ApiError ? e.message : 'Something went wrong – please try again.';
                      });
                    }
                  },
            child: Text(bi('Send', 'पाठवा')),
          ),
        ],
      );
    }),
  );
  return sent == true;
}

(String, Color, Color) _state(Map q) {
  final st = '${q['status']}';
  if (st == 'approved') return (bi('Approved', 'मंजूर'), C.greenDark, C.greenSoft);
  if (st == 'refused') return (bi('Refused', 'नाकारले'), C.red, C.redSoft);
  return (q['level'] == 1 ? bi('With the reporting person', 'Reporting person कडे') : bi('With the HR office', 'HR office कडे'), C.amber, C.amberSoft);
}

Widget _regCard(Map q, {bool who = false, List<Widget> actions = const []}) {
  final s = _state(q), steps = [for (final x in (q['steps'] as List? ?? const []).whereType<Map>()) x];
  return Container(
    key: Key('reg-${q['id']}'),
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(who ? '${q['name'] ?? ''} · ${_dmy('${q['day']}')}' : _dmy('${q['day']}'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      // (where it stands – on its own line: its words are long on a narrow phone)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: s.$3, borderRadius: BorderRadius.circular(30)),
        child: Text(s.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: s.$2)),
      ),
      const SizedBox(height: 8),
      Text('IN ${_or(q['in_time'])} · OUT ${_or(q['out_time'])}${q['out_next_day'] == true ? ' (+1)' : ''}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text('${q['reason'] ?? ''}', style: const TextStyle(fontSize: 13.5, color: C.muted, height: 1.35)),
      for (final p in steps)
        if ('${p['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${p['level'] == 1 ? bi('Reporting person', 'Reporting person') : bi('HR office', 'HR office')}: ${p['note']}', style: const TextStyle(fontSize: 12.5, color: C.faint))),
      if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: actions)),
    ]),
  );
}

/// His own requests, the newest first.
class AttendRegsScreen extends StatefulWidget {
  const AttendRegsScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<AttendRegsScreen> createState() => _AttendRegsScreenState();
}

class _AttendRegsScreenState extends State<AttendRegsScreen> {
  List<Map> rows = [];
  String err = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myRegs'});
      if (!mounted) return;
      setState(() {
        rows = [for (final x in (j['rows'] as List? ?? const []).whereType<Map>()) x];
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: toneBar(Tone.hr, title: Text(bi('My requests', 'माझ्या विनंत्या'))),
        body: loading
            ? const SkeletonList(tiles: 0, rows: 4)
            : ListView(key: const Key('regs-page'), padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false),
                if (err.isEmpty && rows.isEmpty) EmptyState(bi('No request yet', 'अजून विनंती नाही'), bi('In "This month", tap a day gone to set it right.', '"हा महिना" मध्ये गेलेल्या दिवसावर tap करा.'), pic: 'calendar'),
                for (final q in rows) _regCard(q),
              ]),
      );
}

/// The requests of the people who report to him – the first level: pass it on to the HR office, or refuse it with the reason.
class TeamRegsScreen extends StatefulWidget {
  const TeamRegsScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<TeamRegsScreen> createState() => _TeamRegsScreenState();
}

class _TeamRegsScreenState extends State<TeamRegsScreen> {
  List<Map> rows = [];
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _take(Map<String, dynamic> j) => rows = [for (final x in (j['rows'] as List? ?? const []).whereType<Map>()) x];

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'teamRegs'});
      if (!mounted) return;
      setState(() {
        _take(j);
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

  Future<void> _decide(Map q, bool yes) async {
    if (busy) return;
    var note = '';
    if (!yes) {
      final n = await askNote(context, bi('Refuse this request', 'ही विनंती नाकारा'), label: bi('Why', 'का'), ok: bi('Refuse', 'नाकारा'), danger: true, max: 200);
      if (n == null) return;
      note = n;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final j = await widget.ask({'action': 'teamRegDecide', 'id': q['id'], 'decision': yes ? 'approved' : 'refused', 'note': note});
      if (!mounted) return;
      setState(() {
        _take(j);
        busy = false;
      });
      toast(context, yes ? bi('Passed to the HR office.', 'HR office कडे पाठवले.') : bi('Refused.', 'नाकारले.'));
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
  Widget build(BuildContext context) => Scaffold(
        appBar: toneBar(Tone.hr, title: Text(bi('My team\'s requests', 'माझ्या टीमच्या विनंत्या'))),
        body: loading
            ? const SkeletonList(tiles: 0, rows: 4)
            : ListView(key: const Key('team-page'), padding: const EdgeInsets.fromLTRB(16, 6, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false),
                if (err.isEmpty && rows.isEmpty) EmptyState(bi('Nothing is waiting', 'काही प्रलंबित नाही'), bi('A request of a person who reports to you comes here first.', 'तुम्हाला report करणाऱ्याची विनंती आधी इथे येते.'), pic: 'calendar'),
                for (final q in rows)
                  _regCard(q, who: true, actions: [
                    Expanded(child: FilledButton(key: Key('team-yes-${q['id']}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 8)), onPressed: busy ? null : () => _decide(q, true), child: FittedBox(fit: BoxFit.scaleDown, child: Text(bi('Approve', 'मंजूर'))))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton(key: Key('team-no-${q['id']}'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 8), foregroundColor: C.red), onPressed: busy ? null : () => _decide(q, false), child: FittedBox(fit: BoxFit.scaleDown, child: Text(bi('Refuse', 'नाकारा'))))),
                  ]),
              ]),
      );
}
