/* A REPORT AS THE APP SHOWS IT (3.2.0): what the web draws as its report tables, as data – so the phone shows it in its own
 * screens, and the same report goes to Excel (every table a sheet) and to a PDF to print or send. Every figure is the server's
 * (the same report action as the web); here it is only laid out, the same columns and totals as the web. */

import 'fuel.dart';

enum RKind { normal, group, sub, grand, sunday }

/// One cell. [n] = a number column (right side); [value] = the number for Excel; [span] = cells it covers (a group line).
class RCell {
  const RCell(this.text, {this.n = false, this.bold = false, this.tone = '', this.value, this.span = 1});
  final String text;
  final bool n, bold;
  final String tone; // '' · 'bad' · 'warn' · 'good' · 'info' · 'muted'
  final Object? value;
  final int span;
}

class RRow {
  const RRow(this.cells, {this.kind = RKind.normal});
  final List<RCell> cells;
  final RKind kind;
}

class RTable {
  RTable({required this.sheet, required this.head, required this.rows, this.foot = const [], this.title = '', this.numCols = const {}, this.empty = ''});
  final String sheet, title, empty;
  final List<String> head;
  final List<RRow> rows, foot;
  /// the columns that hold numbers (right side)
  final Set<int> numCols;
}

class RNote {
  const RNote(this.text, {this.heading = false, this.letter = false});
  final String text;
  /// (3.24.0, Mechanical update-133) [letter]: a line of a letter (the BOQ amendment) – the page's own size and colour, its line
  /// breaks kept
  final bool heading, letter;
}

class RDoc {
  RDoc({required this.title, this.meta = '', this.kpis = const [], this.blocks = const [], this.portrait = true, this.period = '', this.file = 'RCL_report', this.signs = const [], this.onBehalf = false});
  final String title, meta, period, file;
  /// (3.24.0, Mechanical update-133) "For and on behalf of <the name on top>." above the signatures (the BOQ amendment letter)
  final bool onBehalf;
  final List<(String, String)> kpis;
  final List<Object> blocks; // RTable · RNote
  final bool portrait;
  /// (3.4.0) the signatures under the print (title, small line) – none given: Prepared / Checked / Approved by
  final List<(String, String)> signs;
  List<RTable> get tables => blocks.whereType<RTable>().toList();
}

/// (3.44.0, Mechanical update-163) the same report in the words of ONE fuel (a Petrol / CNG report): every text of it – on the
/// screen, the print and Excel alike ("Diesel" → its name; CNG's litres → kg). Diesel / none: as it is.
RDoc fuelDoc(RDoc d, String f) {
  if (f.isEmpty || f == 'Diesel') return d;
  String w(String t) => fuelText(t, f);
  RRow row(RRow r) => RRow([for (final c in r.cells) RCell(w(c.text), n: c.n, bold: c.bold, tone: c.tone, value: c.value, span: c.span)], kind: r.kind);
  return RDoc(
    title: w(d.title),
    meta: w(d.meta),
    kpis: [for (final k in d.kpis) (w(k.$1), w(k.$2))],
    blocks: [
      for (final b in d.blocks)
        b is RTable
            ? RTable(sheet: w(b.sheet), head: [for (final h in b.head) w(h)], rows: [for (final r in b.rows) row(r)], foot: [for (final r in b.foot) row(r)], title: w(b.title), numCols: b.numCols, empty: w(b.empty))
            : b is RNote
                ? RNote(w(b.text), heading: b.heading, letter: b.letter)
                : b,
    ],
    portrait: d.portrait,
    period: d.period,
    file: d.file,
    signs: d.signs,
    onBehalf: d.onBehalf,
  );
}

/* ---- the web's ways of writing numbers ---- */
double r2(num v) => (v * 100).roundToDouble() / 100;
num nOf(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
bool blankV(dynamic v) => v == null || v == '';

/// 1,234.5 (Indian grouping, up to 2 decimals) – the web's fmt
String fmt(dynamic v) {
  if (blankV(v)) return '';
  final n = nOf(v);
  final neg = n < 0;
  var s = n.abs().toStringAsFixed(2);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  final p = s.split('.');
  return (neg ? '-' : '') + _group(p[0]) + (p.length > 1 ? '.${p[1]}' : '');
}

/// 1,234.50 (always 2 decimals) – the web's money
String money(dynamic v) {
  if (blankV(v)) return '';
  final n = nOf(v);
  final neg = n < 0;
  final p = n.abs().toStringAsFixed(2).split('.');
  return (neg ? '-' : '') + _group(p[0]) + '.${p[1]}';
}

String _group(String whole) {
  if (whole.length <= 3) return whole;
  final last3 = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final g = <String>[];
  while (rest.length > 2) {
    g.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) g.insert(0, rest);
  return '${g.join(',')},$last3';
}

/// '–' for nothing / 0 (the web's z)
String z(dynamic v) => blankV(v) || nOf(v) == 0 ? '–' : fmt(v);

/// +12.5% / -3% / –
String pct(dynamic v) => blankV(v) ? '–' : '${nOf(v) > 0 ? '+' : ''}${fmt(v)}%';

/// +12 / -3 (a change)
String signed(dynamic v) => blankV(v) ? '–' : '${nOf(v) > 0 ? '+' : ''}${fmt(v)}';

/// '2026-10-13' → '13-10-2026'
String dmy(dynamic key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('${key ?? ''}');
  return m == null ? '${key ?? ''}' : '${m.group(3)}-${m.group(2)}-${m.group(1)}';
}

/* ---- cells ---- */
RCell tc(dynamic v, {bool bold = false, String tone = ''}) => RCell('${v ?? ''}', bold: bold, tone: tone);
RCell nc(dynamic v, {bool bold = false, String tone = '', String Function(dynamic)? show}) => RCell((show ?? fmt)(v), n: true, bold: bold, tone: tone, value: blankV(v) ? null : nOf(v));
RCell mc(dynamic v, {bool bold = false}) => RCell(money(v), n: true, bold: bold, value: blankV(v) ? null : nOf(v));
RCell zc(dynamic v, {bool bold = false}) => RCell(z(v), n: true, bold: bold, value: blankV(v) || nOf(v) == 0 ? null : nOf(v));
RCell sc(int i) => RCell('$i', value: i);
RRow grp(String text, int cols) => RRow([RCell(text, bold: true, span: cols)], kind: RKind.group);

List<Map<String, dynamic>> listOf(dynamic v) => (v is List ? v : const []).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
Map<String, dynamic> mapOf(dynamic v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

/// How wide each column is (in letters), from its heading and its cells (the screen, Excel and the print use it).
List<double> colUnits(RTable tb) {
  final w = List<double>.generate(tb.head.length, (i) => (tb.head[i].length * .55).clamp(3, 14).toDouble());
  for (final r in [...tb.rows, ...tb.foot]) {
    var c = 0;
    for (final cell in r.cells) {
      if (cell.span == 1 && c < w.length) {
        final l = cell.text.split('\n').fold<int>(0, (m, p) => p.length > m ? p.length : m).toDouble();
        if (l > w[c]) w[c] = l > 34 ? 34 : l;
      }
      c += cell.span;
    }
  }
  return w;
}
