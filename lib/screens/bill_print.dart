/* A BILL ON PAPER (3.8.0) – the papers of a bill (Abstract of Bill, Tax Invoice, GST declaration, Debit Note) and after them the
 * Log Book of its machinery, one page each, as the web's print window: on A4, each bill fitted to one page, under the bill's
 * company name; handed to the phone's printing (a printer, or "Save as PDF"). Used by Machinery Billing (preview, the bills just
 * submitted), RCL Drive, Bill Summary and the Vendor Ledger (a saved bill: View / Print, its Log Book). */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show rootBundle;

import '../core/bill.dart';
import '../core/lb_print.dart';
import '../core/session.dart';
import '../ui/widgets.dart';
import '../web/print_view.dart';
import 'log_print.dart';

/// A button in a row of buttons (the theme's buttons are as wide as the screen).
final kSmallBtn = OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14));

String _logo = '';

/// The Rachana logo as a data: address (for the papers and the Log Book under the Rachana name).
Future<String> rachanaLogo() async {
  if (_logo.isNotEmpty) return _logo;
  try {
    _logo = 'data:image/png;base64,${base64Encode((await rootBundle.load('assets/brand/rachana_logo.png')).buffer.asUint8List())}';
  } catch (_) {/* the web's own picture is used */}
  return _logo;
}

/// The logo for a bill of [company] ('' = not Rachana).
Future<String> logoFor(String company) async => RegExp('rachana', caseSensitive: false).hasMatch(company) ? rachanaLogo() : '';

/// The machinery numbers of a bill (the number it has today when it was changed after the bill), upper case.
Set<String> billNos(Map b) {
  String no(Map m) => '${m['noNow'] ?? ''}'.isNotEmpty ? '${m['noNow']}' : '${m['no'] ?? ''}';
  return {for (final m in (b['machines'] as List? ?? const []).whereType<Map>()) no(m).toUpperCase()}..remove('');
}

String _key(String no) => no.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// The Log Book sheets of a bill's machinery for [from] – [to] (the bill's own Paid / Not paid for Idle days and its diesel rate),
/// under the bill's company name – '' when it has no entries. [machines] (3.32.0): a saved bill's evidence – its entries as
/// submitted (taken as they are) and its machinery as it was then.
String billLogSheets(Session s, Map b, List<Map<String, dynamic>> rows0, String from, String to, Map extra, {String logo = '', Map<String, Map<String, dynamic>>? machines}) {
  final nos = billNos(b);
  final rows = machines != null ? rows0 : rows0.where((r) => nos.contains('${r['no']}'.toUpperCase())).toList();
  if (rows.isEmpty) return '';
  final idle = {for (final n in (machines != null ? machines.keys : nos.map(_key))) n: b['idlePaid'] != false};
  final rate = num.tryParse('${b['dieselRate'] ?? ''}') ?? 0;
  try {
    return logBookPrint(rows: rows, from: from, to: to, head: '${b['company'] ?? ''}', site: s.siteLabel, extra: extra, machine: (no) => machines?[_key(no)] ?? s.machine(no)?.m, dieselRate: rate > 0 ? rate : 0, idle: idle, logo: logo).sheets;
  } catch (_) {
    return '';
  }
}

/// (3.32.0 – the web's update-151) A saved bill's Log Book: [fixed] – AS SUBMITTED, the evidence kept with the bill (its entries,
/// its machinery as it was, its BOQ / diesel / rates and Idle choice), never the Log Book of today; otherwise (a bill submitted
/// before) – the Log Book of today ([rows] of its machinery in its dates), and [note] says so.
class SavedLog {
  SavedLog(this.kind, this.note, this.rows, {this.extra, this.machines});
  final String kind, note;
  final List<Map<String, dynamic>> rows;
  final Map? extra;
  final Map<String, Map<String, dynamic>>? machines;
  bool get fixed => kind == 'submission';
}

