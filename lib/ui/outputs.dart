/* EXCEL AND PRINT OF ANY LIST OR REPORT (3.4.0 – the reports' own, now shared by every screen): an .xlsx made on the phone and
 * handed to the phone's sharing (Excel, Sheets, WhatsApp, Drive …), and the A4 page as the web prints it (the company picked on
 * top, the site, the signatures) handed to the phone's printing (a printer, or "Save as PDF"). */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/rdoc.dart';
import '../core/rprint.dart';
import '../core/session.dart';
import '../core/xlsx.dart';
import '../web/files.dart' show safeFileName;
import '../web/print_view.dart';
import 't.dart';
import 'theme.dart';

/// The lines on top of every sheet: the company, the site, the title, the dates.
List<String> sheetTop(Session s, RDoc d, [String? head]) => [head ?? s.printNames.first, if (s.siteLabel.isNotEmpty) s.siteLabel, d.title, if (d.period.isNotEmpty) d.period];

/// An .xlsx to the phone's sharing.
Future<void> shareXlsx(Uint8List bytes, String fileName) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/rcl_files');
  await dir.create(recursive: true);
  final name = safeFileName(fileName.endsWith('.xlsx') ? fileName : '$fileName.xlsx');
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', name: name)], title: name));
}

/// (3.9.0) Any file to the phone's sharing (a .csv list …).
Future<void> shareFile(Uint8List bytes, String fileName, String mime) async {
  final dir = Directory('${(await getTemporaryDirectory()).path}/rcl_files');
  await dir.create(recursive: true);
  final name = safeFileName(fileName);
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mime, name: name)], title: name));
}

/// The report / list as Excel (every table a sheet; [bare]: the heading line first – an export to be imported back).
Future<void> shareDocXlsx(Session s, RDoc d, {bool bare = false}) => shareXlsx(reportXlsx(d, bare ? const [] : sheetTop(s, d)), '${d.file}.xlsx');

/// The report / list printed: the name on top asked when the site has several, then the phone's printing.
Future<void> printDoc(BuildContext context, Session s, RDoc d, {String? printed}) async {
  final head = await pickPrintName(context, s.printNames, 'Print – ${d.title}');
  if (head == null || !context.mounted) return;
  var logo = '';
  if (head.toLowerCase().contains('rachana')) {
    try {
      logo = 'data:image/png;base64,${base64Encode((await rootBundle.load('assets/brand/rachana_logo.png')).buffer.asUint8List())}';
    } catch (_) {/* the name only */}
  }
  final html = reportHtml(d, company: head, site: s.siteLabel, printed: printed ?? whenText(DateTime.now().toIso8601String()), logo: logo);
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: html, title: d.title)));
}

/// Which name heads the print (the site's bill names; the company first) – asked only when there is more than one.
Future<String?> pickPrintName(BuildContext context, List<String> names, String title) async {
  if (names.length < 2) return names.isEmpty ? 'Rachana Construction Limited' : names.first;
  return showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text(title),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 8), child: Text('Which name should be printed at the top?', style: const TextStyle(color: C.muted))),
        for (final n in names) SimpleDialogOption(key: Key('pn-$n'), onPressed: () => Navigator.pop(c, n), child: Text(n, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}
