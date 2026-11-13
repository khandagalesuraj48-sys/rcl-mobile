/* MY ATTENDANCE AS A PDF (3.117.0, his word of 13-11-2026: "user application madhun attednnce pdf download kru shakel proper …
 * company name … site … heading madhe month … period … sr no date eka khali ek … khali ek mast design madhe kiti diwas present
 * absent late mark … kontya hi month chi"): one month of one person on one A4 page – the company and the site in the head, the
 * month and its period, every day in a row (Sr · Date · Day · Status · IN · OUT · Hours · Remark) and, under it, the month's
 * count in boxes. Made on the phone from what the HR server said for the month (myMonth) – nothing is counted here except the
 * hours between a day's IN and OUT.
 * (3.118.0, his own sheet as the pattern – "attendnce pdf as asaw … company name bold warti centre la … employee name … site
 * employee id … tyachi khali ek dark line … company logo pn … saglyat adhi date nantr day nantr work place … late asel tr late
 * as lihun … kiti minute … sign la thodi space … niyam hawe aahet je rules apan set kelet te"): the logo and the company's
 * name in the head, "Attendance for the Month …", the employee, his ID, the site and the period, a dark line; the days in a
 * ruled table – Date · Day · Work place (where IN was marked) · In Time · Out Time · Total Hrs · Status · Late ("Late 12 min");
 * the Summary; the site's rules in words (as the HR server says them); room to sign – HR · Accounts · Director.
 * (3.117.1) Written here, by hand, as a plain PDF (two of the PDF's own types, boxes and words) – no package: the package `pdf`
 * pulled an older `archive` in, with which the package `image` no longer builds. */
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

const _status = {'P': 'Present', 'HD': 'Half day', 'A': 'Absent', 'L': 'Leave', 'WO': 'Weekly off', 'H': 'Holiday', 'WOP': 'Worked on weekly off', 'HP': 'Worked on holiday', 'IN': 'At work', 'MIS': 'OUT not marked'};
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _week = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// The letters the PDF's own type has (Latin); any other letter is left out so that the page is always made.
String pdfWords(Object? v) => String.fromCharCodes('${v ?? ''}'.replaceAll('–', '-').replaceAll('·', '-').runes.where((r) => r >= 0x20 && r <= 0xFF && r != 0x7F)).trim();

String _dmy(String day) => day.length >= 10 ? '${day.substring(8, 10)}/${day.substring(5, 7)}/${day.substring(0, 4)}' : day;

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

