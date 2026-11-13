/* MY ATTENDANCE AS A PDF (3.117.0, his word of 13-11-2026: "user application madhun attednnce pdf download kru shakel proper …
 * company name … site … heading madhe month … period … sr no date eka khali ek … khali ek mast design madhe kiti diwas present
 * absent late mark … kontya hi month chi"): one month of one person on one A4 page – the company and the site in the head, the
 * month and its period, every day in a row (Sr · Date · Day · Status · IN · OUT · Hours · Remark) and, under it, the month's
 * count in boxes. Made on the phone from what the HR server said for the month (myMonth) – nothing is counted here except the
 * hours between a day's IN and OUT.
 * (3.117.1) Written here, by hand, as a plain PDF (two of the PDF's own types, boxes and words) – no package: the package `pdf`
 * pulled an older `archive` in, with which the package `image` no longer builds. */
import 'dart:convert';
import 'dart:typed_data';

const _status = {'P': 'Present', 'HD': 'Half day', 'A': 'Absent', 'L': 'Leave', 'WO': 'Weekly off', 'H': 'Holiday', 'WOP': 'Worked on weekly off', 'HP': 'Worked on holiday', 'IN': 'At work', 'MIS': 'OUT not marked'};
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _week = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The letters the PDF's own type has (Latin); any other letter is left out so that the page is always made.
String pdfWords(Object? v) => String.fromCharCodes('${v ?? ''}'.replaceAll('–', '-').replaceAll('·', '-').runes.where((r) => r >= 0x20 && r <= 0xFF && r != 0x7F)).trim();

String _dmy(String day) => day.length >= 10 ? '${day.substring(8, 10)}-${day.substring(5, 7)}-${day.substring(0, 4)}' : day;

