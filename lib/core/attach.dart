/* (3.34.0, Mechanical update-153) THE ATTACHMENTS OF A LOG BOOK ENTRY – the web's atOpen / atMake / atEdit in the app:
 * photos (the camera, the gallery) and PDFs (the phone's files) of an entry – at most the site's number (Settings → Rules of the
 * site, 10 unless set). A photo is made ready on the phone – turned upright, at most 1600 px, a JPEG of a few hundred KB – and can be
 * corrected (turned, straightened, the four corners: a cut, or a photo taken at an angle made straight; a suggested cut of the
 * paper is only shown – used when "Use this" is pressed); "Original quality" (bigger) or "Use the original file" (sent as it is,
 * up to 3 MB). Only ONE copy of each photo is ever sent – the corrected one or the original, never both.
 * The files are sent when the entry is saved (uploadAttachment – the same action as the web; the server keeps each file once under
 * its fingerprint, SHA-256); the entry keeps the list ({ sha } of each). The same file twice in one entry is refused here at once.
 * Scan with Mobile: the web's QR code (…/?cap=<id>.<token>) read by the app's scanner opens the capture screen (attach_box.dart). */
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'api.dart';

const int kAttRaw = 3 * 1024 * 1024;
const Map<String, String> kAttKinds = {'image/jpeg': 'JPG', 'image/png': 'PNG', 'application/pdf': 'PDF'};

/// What a file really is, from its first bytes (as the server) – '' = not a photo or a PDF.
String attSniff(Uint8List b) {
  if (b.length > 2 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length > 3 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length > 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46 && b[4] == 0x2D) return 'application/pdf';
  return '';
}

/// The file's fingerprint (SHA-256, as the server keeps it).
String attSha(Uint8List b) => crypto.sha256.convert(b).toString();

String attSize(num n) => n <= 0 ? '' : n >= 1048576 ? '${(n / 1048576).toStringAsFixed(1)} MB' : '${math.max(1, (n / 1024).round())} KB';

/// The correction of a photo: turned (0 / 90 / 180 / 270), straightened (a few degrees), its four corners (0..1 of the turned photo:
/// top-left, top-right, bottom-right, bottom-left; null = the whole photo), original quality, the original file as it is.
class AttEdit {
  const AttEdit({this.rot = 0, this.ang = 0, this.q, this.hq = false, this.orig = false});
  final int rot;
  final double ang;
  final List<List<double>>? q;
  final bool hq, orig;
  bool get none => rot == 0 && ang == 0 && q == null && !hq && !orig;
}

const List<List<double>> kAttFull = [[0, 0], [1, 0], [1, 1], [0, 1]];
bool attIsFull(List<List<double>>? q) => q == null || [for (var i = 0; i < 4; i++) (q[i][0] - kAttFull[i][0]).abs() < .002 && (q[i][1] - kAttFull[i][1]).abs() < .002].every((x) => x);
bool _isRect(List<List<double>> q) => (q[0][1] - q[1][1]).abs() < .002 && (q[3][1] - q[2][1]).abs() < .002 && (q[0][0] - q[3][0]).abs() < .002 && (q[1][0] - q[2][0]).abs() < .002;

/// One attachment: a file the entry has (state 'ok', with its place [p]) or one made here (state 'new' until it is sent).
class AttFile {
  AttFile({this.sha = '', this.p = '', this.mime = 'image/jpeg', this.name = '', this.size = 0, this.by = '', this.at = '', this.url = '', this.state = 'ok', this.src, this.bytes, this.ed = const AttEdit()});
  String sha, p, mime, name, by, at, url, state;
  String err = '', note = '';
  int size;

  /// the file as it came (a photo: what a correction starts from); never sent beside a corrected copy
  Uint8List? src;

  /// what is sent (made ready here)
  Uint8List? bytes;
  AttEdit ed;
  bool get pdf => mime == 'application/pdf';
  bool get sent => state == 'ok' && p.isNotEmpty;
  Map<String, dynamic> get ref => {'sha': sha};

