/* MY ENTRIES IN VERIFICATION (3.1.11, Mechanical update-118, asked 16-10-2026: "jewa t entry sent verification krel tyala pn
 * samajayla haw konti entry verification madhe aahe ani konte approval zale aahet tithch disaw … dashbord war tya user la disel ki
 * konte entry pending aahet … tyach reminder pn to pathau shakel … entry wise or all send reminder").
 *   – VerifyStrip: on Home (all his entries) and on the entry forms (that page's): Waiting / Sent back / Approved, tap → the sheet;
 *   – VerifySheet: each entry – waiting at whom and since when, sent back (with the question), approved, not saved – with
 *     "Remind" for one that waits and "Remind all waiting". The approver is told at once (Mechanical: web and phone). */
import 'package:flutter/material.dart' hide Text;

import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/web_host.dart';

String _ago(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 0) return '';
  return m < 60 ? '$m min' : m < 1440 ? '${m ~/ 60} h ${m % 60} min' : '${m ~/ 1440} day(s)';
}

String _when(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(t.day)}-${p(t.month)} ${p(t.hour)}:${p(t.minute)}';
}

/// Counts of [list]: waiting, sent back, approved, not saved.
(int, int, int, int) verifyCounts(List<Map<String, dynamic>> list) {
  int n(Set<String> st) => list.where((r) => st.contains('${r['status']}')).length;
  return (n({'Pending'}), n({'Reverted'}), n({'Approved'}), n({'Rejected', 'Returned', 'Withdrawn'}));
}

/// The answer of a reminder in words.
String remindWords(Map<String, dynamic> r) {
  final done = (r['reminded'] as List? ?? []).map((e) => '$e').toList();
  final later = (r['later'] as List? ?? []).whereType<Map>().map((l) => '${l['id']} was reminded at ${l['at']} – again after ${l['next']}').toList();
  return [if (done.isNotEmpty) 'Reminder sent: ${done.join(', ')}.', ...later].join(' ');
}

class VerifyStrip extends StatelessWidget {
  const VerifyStrip({super.key, this.module = '', this.days = 7, this.margin = EdgeInsets.zero});
  final String module; // '' = all pages (Home)
  final int days;
  final EdgeInsets margin; // only when it is shown (nothing at all when there is no entry)
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = s.mineFor(module, days: days);
    if (list.isEmpty) return const SizedBox.shrink();
    final (wait, back, ok, no) = verifyCounts(list);
    return Padding(padding: margin, child: Press(
      key: const Key('verify-strip'),
      onTap: () => showVerifySheet(context, module: module, days: days),
      color: C.amberSoft,
      border: C.amber.withValues(alpha: .35),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(children: [
        const Pic('bell', size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const TwoLang('My entries in verification', 'माझ्या verification मधल्या एन्ट्री', size: 15),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              Pill('${tr('Waiting')} $wait', color: C.amber, bg: Colors.white),
              if (back > 0) Pill('${tr('Sent back')} $back', color: C.red, bg: Colors.white),
              Pill('${tr('Approved')} $ok', color: C.greenDark, bg: Colors.white),
              if (no > 0) Pill('${tr('Not saved')} $no', color: C.slate, bg: Colors.white),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: C.amber),
      ]),
    ));
  }
}

Future<void> showVerifySheet(BuildContext context, {String module = '', int days = 7}) =>
    showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => VerifySheet(module: module, days: days));

class VerifySheet extends StatefulWidget {
  const VerifySheet({super.key, this.module = '', this.days = 7});
  final String module;
  final int days;
  @override
  State<VerifySheet> createState() => _VerifySheetState();
}

class _VerifySheetState extends State<VerifySheet> {
  String busy = ''; // the id being reminded, or '*' for all

