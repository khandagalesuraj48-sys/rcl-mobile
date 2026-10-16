/* READING AN EXCEL / CSV FILE (3.11.0) – the rows of each tab as the web reads them. The web uses SheetJS 0.18.5 (its own copy,
 * app/vendor/xlsx-0.18.5.full.min.js – byte for byte the npm 0.18.5 release):
 *     XLSX.read(bytes, {type: 'array', cellDates: false})  →  each tab  →  sheet_to_json(ws, {header: 1, raw: true, defval: ''})
 * This is the same reading, step by step from that library's own code (parse_ws_xml / parse_ws_xml_data / parse_si /
 * unescapexml / safe_decode_range / make_json_row / dsv_to_sheet_str / fuzzynum):
 *   – an .xlsx: every row of the tab's range (its <dimension>, else the cells it has), empty rows too; a number stays a number
 *     (a date is Excel's day number), text as written, TRUE / FALSE, an error or an empty cell '' (#NULL! = null);
 *   – a .csv: the separator guessed as the web does (, tab ; |), quotes, "2,000" / "1e3" / "50%" as numbers, TRUE / FALSE, the
 *     rest as text. ONE difference, on purpose: a date in a CSV stays as it is written (16-10-2026 …) – the web's reader lets the
 *     browser guess it and takes 05-10-2026 as 10 May (a web bug, reported – not copied). A CSV without the UTF-8 mark is read
 *     as UTF-8 when it is valid UTF-8 (the web: as Latin-1 – the same for plain English text).
 *   – an old .xls (or a password-protected file) is not read here: "save it as .xlsx".
 * Proven against the web's library: test/fixtures/sheets (the files and what SheetJS 0.18.5 reads from them). */
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One tab: its name and its rows (each row as long as the range is wide). A cell: String | double | bool | null (#NULL!).
class SheetTab {
  SheetTab(this.name, this.rows);
  final String name;
  final List<List<Object?>> rows;
}

class SheetError implements Exception {
  SheetError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Every tab of the file, in the workbook's order (a CSV: one tab "Sheet1").
List<SheetTab> readSheets(Uint8List b) {
  if (b.length >= 4 && b[0] == 0x50 && b[1] == 0x4B && b[2] < 9 && b[3] < 9) return _xlsx(b);
  if (b.length >= 8 && b[0] == 0xD0 && b[1] == 0xCF && b[2] == 0x11 && b[3] == 0xE0) {
    throw SheetError('This is an old Excel file (.xls) or a file with a password. Open it in Excel, save it as "Excel Workbook (.xlsx)" (or CSV) and import that.');
  }
  return [SheetTab('Sheet1', csvRows(_text(b)))];
}

/* ---------------- what JavaScript does with a value (the web's own code turns cells into text and numbers) ---------------- */

/// String(v) of JavaScript.
String jsS(Object? v) {
  if (v == null) return 'null';
  if (v is bool) return v ? 'true' : 'false';
  if (v is num) return jsNumS(v);
  return '$v';
}

String jsNumS(num v) {
  if (v is int) return '$v';
  final d = v.toDouble();
  if (d.isNaN) return 'NaN';
  if (d.isInfinite) return d > 0 ? 'Infinity' : '-Infinity';
  if (d == d.truncateToDouble() && d.abs() < 1e21) return d.toInt().toString();
  return d.toString();
}

/// Is it "truthy" in JavaScript (v || '' …).
bool jsTrue(Object? v) => !(v == null || v == false || v == '' || (v is num && (v == 0 || v.isNaN)));

final _jsNumRe = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

/// Number(s) of JavaScript (a text; '' and blanks are 0, anything else that is not a number NaN).
double jsNumber(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  if (_jsNumRe.hasMatch(t)) {
    var x = t.replaceFirst(RegExp(r'\.(?=[eE]|$)'), '');
    if (x.startsWith('.')) x = '0$x';
    x = x.replaceFirstMapped(RegExp(r'^([+-])\.'), (m) => '${m[1]}0.');
    return double.parse(x);
  }
  final h = RegExp(r'^0([xXbBoO])([0-9a-fA-F]+)$').firstMatch(t);
  if (h != null) {
    final radix = switch (h[1]!.toLowerCase()) { 'x' => 16, 'b' => 2, _ => 8 };
    final n = BigInt.tryParse(h[2]!, radix: radix);
    return n == null ? double.nan : n.toDouble();
  }
  final inf = RegExp(r'^([+-]?)Infinity$').firstMatch(t);
  if (inf != null) return inf[1] == '-' ? double.negativeInfinity : double.infinity;
  return double.nan;
}

/// parseFloat of JavaScript (the number at the start of the text).
double jsParseFloat(String s) {
  final t = s.replaceFirst(RegExp(r'^\s+'), '');
  final inf = RegExp(r'^([+-]?)Infinity').firstMatch(t);
  if (inf != null) return inf[1] == '-' ? double.negativeInfinity : double.infinity;
  final m = RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?').firstMatch(t);
  return m == null ? double.nan : jsNumber(m[0]!);
}

/// SheetJS fuzzynum: Number(s), else "2,000" / "$5" / "50%" / "(100)".
double fuzzyNum(String s) {
  var v = jsNumber(s);
  if (!v.isNaN) return v.isFinite ? v : double.nan;
  if (!RegExp(r'\d').hasMatch(s)) return v;
  var wt = 1.0;
  var ss = s.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}${m[2]}'); // as the JS replace: no overlap ("1,2,3" → "12,3")
  ss = ss.replaceAll(r'$', '').replaceAllMapped(RegExp('%'), (m) {
    wt *= 100;
    return '';
  });
  v = jsNumber(ss);
  if (!v.isNaN) return v / wt;
  ss = ss.replaceFirstMapped(RegExp(r'[(](.*)[)]'), (m) {
    wt = -wt;
    return m[1]!;
  });
  v = jsNumber(ss);
  if (!v.isNaN) return v / wt;
  return v;
}

/* ---------------- .xlsx ---------------- */

String _utf8(List<int> b) => utf8.decode(b, allowMalformed: true);

final _encRe = RegExp(r'&(?:quot|apos|gt|lt|amp|#x?([\da-fA-F]+));', caseSensitive: false), _codeRe = RegExp(r'_x([\da-fA-F]{4})_', caseSensitive: false);
const _enc = {'&quot;': '"', '&apos;': "'", '&gt;': '>', '&lt;': '<', '&amp;': '&'};

/// SheetJS unescapexml (entities, then Excel's _xHHHH_; CDATA kept as it is).
String unescapeXml(String s) {
  final i = s.indexOf('<![CDATA[');
  if (i == -1) {
    return s.replaceAllMapped(_encRe, (m) {
      final k = m[0]!;
      final e = _enc[k];
      if (e != null) return e;
      if (m[1] == null) return '\u0000';
      final n = int.tryParse(m[1]!, radix: k.contains('x') ? 16 : 10);
      return n == null ? k : String.fromCharCode(n & 0xFFFF);
    }).replaceAllMapped(_codeRe, (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)));
  }
  final j = s.indexOf(']]>');
  return unescapeXml(s.substring(0, i)) + s.substring(i + 9, j < 0 ? s.length : j) + (j < 0 ? '' : unescapeXml(s.substring(j + 3)));
}

