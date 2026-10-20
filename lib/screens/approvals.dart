/* APPROVALS – the app's own screens (3.2.0, asked 16-10-2026: "purn web application completely app ui madhe … web ui la hat nahi
 * lawnar but same working same logics … app madhe mala kuthunch web ui dista kama naye"). The same list, the same actions and the
 * same checks as the web page (Mechanical: getChangeRequests, decideChangeRequest(s), answerFlow, remindFlow, getFlowRules,
 * saveFlowRules – the server decides everything):
 *   – the counts: waiting for you, sent back to you, waiting in all, your entries waiting, the oldest;
 *   – each request: when, who, which work, what it changes, its steps; waiting at whom (level x of y), sent back (the question),
 *     approved / rejected / returned (by whom, the note, why not saved);
 *   – Approve / Send back / Reject (one, or several ticked at once), Answer and send again / Take back, Remind;
 *   – the Super Admin: the verification rules of the site (works, levels of people, "only when", remind after). */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/help.dart' show GuideButton;
import 'verify.dart' show askSendAgain, againWords;
import 'flow_fix.dart' show openFix;
import '../ui/ask_bot.dart';

Future<void> openApprovals(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ApprovalsScreen()));

/// The requests shown: what waits, everything he sent – and, with [all], what was decided too (as the web).
List<Map<String, dynamic>> approvalsShown(Map? d, {bool all = false}) =>
    ((d?['requests'] as List?) ?? const []).whereType<Map>().map((r) => r.cast<String, dynamic>()).where((r) => all || r['status'] == 'Pending' || r['mine'] == true).toList();

