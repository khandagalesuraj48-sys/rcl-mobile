/* A REPORT AS AN EXCEL FILE (3.2.0): every table of the report a sheet – the company, the site, the title and the dates on top,
 * the heading line bold, group / total lines bold, numbers as numbers. Made here on the phone (a small .xlsx writer: the file is
 * a zip of a few XML parts), the same file the web gives. */
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

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