final _attRe = RegExp(r'''([^"\s?>\/]+)\s*=\s*((?:")([^"]*)(?:")|(?:')([^']*)(?:')|([^'">\s]+))''');

/// SheetJS parsexmltag: the attributes (a prefix like x: dropped; also lower-cased).
Map<String, String> xmlAttrs(String tag) {
  final z = <String, String>{};
  for (final m in _attRe.allMatches(tag)) {
    var q = m[1]!;
    final v = m[3] ?? m[4] ?? m[5] ?? '';
    final c = q.indexOf(':');
    if (c < 0) {
      if (q.indexOf('_') > 0) q = q.substring(0, q.indexOf('_'));
    } else {
      q = (c == 5 && q.substring(0, 5) == 'xmlns' ? 'xmlns' : '') + q.substring(c + 1);
    }
    z[q] = v;
    z[q.toLowerCase()] = v;
  }
  return z;
}

final _tagRe = RegExp(r'''<[\/\?]?[a-zA-Z0-9:_-]+(?:\s+[^"\s?>\/]+\s*=\s*(?:"[^"]*"|'[^']*'|[^'">\s=]+))*\s*[\/\?]?>''', multiLine: true);
final _sitRe = RegExp(r'<(?:\w+:)?t[^>]*>([^<]*)<\/(?:\w+:)?t>'), _sirRe = RegExp(r'<(?:\w+:)?r>'), _sirphRe = RegExp(r'<(?:\w+:)?rPh.*?>([\s\S]*?)<\/(?:\w+:)?rPh>');