/// The month's name and its period: ("November-2026", "01/11/2026 to 30/11/2026").
(String, String) pdfMonth(String month) {
  final y = int.tryParse(month.length >= 4 ? month.substring(0, 4) : '') ?? 2000, mo = (int.tryParse(month.length >= 7 ? month.substring(5, 7) : '') ?? 1).clamp(1, 12).toInt();
  final last = DateTime.utc(y, mo + 1, 0).day, mm = mo.toString().padLeft(2, '0');
  return ('${_months[mo - 1]}-$y', '01/$mm/$y to ${last.toString().padLeft(2, '0')}/$mm/$y');
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

/// [t] in lines not wider than [width] (broken between words).
List<String> pdfWrap(String t, double width, double size, {bool bold = false}) {
  final out = <String>[];
  var cur = '';
  for (final w in t.split(' ').where((x) => x.isNotEmpty)) {
    final next = cur.isEmpty ? w : '$cur $w';
    if (cur.isNotEmpty && pdfWidth(next, size, bold: bold) > width) {
      out.add(cur);
      cur = w;
    } else {
      cur = next;
    }
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

/// A picture for the PDF's head: a JPEG and its size in dots.
class PdfLogo {
  const PdfLogo(this.jpg, this.w, this.h);
  final Uint8List jpg;
  final int w, h;
}

/// The company's logo of the app (Rachana's) as the PDF takes it – on white, as a JPEG. null: it could not be read, or the
/// sheet is of another company (its name is written, no logo of somebody else beside it).
Future<PdfLogo?> pdfLogo(String company) async {
  if (!company.toLowerCase().contains('rachana')) return null;
  try {
    final data = await rootBundle.load('assets/brand/rachana_logo.png'), im = img.decodePng(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    if (im == null) return null;
    final bg = img.Image(width: im.width, height: im.height);
    img.fill(bg, color: img.ColorRgb8(255, 255, 255));
    final flat = img.compositeImage(bg, im.convert(numChannels: 4));
    return PdfLogo(Uint8List.fromList(img.encodeJpg(flat, quality: 88)), flat.width, flat.height);
  } catch (_) {
    return null;
  }
}

/// One A4 page being drawn: boxes, lines, words and one picture (y from the top of the page, as one reads).
class _Page {
  static const double h = 842; // (A4: 595 wide, 842 high)
  final _b = StringBuffer();
  PdfLogo? _pic;
  static String _n(double v) => v.toStringAsFixed(2);
  static String _rgb(int c) => '${_n(((c >> 16) & 255) / 255)} ${_n(((c >> 8) & 255) / 255)} ${_n((c & 255) / 255)}';

  void box(double x, double y, double bw, double bh, int color) => _b.writeln('${_rgb(color)} rg ${_n(x)} ${_n(h - y - bh)} ${_n(bw)} ${_n(bh)} re f');
  void frame(double x, double y, double bw, double bh, int color, double thick) => _b.writeln('${_rgb(color)} RG ${_n(thick)} w ${_n(x)} ${_n(h - y - bh)} ${_n(bw)} ${_n(bh)} re S');
  void across(double x, double y, double x2, int color, double thick) => _b.writeln('${_rgb(color)} RG ${_n(thick)} w ${_n(x)} ${_n(h - y)} m ${_n(x2)} ${_n(h - y)} l S');
  void down(double x, double y, double y2, int color, double thick) => _b.writeln('${_rgb(color)} RG ${_n(thick)} w ${_n(x)} ${_n(h - y)} m ${_n(x)} ${_n(h - y2)} l S');
  void picture(PdfLogo p, double x, double y, double pw, double ph) {
    _pic = p;
    _b.writeln('q ${_n(pw)} 0 0 ${_n(ph)} ${_n(x)} ${_n(h - y - ph)} cm /Im1 Do Q');
  }

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
    final stream = latin1.encode(_b.toString()), pic = _pic;
    final objs = <List<int>>[
      latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'),
      latin1.encode('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      latin1.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >>${pic == null ? '' : ' /XObject << /Im1 8 0 R >>'} >> >>'),
      [...latin1.encode('<< /Length ${stream.length} >>\nstream\n'), ...stream, ...latin1.encode('\nendstream')],
      latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'),
      latin1.encode('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'),
      latin1.encode('<< /Title (${info(title)}) /Author (${info(author)}) /Producer (RCL attendance app) >>'),
      if (pic != null) [...latin1.encode('<< /Type /XObject /Subtype /Image /Width ${pic.w} /Height ${pic.h} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${pic.jpg.length} >>\nstream\n'), ...pic.jpg, ...latin1.encode('\nendstream')],
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

/// [rules]: the site's rules in words (the HR server's myMonth); [logo]: the picture of the head ([pdfLogo]). A day's `place`
/// is the work place where its IN was marked.
Future<Uint8List> attendancePdf({required String company, required String site, required String name, required String code, required String month, required List<Map> days, required Map total, String made = '', List<String> rules = const [], PdfLogo? logo}) async {
  const ink = 0x111111, muted = 0x555555, navy = 0x0F1F3D, grey = 0xD9DCE3, rule = 0x333333, blue = 0x1D3FBF, red = 0xC22A1B, green = 0x146C2E, amber = 0x8A5A00;
  int hue(String c) => switch (c) { 'P' || 'WOP' || 'HP' || 'IN' => green, 'A' || 'MIS' => red, 'HD' => amber, 'L' || 'H' => blue, _ => muted };
  final (title, period) = pdfMonth(month);
  final p = _Page();
  const double l = 30, r = 565, mid = (l + r) / 2;
  // ---- the head: the logo, the company's name in the middle, what the sheet is
  var room = r - l;
  if (logo != null && logo.w > 0) {
    const lw = 118.0;
    p.picture(logo, l, 30, lw, lw * logo.h / logo.w);
    room = 2 * (mid - (l + lw + 10));
  }
  final firm = pdfWords(company);
  var fs = 17.0;
  while (fs > 11 && pdfWidth(firm, fs, bold: true) > room) {
    fs -= .5;
  }
  p.text(pdfFit(firm, room, fs, bold: true), mid, 46, fs, ink, bold: true, mid: true);
  p.text('Attendance for the Month $title', mid, 63, 11.5, ink, bold: true, mid: true);
  // ---- who, where, which days – and the dark line under them
  p.text('Employee Name :', l, 86, 9.5, ink, bold: true);
  p.text(pdfFit(pdfWords(name), 210, 9.5), l + 82, 86, 9.5, ink);
  p.text('Employee ID :', 330, 86, 9.5, ink, bold: true);
  p.text(pdfWords(code), 396, 86, 9.5, ink);
  p.text('Site :', l, 100, 9.5, ink, bold: true);
  p.text(pdfFit(pdfWords(site), 210, 9.5), l + 82, 100, 9.5, ink);
  p.text('Period :', 330, 100, 9.5, ink, bold: true);
  p.text(period, 396, 100, 9.5, ink);
  p.across(l, 108, r, navy, 1.8);
  // ---- the days, ruled: Date · Day · Work place · In Time · Out Time · Total Hrs · Status · Late
  const cols = <double>[30, 92, 150, 250, 302, 354, 418, 488, 565];
  const heads = ['Date', 'Day', 'Work place', 'In Time', 'Out Time', 'Total Hrs', 'Status', 'Late'];
  double c(int i) => (cols[i] + cols[i + 1]) / 2;
  const top = 116.0, headH = 20.0, rowH = 14.6;
  p.box(l, top, r - l, headH, grey);
  for (var i = 0; i < heads.length; i++) {
    p.text(heads[i], c(i), top + 13.5, 9, ink, bold: true, mid: true);
  }
  var y = top + headH;
  final list = days.length > 31 ? days.sublist(0, 31) : days;
  for (final d in list) {
    final day = '${d['day'] ?? ''}', code0 = '${d['code'] ?? ''}', dt = DateTime.tryParse('${day}T00:00:00Z');
    final late = d['late_min'] is num ? (d['late_min'] as num).round() : 0, base = y + 10.3;
    p.text(_dmy(day), c(0), base, 8.5, ink, mid: true);
    p.text(dt == null ? '' : _week[dt.weekday - 1], cols[1] + 5, base, 8.5, ink);
    p.text(pdfFit(pdfWords(d['place']), cols[3] - cols[2] - 9, 8.5), cols[2] + 5, base, 8.5, ink);
    p.text('${d['in'] ?? ''}', c(3), base, 8.5, ink, mid: true);
    p.text('${d['out'] ?? ''}', c(4), base, 8.5, ink, mid: true);
    p.text(pdfHours(d['in'], d['out']), c(5), base, 8.5, ink, mid: true);
    p.text(pdfFit(_status[code0] ?? code0, cols[7] - cols[6] - 6, 8.5, bold: true), c(6), base, 8.5, hue(code0), bold: true, mid: true);
    p.text(late > 0 ? 'Late $late min' : d['auto'] == true ? 'No OUT' : '', c(7), base, 8.5, red, bold: true, mid: true);
    y += rowH;
    p.across(l, y, r, rule, .4);
  }
  for (final x in cols) {
    p.down(x, top, y, rule, .5);
  }
  p.frame(l, top, r - l, y - top, ink, 1.1);
  p.across(l, top + headH, r, ink, .9);
  // ---- the Summary (left) and the site's rules in words (right)
  String n(Object? v) => v is num ? (v == v.roundToDouble() ? '${v.round()}' : '$v') : '0';
  num num0(Object? v) => v is num ? v : 0;
  y += 10;
  final sy = y;
  const sw = 190.0;
  final items = [('Total Month Days', '${list.length}'), ('Present Days', n(total['P'])), ('Half Days', n(total['HD'])), ('Absent Days', n(total['A'])), ('Leaves', n(total['L'])), ('Weekly off / Holidays', n(num0(total['WO']) + num0(total['H']))), ('Late Marks', n(total['late'])), ('Total Paid Days', n(total['paid']))];
  p.box(l, y, sw, 14, 0xF6D3D0);
  p.text('Summary', l + 5, y + 10, 9, ink, bold: true);
  y += 14;
  for (final it in items) {
    p.text(it.$1, l + 5, y + 10, 8.8, ink, bold: true);
    p.text(it.$2, l + sw - 6, y + 10, 8.8, ink, bold: true, right: true);
    y += 14;
    p.across(l, y, l + sw, rule, .4);
  }
  p.down(l + sw - 50, sy + 14, y, rule, .4);
  p.frame(l, sy, sw, y - sy, ink, .9);
  var low = y;
  final notes = <String>[];
  for (var i = 0; i < rules.length; i++) {
    notes.addAll(pdfWrap(pdfWords('${i + 1}) ${rules[i]}'), r - (l + sw + 12) - 12, 7.6));
  }
  if (notes.isNotEmpty) {
    const nx = l + sw + 12;
    final lines = notes.length > 14 ? notes.sublist(0, 14) : notes, nh = 14 + lines.length * 9.6 + 5;
    p.box(nx, sy, r - nx, 14, 0xCFE3FB);
    p.text('Rules of attendance', nx + 5, sy + 10, 9, ink, bold: true);
    var ny = sy + 14 + 9.2;
    for (final t in lines) {
      p.text(t, nx + 6, ny, 7.6, ink);
      ny += 9.6;
    }
    p.frame(nx, sy, r - nx, nh, ink, .9);
    if (sy + nh > low) low = sy + nh;
  }
  // ---- room to sign: HR · Accounts · Director
  final ly = (low + 46 > 796 ? 796 : low + 46).toDouble();
  const sx = <double>[250, 360, 470], sl = 95.0;
  const who = ['HR', 'Accounts', 'Director'];
  for (var i = 0; i < 3; i++) {
    p.across(sx[i], ly, sx[i] + sl, ink, .8);
    p.text(who[i], sx[i] + sl / 2, ly + 13, 10, ink, bold: true, mid: true);
  }
  // ---- the foot
  p.text(made.isEmpty ? 'Made from the RCL ERP attendance app' : 'Made on $made from the RCL ERP attendance app', l, 826, 7.5, muted);
  p.text('Page 1 of 1', r, 826, 7.5, muted, right: true);
  return p.file('Attendance $title - $name', company);
}