  Future<void> _remind(Session s, {String id = ''}) async {
    setState(() => busy = id.isEmpty ? '*' : id);
    try {
      final waiting = s.mineFor(widget.module, days: widget.days).where((r) => r['canRemind'] == true).map((r) => '${r['id']}').toList();
      final r = await s.remindFlow(ids: id.isNotEmpty ? [id] : waiting);
      if (mounted) toast(context, tr(remindWords(r)), bad: (r['reminded'] as List? ?? []).isEmpty);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = s.mineFor(widget.module, days: widget.days);
    final (wait, _, _, _) = verifyCounts(list);
    return SizedBox(
      height: MediaQuery.of(context).size.height * .85,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 4), child: TwoLang('My entries in verification', 'माझ्या verification मधल्या एन्ट्री', size: 20, weight: FontWeight.w700)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(bi('Not saved until approved. "Remind" tells the person it waits for at once (once in 5 minutes for the same entry).', 'मंजूर होईपर्यंत सेव्ह होत नाही. "Remind" दाबले की ज्याच्याकडे एन्ट्री थांबली आहे त्याला लगेच कळते (एकाच एन्ट्रीसाठी ५ मिनिटांत एकदा).'),
              style: const TextStyle(color: C.muted, fontSize: 13.5)),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState('Nothing in verification', 'Your entries are saved.', pic: 'clipboard')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _row(s, list[i]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => openWeb(context, 'Approvals', 'approvals', pic: 'bell'),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(tr('Open Approvals')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                key: const Key('verify-remind-all'),
                onPressed: wait == 0 || busy.isNotEmpty ? null : () => _remind(s),
                icon: busy == '*' ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.notifications_active_rounded),
                label: Text(tr('Remind all waiting ({0})').replaceFirst('{0}', '$wait')),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _row(Session s, Map<String, dynamic> r) {
    final st = '${r['status'] ?? ''}', id = '${r['id'] ?? ''}';
    final sum = (r['summary'] as List? ?? []).map((e) => '$e').toList();
    final waitFor = (r['waitingFor'] as List? ?? []).map((e) => '$e').toList();
    final levels = (r['levels'] is num) ? (r['levels'] as num).toInt() : 0, level = (r['level'] is num) ? (r['level'] as num).toInt() : 0;
    final (Color fg, Color bg, String head, String line) = switch (st) {
      'Pending' => (C.amber, C.amberSoft, tr('Waiting'), '${waitFor.isEmpty ? tr('at the Super Admin') : 'at ${waitFor.join(', ')}'}${levels > 1 ? ' · level $level of $levels' : ''} · since ${_ago('${r['waitSince'] ?? r['at'] ?? ''}')}'),
      'Reverted' => (C.red, C.redSoft, tr('Sent back to you'), '${(r['reverted'] as Map?)?['by'] ?? ''}: ${(r['reverted'] as Map?)?['note'] ?? ''}'),
      'Approved' => (C.greenDark, C.greenSoft, tr('Approved – saved'), '${r['decidedBy'] ?? ''} · ${_when('${r['decidedAt'] ?? ''}')}'),
      _ => (C.slate, C.slateSoft, st == 'Withdrawn' ? tr('Taken back') : tr('{0} – not saved').replaceFirst('{0}', tr(st)), '${r['decidedBy'] ?? ''}${'${r['note'] ?? ''}'.isEmpty ? '' : ': ${r['note']}'}'),
    };
    final reminds = (r['reminds'] is num) ? (r['reminds'] as num).toInt() : 0;
    return Container(
      key: Key('verify-$id'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(id, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Flexible(child: Text('${r['task'] ?? ''} · ${_when('${r['at'] ?? ''}')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted))),
            ]),
            if (sum.isNotEmpty) Text(sum.first + (sum.length > 1 ? ' (+${sum.length - 1})' : ''), style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 4),
            Pill(head, color: fg, bg: bg),
            const SizedBox(height: 2),
            Text(line, style: const TextStyle(fontSize: 12.5, color: C.muted)),
            if (reminds > 0) Text('reminded $reminds× · ${_when('${r['remindedAt'] ?? ''}')}', style: const TextStyle(fontSize: 12, color: C.amber)),
          ]),
        ),
        if (r['canRemind'] == true)
          FilledButton.tonal(
            key: Key('verify-remind-$id'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),      // (the app's buttons are as wide as the screen)
            onPressed: busy.isNotEmpty ? null : () => _remind(s, id: id),
            child: busy == id ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)) : Text(tr('Remind')),
          )
        else if (r['canAnswer'] == true)
          OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 14)),
              onPressed: () => openWeb(context, 'Approvals', 'approvals', pic: 'bell'),
              child: Text(tr('Answer'))),
      ]),
    );
  }
}