  factory AttFile.kept(Map m) => AttFile(
      sha: '${m['sha'] ?? ''}', p: '${m['p'] ?? ''}', mime: '${m['mime'] ?? 'image/jpeg'}', name: '${m['name'] ?? ''}', size: ((m['size'] as num?) ?? 0).toInt(), by: '${m['by'] ?? ''}', at: '${m['at'] ?? ''}', url: '${m['url'] ?? ''}');
}

/// A list of attachments as the server gives it (getLogEntry → att, getLogAttachments → files).
List<AttFile> attList(Object? v) => [for (final x in (v is List ? v : const [])) if (x is Map && '${x['sha'] ?? ''}'.isNotEmpty) AttFile.kept(x)];

/// The fingerprints of a list (what an entry has).
List<String> attShas(List<AttFile> l) => [for (final f in l) f.sha];

// ---------------------------------------------------------------------------------------------------------------------------------
//  Making a photo ready (in the background: compute) – the same steps as the web's atBase / atWarp / atMake
// ---------------------------------------------------------------------------------------------------------------------------------
img.Image _turned(img.Image im, int rot, double ang, int lim) {
  if (math.max(im.width, im.height) > lim) {
    im = im.width >= im.height ? img.copyResize(im, width: lim, interpolation: img.Interpolation.average) : img.copyResize(im, height: lim, interpolation: img.Interpolation.average);
  }
  final r = ((rot % 360) + 360) % 360;
  if (r != 0) im = img.copyRotate(im, angle: r);
  if (ang.abs() > .01) {
    final a = img.copyRotate(im.convert(numChannels: 4), angle: ang, interpolation: img.Interpolation.linear);
    final bg = img.Image(width: a.width, height: a.height);
    img.fill(bg, color: img.ColorRgb8(255, 255, 255));
    im = img.compositeImage(bg, a);
  }
  return im;
}

img.Image _warp(img.Image src, List<List<double>> q, int max) {
  final sw = src.width, sh = src.height;
  final pts = [for (final p in q) [p[0] * (sw - 1), p[1] * (sh - 1)]];
  double d(List<double> a, List<double> b) => math.sqrt(math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2));
  var w = math.max(d(pts[0], pts[1]), d(pts[3], pts[2])), h = math.max(d(pts[0], pts[3]), d(pts[1], pts[2]));
  final sc = math.min(1.0, max / math.max(w, h));
  final ow = math.max(8, (w * sc).round()), oh = math.max(8, (h * sc).round());
  if (_isRect(q)) {
    final x = pts[0][0].round(), y = pts[0][1].round(), cw = math.max(1, (pts[1][0] - pts[0][0]).round()), ch = math.max(1, (pts[3][1] - pts[0][1]).round());
    final c = img.copyCrop(src, x: x, y: y, width: cw, height: ch);
    return (cw > ow || ch > oh) ? img.copyResize(c, width: ow, height: oh, interpolation: img.Interpolation.average) : c;
  }
  // a photo taken at an angle: every point of the straight picture is looked up in the photo (the four corners' perspective)
  return img.copyRectify(src,
      topLeft: img.Point(pts[0][0], pts[0][1]),
      topRight: img.Point(pts[1][0], pts[1][1]),
      bottomLeft: img.Point(pts[3][0], pts[3][1]),
      bottomRight: img.Point(pts[2][0], pts[2][1]),
      interpolation: img.Interpolation.linear,
      toImage: img.Image(width: ow, height: oh));
}

/// (in compute) the photo as it is sent: a JPEG – [a]: src, rot, ang, q, hq
Uint8List attMakeJpg(Map<String, Object?> a) {
  final src = a['src'] as Uint8List;
  final hq = a['hq'] == true;
  var im = img.decodeImage(src);
  if (im == null) throw ArgumentError('This photo cannot be read – add it again.');
  im = img.bakeOrientation(im);
  final lim = hq ? 3000 : 1600;
  final q = (a['q'] as List?)?.map((p) {
    final l = p as List;
    return [(l[0] as num).toDouble(), (l[1] as num).toDouble()];
  }).toList();
  var out = _turned(im, (a['rot'] as int?) ?? 0, (a['ang'] as double?) ?? 0, hq ? 3000 : 2200);
  if (!attIsFull(q)) out = _warp(out, q!, lim);
  if (math.max(out.width, out.height) > lim) out = out.width >= out.height ? img.copyResize(out, width: lim, interpolation: img.Interpolation.average) : img.copyResize(out, height: lim, interpolation: img.Interpolation.average);
  var jpg = img.encodeJpg(out, quality: hq ? 92 : 82);
  if (!hq && jpg.length > 700 * 1024) jpg = img.encodeJpg(out, quality: 70);
  if (jpg.length > kAttRaw) jpg = img.encodeJpg(out, quality: 60);
  return jpg;
}

