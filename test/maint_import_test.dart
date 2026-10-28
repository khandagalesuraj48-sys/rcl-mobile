/* (3.53.0, Mechanical update-173) THE OLD MAINTENANCE LOG BOOK, READ AS THE WEB READS IT – maint_logbook.xlsx is his "All Machinery
 * Maintenance Logbook" layout (a sheet a machinery, its name above the heading, a bill = rows of one date and party, a merged date,
 * a reading only on a bill's first row, "Amount With GST" in whole rupees, a ₹0 line, the total line, a row with a wrong date);
 * maint_logbook.json is what the web's own code (App.html mliRead / mliSheet / mliMatch, SheetJS 0.18.5) makes of it – made by the
 * scratchpad's mli_fixture.js. The app's core/maint_import.dart must make exactly the same. */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/maint_import.dart';
import 'package:rcl_mobile/core/sheet_read.dart';

const dir = 'test/fixtures/sheets';
final web = jsonDecode(File('$dir/maint_logbook.json').readAsStringSync()) as Map<String, dynamic>;

/// The first place two JSON values differ ('' = the same): numbers by value, a text is not a number, '' is not null.
String differ(Object? a, Object? b, [String at = r'$']) {
  if (a is num && b is num) return a == b ? '' : '$at: $a ≠ $b';
  if (a is Map && b is Map) {
    for (final k in {...a.keys, ...b.keys}) {
      if (a.containsKey(k) != b.containsKey(k)) return '$at.$k: only on one side';
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

void main() {
  final master = [for (final m in web['master'] as List) (m as Map).cast<String, dynamic>()];
  final today = '${web['today']}';
  final tabs = readSheets(Uint8List.fromList(File('$dir/maint_logbook.xlsx').readAsBytesSync()));

  test('the Own machinery on the site today – as the web', () {
    expect([for (final m in mliOwn(master, today)) m['id']], web['own']);
  });

  test('the file read sheet by sheet, bill by bill, line by line – exactly as the web', () {
    final got = jsonDecode(jsonEncode([for (final x in mliRead(tabs, master, today)) x.toJson()]));
    // (the web's res / done – the answers of Check and Import – are empty before Check)
    final want = [for (final x in web['sheets'] as List) Map<String, dynamic>.from(x as Map)..remove('res')..remove('done')];
    expect((web['sheets'] as List).every((x) => x['res'] == null && x['done'] == null), isTrue);
    expect(differ(got, want), '');
    expect([for (final x in got as List) '${x['sheet']}→${x['no']}'], ['Roller 03→RL-173', 'MH12XW0169→MH-12-XW-0169', 'JCB→']);
  });

  test('(28-10-2026) the lines that do not add up – Qty × Rate, Amount + GST, an odd GST % – as the web finds them', () {
    final got = [for (final x in mliRead(tabs, master, today)) jsonDecode(jsonEncode(x.warn))];
    expect(differ(got, [for (final x in web['sheets'] as List) x['warn']]), '');
    expect(got[1], [
      {'line': 6, 'work': 'Coolant', 'k': 'qr', 'a': 500, 'b': 450},
      {'line': 6, 'work': 'Coolant', 'k': 'ag', 'a': 531, 'b': 541},
    ]);
  });

  test('(28-10-2026) a PDF read by the AI: its tables as sheets – a table without its machinery goes on with the one before; "Line n" = its n-th row – as the web', () {
    final got = jsonDecode(jsonEncode([for (final x in mliAiSheets('Old log book.pdf', (web['aiTables'] as List).cast<Map>(), master, today)) x.toJson()]));
    final want = [for (final x in web['aiSheets'] as List) Map<String, dynamic>.from(x as Map)..remove('res')..remove('done')];
    expect(differ(got, want), '');
    expect([for (final x in got as List) '${x['sheet']}→${x['no']}:${x['rows']}'], ['ROLLER NO-03→RL-173:3', 'MH12XW0169→MH-12-XW-0169:1']);
  });

  test('(28-10-2026) the names of the file with their rows; the bills sent with the ticked names (with a name) – as the web', () {
    final sheets = mliRead(tabs, master, today);
    expect(differ(jsonDecode(jsonEncode(mliNamesOf(sheets))), web['names']), '');
    final fixes = [for (final z in (web['fixes'] as List).cast<Map>()) MliFix('${z['f']}', '${z['from']}', '${z['to']}', 0)..on = z['on'] == true];
    expect(differ(jsonDecode(jsonEncode(mliBills(sheets[0], fixes))), web['billsFixed']), '');
    expect(sheets[0].bills[0]['garage'], 'Store', reason: 'the file as it is stays');
    expect(identical(mliBills(sheets[0], [MliFix('party', 'Store', 'X', 1)]), sheets[0].bills), isTrue, reason: 'nothing ticked: the bills as read');
  });

  test('a name as a key: ROLLER NO-03 = ROLLER-03 = Roller No.03; MH12XW0169 = MH-12-XW-0169', () {
    expect(mliKey('ROLLER NO-03'), mliKey('ROLLER-03'));
    expect(mliKey('Roller No.03'), mliKey('ROLLER 3'));
    expect(mliKey('MH12XW0169'), mliKey('MH-12-XW-0169'));
    expect(mliKey('NOVA 1'), isNot(mliKey('VA 1')));
  });

  test('a line\'s GST % from its GST Amount: 18 % when it makes it to ₹1 (whole rupees), else the % itself; none when ₹0', () {
    expect(mliGst(1180, 212), 18);
    expect(mliGst(1180, 212.4), 18);
    expect(mliGst(1000, 50), 5);
    expect(mliGst(1000, 33), 3.3);
    expect(mliGst(0, 0), '');
    expect(mliGst(500, ''), '');
    expect(mliNum('1,180.50'), 1180.5);
    expect(mliNum('₹ 59'), 59);
    expect(mliNum('—'), '');
  });
}
