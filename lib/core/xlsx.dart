/* A REPORT AS AN EXCEL FILE (3.2.0): every table of the report a sheet – the company, the site, the title and the dates on top,
 * the heading line bold, group / total lines bold, numbers as numbers. Made here on the phone (a small .xlsx writer: the file is
 * a zip of a few XML parts), the same file the web gives. */
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'lb_io.dart' show XSheet, XFormula, XList;
import 'rdoc.dart';

String _x(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _col(int i) {
  var n = i + 1, s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

/// A sheet name Excel accepts (31 letters, no : \ / ? * [ ]), unique in the book.
String _sheetName(String n, Set<String> used) {
  var s = n.replaceAll(RegExp(r'[:\\/?*\[\]]'), ' ').trim();
  if (s.isEmpty) s = 'Sheet';
  if (s.length > 31) s = s.substring(0, 31);
  var k = s, i = 2;
  while (used.contains(k.toLowerCase())) {
    final tail = ' ($i)';
    k = (s.length + tail.length > 31 ? s.substring(0, 31 - tail.length) : s) + tail;
    i++;
  }
  used.add(k.toLowerCase());
  return k;
}

/// The report as an .xlsx file. [top]: the lines above every table (company, site, title, dates).
Uint8List reportXlsx(RDoc doc, List<String> top) {
  final used = <String>{}, sheets = <(String, String)>[];
  final tables = doc.tables;
  for (final tb in tables.isEmpty ? [RTable(sheet: 'Report', head: const ['Nothing to show'], rows: const [])] : tables) {
    final name = _sheetName(tb.sheet, used);
    final rows = StringBuffer(), merges = <String>[];
    var r = 0;
    final widths = List<double>.filled(tb.head.length, 8);
    void line(List<RCell> cells, int style, {bool title = false}) {
      r++;
      rows.write('<row r="$r">');
      var c = 0;
      for (final cell in cells) {
        final ref = '${_col(c)}$r';
        final st = style == 0 && cell.bold ? 1 : style;
        final v = cell.value;
        if (!title && v is num && cell.n) {
          rows.write('<c r="$ref" s="$st"><v>$v</v></c>');
        } else if (cell.text.isNotEmpty) {
          rows.write('<c r="$ref" s="$st" t="inlineStr"><is><t xml:space="preserve">${_x(cell.text)}</t></is></c>');
        }
        if (!title && c < widths.length && cell.span == 1) {
          final w = cell.text.split('\n').fold<int>(0, (m, p) => p.length > m ? p.length : m) * 1.1 + 2;
          if (w > widths[c]) widths[c] = w > 60 ? 60 : w;
        }
        if (cell.span > 1) merges.add('$ref:${_col(c + cell.span - 1)}$r');
        c += cell.span;
      }
      rows.write('</row>');
    }

    for (final l in [...top, if (tb.title.isNotEmpty) tb.title]) {
      line([RCell(l)], 1, title: true);
    }
    if (top.isNotEmpty || tb.title.isNotEmpty) r++; // an empty line (an export to import back: its heading line first)
    line([for (final h in tb.head) RCell(h)], 2);
    for (final row in tb.rows) {
      line(row.cells, row.kind == RKind.group ? 3 : row.kind == RKind.sub || row.kind == RKind.grand ? 1 : 0);
    }
    if (tb.rows.isEmpty && tb.empty.isNotEmpty) line([RCell(tb.empty)], 0);
    for (final row in tb.foot) {
      line(row.cells, 1);
    }
    final cols = StringBuffer('<cols>');
    for (var i = 0; i < widths.length; i++) {
      cols.write('<col min="${i + 1}" max="${i + 1}" width="${widths[i].toStringAsFixed(1)}" customWidth="1"/>');
    }
    cols.write('</cols>');
    sheets.add((
      name,
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '$cols<sheetData>$rows</sheetData>${merges.isEmpty ? '' : '<mergeCells count="${merges.length}">${merges.map((m) => '<mergeCell ref="$m"/>').join()}</mergeCells>'}</worksheet>'
    ));
  }
  final a = Archive();
  void add(String path, String text) {
    final b = utf8.encode(text);
    a.addFile(ArchiveFile(path, b.length, b));
  }

  add('[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>');
  add('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  add('xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
      '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_x(sheets[i].$1)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets></workbook>');
  add('xl/_rels/workbook.xml.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
      '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>');
  // styles: 0 plain · 1 bold · 2 heading (bold, grey) · 3 a group line (bold, light green)
  add('xl/styles.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="10"/><name val="Arial"/></font><font><b/><sz val="10"/><name val="Arial"/></font></fonts>'
      '<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE5E7EB"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE6F4E8"/></patternFill></fill></fills>'
      '<borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs>'
      '<cellXfs count="4"><xf fontId="0" fillId="0"/><xf fontId="1" fillId="0" applyFont="1"/><xf fontId="1" fillId="2" applyFont="1" applyFill="1"/><xf fontId="1" fillId="3" applyFont="1" applyFill="1"/></cellXfs></styleSheet>');
  for (var i = 0; i < sheets.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', sheets[i].$2);
  }
  final List<int>? out = ZipEncoder().encode(a);
  return Uint8List.fromList(out ?? const []);
}

/* ---------------- (3.12.0) a file of tabs as the web's saveXlsxLists writes it (ExcelJS): texts, numbers, formulas with their
 * figures, the heading row bold on grey and frozen, the column widths, a drop-down list on each cell that has one (an empty one
 * yellow, to fill), a hidden tab (the lists). Excel works the formulas out again when the file is opened. ---------------- */
Uint8List sheetsXlsx(List<XSheet> tabs) {
  final used = <String>{}, sheets = <(String, String, bool)>[];
  for (final sh in tabs) {
    final name = _sheetName(sh.name, used);
    final yellow = {for (final v in sh.validations) if (v.$4) '${v.$1}|${v.$2}'};
    final rows = StringBuffer();
    var maxC = 0;
    for (var r = 1; r <= sh.aoa.length; r++) {
      final row = sh.aoa[r - 1];
      final cells = StringBuffer();
      var width = row.length;
      for (final k in yellow) {
        final p = k.split('|');
        if (p[0] == '$r' && int.parse(p[1]) > width) width = int.parse(p[1]);
      }
      for (var c = 1; c <= width; c++) {
        final v = c <= row.length ? row[c - 1] : '';
        final ref = '${_col(c - 1)}$r';
        final st = r == sh.head && v != '' ? 1 : (yellow.contains('$r|$c') ? 2 : 0);
        if (v is XFormula) {
          final res = v.result;
          cells.write('<c r="$ref" s="$st"><f>${_x(v.formula)}</f>${res == null || !res.isFinite ? '' : '<v>$res</v>'}</c>');
        } else if (v is num && !v.isFinite) {
          continue;
        } else if (v is num) {
          cells.write('<c r="$ref" s="$st"><v>$v</v></c>');
        } else if (v is bool) {
          cells.write('<c r="$ref" s="$st" t="b"><v>${v ? 1 : 0}</v></c>');
        } else if ('$v'.isNotEmpty) {
          cells.write('<c r="$ref" s="$st" t="inlineStr"><is><t xml:space="preserve">${_x('$v')}</t></is></c>');
        } else if (st != 0) {
          cells.write('<c r="$ref" s="$st"/>');
        } else {
          continue;
        }
        if (c > maxC) maxC = c;
      }
      if (cells.isNotEmpty) rows.write('<row r="$r">$cells</row>');
    }
    final cols = StringBuffer();
    for (var i = 0; i < sh.widths.length; i++) {
      cols.write('<col min="${i + 1}" max="${i + 1}" width="${sh.widths[i]}" customWidth="1"/>');
    }
    // one drop-down entry for every list, with all its cells
    final groups = <XList, List<String>>{};
    for (final v in sh.validations) {
      (groups[v.$3] ??= []).add('${_col(v.$2 - 1)}${v.$1}');
    }
    final dv = StringBuffer();
    for (final g in groups.entries) {
      final l = g.key;
      dv.write('<dataValidation type="list" allowBlank="1" showInputMessage="${l.prompt.isEmpty ? 0 : 1}" showErrorMessage="1" errorStyle="warning" errorTitle="Pick from the list" '
          'error="${_x(l.error)}" promptTitle="${_x(l.title)}" prompt="${_x(l.prompt)}" sqref="${g.value.join(' ')}"><formula1>${_x(l.list)}</formula1></dataValidation>');
    }
    final dim = maxC == 0 ? 'A1' : 'A1:${_col(maxC - 1)}${sh.aoa.length}';
    sheets.add((
      name,
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<dimension ref="$dim"/>'
          '${sh.head > 0 ? '<sheetViews><sheetView workbookViewId="0"><pane ySplit="${sh.head}" topLeftCell="A${sh.head + 1}" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>' : ''}'
          '${cols.isEmpty ? '' : '<cols>$cols</cols>'}<sheetData>$rows</sheetData>'
          '${groups.isEmpty ? '' : '<dataValidations count="${groups.length}">$dv</dataValidations>'}</worksheet>',
      sh.hidden,
    ));
  }
  final a = Archive();
  void add(String path, String text) {
    final b = utf8.encode(text);
    a.addFile(ArchiveFile(path, b.length, b));
  }

  add('[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '${[for (var i = 0; i < sheets.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}</Types>');
  add('_rels/.rels', '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>');
  add('xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
      '${[for (var i = 0; i < sheets.length; i++) '<sheet name="${_x(sheets[i].$1)}" sheetId="${i + 1}"${sheets[i].$3 ? ' state="hidden"' : ''} r:id="rId${i + 1}"/>'].join()}</sheets><calcPr calcId="191029" fullCalcOnLoad="1"/></workbook>');
  add('xl/_rels/workbook.xml.rels',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 0; i < sheets.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
      '<Relationship Id="rId${sheets.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>');
  // styles: 0 plain · 1 the heading (bold, grey, wrapped) · 2 a box to fill (yellow)
  add('xl/styles.xml',
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
      '<fills count="4"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE2E8F0"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFEF9C3"/></patternFill></fill></fills>'
      '<borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs>'
      '<cellXfs count="3"><xf fontId="0" fillId="0"/><xf fontId="1" fillId="2" applyFont="1" applyFill="1" applyAlignment="1"><alignment wrapText="1" vertical="center"/></xf><xf fontId="0" fillId="3" applyFill="1"/></cellXfs></styleSheet>');
  for (var i = 0; i < sheets.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', sheets[i].$2);
  }
  final List<int>? out = ZipEncoder().encode(a);
  return Uint8List.fromList(out ?? const []);
}