/// (in compute) a small picture of the photo turned and straightened – what the correction screen shows: { jpg, w, h }
Map<String, Object> attPreview(Map<String, Object?> a) {
  var im = img.decodeImage(a['src'] as Uint8List);
  if (im == null) throw ArgumentError('This photo cannot be read – add it again.');
  im = _turned(img.bakeOrientation(im), (a['rot'] as int?) ?? 0, (a['ang'] as double?) ?? 0, 1100);
  return {'jpg': img.encodeJpg(im, quality: 85), 'w': im.width, 'h': im.height};
}

/* (in compute) a suggested cut: the paper (or the screen) in the photo – the largest bright part of it, its four farthest corners
 * (Otsu's split of the brightness) – the web's atSuggest. null = nothing clear enough to suggest. */
List<List<double>>? attSuggest(Uint8List jpg) {
  var im = img.decodeImage(jpg);
  if (im == null) return null;
  const n = 160;
  final sc = n / math.max(im.width, im.height);
  im = img.copyResize(im, width: math.max(8, (im.width * sc).round()), height: math.max(8, (im.height * sc).round()), interpolation: img.Interpolation.average);
  final w = im.width, h = im.height, l = Float64List(w * h), hist = List<int>.filled(256, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = im.getPixel(x, y), v = .299 * p.r + .587 * p.g + .114 * p.b;
      l[y * w + x] = v.toDouble();
      hist[v.clamp(0, 255).toInt()]++;
    }
  }
  double sum = 0;
  for (var i = 0; i < 256; i++) {
    sum += i * hist[i];
  }
  double sB = 0, best = 0;
  var wB = 0, th = 128;
  for (var i = 0; i < 256; i++) {
    wB += hist[i];
    if (wB == 0) continue;
    final wF = w * h - wB;
    if (wF == 0) break;
    sB += i * hist[i];
    final mB = sB / wB, mF = (sum - sB) / wF, v = wB * wF * (mB - mF) * (mB - mF);
    if (v > best) {
      best = v;
      th = i;
    }
  }
  final seen = Uint8List(w * h);
  var bestN = 0;
  List<int>? bestPts;
  for (var s0 = 0; s0 < w * h; s0++) {
    if (seen[s0] == 1 || l[s0] <= th) continue;
    final st = <int>[s0], pts = <int>[];
    seen[s0] = 1;
    while (st.isNotEmpty) {
      final p = st.removeLast(), x = p % w, y = p ~/ w;
      pts.add(p);
      for (final nb in [x > 0 ? p - 1 : -1, x < w - 1 ? p + 1 : -1, y > 0 ? p - w : -1, y < h - 1 ? p + w : -1]) {
        if (nb > -1 && seen[nb] == 0 && l[nb] > th) {
          seen[nb] = 1;
          st.add(nb);
        }
      }
    }
    if (pts.length > bestN) {
      bestN = pts.length;
      bestPts = pts;
    }
  }
  if (bestPts == null || bestN < w * h * .12 || bestN > w * h * .93) return null;
  List<int>? tl, tr, br, bl;
  for (final p in bestPts) {
    final x = p % w, y = p ~/ w;
    if (tl == null || x + y < tl[0] + tl[1]) tl = [x, y];
    if (br == null || x + y > br[0] + br[1]) br = [x, y];
    if (tr == null || x - y > tr[0] - tr[1]) tr = [x, y];
    if (bl == null || x - y < bl[0] - bl[1]) bl = [x, y];
  }
  final q = [for (final p in [tl!, tr!, br!, bl!]) [(p[0] / (w - 1)).clamp(0.0, 1.0).toDouble(), (p[1] / (h - 1)).clamp(0.0, 1.0).toDouble()]];
  final area = ((q[0][0] * q[1][1] - q[1][0] * q[0][1]) + (q[1][0] * q[2][1] - q[2][0] * q[1][1]) + (q[2][0] * q[3][1] - q[3][0] * q[2][1]) + (q[3][0] * q[0][1] - q[0][0] * q[3][1])).abs() / 2;
  return area > .1 && area < .95 ? q : null;
}