/// SheetJS parse_si: a shared / inline string (plain, or rich text: its runs joined, the phonetic runs left out). null = none.
String? parseSi(String x) {
  if (x.isEmpty) return '';
  if (RegExp(r'^\s*<(?:\w+:)?t[^>]*>').hasMatch(x)) {
    return unescapeXml(x.substring(x.indexOf('>') + 1).split(RegExp(r'<\/(?:\w+:)?t>'))[0]);
  }
  if (_sirRe.hasMatch(x)) {
    return unescapeXml(_sitRe.allMatches(x.replaceAll(_sirphRe, '')).map((m) => m[0]!).join().replaceAll(_tagRe, ''));
  }
  return null;
}

/// SheetJS safe_decode_range: "B3:G7" → (r0, c0, r1, c1), 0-based; "A1" alone = one cell.
(int, int, int, int) decodeRange(String range) {
  var i = 0, idx = 0, cc = 0;
  final len = range.length;
  for (idx = 0; i < len; ++i) {
    if ((cc = range.codeUnitAt(i) - 64) < 1 || cc > 26) break;
    idx = 26 * idx + cc;
  }
  final sc = --idx;
  for (idx = 0; i < len; ++i) {
    if ((cc = range.codeUnitAt(i) - 48) < 0 || cc > 9) break;
    idx = 10 * idx + cc;
  }
  final sr = --idx;
  if (i == len || cc != 10) return (sr, sc, sr, sc);
  ++i;
  for (idx = 0; i != len; ++i) {
    if ((cc = range.codeUnitAt(i) - 64) < 1 || cc > 26) break;
    idx = 26 * idx + cc;
  }
  final ec = --idx;
  for (idx = 0; i != len; ++i) {
    if ((cc = range.codeUnitAt(i) - 48) < 0 || cc > 9) break;
    idx = 10 * idx + cc;
  }
  final er = --idx;
  return (sr, sc, er, ec);
}

class _Cell {
  _Cell(this.t, this.v);
  String t; // n s b e (d becomes n)
  Object? v;
}

String _path(String base, String target) {
  if (target.startsWith('/')) return target.substring(1);
  final parts = [...base.split('/')..removeLast(), ...target.split('/')];
  final out = <String>[];
  for (final p in parts) {
    if (p == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else if (p.isNotEmpty && p != '.') {
      out.add(p);
    }
  }
  return out.join('/');
}

Map<String, (String, String)> _rels(String? xml, String base) {
  final out = <String, (String, String)>{};
  if (xml == null) return out;
  for (final m in RegExp(r'<(?:\w+:)?Relationship\b[^>]*>').allMatches(xml)) {
    final a = xmlAttrs(m[0]!);
    out[a['Id'] ?? a['id'] ?? ''] = (a['Type'] ?? a['type'] ?? '', _path(base, a['Target'] ?? a['target'] ?? ''));
  }
  return out;
}

List<SheetTab> _xlsx(Uint8List b) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(b);
  } catch (_) {
    throw SheetError('Could not read the file – it is not an Excel file that can be opened.');
  }
  final files = <String, ArchiveFile>{for (final f in zip.files) if (f.isFile) f.name.replaceFirst(RegExp(r'^/'), ''): f};
  ArchiveFile? find(String p) => files[p] ?? files.entries.where((e) => e.key.toLowerCase() == p.toLowerCase()).map((e) => e.value).firstOrNull;
  String? text(String p) {
    final f = find(p);
    return f == null ? null : _utf8(f.content as List<int>);
  }

  final root = _rels(text('_rels/.rels'), '');
  final wbPath = root.values.where((r) => r.$1.endsWith('/officeDocument')).map((r) => r.$2).firstOrNull ?? 'xl/workbook.xml';
  final wbXml = text(wbPath);
  if (wbXml == null) throw SheetError('Could not read the file – it is not an Excel workbook.');
  final rels = _rels(text(_path(wbPath, '_rels/${wbPath.split('/').last}.rels')), wbPath);
  // the shared strings
  final sstPath = rels.values.where((r) => r.$1.endsWith('/sharedStrings')).map((r) => r.$2).firstOrNull ?? _path(wbPath, 'sharedStrings.xml');
  final strs = <String?>[];
  final sst = RegExp(r'<(?:\w+:)?sst([^>]*)>([\s\S]*)<\/(?:\w+:)?sst>').firstMatch(text(sstPath) ?? '');
  if (sst != null) {
    for (final x in sst[2]!.replaceAll(RegExp(r'<(?:\w+:)?(?:si|sstItem)>'), '').split(RegExp(r'<\/(?:\w+:)?(?:si|sstItem)>'))) {
      strs.add(parseSi(x.trim()));
    }
  }
  final out = <SheetTab>[];
  for (final m in RegExp(r'<(?:\w+:)?sheet\b[^>]*>').allMatches(wbXml)) {
    final a = xmlAttrs(m[0]!);
    final name = unescapeXml(a['name'] ?? '');
    final rid = a['id'] ?? '';
    final target = rels[rid]?.$2 ?? _path(wbPath, 'worksheets/sheet${out.length + 1}.xml');
    final xml = text(target);
    if (xml == null || (rels[rid]?.$1 ?? '/worksheet').endsWith('/chartsheet')) continue;
    out.add(SheetTab(name, _sheetRows(xml, strs)));
  }
  return out;
}

