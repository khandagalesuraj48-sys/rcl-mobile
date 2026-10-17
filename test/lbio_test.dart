/* (3.12.0) The Log Book in Excel – proven against the web's own code (fixtures/lbio/web_lbio.json, made by running App.html's
 * lbExport / lbColsFor / lbSheet / lbTemplate / the import's own lines / lbProblems in node, see the scratchpad's lbio/gen.js):
 *   – every export (date-wise and machinery-wise; all machinery and one picked) of real Log Book rows of the server: the file
 *     name, what is said, every tab, every cell (texts, numbers, the Total formulas with their figures), the widths, the
 *     heading row, the drop-down of every cell (its list, title, prompt, error; yellow when empty);
 *   – the two templates;
 *   – the import of every export read back and of a file typed by hand (times, Status, the way in other letters, item work,
 *     Work type, Debit to, a water tanker's trips, blank rows, a total line, a tab without the columns): every row and its
 *     problems, the trips, the tanker lines refused. */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/imports.dart' show findMachine;
import 'package:rcl_mobile/core/lb_io.dart';
import 'package:rcl_mobile/core/sheet_read.dart';
import 'package:rcl_mobile/core/xlsx.dart';

const dir = 'test/fixtures/lbio';
final fx = jsonDecode(File('$dir/web_lbio.json').readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> maps(Object? l) => [for (final x in (l as List? ?? const [])) (x as Map).cast<String, dynamic>()];

/// The first place two JSON values differ ('' = the same): numbers by value; "NaN!" = NaN.
String differ(Object? a, Object? b, [String at = r'$']) {
  if (a is double && a.isNaN && b == 'NaN!') return '';
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
  test('Every export of the Log Book (date-wise / machinery-wise, all or one machinery) – cell by cell as the web\'s', () {
    final cases = (fx['cases'] as Map).cast<String, dynamic>();
    var n = 0;
    for (final e in maps(fx['exports'])) {
      final c = (cases[e['case']] as Map).cast<String, dynamic>();
      final master = maps(c['master']);
      final no = '${e['no']}';
      final picked = no.isEmpty ? null : findMachine(master, no);
      final f = lbExportFilter(from: '${c['from']}', to: '${c['to']}', no: no, picked: picked);
      final why = '${e['case']} ${e['kind']} ${no.isEmpty ? 'all' : no}';
      expect(differ(f, (e['asked'] as List).single), '', reason: '$why: the filter asked of the server');
      final rows = [for (final r in maps(c['rows'])) if (no.isEmpty || r['no'] == no) jsonDecode(jsonEncode(r)) as Map<String, dynamic>];
      if ('${e['error']}'.isNotEmpty) {
        expect(() => lbExport(kind: '${e['kind']}', f: f, picked: picked, rows0: rows, itemBoq: c['itemBoq'] as Map, master: master, today: '${c['today']}', company: 'Rachana Construction Limited', site: 'VTR Site – NH 848'),
            throwsA(isA<SheetError>().having((x) => x.message, 'message', e['error'])),
            reason: why);
        continue;
      }
      final x = lbExport(kind: '${e['kind']}', f: f, picked: picked, rows0: rows, itemBoq: c['itemBoq'] as Map, master: master, today: '${c['today']}', company: 'Rachana Construction Limited', site: 'VTR Site – NH 848');
      expect(x.file, e['file'], reason: why);
      expect(x.said, (e['toast'] as List).single, reason: why);
      expect(differ([for (final s in x.sheets) sheetJson(s)], e['sheets']), '', reason: why);
      n++;
    }
    expect(n, 20);
  });

  test('The two templates – 200 lines, the drop-downs, the machinery of the site on a hidden tab', () {
    for (final t in maps(fx['templates'])) {
      final x = lbTemplate('${t['kind']}', maps(t['master']), '${t['today']}');
      expect(x.file, t['file']);
      expect(differ([for (final s in x.sheets) sheetJson(s)], t['sheets']), '', reason: '${t['kind']}');
    }
  });

  test('The import: every row as the web reads it, the blank ones left out, a water tanker\'s trips, each row\'s problems', () {
    for (final i in maps(fx['imports'])) {
      final f = '${i['file']}';
      final master = maps(i['master']);
      final tabs = readSheets(Uint8List.fromList(File('$dir/$f').readAsBytesSync()));
      if (i['error'] != null) {
        expect(() => readLogFile(tabs, master), throwsA(isA<SheetError>().having((x) => x.message, 'message', i['error'])), reason: f);
        continue;
      }
      final x = readLogFile(tabs, master);
      expect(differ([for (final r in x.rows) {'row': r, 'problems': logProblems(r, '${i['today']}', master)}], i['rows']), '', reason: '$f rows');
      expect([x.skipped, x.tkStatus, x.tkStatusNote], [i['skipped'], i['tkStatus'], i['tkStatusNote']], reason: f);
      expect(differ(x.trips, i['trips']), '', reason: '$f trips');
      expect(differ(x.tkBad, i['tkBad']), '', reason: '$f tanker lines refused');
    }
  });

  test('The Excel file of an export: read back, the cells are the same (the formulas give their figures)', () {
    final t = lbTemplate('date', maps(maps(fx['templates']).first['master']), '2026-10-06');
    final tabs = readSheets(sheetsXlsx(t.sheets));
    expect(tabs.map((x) => x.name), ['Log Book', 'Lists']);
    expect(tabs.first.rows.first.take(4), ['Date', 'Shift', 'Machinery', 'Measured by']);
    expect(tabs.first.rows[1][5], 1260, reason: 'a number stays a number (Close KM)');
    final e = maps(fx['exports']).firstWhere((e) => e['case'] == 'kmhr_monthly' && e['kind'] == 'date' && e['no'] == '');
    final c = (fx['cases'] as Map)['kmhr_monthly'] as Map;
    final x = lbExport(kind: 'date', f: lbExportFilter(from: '${c['from']}', to: '${c['to']}', no: '', picked: null), picked: null, rows0: maps(c['rows']), itemBoq: const {}, master: maps(c['master']), today: '${c['today']}', company: 'Rachana Construction Limited', site: 'VTR Site – NH 848');
    final back = readSheets(sheetsXlsx(x.sheets)).single.rows;
    final want = (e['sheets'] as List).first['aoa'] as List;
    for (var r = 0; r < want.length; r++) {
      for (var k = 0; k < (want[r] as List).length; k++) {
        final w = (want[r] as List)[k];
        final v = w is Map ? (w['result'] ?? '') : w;
        expect(back[r][k], v, reason: 'row ${r + 1} col ${k + 1}');
      }
    }
  });
}