int? _min(Object? v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${v ?? ''}');
  return m == null ? null : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

/// "8 h 05 m" between a day's IN and OUT (past midnight when OUT is before IN); '' when one of them is not there.
String pdfHours(Object? a, Object? b) {
  final x = _min(a), y = _min(b);
  if (x == null || y == null) return '';
  final d = y >= x ? y - x : y + 1440 - x;
  return '${d ~/ 60} h ${(d % 60).toString().padLeft(2, '0')} m';
}

/// The month's name and its period: ("November 2026", "01-11-2026 to 30-11-2026").
(String, String) pdfMonth(String month) {
  final y = int.tryParse(month.length >= 4 ? month.substring(0, 4) : '') ?? 2000, mo = (int.tryParse(month.length >= 7 ? month.substring(5, 7) : '') ?? 1).clamp(1, 12).toInt();
  final last = DateTime.utc(y, mo + 1, 0).day, mm = mo.toString().padLeft(2, '0');
  return ('${_months[mo - 1]} $y', '01-$mm-$y to ${last.toString().padLeft(2, '0')}-$mm-$y');
}

// How wide each letter of Helvetica is (thousandths of the letter's size), ' ' to '~' – the PDF's own type, its own table.
const _wide = [278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, 1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, 333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584];

/// How wide [t] is written at [size] (bold: a little wider).
double pdfWidth(String t, double size, {bool bold = false}) {
  var w = 0;
  for (final c in t.codeUnits) {
    w += c >= 32 && c <= 126 ? _wide[c - 32] : 556;
  }
  return w * size / 1000 * (bold ? 1.07 : 1);
}

/// [t] cut to fit [width] (with "..").
String pdfFit(String t, double width, double size, {bool bold = false}) {
  if (pdfWidth(t, size, bold: bold) <= width) return t;
  var s = t;
  while (s.isNotEmpty && pdfWidth('$s..', size, bold: bold) > width) {
    s = s.substring(0, s.length - 1);
  }
  return '$s..';
}

/// One A4 page being drawn: boxes and words (y from the top of the page, as one reads).
class _Page {
  static const double w = 595, h = 842;
  final _b = StringBuffer();
  static String _n(double v) => v.toStringAsFixed(2);
  static String _rgb(int c) => '${_n(((c >> 16) & 255) / 255)} ${_n(((c >> 8) & 255) / 255)} ${_n((c & 255) / 255)}';

  void box(double x, double y, double bw, double bh, int color) => _b.writeln('${_rgb(color)} rg ${_n(x)} ${_n(h - y - bh)} ${_n(bw)} ${_n(bh)} re f');
  void line(double x, double y, double x2, int color) => _b.writeln('${_rgb(color)} RG 0.5 w ${_n(x)} ${_n(h - y)} m ${_n(x2)} ${_n(h - y)} l S');

  /// [t] with its baseline at [y]; [right]: its end at [x]; [mid]: its middle at [x].
  void text(String t, double x, double y, double size, int color, {bool bold = false, bool right = false, bool mid = false}) {
    final s = pdfWords(t);
    if (s.isEmpty) return;
    final tw = pdfWidth(s, size, bold: bold), tx = right ? x - tw : mid ? x - tw / 2 : x;
    final esc = s.replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');
    _b.writeln('BT /${bold ? 'F2' : 'F1'} ${_n(size)} Tf ${_rgb(color)} rg ${_n(tx)} ${_n(h - y)} Td ($esc) Tj ET');
  }

  /// The page as a PDF file.
  Uint8List file(String title, String author) {
    String info(String v) => pdfWords(v).replaceAll('\\', '\\\\').replaceAll('(', '\\(').replaceAll(')', '\\)');
    final stream = latin1.encode(_b.toString());
    final objs = <List<int>>[
      latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'),
      latin1.encode('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      latin1.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> >> >>'),
      [...latin1.encode('<< /Length ${stream.length} >>\nstream\n'), ...stream, ...latin1.encode('\nendstream')],
      latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'),
      latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'),
      latin1.encode('<< /Title (${info(title)}) /Author (${info(author)}) /Producer (RCL attendance app) >>'),
    ];
    final out = BytesBuilder()..add(latin1.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));
    final at = <int>[];
    for (var i = 0; i < objs.length; i++) {
      at.add(out.length);
      out
        ..add(latin1.encode('${i + 1} 0 obj\n'))
        ..add(objs[i])
        ..add(latin1.encode('\nendobj\n'));
    }
    final xref = out.length;
    out.add(latin1.encode('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n${[for (final a in at) '${a.toString().padLeft(10, '0')} 00000 n \n'].join()}trailer\n<< /Size ${objs.length + 1} /Root 1 0 R /Info 7 0 R >>\nstartxref\n$xref\n%%EOF\n'));
    return out.toBytes();
  }
}

