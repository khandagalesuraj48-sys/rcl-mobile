/* THE LOG BOOK PRINT (3.6.0) – asked as on the web: which name goes on top, the diesel debit rate of this print (empty = the
 * automatic rate) and the page (portrait / landscape); the diesel and BOQ of the dates come from the server (logPrintExtra), the
 * sheets are made on the phone (core/lb_print.dart) and handed to the phone's printing (a printer or "Save as PDF"). Used by Edit
 * Log Book, the Log Book of a day and Log Book Format → View format (a SAMPLE). */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show rootBundle, FilteringTextInputFormatter;

import '../core/lb_print.dart';
import '../core/log_edit.dart' show r2;
import '../core/session.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/print_view.dart';

class LbPrintAsk {
  LbPrintAsk(this.head, this.typed, this.bad, this.portrait);
  final String head;
  final num? typed; // a rate typed (null = empty: the automatic rate)
  final bool bad, portrait;
}

String _lastHead = '';
bool _lastPortrait = true;

/// The question before a Log Book print. [rate]: the diesel rate may be typed (not for a sample).
Future<LbPrintAsk?> askLbPrint(BuildContext context, List<String> names, {required bool rate, num value = 0, bool byBill = false}) {
  final all = names.isEmpty ? const ['Rachana Construction Limited'] : names;
  var head = all.contains(_lastHead) ? _lastHead : all.first;
  var portrait = _lastPortrait;
  final rc = TextEditingController(text: value > 0 ? '$value' : '');
  return showDialog<LbPrintAsk>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (dc, set) => AlertDialog(
        title: Text('Print Log Book'),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (all.length > 1) ...[
            Text('Which name should be printed at the top?', style: const TextStyle(color: C.muted)),
            const SizedBox(height: 4),
            for (final n in all)
              ListTile(
                key: Key('pn-$n'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                onTap: () => set(() => head = n),
                leading: Icon(n == head ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: n == head ? C.green : C.faint),
                title: Text(n, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
            const SizedBox(height: 8),
          ],
          if (rate) ...[
            TextField(
              key: const Key('pn-rate'),
              controller: rc,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(labelText: tr('Diesel debit rate ₹ / litre'), hintText: tr('automatic')),
            ),
            const SizedBox(height: 4),
            Text(
                byBill
                    ? 'Empty = each bill at its own rate (the rate typed in that bill, else the automatic rate). Type a rate to debit the diesel at that rate in this print.'
                    : 'Empty = the automatic rate (the higher of the average rate of these dates and the last purchase rate). Type a rate to debit the diesel at that rate in this print.',
                style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
            const SizedBox(height: 10),
          ],
          Text('Page', style: const TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            key: const Key('pn-page'),
            segments: [ButtonSegment(value: true, label: Text('Portrait')), ButtonSegment(value: false, label: Text('Landscape'))],
            selected: {portrait},
            onSelectionChanged: (v) => set(() => portrait = v.first),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
          FilledButton(
            key: const Key('pn-ok'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
            onPressed: () {
              final t = rc.text.trim(), v = t.isEmpty ? null : num.tryParse(t);
              final bad = t.isNotEmpty && (v == null || !(r2(v) >= .01 && v < 1000));
              _lastHead = head;
              _lastPortrait = portrait;
              Navigator.pop(dc, LbPrintAsk(head, bad ? null : v, bad, portrait));
            },
            child: const Text('Print'),
          ),
        ],
      ),
    ),
  );
}

/// The Log Book of [rows] (getLogBookList's rows) for [from] – [to], printed. [fmt] / [sample]: View format.
Future<void> printLogBook(BuildContext context, Session s, {required List<Map<String, dynamic>> rows, required String from, required String to, String fmt = '', String sample = '', num dieselRate = 0, Map? rateBy, Map? idle}) async {
  if (rows.isEmpty) {
    toast(context, 'No Log Book entries to print – pick a Machinery and dates first.', bad: true);
    return;
  }
  final opt = await askLbPrint(context, s.printNames, rate: sample.isEmpty, value: dieselRate, byBill: dieselRate <= 0 && rateBy != null && rateBy.isNotEmpty);
  if (opt == null || !context.mounted) return;
  if (opt.bad) {
    toast(context, 'Diesel rate: type ₹ per litre (for example 95.50), or leave it empty for the automatic rate. Nothing was printed.', bad: true);
    return;
  }
  var rate = dieselRate;
  var by = rateBy;
  if (sample.isEmpty) {
    // typed here = the rate of this print; a rate that stood in the box and was emptied = automatic; empty for several bills = each bill's own rate
    if ((opt.typed ?? 0) > 0) {
      rate = r2(opt.typed!);
      by = null;
    } else {
      rate = 0;
      by = dieselRate > 0 ? null : rateBy;
    }
  }
  final dates = rows.map((r) => '${r['date']}').toList()..sort();
  final f = from.isNotEmpty ? from : dates.first, t = to.isNotEmpty ? to : (s.today.isNotEmpty ? s.today : dates.last);
  Map extra = {'debit': {}};
  if (sample.isEmpty) {
    try {
      extra = (await s.api.call('logPrintExtra', [
            {'from': f, 'to': t, 'nos': rows.map((r) => '${r['no']}').toSet().toList()}
          ])) as Map? ??
          extra;
    } catch (_) {/* the bill part without debit / BOQ */}
  }
  var logo = '';
  if (opt.head.toLowerCase().contains('rachana')) {
    try {
      logo = 'data:image/png;base64,${base64Encode((await rootBundle.load('assets/brand/rachana_logo.png')).buffer.asUint8List())}';
    } catch (_) {/* the name only */}
  }
  final p = logBookPrint(
    rows: rows,
    from: f,
    to: t,
    head: opt.head,
    site: s.siteLabel,
    extra: extra,
    machine: (no) => sample.isNotEmpty ? null : s.machine(no)?.m,
    fmtF: fmt,
    sample: sample,
    dieselRate: rate,
    rateBy: by,
    idle: idle,
    logo: logo,
    portrait: opt.portrait,
  );
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: p.html, title: p.title, fit: true)));
}
