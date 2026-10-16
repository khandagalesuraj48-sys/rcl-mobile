/* (3.13.0) The other Excel imports, the water tanker's Export and the QR labels – proven against the web's own code:
 *   – fixtures/more/web_more.json: App.html's own lines that read an Asset Master file (m_file), a Vehicle Compliance file
 *     (cp_file), a water tanker's trips (lt_file – with the tanker open and with none) and the Store's item file (rcl-store
 *     f_file, an .xlsx and a .csv) run in node on the same test files (the scratchpad's more/gen.js);
 *   – fixtures/more/web_tanker_export.json: the web's Export Excel of a water tanker (lt_export, more/tk_export.js);
 *   – fixtures/qr/web_qr.json: the web's QR code (qrcode-generator 1.4.4 in App.html) of the label links (qr/qr.js). */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/lb_io.dart' show XSheet, XList, XFormula;
import 'package:rcl_mobile/core/more_imports.dart';
import 'package:rcl_mobile/core/sheet_read.dart';
import 'package:rcl_mobile/core/xlsx.dart';

const dir = 'test/fixtures/more';
final web = jsonDecode(File('$dir/web_more.json').readAsStringSync()) as Map<String, dynamic>;

Uint8List bytes(String f) => Uint8List.fromList(File('$dir/$f').readAsBytesSync());

/// The first place two JSON values differ ('' = the same): numbers by value.
String differ(Object? a, Object? b, [String at = r'$']) {
  if (a is num && b is num) return a == b ? '' : '$at: $a ≠ $b';
  if (a is Map && b is Map) {
    for (final k in {...a.keys, ...b.keys}) {
      if (a.containsKey(k) != b.containsKey(k)) return '$at.$k: only on one side (${jsonEncode(a[k])} / ${jsonEncode(b[k])})';
      final d = differ(a[k], b[k], '$at.$k');
      if (d.isNotEmpty) return d;
    }
    return '';
  }
  if (a is List && b is List) {
    if (a.length != b.length) return '$at: ${a.length} items ≠ ${b.length} items';
    for (var i = 0; i < a.length; i++) {
      final d = differ(a[i], b[i], '$at[$i]');
      if (d.isNotEmpty) return d;
    }
    return '';
  }
  return a == b ? '' : '$at: ${jsonEncode(a)} ≠ ${jsonEncode(b)}';
}

/// What a reader gives, as the fixture writes it (an error: {error: its words}).
Object? run(Object? Function() f) {
  try {
    return jsonDecode(jsonEncode(f()));
  } on SheetError catch (e) {
    return {'error': e.message};
  }
}

List<SheetTab> storeTabs(Uint8List b) => isZipSheet(b) ? asShown(readSheets(b)) : readSheets(b, shown: true);

/// A tab as the fixture writes it (the drop-down texts once, each cell's drop-down by its number).
Map<String, Object?> sheetJson(XSheet s) {
  final kinds = <XList>[];
  final vals = [
    for (final v in s.validations)
      () {
        var k = kinds.indexOf(v.$3);
        if (k < 0) {
          kinds.add(v.$3);
          k = kinds.length - 1;
        }
        return [v.$1, v.$2, k, v.$4];
      }(),
  ];
  return {
    'name': s.name,
    'hidden': s.hidden,
    'head': s.head,
    'widths': s.widths,
    'aoa': [for (final r in s.aoa) [for (final c in r) c is XFormula ? c.toJson() : c]],
    'lists': [for (final k in kinds) {'list': k.list, 'title': k.title, 'prompt': k.prompt, 'error': k.error}],
    'validations': vals,
  };
}