final _rowSplit = RegExp(r'<\/(?:\w+:)?row>'), _cellSplit = RegExp(r'<(?:\w+:)?c[ \/>]'), _rRe = RegExp(r'''r=["']([^"']*)["']''');
final _isRe = RegExp(r'<(?:\w+:)?is>([\S\s]*?)<\/(?:\w+:)?is>');
final _vRe = RegExp(r'<(?:\w+:)?v(?: xml:space="preserve")?(?:[^>]*)>([\s\S]*?)<\/(?:\w+:)?v>');
final _fRe = RegExp(r'<(?:\w+:)?f(?: xml:space="preserve")?(?:[^>]*)>([\s\S]*?)<\/(?:\w+:)?f>');

/// SheetJS parse_ws_xml + parse_ws_xml_data + sheet_to_json(header 1, raw, defval '').
List<List<Object?>> _sheetRows(String data, List<String?> strs) {
  final cells = <int, Map<int, _Cell>>{};
  var gsr = 2000000, gsc = 2000000, ger = 0, gec = 0; // the range guessed from the cells
  (int, int, int, int)? ref;
  final mt = RegExp(r'<(?:\w+:)?sheetData[^>]*>([\s\S]*)<\/(?:\w+:)?sheetData>').firstMatch(data);
  final data1 = mt == null ? data : data.substring(0, mt.start);
  final ridx = RegExp(r'<(?:\w*:)?dimension').firstMatch(data1)?.start ?? -1;
  if (ridx > 0) {
    final dm = RegExp(r'"(\w*:\w*)"').firstMatch(data1.substring(ridx, ridx + 50 > data1.length ? data1.length : ridx + 50));
    if (dm != null) {
      final d = decodeRange(dm[1]!);
      if (d.$1 <= d.$3 && d.$2 <= d.$4 && d.$1 >= 0 && d.$2 >= 0) ref = d;
    }
  }
  if (mt != null) {
    var tagr = 0, tagc = 0;
    for (final chunk in mt[1]!.split(_rowSplit)) {
      var x = chunk.trim();
      final xlen = x.length;
      if (xlen == 0) continue;
      var rstarti = 0, ri = 0;
      for (ri = 0; ri < xlen; ++ri) {
        final ch = x[ri];
        if (ch == '>') {
          if (ri == 0 || x[ri - 1] != '/') {
            ++ri;
            break;
          }
        } else if (ch == '<') {
          rstarti = ri;
        }
      }
      if (rstarti >= ri) break;
      final rtag = xmlAttrs(x.substring(rstarti, ri));
      tagr = rtag['r'] != null ? (int.tryParse(RegExp(r'^\s*[+-]?\d+').stringMatch(rtag['r']!)?.trim() ?? '') ?? tagr + 1) : tagr + 1;
      tagc = -1;
      if (gsr > tagr - 1) gsr = tagr - 1;
      if (ger < tagr - 1) ger = tagr - 1;
      var parts = x.substring(ri).split(_cellSplit);
      var rslice = 0;
      for (; rslice != parts.length; ++rslice) {
        final p = parts[rslice].trim();
        if (p.isEmpty || p[0] != '<') break;
      }
      parts = parts.sublist(rslice);
      for (var k = 0; k < parts.length; k++) {
        x = parts[k].trim();
        if (x.isEmpty) continue;
        final cref = _rRe.firstMatch(x);
        x = '<c ${x[0] == '<' ? '>' : ''}$x';
        if (cref != null) {
          var idx = 0;
          final d = cref[1]!;
          for (var i = 0; i != d.length; ++i) {
            final cc = d.codeUnitAt(i) - 64;
            if (cc < 1 || cc > 26) break;
            idx = 26 * idx + cc;
          }
          tagc = idx - 1;
        } else {
          ++tagc;
        }
        var i = x.indexOf('>');
        i = i < 0 ? x.length : i + 1;
        final tag = xmlAttrs(x.substring(0, i));
        final d = x.substring(i);
        // where the cell is kept: its own r (else this row and the next column)
        var row = tagr - 1, col = tagc;
        final r0 = tag['r'];
        if (r0 != null && r0.isNotEmpty) {
          final rc = decodeRange(r0);
          row = rc.$1;
          col = rc.$2;
          if (row < 0 || col < 0) continue; // a reference the web would never find
        }
        String? v;
        final vm = _vRe.firstMatch(d);
        if (vm != null && vm[1] != '') v = unescapeXml(vm[1]!);
        final fm = _fRe.firstMatch(d);
        final hasF = (fm != null && fm[1] != '') || RegExp(r'<f[^>]*\/>').hasMatch(d);
        String t;
        Object? val = v;
        if (tag['t'] == null && v == null) {
          if (!hasF) continue;
          val = 0;
          t = 'n';
        } else {
          t = tag['t'] ?? 'n';
        }
        if (gsc > tagc) gsc = tagc;
        if (gec < tagc) gec = tagc;
        switch (t) {
          case 'n':
            if (val == null || val == '' || val == 0) continue; // JS: p.v == "" (0 == "" too)
            val = jsParseFloat(val as String);
          case 's':
            if (val == null) continue;
            final n = int.tryParse(RegExp(r'^\s*[+-]?\d+').stringMatch(val as String)?.trim() ?? '');
            if (n == null || n < 0 || n >= strs.length) throw SheetError('Could not read the file – a cell points to a text that is not in it.');
            val = strs[n];
          case 'str':
            t = 's';
            val = v ?? '';
          case 'inlineStr':
            t = 's';
            final im = _isRe.firstMatch(d);
            val = im == null ? '' : parseSi(im[1]!);
          case 'b':
            t = 'b';
            val = v == '1' || v == 'true' || v == 'TRUE';
          case 'd':
            t = 'n';
            val = _isoSerial(v ?? '');
          case 'e':
            val = v == '#NULL!' ? null : '';
          default:
            continue;
        }
        (cells[row] ??= {})[col] = _Cell(t, val);
      }
    }
  }
  final (int, int, int, int) r;
  if (ref != null) {
    r = ref;
  } else if (gec >= gsc && ger >= gsr) {
    r = (gsr, gsc, ger, gec);
  } else {
    return [];
  }
  return [
    for (var row = r.$1; row <= r.$3; row++)
      [
        for (var c = r.$2; c <= r.$4; c++) _json(cells[row]?[c]),
      ],
  ];
}

