/* OPEN & CORRECT (3.22.0, with Mechanical update-130 – asked 19-10-2026: "jy entry pathwale hote te mala open krun edit pn krta
 * yaw kay kuth chukley te pn samjayla haw"; his choices: only the sender, corrected → to verification again, Diesel Issue first).
 * His own rejected / returned Diesel Issue entry opens in the app's own form it was made in – One entry (EntryForm) or Multiple
 * entries (IssueManyScreen: one date – many machinery, or one machinery – many dates) – as it was sent, with why it came back and
 * what is wrong NOW (Mechanical checks it as a save: red – a mistake, amber – a warning) on top and on its rows. He corrects it;
 * the form's button – "Send again (VF-…)" – asks what he corrected and sends it: the same request, from level 1, corrected; the
 * people who approve it see what changed. Nothing is saved until it is approved. The same as the web page (Mechanical
 * openFlow / editFlow: the same checks, the same access). */
import 'package:flutter/material.dart' hide Text;

import '../core/api.dart' show ApiError;
import '../core/format.dart' show asNum;
import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'entry_more.dart' show IssueManyScreen;
import 'forms.dart' show EntryForm;

/// An entry being corrected: Mechanical's openFlow answer ({id, fn, form, args, status, result, decidedBy, note, check}) and his
/// remark (asked once, kept for "Send again anyway").
class FlowFix {
  FlowFix(this.r);
  final Map<String, dynamic> r;
  String remark = '';
  String get id => '${r['id'] ?? ''}';
  String get form => '${r['form'] ?? ''}';
  Map<String, dynamic> get check => ((r['check'] as Map?) ?? const {}).cast<String, dynamic>();
  /// what was sent: the save's first value (one entry / Multiple entries: a map; one machinery – many dates: the list of rows)
  Object? get first => ((r['args'] as List?) ?? const []).isEmpty ? null : (r['args'] as List).first;
  String get status => r['status'] == 'Returned' ? 'Returned, not saved' : 'Rejected, not saved';
  /// one entry: the photos sent with it (they stay with it)
  int get photos => first is Map ? ((first as Map)['photos'] as List? ?? const []).length : 0;
  String get why => r['status'] == 'Returned' ? '${r['result'] ?? 'Not saved'}' : 'Rejected by ${r['decidedBy'] ?? '–'}${'${r['note'] ?? ''}'.isEmpty ? '' : ': ${r['note']}'}';
  /// what the save says of it now (the web's words)
  String get now {
    final c = check;
    if (c['ok'] == true) return 'The save takes it now as it is – check it, correct what is needed and send it again.';
    if ('${c['error'] ?? ''}'.isNotEmpty) return 'Now: ${c['error']}';
    if ((c['errors'] as List? ?? const []).isNotEmpty) return 'Now: the rows in red are wrong – correct them (the list is under the rows).';
    if ((c['warnings'] as List? ?? const []).isNotEmpty) return 'Now: the rows in amber have warnings, not mistakes – check them (the list is under the rows).';
    if ('${c['warning'] ?? ''}'.isNotEmpty) return tr('Now (a warning, not a mistake): {0}').replaceFirst('{0}', '${c['warning']}'.replaceFirst(RegExp(r'\s*Save anyway\?\s*$'), ''));
    return '';
  }

  /// the rows the save marks: (row, message, warning)
  List<(int, String, bool)> get rowNotes => fixNotes(check['errors'], false) + fixNotes(check['warnings'], true);
}

/// A save's list of rows ([{row, msg}]) as (row, message, warning).
List<(int, String, bool)> fixNotes(Object? l, bool warn) => [
      for (final x in (l as List? ?? const []).whereType<Map>()) ((asNum(x['row']) ?? 0).toInt(), '${x['msg'] ?? ''}'.replaceFirst(RegExp(r'^Error:\s*'), ''), warn),
    ];

/// "Open & correct": his entry from Mechanical, in its form. Mechanical's answer when it was sent again, corrected (null: not sent).
Future<Map<String, dynamic>?> openFix(BuildContext context, Session s, String id) async {
  final r = await s.openFlow(id);
  if (!context.mounted) return null;
  final fx = FlowFix(r);
  final Widget page = switch (fx.form) {
    'one' => EntryForm(kind: kindOf('issue'), fix: fx),
    'date' || 'mach' => IssueManyScreen(fix: fx),
    _ => throw ApiError('Entry $id cannot be opened to correct here – use "Send again", or enter it again.'),
  };
  final res = await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => page));
  return res is Map ? res.cast<String, dynamic>() : null;
}

/// The remark (asked once): what he corrected – null when he cancels (nothing sent).
Future<String?> askFixNote(BuildContext context, FlowFix fx) async {
  if (fx.remark.isNotEmpty) return fx.remark;
  final n = await askNote(context, tr('Send {0} again, corrected?').replaceFirst('{0}', fx.id),
      body: [
        Text('${fx.id} goes to verification again, corrected – the same request, from level 1. The people who approve it see what you changed. It is checked as a save first: what is still wrong is marked and nothing is sent.',
            style: const TextStyle(fontSize: 13.5, color: C.muted)),
      ],
      label: 'What did you correct? (your remark goes with the entry to the people who approve it)',
      ok: 'Send again',
      neededMsg: 'Write what you corrected.');
  if (n != null) fx.remark = n;
  return n;
}

/// Sent again, corrected: the words.
String fixDoneWords(Map<String, dynamic> res) {
  final lv = asNum(res['levels'])?.toInt() ?? 1;
  return '${res['id']} corrected and sent again for verification (level 1${lv > 1 ? ' of $lv' : ''}) – saved when approved.';
}

/// The bar on top of the form while an entry is corrected: why it came back, what is wrong now, how it goes – and "Stop correcting".
class FixBar extends StatelessWidget {
  const FixBar(this.fx, {super.key});
  final FlowFix fx;
  @override
  Widget build(BuildContext context) => Container(
        key: const Key('fix-bar'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.amber.withValues(alpha: .45))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${tr('Correcting {0}').replaceFirst('{0}', fx.id)} – ${tr(fx.status)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(fx.why, key: const Key('fix-why'), style: const TextStyle(color: C.red, fontWeight: FontWeight.w700, fontSize: 14)),
          if (fx.now.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(fx.now, key: const Key('fix-now'), style: const TextStyle(fontSize: 14))),
          if (fx.photos > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text(tr('Photos sent with it: {0} – they stay with it; a new photo of the same kind takes its place.').replaceFirst('{0}', '${fx.photos}'), style: const TextStyle(fontSize: 13))),
          const SizedBox(height: 4),
          Text(tr('Correct the entry below and press "Send again ({0})": it goes to verification again – the same request, from level 1 – and is saved when it is approved. Nothing is saved until then.').replaceAll('{0}', fx.id),
              style: const TextStyle(fontSize: 12.5, color: C.muted)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('fix-stop'),
              onPressed: () {
                toast(context, tr('{0} stays as it was – nothing changed.').replaceFirst('{0}', fx.id));
                Navigator.of(context).pop(false);
              },
              child: const Text('Stop correcting'),
            ),
          ),
        ]),
      );
}