void main() {
  test('Asset Master – Import from Excel: the tab "Master", the columns by their names, N/A, Lifetime, the dates – as the web reads it', () {
    expect(differ(run(() => masterImportRows(readSheets(bytes('master.xlsx')))), web['master']), '');
    expect(run(() => masterImportRows(readSheets(bytes('compliance_short.xlsx')))), {'error': 'The file needs a "Machinery Number" or "Machinery Name" column. Use Export to get the right format.'});
  });

  test('Vehicle Compliance – Import Excel: the tab "Compliance", the paper columns, NA / Lifetime / Not needed, the dates', () {
    for (final k in ['compliance', 'compliance_short']) {
      expect(differ(run(() => complianceImportRows(readSheets(bytes('$k.xlsx')))), web[k]), '', reason: k);
    }
    expect(run(() => complianceImportRows(readSheets(bytes('store.xlsx')))), web['compliance_none']);
  });

  test('Water tanker – Import Excel: every tab, the times, a line without its tanker is the open tanker\'s (or none)', () {
    expect(differ(run(() => tankerImportRows(readSheets(bytes('tanker.xlsx')), 'MH-04-J-9844')), web['tanker']), '');
    expect(differ(run(() => tankerImportRows(readSheets(bytes('tanker.xlsx')), '')), web['tanker_nome']), '');
    expect(run(() => tankerImportRows(readSheets(bytes('store.xlsx')), 'X')), {'error': 'No trips in the file.'});
  });

  test('Water tanker – Export Excel: the web\'s file (name, said, every cell, widths, heading row, the Shift drop-down)', () {
    final cases = jsonDecode(File('$dir/web_tanker_export.json').readAsStringSync()) as List;
    for (final c0 in cases) {
      final c = (c0 as Map).cast<String, dynamic>();
      final x = tankerExport(
        machine: c['machine'] as Map,
        trips: [for (final t in c['trips'] as List) t as Map],
        from: '${c['from']}',
        to: '${c['to']}',
        company: '${c['company']}'.isEmpty ? 'Rachana Construction Limited' : '${c['company']}',
        site: '${c['site']}',
      );
      expect(x.file, c['file'], reason: c['name']);
      expect(x.said, c['toast'], reason: c['name']);
      expect(differ([sheetJson(x.sheet)], c['sheets']), '', reason: c['name']);
    }
    // the file itself, read back: the trips come in again as the web reads them
    final c = (cases.first as Map).cast<String, dynamic>();
    final x = tankerExport(machine: c['machine'] as Map, trips: [for (final t in c['trips'] as List) t as Map], from: '${c['from']}', to: '${c['to']}', company: 'Rachana Construction Limited', site: '${c['site']}');
    final back = tankerImportRows(readSheets(sheetsXlsx([x.sheet])), '');
    expect([for (final r in back) [r['date'], r['shift'], r['no'], r['c'], r['a'], r['b'], r['ch'], r['u']]], [
      ['2026-10-14', 'Day', 'MH-04-J-9844', 'WT-101', '08:10', '08:40', '12+000', 'Curing'],
      ['2026-10-15', 'Night', 'MH-04-J-9844', 'WT-102', '21:15', '21:55', '', ''],
    ]);
  });

  test('Store – Import from Excel: the cells as the sheet shows them (.xlsx and .csv), the headings found, blank rows left out', () {
    expect(differ(run(() => storeImportRows(storeTabs(bytes('store.xlsx')))), web['store']), '');
    expect(differ(run(() => storeImportRows(storeTabs(bytes('store.csv')))), web['store_csv']), '');
    expect(run(() => storeImportRows(storeTabs(bytes('compliance_short.xlsx')))), web['store_none']);
  });

  test('A number as the sheet shows it (SheetJS General)', () {
    // the figures: SheetJS 0.18.5 X.SSF.format('General', v) of the same numbers
    expect([for (final v in [10, 0.5, 18.5, 0.1 + 0.2, 12345678901, 40092100, 1 / 3, 1e-7, 123456789012345.0, -2.5, 1e21, 2147483648, -0.000123456, 98765.4321]) generalText(v)],
        ['10', '0.5', '18.5', '0.3', '12345678901', '40092100', '0.333333333', '0.0000001', '1.23457E+14', '-2.5', '1E+21', '2147483648', '-0.000123456', '98765.4321']);
  });

  test('QR labels: the web\'s link and QR code (SVG) for every machinery number', () {
    final qr = jsonDecode(File('test/fixtures/qr/web_qr.json').readAsStringSync()) as List;
    expect(qr.length, greaterThan(5));
    for (final x0 in qr) {
      final x = (x0 as Map).cast<String, dynamic>();
      expect(qrLink('https://rcl-erp.example.app', '${x['id']}'), x['link'], reason: '${x['id']}');
      expect(qrLink('https://rcl-erp.example.app/', '${x['id']}'), x['link'], reason: '${x['id']}');
      expect(qrSvg('${x['link']}'), x['svg'], reason: '${x['id']}');
    }
    final html = qrLabelsHtml([
      {'id': 'MH-25-AJ-8511', 'name': 'MH-25-AJ-8511', 'type': 'Tipper'},
      {'id': 'EX-1', 'name': 'Sany 210', 'type': 'sany 210'},
      {'id': 'DG <1>', 'name': '', 'type': ''},
    ], 'https://rcl-erp.example.app', 'NHAI – VTR');
    expect('<div class="qrl">'.allMatches(html).length, 3);
    expect(html, contains('<u>NHAI – VTR</u>'));
    expect(html, contains('<b>MH-25-AJ-8511</b><span>Tipper</span>'), reason: 'the name left out when it is the number');
    expect(html, contains('<b>EX-1</b><span>Sany 210</span>'), reason: 'the type left out when it is the name');
    expect(html, contains('<b>DG &lt;1&gt;</b><span></span>'));
    final page = qrPrintHtml('QR labels – 3 machinery', html, 'Sketchline "Infra"');
    expect(page, contains('<body class="qr-labels"><div class="sheet">$html</div>'));
    expect(page, contains('@bottom-left { content: "SKETCHLINE INFRA  |  Fleet ERP"; }'));
    expect(qrPrintHtml('QR labels – EX-1', html, ''), isNot(contains('@page { @bottom-left { content: "  |')));
  });
}