/// The words of a decision's answer, as the web says them.
String decidedWords(Map<String, dynamic> res) {
  final st = '${res['status'] ?? ''}', id = '${res['id'] ?? ''}';
  return '$id ${st.toLowerCase()}${st == 'Approved' ? ' – saved.' : st == 'Pending' ? ' – sent on to level ${res['level']}.' : st == 'Returned' ? ' – not saved: ${res['result'] ?? ''}' : ' – nothing was saved.'}';
}

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});
  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  Map<String, dynamic>? d;
  bool loading = true, all = false;
  String err = '', busy = '';
  final ticked = <String>{};
  Session? _ls;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ls = SessionScope.read(context)..dataTick.addListener(_live);
      _load();
    });
  }

  @override
  void dispose() {
    _ls?.dataTick.removeListener(_live);
    super.dispose();
  }

  // another person decided or sent something (the live sync of the app): the list again, quietly
  void _live() {
    if (mounted && (_ls?.lastChanged.contains('flow') ?? false)) _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context);
    if (!quiet) setState(() => loading = true);
    try {
      final r = await s.api.call('getChangeRequests', [<String, dynamic>{}]);
      if (!mounted) return;
      _take(s, r);
      setState(() {
        loading = false;
        err = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        if (!quiet) err = errText(e);
      });
    }
  }

  void _take(Session s, dynamic list) {
    if (list is! Map) return;
    d = list.cast<String, dynamic>();
    s.takeApprovals(d!);
    final can = approvalsShown(d, all: true).where((r) => r['canDecide'] == true).map((r) => '${r['id']}').toSet();
    ticked.removeWhere((id) => !can.contains(id));
  }

  Map<String, dynamic>? _req(String id) {
    for (final r in approvalsShown(d, all: true)) {
      if (r['id'] == id) return r;
    }
    return null;
  }

  Future<void> _run(String key, Future<void> Function() job) async {
    if (busy.isNotEmpty) return;
    setState(() => busy = key);
    try {
      await job();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  List<String> _what(Map<String, dynamic> r) => [
        ...((r['summary'] as List?) ?? const []).map((e) => '$e'),
        r['kind'] == 'Flow' ? 'Sent by: ${r['by']} · Work: ${r['task']}${(asNum(r['levels']) ?? 0) > 0 ? ' · Level ${r['level']} of ${r['levels']}' : ''}' : 'Asked by: ${r['by']} · Reason: ${r['reason'] ?? ''}',
      ];

  Future<void> _approve(Map<String, dynamic> r) async {
    final s = SessionScope.read(context), flow = r['kind'] == 'Flow', level = asNum(r['level']) ?? 1, levels = asNum(r['levels']) ?? 1;
    final last = !flow || level >= levels;
    final note = !flow
        ? 'It is saved now as ${r['by']}\'s change, with every check of a save. The submitted bill is not changed – the difference is taken in the vendor\'s next bill (Credit / Debit Note).'
        : last
            ? 'It is saved now as ${r['by']}\'s entry, with every check of a save.'
            : 'It goes on to level ${level + 1} – nothing is saved yet.';
    if (!await askLines(context, flow ? 'Approve this entry?' : 'Approve this change?', _what(r), note: note, yes: last ? 'Approve and save' : 'Approve – to level ${level + 1}')) return;
    await _run('ok:${r['id']}', () async {
      final res = (await s.api.call('decideChangeRequest', [{'id': r['id'], 'approve': true, 'note': ''}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _take(s, res['list']));
      HapticFeedback.lightImpact();
      toast(context, tr(decidedWords(res)), bad: res['status'] == 'Returned');
      s.dataTick.value++;
    });
  }

  Future<void> _reject(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    final note = await askNote(context, 'Reject this change?', body: [for (final l in _what(r)) Text('• $l', style: const TextStyle(fontSize: 14))], label: 'Why is it rejected? (${r['by']} reads it)', ok: 'Reject', danger: true, neededMsg: 'Write why the change is rejected.');
    if (note == null) return;
    await _run('no:${r['id']}', () async {
      final res = (await s.api.call('decideChangeRequest', [{'id': r['id'], 'approve': false, 'note': note}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _take(s, res['list']));
      toast(context, tr(decidedWords(res)));
    });
  }

  Future<void> _sendBack(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    final note = await askNote(context, 'Send this entry back?', body: [for (final l in _what(r)) Text('• $l', style: const TextStyle(fontSize: 14))], label: 'Remark or question for ${r['by']} (he answers it)', ok: 'Send back', neededMsg: 'Write the remark or question.');
    if (note == null) return;
    await _run('back:${r['id']}', () async {
      final res = (await s.api.call('decideChangeRequest', [{'id': r['id'], 'revert': true, 'note': note}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _take(s, res['list']));
      toast(context, tr('${res['id']} sent back to ${r['by']}.'));
    });
  }

  Future<void> _answer(Map<String, dynamic> r) async {
    final s = SessionScope.read(context), rv = (r['reverted'] as Map?) ?? const {};
    final note = await askNote(context, 'Answer and send again?',
        body: [
          for (final l in _what(r)) Text('• $l', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(12)), child: Text('${rv['by'] ?? ''}: ${rv['note'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
        label: 'Your answer (it goes with the entry to ${rv['by'] ?? 'the person'})',
        ok: 'Send again',
        neededMsg: 'Write your answer.');
    if (note == null) return;
    await _run('ans:${r['id']}', () async {
      final res = (await s.api.call('answerFlow', [{'id': r['id'], 'note': note, 'withdraw': false}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _take(s, res['list']));
      toast(context, tr('${res['id']} sent again for verification.'));
    });
  }

  Future<void> _takeBack(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    if (!await askLines(context, 'Take this entry back?', _what(r), note: 'It is not saved. To enter it again with changes, make a new entry.', yes: 'Take back', danger: true)) return;
    await _run('wd:${r['id']}', () async {
      final res = (await s.api.call('answerFlow', [{'id': r['id'], 'note': '', 'withdraw': true}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _take(s, res['list']));
      toast(context, tr('${res['id']} taken back – nothing saved.'));
    });
  }

  /// (3.21.1, Mechanical update-128) his own rejected / returned entry: sent again as it was, with his remark
  Future<void> _sendAgain(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    await _run('again:${r['id']}', () async {
      final res = await askSendAgain(context, s, [r]);
      if (res == null || !mounted) return;
      if (res['list'] is Map) setState(() => _take(s, res['list']));
      toast(context, tr(againWords(res)), bad: (res['done'] as List? ?? []).isEmpty || (res['failed'] as List? ?? []).isNotEmpty);
    });
  }

  /// (3.22.0, Mechanical update-130) his own returned / rejected Diesel Issue entry: opened in its form to correct
  Future<void> _fix(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    await _run('fix:${r['id']}', () async {
      final res = await openFix(context, s, '${r['id']}');
      if (res != null && res['list'] is Map && mounted) setState(() => _take(s, res['list']));
    });
  }

  Future<void> _remind(Map<String, dynamic> r) async {
    final s = SessionScope.read(context);
    await _run('rem:${r['id']}', () async {
      final res = await s.remindFlow(ids: ['${r['id']}']);
      if (!mounted) return;
      if (res['list'] is Map) setState(() => _take(s, res['list']));
      final done = (res['reminded'] as List? ?? []).map((e) => '$e').toList();
      final later = (res['later'] as List? ?? []).whereType<Map>().map((l) => '${l['id']} was reminded at ${l['at']} – again after ${l['next']}').toList();
      toast(context, tr([if (done.isNotEmpty) 'Reminder sent: ${done.join(', ')}.', ...later].join(' ')), bad: done.isEmpty);
    });
  }

  /// Several ticked at once: approve (a note may be written), send back or reject (a note is needed).
  Future<void> _bulk(String how) async {
    final s = SessionScope.read(context), ids = ticked.toList()..sort();
    if (ids.isEmpty) return;
    final approve = how == 'ok', back = how == 'back';
    final title = '${back ? 'Send back' : approve ? 'Approve' : 'Reject'} ${ids.length} request(s)?';
    final note = await askNote(context, title,
        body: [
          Text(ids.join(', '), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
              back
                  ? 'Each goes back to the person who sent it, with your remark or question – nothing is saved; he answers and sends it again.'
                  : approve
                      ? 'Each one goes to its next level, or – at the last level – is saved now with every check of a save (one that cannot be saved goes back to its sender with the reason).'
                      : '',
              style: const TextStyle(fontSize: 13.5, color: C.muted)),
        ],
        label: back ? 'Remark or question (the senders read it)' : approve ? 'Note (optional)' : 'Why are they rejected? (the senders read it)',
        ok: back ? 'Send back' : approve ? 'Approve' : 'Reject',
        danger: !approve && !back,
        needed: !approve,
        neededMsg: back ? 'Write the remark or question.' : 'Write why they are rejected.');
    if (note == null) return;
    await _run('bulk', () async {
      final res = (await s.api.call('decideChangeRequests', [{'ids': ids, 'approve': approve, 'revert': back, 'note': note}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final failed = (res['failed'] as List? ?? []).whereType<Map>().toList();
      setState(() {
        ticked.clear();
        _take(s, res['list']);
      });
      toast(context, tr('${(res['done'] as List? ?? []).length} done${failed.isNotEmpty ? ', ${failed.length} not: ${failed.map((f) => '${f['id']} – ${f['error']}').join('; ')}' : ''}.'), bad: failed.isNotEmpty);
      s.dataTick.value++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = approvalsShown(d, all: all);
    final wait = approvalsShown(d, all: true).where((r) => r['status'] == 'Pending').toList();
    final oldest = wait.fold<double>(0, (mx, r) {
      final t = DateTime.tryParse('${r['waitSince'] ?? r['at'] ?? ''}');
      if (t == null) return mx;
      final h = DateTime.now().difference(t).inMinutes / 60;
      return h > mx ? h : mx;
    });
    final canTick = list.any((r) => r['canDecide'] == true), canBack = ticked.any((id) => _req(id)?['kind'] == 'Flow');
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Approvals', 'मंजुरी', size: 20, weight: FontWeight.w700),
        actions: withAsk([const GuideButton('approvals'), 
          if (s.superAdmin) IconButton(key: const Key('flow-rules'), tooltip: tr('Verification rules'), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FlowRulesScreen())), icon: const Icon(Icons.tune_rounded)),
          IconButton(tooltip: tr('Refresh'), onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Text('Entries sent for verification (the Super Admin\'s rules) and changes of a submitted bill. Waiting = not saved yet; Approved = saved; Sent back = a remark or question for the sender, he answers and sends it again; Rejected, Returned or Taken back = not saved.',
              style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _count('Waiting for you', '${d?['forMe'] ?? 0}', C.amber, C.amberSoft, 'cr-forme'),
            if ((asNum(d?['backToMe']) ?? 0) > 0) _count('Sent back to you', '${d?['backToMe']}', C.red, C.redSoft, 'cr-back'),
            _count('Waiting in all', '${wait.length}', C.blue, C.blueSoft, 'cr-wait'),
            _count('Your entries waiting', '${wait.where((r) => r['mine'] == true).length}', C.greenDark, C.greenSoft, 'cr-mine'),
            if (wait.isNotEmpty) _count('Oldest waiting', oldest >= 24 ? '${oldest ~/ 24} d' : '${oldest.floor()} h', C.slate, C.slateSoft, 'cr-old'),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilterChip(key: const Key('cr-all'), label: Text('Show approved and rejected too'), selected: all, onSelected: (v) => setState(() => all = v)),
            if (canTick)
              TextButton(
                onPressed: () => setState(() {
                  final ids = list.where((r) => r['canDecide'] == true).map((r) => '${r['id']}');
                  if (ticked.length == ids.length) {
                    ticked.clear();
                  } else {
                    ticked.addAll(ids);
                  }
                }),
                child: Text(ticked.isEmpty ? 'Tick all' : 'Untick all'),
              ),
          ]),
          if ('${d?['missing'] ?? ''}'.isNotEmpty) InfoLine('${d!['missing']}', bad: true),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 8),
          if (loading && d == null)
            ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 150)))
          else if (list.isEmpty)
            EmptyState(all ? 'Nothing yet.' : 'Nothing is waiting.', 'Entries sent for verification show here.', pic: 'bell')
          else
            for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(r)),
        ]),
      ),
      bottomNavigationBar: ticked.isEmpty
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, -4))]),
                child: Row(children: [
                  Expanded(child: FilledButton(key: const Key('bulk-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 50)), onPressed: busy.isEmpty ? () => _bulk('ok') : null, child: Text(busy == 'bulk' ? '…' : '${tr('Approve')} (${ticked.length})'))),
                  if (canBack) ...[const SizedBox(width: 8), Expanded(child: OutlinedButton(key: const Key('bulk-back'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), onPressed: busy.isEmpty ? () => _bulk('back') : null, child: const Text('Send back')))],
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(key: const Key('bulk-no'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), foregroundColor: C.red), onPressed: busy.isEmpty ? () => _bulk('no') : null, child: const Text('Reject'))),
                ]),
              ),
            ),
    );
  }

  Widget _count(String en, String n, Color fg, Color bg, String key) => Container(
        key: Key(key),
        constraints: const BoxConstraints(minWidth: 104),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(en, style: TextStyle(fontSize: 12.5, color: fg, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(n, style: TextStyle(fontSize: 24, color: fg, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _card(Map<String, dynamic> r) {
    final id = '${r['id'] ?? ''}', st = '${r['status'] ?? ''}', flow = r['kind'] == 'Flow';
    final sum = ((r['summary'] as List?) ?? const []).map((e) => '$e').toList();
    final hist = ((r['history'] as List?) ?? const []).whereType<Map>().toList();
    final (Color fg, Color bg, String head) = switch (st) {
      'Pending' => (C.amber, C.amberSoft, 'Waiting'),
      'Reverted' => (C.red, C.redSoft, 'Sent back'),
      'Approved' => (C.greenDark, C.greenSoft, 'Approved'),
      'Withdrawn' => (C.slate, C.slateSoft, 'Taken back'),
      _ => (C.red, C.redSoft, st),
    };
    final waitFor = ((r['waitingFor'] as List?) ?? const []).map((e) => '$e').toList();
    final rv = (r['reverted'] as Map?) ?? const {};
    final line = switch (st) {
      'Pending' => (asNum(r['levels']) ?? 0) > 0 ? 'level ${r['level']} of ${r['levels']}${waitFor.isNotEmpty ? ': ${waitFor.join(', ')}' : ''}' : 'Super Admin',
      'Reverted' => '${rv['by'] ?? ''} · ${whenText('${rv['at'] ?? ''}')}',
      'Withdrawn' => '',
      _ => [r['decidedBy'], whenText('${r['decidedAt'] ?? ''}')].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '),
    };
    final ticks = r['canDecide'] == true;
    // (3.22.0) corrected by the sender: what changed, in sight of the people who approve it
    final lastSent = st == 'Pending' ? hist.lastWhere((h) => const ['Sent', 'Sent again', 'Corrected and sent again'].contains(h['step']), orElse: () => const {}) : const {};
    final fixed = lastSent['step'] == 'Corrected and sent again' ? lastSent : null;
    return Container(
      key: Key('cr-$id'),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: ticked.contains(id) ? C.green : C.line.withValues(alpha: .7), width: ticked.contains(id) ? 2 : 1), boxShadow: softShadow(.04)),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ticks)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(width: 28, height: 28, child: Checkbox(key: Key('tick-$id'), value: ticked.contains(id), onChanged: (v) => setState(() => v == true ? ticked.add(id) : ticked.remove(id)))),
            ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$id · ${whenText('${r['at'] ?? ''}')}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 2),
              Text('${r['by'] ?? ''} · ${flow ? '${r['task'] ?? ''}' : tr('Change of a billed period')}${(asNum(r['qty']) ?? 0) > 0 ? ' · ${fmtNum(asNum(r['qty']))} L' : ''}', style: const TextStyle(fontSize: 13.5, color: C.muted)),
            ]),
          ),
          Pill(tr(head), color: fg, bg: bg),
        ]),
        const SizedBox(height: 8),
        for (final l in sum.take(8)) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(l, style: const TextStyle(fontSize: 14, height: 1.3))),
        if (sum.length > 8) Text('+ ${sum.length - 8} more', style: const TextStyle(fontSize: 13, color: C.muted)),
        if (!flow && '${r['reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Reason: ${r['reason']}', style: const TextStyle(fontSize: 13, color: C.muted))),
        if (fixed != null)
          Container(
            key: Key('cr-fixed-$id'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: C.amber, width: 3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${tr('Corrected by {0}').replaceFirst('{0}', '${fixed['by'] ?? ''}')}${'${fixed['note'] ?? ''}'.isNotEmpty ? ': ${fixed['note']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              for (final c in ((fixed['changes'] as List?) ?? const []).isEmpty ? const ['(nothing changed in the entry)'] : fixed['changes'] as List) Text('• $c', style: const TextStyle(fontSize: 13)),
            ]),
          ),
        if (line.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(line, style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600))),
        if (st == 'Reverted' && '${rv['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${rv['note']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
        if (st == 'Pending' && (asNum(r['reminds']) ?? 0) > 0) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Reminded ${r['reminds']}× by ${r['by']} · ${whenText('${r['remindedAt'] ?? ''}')}', style: const TextStyle(fontSize: 12.5, color: C.amber))),
        if (st != 'Pending' && st != 'Reverted' && '${r['note'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${r['note']}', style: const TextStyle(fontSize: 13.5))),
        if (st == 'Returned' && '${r['result'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('${r['result']}', style: const TextStyle(fontSize: 13.5, color: C.red))),
        if (hist.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Material(type: MaterialType.transparency, child: ExpansionTile(
              key: Key('steps-$id'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              dense: true,
              title: Text('Steps (${hist.length})', style: const TextStyle(fontSize: 13, color: C.blue, fontWeight: FontWeight.w600)),
              children: [
                for (final h in hist)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('${h['step'] ?? ''}${h['level'] != null ? ' L${h['level']}' : ''} – ${h['by'] ?? ''} · ${whenText('${h['at'] ?? ''}')}${'${h['note'] ?? ''}'.isNotEmpty ? ': ${h['note']}' : ''}${[for (final c in (h['changes'] as List? ?? const [])) '\n   $c'].join()}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ),
                  ),
              ],
            )),
          ),
        if (r['canDecide'] == true || r['canAnswer'] == true || r['canRemind'] == true || r['canResend'] == true) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (r['canDecide'] == true) ...[
              _btn('Approve', 'ok:$id', () => _approve(r), filled: true),
              if (flow) _btn('Send back', 'back:$id', () => _sendBack(r)),
              _btn('Reject', 'no:$id', () => _reject(r), danger: true),
            ],
            if (r['canAnswer'] == true) ...[
              _btn('Answer and send again', 'ans:$id', () => _answer(r), filled: true),
              _btn('Take back', 'wd:$id', () => _takeBack(r), danger: true),
            ],
            if (r['canRemind'] == true) _btn('Remind', 'rem:$id', () => _remind(r)),
            if (r['canFix'] == true) _btn('Open & correct', 'fix:$id', () => _fix(r), filled: true),      // (3.22.0)
            if (r['canResend'] == true) _btn('Send again', 'again:$id', () => _sendAgain(r), filled: r['canFix'] != true),
          ]),
        ],
      ]),
    );
  }

  Widget _btn(String en, String key, VoidCallback go, {bool filled = false, bool danger = false}) {
    final child = busy == key ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)) : Text(en);
    final onTap = busy.isEmpty ? go : null;
    return filled
        ? FilledButton(key: Key(key), style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 18)), onPressed: onTap, child: child)
        : OutlinedButton(key: Key(key), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16), foregroundColor: danger ? C.red : C.ink), onPressed: onTap, child: child);
  }
}

