// (3.57.0) THE OLD INWARD REGISTER (the Store's import): the app reads his register and makes the check EXACTLY as the web does –
// proven against the web's own code (rcl-store public/grnreg.js on the same file: test/fixtures/sheets/grn_reg.json, made by
// tool/grnreg_fixture.js): the sheet, every row, the GRNs, the rows to look at, the duplicates, the notes, the new suppliers and items,
// the next GRN – with nothing chosen, and with a duplicate deleted, a date and a quantity typed, names ticked.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/grn_reg.dart';
import 'package:rcl_mobile/core/sheet_read.dart';

/// JSON of JavaScript and of Dart alike: a whole number as a whole number, nothing for null / undefined
Object? norm(Object? v) {
  if (v is num) return v == v.truncateToDouble() && v.abs() < 1e15 ? v.toInt() : v.toDouble();
  if (v is Map) return {for (final e in v.entries) if (e.value != null) '${e.key}': norm(e.value)};
  if (v is List) return [for (final x in v) norm(x)];
  if (v is (String, int)) return [v.$1, v.$2];
  return v;
}

void main() {
  final web = jsonDecode(File('test/fixtures/sheets/grn_reg.json').readAsStringSync()) as Map<String, dynamic>;
  final tabs = readSheets(File('test/fixtures/sheets/grn_reg.xlsx').readAsBytesSync());
  final sh = grnPickSheet(tabs)!;
  final rows = grnReadRows(sh);
  final info = (web['info'] as Map).cast<String, dynamic>(), today = '${web['today']}';

  test('the register\'s sheet among all (not the Summary, not a material\'s sheet), its columns by their words', () {
    expect(web['xlsx'], '0.18.5');
    expect({'name': sh.name, 'hi': sh.hi, 'col': sh.col, 'n': sh.n, 'others': sh.others}, norm(web['sheet']));
  });

  test('every row as the web reads it (a GRN\'s details carried to its rows; dates, GRN Nos, the empty rows left)', () {
    final w = web['rows'] as List;
    expect(rows.length, w.length);
    for (var i = 0; i < rows.length; i++) {
      expect(norm(rows[i]), norm(w[i]), reason: 'row ${rows[i]['line']}');
    }
  });

  void same(Map<String, dynamic> p, Map w) {
    for (final k in ['look', 'dups', 'notes', 'empty', 'newItems', 'newSup', 'already']) {
      expect(norm(p[k]), norm(w[k]), reason: k);
    }
    final pd = p['docs'] as List, wd = w['docs'] as List;
    expect(pd.length, wd.length, reason: 'GRNs');
    for (var i = 0; i < pd.length; i++) {
      expect(norm(pd[i]), norm(wd[i]), reason: 'GRN ${(pd[i] as Map)['ref']} (${(pd[i] as Map)['date']})');
    }
    for (final k in ['lines', 'gross', 'from', 'to', 'maxRef', 'first', 'noRef', 'next']) {
      expect(norm(p[k]), norm(w[k]), reason: k);
    }
  }

  test('the check with nothing chosen: the GRNs, to look at, the duplicates, the notes, new suppliers / items, the next GRN – as the web', () {
    final p = grnPlan(rows, info, GrnChoice(), today);
    same(p, web['p0'] as Map);
    expect((p['look'] as List).length, 7);
    expect((p['dups'] as List).length, 4);
  });

  test('with what he chose (a duplicate deleted, a date and a quantity typed, names ticked): as the web', () {
    final ch = GrnChoice.fromJson(web['ch'] as Map);
    expect(norm(ch.toJson()), norm(web['ch']));
    same(grnPlan(rows, info, ch, today), web['p1'] as Map);
  });

  test('the names for the AI; a far date; units, dates, GRN Nos and numbers of the file – as the web', () {
    final n = grnNamesOf(rows), wn = web['names'] as Map;
    for (final l in ['party', 'item', 'category']) {
      expect(norm(n[l]), norm(wn[l]), reason: l);
    }
    final far = grnFarDates([for (final x in const [('1', '2023-01-01'), ('2', '2023-01-05'), ('3', '2003-01-06'), ('4', '2023-01-09'), ('5', '2023-01-12'), ('6', '2023-01-15')]) (ref: x.$1, date: x.$2, typed: false)], today);
    expect({for (final e in far.entries) e.key: {'date': e.value.date, 'near': e.value.near}}, norm(web['far']));
    for (final u in web['units'] as List) {
      final r = grnUnit(u[0]);
      expect({'unit': r.unit, 'note': r.note}, norm(u[1]), reason: '${u[0]}');
    }
    for (final d in web['days'] as List) {
      expect(grnDayIn(d[0]), d[1], reason: '${d[0]}');
    }
    for (final r in web['refs'] as List) {
      expect(grnRefIn(r[0]), r[1], reason: '${r[0]}');
    }
    for (final x in web['nums'] as List) {
      expect(norm(grnNumIn(x[0])), norm(x[1]), reason: '${x[0]}');
    }
  });
}
