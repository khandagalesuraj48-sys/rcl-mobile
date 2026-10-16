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
/// under the bill's company name – '' when it has no entries.
String billLogSheets(Session s, Map b, List<Map<String, dynamic>> rows0, String from, String to, Map extra, {String logo = ''}) {
  final nos = billNos(b);
  final rows = rows0.where((r) => nos.contains('${r['no']}'.toUpperCase())).toList();
  if (rows.isEmpty) return '';
  final idle = {for (final n in nos) _key(n): b['idlePaid'] != false};
  final rate = num.tryParse('${b['dieselRate'] ?? ''}') ?? 0;
  try {
    return logBookPrint(rows: rows, from: from, to: to, head: '${b['company'] ?? ''}', site: s.siteLabel, extra: extra, machine: (no) => s.machine(no)?.m, dieselRate: rate > 0 ? rate : 0, idle: idle, logo: logo).sheets;
  } catch (_) {
    return '';
  }
}

/// The pages shown and printed (the web's print window for bills).
Future<void> showBillPrint(BuildContext context, String title, String pages, {bool withLb = false, String foot = ''}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: billPrintHtml(title, pages, withLb: withLb, foot: foot), title: title, fit: true)));

/// A saved bill opened: its papers as saved and the Log Book of its machinery as it is now (no entries now → the papers alone,
/// and it says so).
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
      final logs = (await s.api.call('getLogBookList', [
        {'from': b['from'], 'to': b['to'], 'all': true}
      ])) as Map;
      final nos = billNos(data);
      final rows = [for (final x in (logs['rows'] as List? ?? const []).whereType<Map>()) if (nos.contains('${x['no']}'.toUpperCase())) x.cast<String, dynamic>()];
      if (rows.isNotEmpty) {
        Map extra = {'debit': {}};
        try {
          extra = (await s.api.call('logPrintExtra', [
                {'from': b['from'], 'to': b['to'], 'nos': rows.map((x) => '${x['no']}').toSet().toList()}
              ])) as Map? ??
              extra;
        } catch (_) {/* the bill part without debit / BOQ */}
        lb = billLogSheets(s, {...data, 'company': b['company']}, rows, '${b['from']}', '${b['to']}', extra, logo: logo);
      } else if (context.mounted) {
        toast(context, 'No Log Book entries now for this bill\'s machinery in its dates – the bill papers are shown without the Log Book.', bad: true);
      }
    } catch (e) {
      if (context.mounted) toast(context, 'The Log Book could not be read (${errText(e)}) – the bill papers are shown without it.', bad: true);
    }
    if (!context.mounted) return;
    await showBillPrint(context, 'Abstract of Bill – ${b['vendor']} – RA Bill ${b['billNo']}', billSheets(data, b['status'] == 'Superseded' ? ' superseded' : '', logo: logo) + lb, withLb: lb.isNotEmpty, foot: '${b['company'] ?? ''}');
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
  }
}

/// The Log Book of a saved bill's machinery for the bill period (as the Log Book is now), printed – at the bill's diesel rate.
Future<void> printSavedBillLog(BuildContext context, Session s, String id) async {
  try {
    final r = (await s.api.call('getBills', [
      {'id': id}
    ])) as Map;
    final list = (r['bills'] as List? ?? const []);
    if (list.isEmpty || !context.mounted) return;
    final b = (list.first as Map).cast<String, dynamic>(), data = ((b['data'] as Map?) ?? const {});
    final nos = billNos(data);
    final logs = (await s.api.call('getLogBookList', [
      {'from': b['from'], 'to': b['to'], 'all': true}
    ])) as Map;
    final rows = [for (final x in (logs['rows'] as List? ?? const []).whereType<Map>()) if (nos.contains('${x['no']}'.toUpperCase())) x.cast<String, dynamic>()];
    if (!context.mounted) return;
    if (rows.isEmpty) {
      toast(context, 'No Log Book entries for this bill\'s machinery in its dates.', bad: true);
      return;
    }
    final rate = num.tryParse('${data['dieselRate'] ?? ''}') ?? 0;
    await printLogBook(context, s, rows: rows, from: '${b['from']}', to: '${b['to']}', idle: {for (final n in nos) _key(n): data['idlePaid'] != false}, dieselRate: rate > 0 ? rate : 0);
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
