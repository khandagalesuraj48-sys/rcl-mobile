/* A MACHINERY LABEL SCANNED (3.14.0) – the web's qrArrive in the app's own screen: the label's machinery, then what to do for it –
 * Diesel Issue (the machinery already in the box), Log Book entry (not for a Debit Basis machinery), its diesel ledger. Only
 * what he may do is offered. The labels are made in Asset Master → ⋮ → QR labels. */
import 'package:flutter/material.dart' hide Text;

import '../core/imports.dart' show findMachine;
import '../core/kinds.dart';
import '../core/qr_scan.dart';
import '../core/report_defs.dart' show kDieselReports;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show newEntry;
import 'logbook.dart' show LogForm;
import 'report_screen.dart' show openReport;

/// The camera → the label → its machinery → the question. [onSaved]: a Diesel Issue was saved (Home reads its figures again).
Future<void> scanMachineLabel(BuildContext context, {VoidCallback? onSaved}) async {
  final s = SessionScope.read(context);
  String? text;
  try {
    text = await scanLabel();
  } catch (_) {
    if (context.mounted) toast(context, 'The label could not be read on this phone.', bad: true);
    return;
  }
  if (text == null || !context.mounted) return;
  if (text.isEmpty) {
    toast(context, 'No QR code was found on the photo – take it again, closer and straight.', bad: true);
    return;
  }
  final id = labelMachine(text);
  if (id.isEmpty) {
    toast(context, 'This QR code is not a machinery label of the ERP.', bad: true);
    return;
  }
  final f = findMachine([for (final m in s.machines) m.m], id);
  final m = f == null ? null : s.machine('${f['id']}');
  if (m == null) {
    toast(context, 'The machinery of this label ($id) is not in the Master.', bad: true);
    return;
  }
  final sub = <String>[];
  for (final x in [m.name.isNotEmpty && m.name != m.id ? m.name : '', m.type, m.owner]) {
    if (x.isNotEmpty && !sub.any((y) => y.toLowerCase() == x.toLowerCase())) sub.add(x);
  }
  final ledger = kDieselReports.where((d) => d.key == 'ledger').firstOrNull;
  final acts = <(String, String, IconData)>[
    if (s.canEdit('Diesel Issue')) ('diesel', 'Diesel Issue', Icons.local_gas_station_rounded),
    if (s.canEdit('Log Book') && !m.debit) ('log', 'Log Book entry', Icons.menu_book_rounded),
    if (ledger != null && s.canSee('Reports')) ('ledger', 'Its diesel ledger', Icons.receipt_long_rounded),
  ];
  final go = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Scanned label', style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          Text(m.id, key: const Key('ql-no'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Text(sub.join(' · '), style: const TextStyle(fontSize: 14, color: C.muted)),
          const SizedBox(height: 14),
          if (acts.isEmpty) Text('You have no page to open for this machinery.', style: const TextStyle(color: C.muted)),
          for (final (i, a) in acts.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: i == 0
                  ? FilledButton.icon(key: Key('ql-${a.$1}'), onPressed: () => Navigator.pop(c, a.$1), icon: Icon(a.$3), label: Text(a.$2))
                  : OutlinedButton.icon(key: Key('ql-${a.$1}'), onPressed: () => Navigator.pop(c, a.$1), icon: Icon(a.$3), label: Text(a.$2)),
            ),
        ]),
      ),
    ),
  );
  if (go == null || !context.mounted) return;
  switch (go) {
    case 'diesel':
      if (await newEntry(context, kKinds.firstWhere((k) => k.key == 'issue'), no: m.id)) onSaved?.call();
    case 'log':
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogForm(date: s.today, no: m.id)));
    case 'ledger':
      await openReport(context, ledger!, no: m.id, run: true);
  }
}