Future<Uint8List> attendancePdf({required String company, required String site, required String name, required String code, required String month, required List<Map> days, required Map total, String made = ''}) async {
  const navy = 0x0F1F3D, gold = 0xB07C19, line = 0xDDE2EC, soft = 0xF4F6FB, muted = 0x59647E, white = 0xFFFFFF, ink = 0x0F1830;
  const green = 0x146C2E, red = 0xC22A1B, amber = 0x8A5A00, purple = 0x6A3D8A;
  int hue(String c) => switch (c) { 'P' || 'WOP' || 'HP' || 'IN' => green, 'A' || 'MIS' => red, 'HD' => amber, 'L' => purple, _ => muted };
  final (title, period) = pdfMonth(month);
  final p = _Page();
  const double l = 30, r = 565;
  // ---- the head: the company and the site; "ATTENDANCE" and the month
  p.box(l, 28, r - l, 56, navy);
  p.text(pdfFit(pdfWords(company), 330, 17, bold: true), l + 16, 53, 17, white, bold: true);
  p.text(pdfFit(pdfWords(site), 330, 10.5), l + 16, 70, 10.5, 0xD5DBEA);
  p.text('ATTENDANCE', r - 16, 50, 9, 0xF1D58A, bold: true, right: true);
  p.text(title, r - 16, 69, 15, white, bold: true, right: true);
  // ---- who and which days
  p.text('Employee:', l, 104, 10.5, muted);
  final nm = pdfFit(pdfWords(name), 210, 10.5, bold: true);
  p.text(nm, l + 54, 104, 10.5, ink, bold: true);
  if (pdfWords(code).isNotEmpty) {
    final x = l + 54 + pdfWidth(nm, 10.5, bold: true) + 14;
    p.text('Code:', x, 104, 10.5, muted);
    p.text(pdfWords(code), x + 32, 104, 10.5, ink, bold: true);
  }
  p.text('Period: $period', r, 104, 10.5, gold, bold: true, right: true);
  // ---- every day in a row
  const cols = <double>[30, 58, 124, 160, 290, 334, 378, 440]; // where each column starts
  const heads = ['Sr', 'Date', 'Day', 'Status', 'IN', 'OUT', 'Hours', 'Remark'];
  var y = 116.0;
  const rowH = 16.0;
  p.box(l, y, r - l, 18, navy);
  for (var i = 0; i < heads.length; i++) {
    p.text(heads[i], cols[i] + 5, y + 12.5, 9.5, white, bold: true);
  }
  y += 18;
  final list = days.length > 31 ? days.sublist(0, 31) : days;
  var sr = 0;
  for (final d in list) {
    final day = '${d['day'] ?? ''}', c = '${d['code'] ?? ''}', dt = DateTime.tryParse('${day}T00:00:00Z');
    final late = d['late_min'] is num ? (d['late_min'] as num).round() : 0;
    final remark = [if (late > 0) 'Late $late min', if (d['late_half'] == true) 'Late - half day', if (d['auto'] == true) 'Closed by itself (no OUT)'].join('; ');
    sr++;
    if (sr.isEven) p.box(l, y, r - l, rowH, soft);
    final base = y + 11.3;
    p.text('$sr', cols[1] - 8, base, 9, ink, right: true);
    p.text(_dmy(day), cols[1] + 5, base, 9, ink);
    p.text(dt == null ? '' : _week[dt.weekday - 1], cols[2] + 5, base, 9, muted);
    p.text(pdfFit(_status[c] ?? c, cols[4] - cols[3] - 8, 9, bold: true), cols[3] + 5, base, 9, hue(c), bold: true);
    p.text('${d['in'] ?? ''}', cols[4] + 5, base, 9, ink);
    p.text('${d['out'] ?? ''}', cols[5] + 5, base, 9, ink);
    p.text(pdfHours(d['in'], d['out']), cols[6] + 5, base, 9, ink);
    p.text(pdfFit(remark, r - cols[7] - 8, 8.5), cols[7] + 5, base, 8.5, muted);
    y += rowH;
    p.line(l, y, r, line);
  }
  // ---- the month in numbers
  String n(Object? v) => v is num ? (v == v.roundToDouble() ? '${v.round()}' : '$v') : '0';
  y += 16;
  p.text('The month in numbers', l, y, 11, navy, bold: true);
  y += 8;
  const gap = 6.0;
  final bw = (r - l - gap * 3) / 4;
  void boxes(List<(String, Object?, int)> items) {
    for (var i = 0; i < items.length; i++) {
      final x = l + i * (bw + gap);
      p.box(x, y, bw, 40, line);
      p.box(x + .6, y + .6, bw - 1.2, 38.8, soft);
      p.text(n(items[i].$2), x + bw / 2, y + 20, 16, items[i].$3, bold: true, mid: true);
      p.text(items[i].$1, x + bw / 2, y + 33, 8.5, muted, mid: true);
    }
    y += 40 + gap;
  }

  boxes([('Present', total['P'], green), ('Half day', total['HD'], amber), ('Absent', total['A'], red), ('Leave', total['L'], purple)]);
  boxes([('Weekly off', total['WO'], muted), ('Holiday', total['H'], muted), ('Late marks', total['late'], amber), ('Days for pay', total['paid'], navy)]);
  // ---- the foot
  p.text(made.isEmpty ? 'Made from the attendance app' : 'Made on $made from the attendance app', l, 822, 8, muted);
  p.text('Page 1 of 1', r, 822, 8, muted, right: true);
  return p.file('Attendance $title - $name', company);
}