Object? _json(_Cell? c) {
  if (c == null) return '';
  if (c.t == 'e') return c.v; // null (#NULL!) or ''
  return c.v ?? '';
}

/// A t="d" cell (an ISO date / time) as Excel's day number.
double _isoSerial(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}(?:\.\d+)?))?)?').firstMatch(s.trim());
  if (m == null) return double.nan;
  final day = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)).difference(DateTime.utc(1899, 12, 30)).inDays;
  final secs = (int.tryParse(m[4] ?? '') ?? 0) * 3600 + (int.tryParse(m[5] ?? '') ?? 0) * 60 + (double.tryParse(m[6] ?? '') ?? 0);
  return day + secs / 86400;
}

/* ---------------- .csv ---------------- */

String _text(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) return _utf8(b.sublist(3));
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
    final u = <int>[for (var i = 2; i + 1 < b.length; i += 2) b[i] | (b[i + 1] << 8)];
    return String.fromCharCodes(u);
  }
  try {
    return utf8.decode(b);
  } catch (_) {
    return latin1.decode(b);
  }
}

const _seps = {0x2C: ',', 0x09: '\t', 0x3B: ';', 0x7C: '|'};
const _sepW = {0x2C: 3, 0x09: 2, 0x3B: 1, 0x7C: 0};