/// The Log Book of the saved bill [b] (getBills' bill) – the web's billLogOf: getBillEvidence first.
Future<SavedLog> savedBillLog(Session s, Map b) async {
  Map? ev;
  try {
    ev = (await s.api.call('getBillEvidence', [
      {'id': b['id']}
    ])) as Map?;
  } catch (_) {
    ev = null;
  }
  final note = evNoteHtml(b, ev, DateTime.now());
  if (ev != null && ev['kind'] == 'submission') {
    final ms = {for (final m in (ev['machines'] as List? ?? const []).whereType<Map>()) if ('${m['id'] ?? ''}'.isNotEmpty) _key('${m['id']}'): m.cast<String, dynamic>()};
    return SavedLog('submission', note, [for (final x in (ev['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()], extra: (ev['extra'] as Map?) ?? {'debit': {}}, machines: ms);
  }
  final nos = billNos((b['data'] as Map?) ?? const {});
  final logs = (await s.api.call('getLogBookList', [
    {'from': b['from'], 'to': b['to'], 'all': true}
  ])) as Map;
  return SavedLog(ev == null ? 'off' : '${ev['kind']}', note, [for (final x in (logs['rows'] as List? ?? const []).whereType<Map>()) if (nos.contains('${x['no']}'.toUpperCase())) x.cast<String, dynamic>()]);
}

/// The Log Book sheets of a saved bill, its note on top ('' = no entries): as submitted, or today's (with today's BOQ / diesel).
Future<String> savedBillLogSheets(Session s, Map b, Map data, SavedLog x, {String logo = ''}) async {
  if (x.rows.isEmpty) return '';
  final bd = {...data, 'company': b['company']};
  if (x.fixed) {
    final ex = x.extra ?? const {};
    final sheets = billLogSheets(s, {...bd, 'idlePaid': ex['idlePaid'], 'dieselRate': ex['dieselRate']}, x.rows, '${b['from']}', '${b['to']}', ex, logo: logo, machines: x.machines ?? const {});
    return sheets.isEmpty ? '' : x.note + sheets;
  }
  Map extra = {'debit': {}};
  try {
    extra = (await s.api.call('logPrintExtra', [
          {'from': b['from'], 'to': b['to'], 'nos': x.rows.map((r) => '${r['no']}').toSet().toList()}
        ])) as Map? ??
        extra;
  } catch (_) {/* the bill part without debit / BOQ */}
  final sheets = billLogSheets(s, bd, x.rows, '${b['from']}', '${b['to']}', extra, logo: logo);
  return sheets.isEmpty ? '' : x.note + sheets;
}

/// The pages shown and printed (the web's print window for bills).
Future<void> showBillPrint(BuildContext context, String title, String pages, {bool withLb = false, String foot = ''}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: billPrintHtml(title, pages, withLb: withLb, foot: foot), title: title, fit: true)));

/// A saved bill opened: its papers as saved and its Log Book – as submitted (3.32.0), or, for a bill submitted before, the Log
/// Book of today, said so (no entries → the papers alone, and it says so).
Future<void> viewSavedBill(BuildContext context, Session s, String id) async {
  try {
    final r = (await s.api.call('getBills', [
      {'id': id}
    ])) as Map;
    final list = (r['bills'] as List? ?? const []);
    if (list.isEmpty || !context.mounted) return;
    final b = (list.first as Map).cast<String, dynamic>();
    final data = <String, dynamic>{'dnNo': b['dnNo'], ...((b['data'] as Map?) ?? const {}).cast<String, dynamic>(), 'billNo': b['billNo'], 'rev': b['rev']};
    final logo = await logoFor('${b['company'] ?? ''}');
    var lb = '';
    try {
      final x = await savedBillLog(s, b);
      if (x.rows.isNotEmpty) {
        lb = await savedBillLogSheets(s, b, data, x, logo: logo);
      } else if (context.mounted) {
        toast(context, 'No Log Book entries ${x.fixed ? 'were kept with this bill' : 'now for this bill\'s machinery in its dates'} – the bill papers are shown without the Log Book.', bad: true);
      }
    } catch (e) {
      if (context.mounted) toast(context, 'The Log Book could not be read (${errText(e)}) – the bill papers are shown without it.', bad: true);
    }
    if (!context.mounted) return;
    await showBillPrint(context, 'Abstract of Bill – ${b['vendor']} – RA Bill ${b['billNo']}', billSheets(data, b['status'] == 'Superseded' ? ' superseded' : b['status'] == 'Deleted' ? ' deleted' : '', logo: logo) + lb, withLb: lb.isNotEmpty, foot: '${b['company'] ?? ''}');
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

/// The Log Book of a saved bill printed: as submitted (3.32.0 – its own BOQ / diesel / rate, no rate question), or, for a bill
/// submitted before, the Log Book of today for the bill period at the bill's diesel rate, said so on top.
Future<void> printSavedBillLog(BuildContext context, Session s, String id) async {
  try {
    final r = (await s.api.call('getBills', [
      {'id': id}
    ])) as Map;
    final list = (r['bills'] as List? ?? const []);
    if (list.isEmpty || !context.mounted) return;
    final b = (list.first as Map).cast<String, dynamic>(), data = ((b['data'] as Map?) ?? const {});
    final x = await savedBillLog(s, b);
    if (!context.mounted) return;
    if (x.rows.isEmpty) {
      toast(context, 'No Log Book entries for this bill\'s machinery in its dates.', bad: true);
      return;
    }
    if (x.fixed) {
      final ex = x.extra ?? const {}, rate = num.tryParse('${ex['dieselRate'] ?? ''}') ?? 0;
      await printLogBook(context, s, rows: x.rows, from: '${b['from']}', to: '${b['to']}', idle: {for (final k in (x.machines ?? const {}).keys) k: ex['idlePaid'] != false}, dieselRate: rate > 0 ? rate : 0, fixed: ex, machines: x.machines, note: x.note);
      return;
    }
    final nos = billNos(data);
    final rate = num.tryParse('${data['dieselRate'] ?? ''}') ?? 0;
    await printLogBook(context, s, rows: x.rows, from: '${b['from']}', to: '${b['to']}', idle: {for (final n in nos) _key(n): data['idlePaid'] != false}, dieselRate: rate > 0 ? rate : 0, note: x.note);
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

/// A saved debit note (work charged to a party, a correction note) as printed.
Future<void> viewDebitNote(BuildContext context, Session s, String id) async {
  try {
    final r = (await s.api.call('getDebitNotes', [
      {'id': id}
    ])) as Map;
    final list = (r['notes'] as List? ?? const []);
    if (list.isEmpty || !context.mounted) return;
    final n = (list.first as Map).cast<String, dynamic>();
    await showBillPrint(context, 'Debit Note – ${n['vendor']} – ${n['no']}', '<section class="billsheet${n['status'] == 'Cancelled' ? ' superseded' : ''}">${debitNoteDocHtml(n)}</section>', foot: '${n['company'] ?? ''}');
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

/// The diesel Debit Note of a saved bill alone.
Future<void> viewBillDebitNote(BuildContext context, Session s, String id) async {
  try {
    final r = (await s.api.call('getBills', [
      {'id': id}
    ])) as Map;
    final list = (r['bills'] as List? ?? const []);
    if (list.isEmpty || !context.mounted) return;
    final b = (list.first as Map).cast<String, dynamic>();
    final data = <String, dynamic>{'dnNo': b['dnNo'], ...((b['data'] as Map?) ?? const {}).cast<String, dynamic>(), 'billNo': b['billNo'], 'rev': b['rev']};
    final dnNo = '${b['dnNo'] ?? ''}';
    await showBillPrint(context, 'Debit Note – ${b['vendor']} – ${dnNo.isNotEmpty ? dnNo : 'RA Bill ${b['billNo']}'}', '<section class="billsheet${b['status'] == 'Superseded' ? ' superseded' : ''}">${debitNoteHtml(data)}</section>', foot: '${b['company'] ?? ''}');
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}