/// The background work of this file (a photo made ready, its preview, the suggested cut): Flutter's compute – a test runs it at once.
Future<R> Function<M, R>(ComputeCallback<M, R> callback, M message, {String? debugLabel}) attCompute = compute;

/// A file that came in (camera, gallery, files) → an item of the box, made ready to send (a photo: in the background).
Future<AttFile> attTake(Uint8List raw, String name, {AttEdit ed = const AttEdit()}) async {
  final kind = attSniff(raw);
  if (kind.isEmpty) throw ApiError('An attachment must be a photo (JPG or PNG) or a PDF.');
  final f = AttFile(name: name.isEmpty ? (kind == 'application/pdf' ? 'document.pdf' : 'photo.jpg') : name, mime: kind, state: 'make', src: raw, ed: ed);
  return attMake(f);
}

/// (again) the item made ready as its correction says: the original file (a PDF, or "Use the original file"), or the photo made smaller.
Future<AttFile> attMake(AttFile f) async {
  final raw = f.src;
  if (raw == null) return f;
  if (f.pdf || f.ed.orig) {
    if (raw.length > kAttRaw) {
      if (f.ed.orig && !f.pdf) {
        f.ed = AttEdit(rot: f.ed.rot, ang: f.ed.ang, q: f.ed.q, hq: f.ed.hq);
        f.note = 'The original is bigger than 3 MB – it is sent made smaller.';
        return attMake(f);
      }
      throw ApiError('This file is too big (more than 3 MB) – a photo is made smaller by the page; make the PDF smaller (or send it in parts).');
    }
    f.bytes = raw;
    f.mime = attSniff(raw);
  } else {
    final args = <String, Object?>{'src': raw, 'rot': f.ed.rot, 'ang': f.ed.ang, 'q': f.ed.q, 'hq': f.ed.hq};
    f.bytes = await attCompute(attMakeJpg, args);
    f.mime = 'image/jpeg';
  }
  f.sha = attSha(f.bytes!);
  f.size = f.bytes!.length;
  f.p = '';
  f.state = 'new';
  f.err = '';
  return f;
}

/// Sends the files not yet kept (one after the other); '' = all are kept, else what to tell the person.
Future<String> attSendAll(Api api, List<AttFile> files, void Function() changed) async {
  for (final f in files.where((x) => x.state == 'new' || x.state == 'err')) {
    final b = f.bytes;
    if (b == null) {
      f.state = 'err';
      f.err = 'Add this file again.';
      continue;
    }
    f.state = 'send';
    f.err = '';
    changed();
    try {
      final r = ((await api.call('uploadAttachment', [{'data': 'data:${f.mime};base64,${base64Encode(b)}', 'name': f.name}])) as Map).cast<String, dynamic>();
      if (f.sha.isNotEmpty && '${r['sha']}' != f.sha) throw ApiError('The file did not arrive as it was sent – add it again.');
      f.sha = '${r['sha']}';
      f.p = '${r['path'] ?? ''}';
      f.mime = '${r['mime'] ?? f.mime}';
      f.size = ((r['size'] as num?) ?? f.size).toInt();
      f.state = 'ok';
    } catch (e) {
      f.state = 'err';
      f.err = '$e';
    }
    changed();
  }
  final bad = files.where((x) => x.state != 'ok').length;
  return bad == 0 ? '' : '$bad file${bad == 1 ? ' was' : 's were'} not sent (marked !) – save again to try again, or remove ${bad == 1 ? 'it' : 'them'}.';
}

/// A QR code of "Scan with Mobile" (the web's …/?cap=<id>.<token>) → its code; '' = not one.
String capCode(String text) {
  final m = RegExp(r'[?&]cap=([0-9a-f]{32}\.[0-9a-f]{64})(&|$)').firstMatch(text.trim());
  return m == null ? '' : m.group(1)!;
}