/* THE VERIFICATION RULES (the Super Admin) – as the web: every work of the site, its levels of named people (any one of a level
 * approves; nobody his own entry), "only when" (dated more than N days back; diesel: more than X litres), remind after N hours.
 * A work with people picked but not ticked: asked before it is saved like that (its entries are saved at once). */
class FlowRulesScreen extends StatefulWidget {
  const FlowRulesScreen({super.key});
  @override
  State<FlowRulesScreen> createState() => _FlowRulesScreenState();
}

class _Rule {
  _Rule(this.m, this.label, this.diesel, this.on, this.levels, this.days, this.qty);
  final String m, label;
  final bool diesel;
  bool on;
  final List<Set<String>> levels;
  final TextEditingController days, qty;
}

class _FlowRulesScreenState extends State<FlowRulesScreen> {
  bool loading = true, saving = false;
  String err = '';
  List<_Rule> rules = [];
  List<(String, String)> users = []; // (email, name)
  final hours = TextEditingController(text: '4');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final r in rules) {
      r.days.dispose();
      r.qty.dispose();
    }
    hours.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    setState(() => loading = true);
    try {
      final d = (await s.api.call('getFlowRules') as Map).cast<String, dynamic>();
      final rs = ((d['rules'] as Map?)?['tasks'] as Map?) ?? const {};
      if (!mounted) return;
      setState(() {
        users = [for (final u in (d['users'] as List? ?? []).whereType<Map>()) ('${u['email']}', '${u['name'] ?? u['email']}')];
        hours.text = '${(d['rules'] as Map?)?['remindHours'] ?? 4}';
        rules = [for (final t in (d['tasks'] as List? ?? []).whereType<Map>()) _ruleOf(t, rs)];
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

  static _Rule _ruleOf(Map t, Map rs) {
    final r = (rs['${t['m']}'] as Map?) ?? const {};
    final lv = <Set<String>>[for (final l in (r['levels'] as List? ?? [])) if (l is List) l.map((e) => '$e').toSet()];
    return _Rule('${t['m']}', '${t['label'] ?? t['m']}', t['diesel'] == true, r['on'] == true, lv.isEmpty ? [<String>{}] : lv, TextEditingController(text: '${r['daysBack'] ?? ''}'), TextEditingController(text: '${r['qtyAbove'] ?? ''}'));
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    final offWith = rules.where((r) => !r.on && r.levels.any((l) => l.isNotEmpty)).map((r) => r.label).toList();
    if (offWith.isNotEmpty &&
        !await askLines(context, 'Ticked off, but people are picked', offWith,
            note: 'People are picked for approval, but the work is not ticked – its entries are saved at once, without verification, and the button says "Save". To send them for verification: tick the work, then Save.', yes: 'Save like this')) {
      return;
    }
    setState(() => saving = true);
    try {
      final tasks = {
        for (final r in rules) r.m: {'on': r.on, 'levels': [for (final l in r.levels) l.toList()], 'daysBack': r.days.text.trim(), 'qtyAbove': r.diesel ? r.qty.text.trim() : ''}
      };
      await s.api.call('saveFlowRules', [{'tasks': tasks, 'remindHours': hours.text.trim()}], true);
      if (!mounted) return;
      toast(context, tr('Verification rules saved.'));
      await _load();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const TwoLang('Verification rules', 'तपासणीचे नियम', size: 20, weight: FontWeight.w700), actions: withAsk([const GuideButton('approvals')])),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                const Text('Tick a work of this site: its saves go to the people of level 1, then level 2 …, and are saved only when the last level approves.', style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
                const SizedBox(height: 4),
                const Text('Any one person of a level approves (the others are the backup). Nobody approves his own entry. The Super Admin\'s own entries are saved at once.', style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
                const SizedBox(height: 4),
                const Text('Only when (optional): only entries dated more than N days back, or (diesel) more than X litres. Empty = every entry. A work added to the app later shows up here by itself.', style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
                if (err.isNotEmpty) InfoLine(err, bad: true),
                const SizedBox(height: 10),
                for (final r in rules) Padding(padding: const EdgeInsets.only(bottom: 10), child: _rule(r)),
                const SizedBox(height: 4),
                Row(children: [
                  const Expanded(child: Text('Remind after (hours) – twice as long: the Super Admin too', style: TextStyle(fontSize: 14))),
                  SizedBox(width: 90, child: TextField(key: const Key('fr-hours'), controller: hours, keyboardType: TextInputType.number, textAlign: TextAlign.center)),
                ]),
              ]),
        bottomNavigationBar: loading
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    key: const Key('fr-save'),
                    onPressed: saving ? null : _save,
                    icon: saving ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.check_circle_rounded),
                    label: const Text('Save the rules'),
                  ),
                ),
              ),
      );

  Widget _rule(_Rule r) => Container(
        key: Key('fr-${r.m}'),
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: r.on ? C.green : C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            Switch(key: Key('fr-on-${r.m}'), value: r.on, onChanged: (v) => setState(() => r.on = v)),
          ]),
          for (var i = 0; i < r.levels.length; i++) ...[
            Row(children: [
              Text('Level ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  if (r.levels.length > 1) {
                    r.levels.removeAt(i);
                  } else {
                    r.levels[0].clear();
                  }
                }),
                style: TextButton.styleFrom(foregroundColor: C.red),
                child: const Text('remove level'),
              ),
            ]),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final u in users)
                FilterChip(
                  label: Text(u.$2),
                  selected: r.levels[i].contains(u.$1),
                  onSelected: (v) => setState(() => v ? r.levels[i].add(u.$1) : r.levels[i].remove(u.$1)),
                ),
            ]),
            const SizedBox(height: 6),
          ],
          TextButton(
            onPressed: () {
              if (r.levels.length >= 5) {
                toast(context, tr('At most 5 levels.'), bad: true);
                return;
              }
              setState(() => r.levels.add(<String>{}));
            },
            child: const Text('+ add a level'),
          ),
          const Text('Only when:', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: r.days, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('dated more than … days back')))),
            if (r.diesel) ...[const SizedBox(width: 8), Expanded(child: TextField(controller: r.qty, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('more than … litres'))))],
          ]),
          const Padding(padding: EdgeInsets.only(top: 4), child: Text('(empty = every entry)', style: TextStyle(fontSize: 12.5, color: C.muted))),
        ]),
      );
}
