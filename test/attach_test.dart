// (3.34.0, Mechanical update-153) the attachments of a Log Book entry: what a file really is, the QR code of Scan with Mobile, a photo
// made ready (upright, at most 1600 px, turned, cut, a photo taken at an angle made straight), the suggested cut, a bill's annex.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rcl_mobile/core/attach.dart';
import 'package:rcl_mobile/core/bill.dart' show billAttHtml;
import 'package:rcl_mobile/core/scan_link.dart';

/// A "meter photo": a light paper on a dark table.
Uint8List paper(int w, int h) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(30, 41, 59));
  img.fillRect(im, x1: (w * .2).round(), y1: (h * .15).round(), x2: (w * .8).round(), y2: (h * .85).round(), color: img.ColorRgb8(248, 250, 252));
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

void main() {
  test('what a file really is – its first bytes (as the server): JPG, PNG, PDF; a web page is none of them', () {
    expect(attSniff(paper(40, 30)), 'image/jpeg');
    expect(attSniff(Uint8List.fromList(img.encodePng(img.Image(width: 4, height: 4)))), 'image/png');
    expect(attSniff(Uint8List.fromList(utf8.encode('%PDF-1.4\n%%EOF'))), 'application/pdf');
    expect(attSniff(Uint8List.fromList(utf8.encode('<html><script>alert(1)</script>'))), '');
    expect(attSha(Uint8List.fromList(utf8.encode('abc'))), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
  });

  test('Scan with Mobile: only the web\'s QR code …/?cap=<32 hex>.<64 hex> is read; a machinery label is not one', () {
    final c = '${'a' * 32}.${'b' * 64}';
    expect(capCode('https://oneclicksolution-erp.vercel.app/?cap=$c'), c);
    expect(capCode('https://x.test/?m=MH-25&cap=$c'), c);
    expect(capCode('https://x.test/?m=MH-25-AJ-8511'), '');
    expect(capCode('https://x.test/?cap=${'a' * 31}.${'b' * 64}'), '');
    expect(capCode('https://x.test/?cap=${'A' * 32}.${'b' * 64}'), '', reason: 'the server makes lower-case codes only');
  });

  test('(3.41.0 – update-160) the QR code\'s link …/scan?cap=<code>&site=<site>: its code and its site; the same link twice is opened once; not a QR code of the ERP: not taken', () {
    ScanLink.i.reset();
    final c = '${'a' * 32}.${'b' * 64}', u = 'https://oneclicksolution-erp.vercel.app/scan?cap=$c&site=T2';
    expect([capCode(u), capSite(u)], [c, 'T2']);
    expect(capSite('https://oneclicksolution-erp.vercel.app/?cap=$c'), '', reason: 'a QR code made before update-160: no site');
    expect(capSite('https://x.test/scan?cap=$c&site=<b>'), '');
    var n = 0;
    void f() => n++;
    ScanLink.i.addListener(f);
    expect(ScanLink.i.take('https://www.google.com/'), false);
    expect(ScanLink.i.take('https://x.test/?m=MH-25-AJ-8511'), false, reason: 'a machinery label is for the scanner itself');
    expect(ScanLink.i.take(u), true);
    expect([ScanLink.i.code, ScanLink.i.site, n], [c, 'T2', 1]);
    expect(ScanLink.i.take(u), true);
    expect(n, 1, reason: 'the same link again (the link the app was opened with, and its stream): once');
    ScanLink.i.done();
    expect([ScanLink.i.code, ScanLink.i.site, n], ['', '', 2]);
    expect(ScanLink.i.take(u), true);
    expect([ScanLink.i.code, n], ['', 2], reason: 'opened already: not again');
    ScanLink.i.removeListener(f);
    ScanLink.i.reset();
  });

  test('a photo made ready: at most 1600 px, JPEG; turned right it is taller than wide; a cut keeps what the corners hold; a photo taken at an angle is made straight', () {
    final src = paper(2000, 1500);
    final a = img.decodeJpg(attMakeJpg({'src': src, 'rot': 0, 'ang': 0.0, 'q': null, 'hq': false}))!;
    expect([a.width, a.height], [1600, 1200]);
    final r = img.decodeJpg(attMakeJpg({'src': src, 'rot': 90, 'ang': 0.0, 'q': null, 'hq': false}))!;
    expect([r.width, r.height], [1200, 1600]);
    final hq = img.decodeJpg(attMakeJpg({'src': src, 'rot': 0, 'ang': 0.0, 'q': null, 'hq': true}))!;
    expect([hq.width, hq.height], [2000, 1500], reason: 'original quality: not made smaller (up to 3000 px)');
    final c = img.decodeJpg(attMakeJpg({'src': src, 'rot': 0, 'ang': 0.0, 'q': [[.25, .25], [.75, .25], [.75, .75], [.25, .75]], 'hq': false}))!;
    expect(c.width, closeTo(1000, 3));
    expect(c.height, closeTo(750, 3));
    final p = img.decodeJpg(attMakeJpg({'src': src, 'rot': 0, 'ang': 0.0, 'q': [[.22, .17], [.78, .17], [.78, .83], [.22, .83]], 'hq': false}))!;
    final mid = p.getPixel(p.width ~/ 2, p.height ~/ 2), edge = p.getPixel(3, 3);
    expect(mid.r > 200 && edge.r > 200, true, reason: 'inside the paper: light everywhere (the dark table is cut away)');
    final sk = img.decodeJpg(attMakeJpg({'src': src, 'rot': 0, 'ang': 0.0, 'q': [[.2, .15], [.82, .2], [.8, .85], [.18, .8]], 'hq': false}))!;
    expect(sk.width > 1000 && sk.height > 800, true, reason: 'four corners not a rectangle: the perspective is made straight');
    final st = img.decodeJpg(attMakeJpg({'src': paper(800, 600), 'rot': 0, 'ang': 5.0, 'q': null, 'hq': false}))!;
    expect(st.width > 800 && st.height > 600, true, reason: 'straightened: the corners are filled');
    final px = st.getPixel(1, 1);
    expect(px.r > 200 && px.g > 200 && px.b > 200, true, reason: '…with white, not black');
  });

  test('the suggested cut finds the paper (its four corners); a photo without a paper: no suggestion', () {
    final q = attSuggest(paper(800, 600))!;
    expect(q[0][0], closeTo(.2, .03));
    expect(q[0][1], closeTo(.15, .03));
    expect(q[2][0], closeTo(.8, .03));
    expect(q[2][1], closeTo(.85, .03));
    final plain = img.Image(width: 200, height: 100);
    img.fill(plain, color: img.ColorRgb8(120, 120, 120));
    expect(attSuggest(Uint8List.fromList(img.encodeJpg(plain))), isNull);
  });

  test('the four corners: the whole photo is no cut', () {
    expect(attIsFull(null), true);
    expect(attIsFull(kAttFull), true);
    expect(attIsFull(const [[.1, 0], [1, 0], [1, 1], [0, 1]]), false);
    expect(const AttEdit().none, true);
    expect(const AttEdit(rot: 90).none, false);
  });

  test('a list from the server: only items with a fingerprint', () {
    final l = attList([
      {'sha': 'a' * 64, 'p': 'log/aa/${'a' * 64}.jpg', 'mime': 'image/jpeg', 'size': 12, 'name': 'm.jpg', 'by': 'Op', 'at': 'x'},
      {'sha': '', 'p': 'x'},
      'nonsense',
    ]);
    expect(l.length, 1);
    expect([l[0].sha.length, l[0].state, l[0].sent, l[0].pdf, l[0].ref], [64, 'ok', true, false, {'sha': 'a' * 64}]);
    expect(attList(null), isEmpty);
  });

  test('a saved bill\'s annex of files (the web\'s billAttHtml): each file once with its entries, photos shown, a PDF marked, "as submitted"', () {
    final h = billAttHtml({
      'billNo': '7',
      'rev': 0,
      'fixed': true,
      'files': [
        {'sha': 'c' * 64, 'mime': 'image/jpeg', 'name': 'meter.jpg', 'url': 'https://x.test/c.jpg', 'entries': [{'no': 'MH-1', 'date': '2026-10-01', 'shift': 'Day'}, {'no': 'MH-1', 'date': '2026-10-01', 'shift': 'Night'}]},
        {'sha': 'd' * 64, 'mime': 'application/pdf', 'name': 'c.pdf', 'url': '', 'entries': [{'no': 'MH-1', 'date': '2026-10-01', 'shift': 'Day'}]},
      ]
    });
    expect(h, contains('Attachments of the Log Book – RA Bill 7 (2 files)'));
    expect('<figure>'.allMatches(h).length, 2);
    expect(h, contains('<img alt="" src="https://x.test/c.jpg">'));
    expect(h, contains('<div class="ba-pdf">PDF</div>'));
    expect(h, contains('MH-1 · 01-10-2026 · Day<br>MH-1 · 01-10-2026 · Night'));
    expect(h, contains('The files each entry had when the bill was submitted'));
    expect(h, contains('SHA-256 ${'c' * 20}…'));
    expect(billAttHtml({'files': []}), '');
    expect(billAttHtml({'billNo': '8', 'fixed': false, 'files': [{'sha': 'e' * 64, 'mime': 'image/jpeg', 'entries': []}]}), contains('ev-note legacy'));
  });
}