String _guessSep(String str) {
  final cnt = <int, int>{};
  var instr = false;
  for (var e = 0; e < str.length; ++e) {
    final cc = str.codeUnitAt(e);
    if (cc == 0x22) {
      instr = !instr;
    } else if (!instr && _seps.containsKey(cc)) {
      cnt[cc] = (cnt[cc] ?? 0) + 1;
    }
  }
  final list = (cnt.isEmpty ? _sepW : cnt).entries.map((e) => (e.value, e.key)).toList();
  list.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : _sepW[a.$2]!.compareTo(_sepW[b.$2]!));
  return _seps[list.last.$2] ?? ',';
}

/// SheetJS dsv_to_sheet_str, then sheet_to_json(header 1, raw, defval '') – see the note on top about dates.
List<List<Object?>> csvRows(String str) {
  var sep = '';
  if (str.startsWith('sep=') && str.length > 5) {
    if (str.length > 6 && str.codeUnitAt(5) == 13 && str.codeUnitAt(6) == 10) {
      sep = str[4];
      str = str.substring(7);
    } else if (str.codeUnitAt(5) == 13 || str.codeUnitAt(5) == 10) {
      sep = str[4];
      str = str.substring(6);
    } else {
      sep = _guessSep(str.substring(0, str.length < 1024 ? str.length : 1024));
    }
  } else {
    sep = _guessSep(str.substring(0, str.length < 1024 ? str.length : 1024));
  }
  final cells = <int, Map<int, Object?>>{};
  var R = 0, C = 0, er = 0, ec = 0, start = 0, end = 0, cc = 0;
  final sepcc = sep.codeUnitAt(0);
  var instr = false;
  var startcc = str.isEmpty ? -1 : str.codeUnitAt(0);
  str = str.replaceAll('\r\n', '\n');
  void finish() {
    var s = str.substring(start, end > str.length ? str.length : end);
    if (s.isNotEmpty && s[0] == '"' && s[s.length - 1] == '"') s = s.length < 2 ? '' : s.substring(1, s.length - 1).replaceAll('""', '"');
    Object? v;
    var keep = true;
    if (s.isEmpty) {
      keep = false;
    } else if (s.trim().isEmpty) {
      v = s;
    } else if (s.codeUnitAt(0) == 0x3D) {
      if (s.length > 1 && s.codeUnitAt(1) == 0x22 && s.codeUnitAt(s.length - 1) == 0x22) {
        v = s.substring(2, s.length - 1 < 2 ? 2 : s.length - 1).replaceAll('""', '"');
      } else if (s.length != 1) {
        v = ''; // a formula: no value
      } else {
        v = s;
      }
    } else if (s == 'TRUE') {
      v = true;
    } else if (s == 'FALSE') {
      v = false;
    } else {
      final n = fuzzyNum(s);
      v = n.isNaN ? s : n;
    }
    if (keep) (cells[R] ??= {})[C] = v;
    start = end + 1;
    startcc = start < str.length ? str.codeUnitAt(start) : -1;
    if (ec < C) ec = C;
    if (er < R) er = R;
    if (cc == sepcc) {
      ++C;
    } else {
      C = 0;
      ++R;
    }
  }

  for (; end < str.length; ++end) {
    cc = str.codeUnitAt(end);
    if (cc == 0x22) {
      if (startcc == 0x22) instr = !instr;
    } else if (cc == sepcc || cc == 0x0a || cc == 0x0d) {
      if (!instr) finish();
    }
  }
  if (end - start > 0) finish();
  return [
    for (var r = 0; r <= er; r++) [for (var c = 0; c <= ec; c++) cells[r]?.containsKey(c) == true ? cells[r]![c] : ''],
  ];
}
