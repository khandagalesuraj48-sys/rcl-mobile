/* (3.29.0) THE LIVE READING (asked 20-10-2026: "ocr kadhi kadhi kam krte tr kadhi kadhi krt nahi kadhi kahi chukich reading ghete
 * … pont madhe ji reading aste ti point nantrch number show nahi kt dispeser litre cha photo ghetla ki te pn auto ani perfect yet
 * nahiye he sagle adchani fix kr"). The Dashboard, Hour meter and Dispenser litres photos are taken with the app's own camera:
 *   – a box on the screen: the meter's digits (or the dispenser's display) go inside it – only the text in it is read;
 *   – the phone reads it about three times a second (ML Kit, on the phone – no internet, no Gemini), every other look on a softer
 *     copy (the segments of an LED / LCD digit join);
 *   – the reading is shown big as it is read; when the camera has seen the SAME number again and again (scan_rules.dart Votes) the
 *     photo is taken by itself (a short buzz) and the number goes into its box;
 *   – the round button takes the photo at any time (then the best reading so far, or the photo itself is read once more);
 *   – the light (torch) for a dark cabin or the night shift.
 * The photo then gets its band (date, time, kind, machinery, place) and is sent as before. A phone whose camera cannot be opened
 * here: the phone's own camera app, as before (ScanOutcome.failed).
 * (3.31.3, asked 23-10-2026: "jewa user landscap madhe rotate krto tewa pn ha box rotate hoyla hawa") The phone held sideways: this
 * screen stays upright on the phone (as a camera app's), the BOX turns with the phone – across the meter as the person sees it –,
 * the digits are read the way they stand, and the photo is kept as the person saw it (scan_rules.dart turnOf … uprightTurn). */
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as pic;
import 'package:sensors_plus/sensors_plus.dart';

import '../core/format.dart';
import '../core/ocr_read.dart';
import '../core/scan_rules.dart';
import '../core/seven.dart';
import '../ui/t.dart';
import '../ui/theme.dart';

/// What the scanner gives back: the photo's file and the number agreed (null = none); [failed] = the camera could not be opened.
class ScanOutcome {
  const ScanOutcome(this.file, this.value, {this.check = '', this.failed = false});
  const ScanOutcome.failed() : file = null, value = null, check = '', failed = true;
  final XFile? file;
  final double? value;
  final String check;
  final bool failed;
}

/// Opens the scanner. [read] turns the lines in the box into a reading; [unit] is shown after it (km, hr, L).
Future<ScanOutcome?> scanPhoto(BuildContext context, {required String title, required String hint, required String unit, required ScanRead Function(List<OcrLine>) read, bool wide = false}) =>
    Navigator.of(context).push<ScanOutcome>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => ScanScreen(title: title, hint: hint, unit: unit, read: read, wide: wide)));

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.title, required this.hint, required this.unit, required this.read, this.wide = false});
  final String title, hint, unit;
  final ScanRead Function(List<OcrLine>) read;
  final bool wide;
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? cam;
  CameraDescription? lens;
  final reader = TextRecognizer(script: TextRecognitionScript.latin);
  var votes = Votes();
  bool busy = false, done = false, torch = false, slow = false;
  int looks = 0;
  DateTime last = DateTime.fromMillisecondsSinceEpoch(0), opened = DateTime.now();
  double? seen, agreed;
  Timer? slowTimer;
  // (3.31.3) how the phone is held (0 upright, 90 / 270 sideways – scan_rules.dart turnOf), from its accelerometer
  int turn = 0;
  StreamSubscription<AccelerometerEvent>? tilt;

  Guide guideOf(int t) => guideFor(t, wide: widget.wide);

  @override
  void initState() {
    super.initState();
    // (3.31.3) this screen stays upright on the phone; the box turns with the phone instead
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        tilt = accelerometerEventStream().listen((e) {
          final t = turnOf(e.x, e.y, turn);
          if (t == turn || !mounted || done) return;
          setState(() {
            turn = t;
            votes = Votes(); // what was read the other way is not mixed in
            seen = null;
          });
        }, onError: (_) {/* no accelerometer: the box stays upright, as before */});
      } catch (_) {/* no accelerometer: the box stays upright, as before */}
    }
    _open();
    slowTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && agreed == null) setState(() => slow = true);
    });
  }

  Future<void> _open() async {
    try {
      final all = await availableCameras();
      lens = all.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => all.first);
      final c = CameraController(lens!, ResolutionPreset.high, enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      try {
        await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {/* the photo keeps the phone's way up */}
      setState(() => cam = c);
      await c.startImageStream(_look);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(const ScanOutcome.failed());
    }
  }

  // ---------- one look (about three a second) ----------
  void _look(CameraImage img) {
    if (busy || done || !mounted) return;
    final now = DateTime.now();
    if (now.difference(last).inMilliseconds < 300) return;
    last = now;
    busy = true;
    _read(img).whenComplete(() => busy = false);
  }

  Future<void> _read(CameraImage img) async {
    final soft = Platform.isAndroid && looks.isOdd;
    looks++;
    final t = turn; // (3.31.3) the way the phone is held for this look
    final input = _input(img, soft: soft, turn: t);
    if (input == null) return;
    final RecognizedText r;
    try {
      r = await reader.processImage(input);
    } catch (_) {
      return;
    }
    if (!mounted || done || t != turn) return; // (3.31.3) the phone was turned meanwhile: the next look reads it the new way
    // the picture as the reader stood it upright: Android – by the camera's turn less the phone's; iPhone – by the phone's (3.31.3)
    final turned = (Platform.isAndroid ? readTurn(lens?.sensorOrientation ?? 90, t) : uprightTurn(t)) % 180 != 0;
    final w = (turned ? img.height : img.width).toDouble(), h = (turned ? img.width : img.height).toDouble();
    final lines = [
      for (final b in r.blocks)
        for (final l in b.lines) OcrLine(l.text, left: l.boundingBox.left, top: l.boundingBox.top, width: l.boundingBox.width, height: l.boundingBox.height),
    ];
    // (3.30.0) each number's line read again by its segments (an LED / LCD display: "7087.0", not ML Kit's "70820"), in the background
    var guided = inGuide(lines, w, h, guideOf(t));
    final at = _at(img, t), jobs = <List<Object>>[], idx = <int>[];
    if (at != null) {
      for (var i = 0; i < guided.length; i++) {
        final l = guided[i], want = digitsIn(l.text);
        if (want < 2 || l.height < 8) continue;
        final b = roiOf(l), g = cropOf(w.toInt(), h.toInt(), at, b.left, b.top, b.width, b.height);
        if (g == null) continue;
        jobs.add([g.bytes, g.w, g.h, want]);
        idx.add(i);
      }
    }
    if (jobs.isNotEmpty) {
      try {
        final texts = await compute(sevenAll, jobs);
        if (!mounted || done || t != turn) return;
        guided = [...guided];
        for (var j = 0; j < idx.length; j++) {
          guided[idx[j]] = withSeven(guided[idx[j]], texts[j]);
        }
      } catch (_) {/* ML Kit's reading stays */}
    }
    final read = widget.read(guided), seven = guided.any((l) => l.seven);
    final got = ScanRead(read.value, sure: read.sure || (seven && read.value != null), check: read.check);
    final ok = votes.add(got);
    setState(() {
      if (got.value != null) seen = got.value;
      if (ok != null) agreed = ok;
    });
    if (ok != null) _take(ok, votes.check);
  }

  /// (3.30.0) The brightness of the camera's picture at an UPRIGHT point (as ML Kit gives its lines): Android – the NV21's first
  /// plane turned by the camera's own turn; iPhone – from BGRA. null = this picture cannot be read so.
  /// (3.31.3) The phone held sideways ([turn]): Android – the camera's turn less the phone's; iPhone – turned by the phone's.
  int Function(int x, int y)? _at(CameraImage img, int turn) {
    final sw = img.width, sh = img.height;
    if (Platform.isIOS) {
      if (img.planes.isEmpty) return null;
      final p = img.planes.first, b = p.bytes, row = p.bytesPerRow;
      int px(int x, int y) {
        final i = y * row + x * 4;
        return i + 2 < b.length ? (299 * b[i + 2] + 587 * b[i + 1] + 114 * b[i]) ~/ 1000 : 0;
      }

      final rot = uprightTurn(turn);
      if (rot == 0) return px; // upright: as before
      return (x, y) {
        final int xs, ys;
        switch (rot) {
          case 90:
            xs = y;
            ys = sh - 1 - x;
          case 270:
            xs = sw - 1 - y;
            ys = x;
          default:
            xs = sw - 1 - x;
            ys = sh - 1 - y;
        }
        return xs < 0 || ys < 0 || xs >= sw || ys >= sh ? 0 : px(xs, ys);
      };
    }
    final y0 = _luma;
    if (y0 == null || y0.length < sw * sh) return null;
    final rot = readTurn(lens?.sensorOrientation ?? 90, turn);
    return (x, y) {
      final int xs, ys;
      switch (rot) {
        case 90:
          xs = y;
          ys = sh - 1 - x;
        case 270:
          xs = sw - 1 - y;
          ys = x;
        case 180:
          xs = sw - 1 - x;
          ys = sh - 1 - y;
        default:
          xs = x;
          ys = y;
      }
      return xs < 0 || ys < 0 || xs >= sw || ys >= sh ? 0 : y0[ys * sw + xs];
    };
  }

  Uint8List? _luma; // (3.30.0) the frame's brightness, before it is softened

  /// The camera's picture for the reader: Android – NV21 (made from the three planes when the phone gives those; every other look
  /// softened); iPhone – BGRA as it comes.
  InputImage? _input(CameraImage img, {bool soft = false, int turn = 0}) {
    // (3.31.3) the phone held sideways: the picture is stood up the way the person sees it (upright: the camera's own turn, as before)
    final rot = InputImageRotationValue.fromRawValue(readTurn(lens?.sensorOrientation ?? 90, turn)) ?? InputImageRotation.rotation90deg;
    if (Platform.isIOS) {
      if (img.planes.isEmpty) return null;
      final p = img.planes.first;
      return InputImage.fromBytes(bytes: p.bytes, metadata: InputImageMetadata(size: Size(img.width.toDouble(), img.height.toDouble()), rotation: rot, format: InputImageFormat.bgra8888, bytesPerRow: p.bytesPerRow));
    }
    final w = img.width, h = img.height;
    Uint8List nv21;
    if (img.planes.length == 1 && img.planes.first.bytesPerRow == w) {
      nv21 = img.planes.first.bytes;
    } else if (img.planes.length == 1) {
      nv21 = _rows(img.planes.first.bytes, img.planes.first.bytesPerRow, w, h);
    } else if (img.planes.length == 3) {
      nv21 = _fromPlanes(img);
    } else {
      return null;
    }
    _luma = nv21;
    if (soft) nv21 = blurLuma(nv21, w, h);
    return InputImage.fromBytes(bytes: nv21, metadata: InputImageMetadata(size: Size(w.toDouble(), h.toDouble()), rotation: rot, format: InputImageFormat.nv21, bytesPerRow: w));
  }

  // NV21 with row padding: the rows made w bytes long
  static Uint8List _rows(Uint8List src, int stride, int w, int h) {
    final rows = h + h ~/ 2, out = Uint8List(w * rows);
    for (var y = 0; y < rows; y++) {
      final s = y * stride;
      if (s + w > src.length) break;
      out.setRange(y * w, y * w + w, src, s);
    }
    return out;
  }

  // YUV 420 in three planes → NV21 (the example of Google ML Kit)
  static Uint8List _fromPlanes(CameraImage img) {
    final w = img.width, h = img.height, ySize = w * h, out = Uint8List(ySize + ySize ~/ 2);
    final yp = img.planes[0], up = img.planes[1], vp = img.planes[2];
    var d = 0;
    for (var row = 0; row < h; row++) {
      out.setRange(d, d + w, yp.bytes, row * yp.bytesPerRow);
      d += w;
    }
    final us = up.bytesPerPixel ?? 1, vs = vp.bytesPerPixel ?? 1;
    var uv = ySize;
    for (var row = 0; row < h ~/ 2; row++) {
      for (var col = 0; col < w ~/ 2; col++) {
        final ui0 = row * up.bytesPerRow + col * us, vi0 = row * vp.bytesPerRow + col * vs;
        if (vi0 >= vp.bytes.length || ui0 >= up.bytes.length) continue;
        out[uv++] = vp.bytes[vi0];
        out[uv++] = up.bytes[ui0];
      }
    }
    return out;
  }

  // ---------- the photo ----------
  Future<void> _take(double? value, String check) async {
    final c = cam;
    if (done || c == null) return;
    done = true;
    if (value != null) HapticFeedback.mediumImpact();
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {/* it stops with the camera */}
    try {
      final t = turn; // (3.31.3) the way the phone is held at the shutter
      var f = await c.takePicture();
      if (torch) {
        try {
          await c.setFlashMode(FlashMode.off);
        } catch (_) {/* off with the camera */}
      }
      if (t != 0) f = await _asSeen(f, t);
      if (mounted) Navigator.of(context).pop(ScanOutcome(f, value, check: check));
    } catch (_) {
      if (mounted) Navigator.of(context).pop(const ScanOutcome.failed());
    }
  }

  /// (3.31.3) The photo of a phone held sideways, turned to stand as the person saw it (the camera keeps it upright on the phone);
  /// in the background. Anything wrong: the photo as it came.
  Future<XFile> _asSeen(XFile f, int t) async {
    try {
      final out = await compute(_turnJpg, <Object>[await f.readAsBytes(), uprightTurn(t)]);
      if (out == null) return f;
      final file = File('${Directory.systemTemp.path}/rcl_scan_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await file.writeAsBytes(out, flush: true);
      return XFile(file.path, mimeType: 'image/jpeg');
    } catch (_) {
      return f;
    }
  }

  Future<void> _torch() async {
    final c = cam;
    if (c == null) return;
    try {
      await c.setFlashMode(torch ? FlashMode.off : FlashMode.torch);
      setState(() => torch = !torch);
    } catch (_) {/* no light on this phone */}
  }

  @override
  void dispose() {
    slowTimer?.cancel();
    tilt?.cancel();
    SystemChrome.setPreferredOrientations(const []); // (3.31.3) the rest of the app turns with the phone again, as before
    final c = cam;
    cam = null;
    if (c != null) {
      () async {
        try {
          if (c.value.isStreamingImages) await c.stopImageStream();
        } catch (_) {/* closing */}
        await c.dispose();
      }();
    }
    reader.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = cam, v = agreed ?? seen;
    return Scaffold(
      key: const Key('scan-screen'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(children: [
              IconButton(tooltip: tr('Close'), onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
              Expanded(child: Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(key: const Key('scan-light'), tooltip: tr('Light'), onPressed: c == null ? null : _torch, icon: Icon(torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: torch ? C.amber : Colors.white)),
            ]),
          ),
          Expanded(
            child: Center(
              child: c == null || !c.value.isInitialized
                  ? const CircularProgressIndicator(color: Colors.white)
                  : CameraPreview(c, child: CustomPaint(key: Key('scan-box-$turn'), painter: _GuidePainter(guideOf(turn), turn, agreed != null))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Text(widget.hint, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          SizedBox(
            height: 46,
            child: Center(
              child: Text(
                v == null ? (slow ? 'Not read yet – come closer, keep it still, or press the button and type it.' : 'Looking for the reading…') : '${fmtNum(v)} ${widget.unit}',
                key: const Key('scan-value'),
                textAlign: TextAlign.center,
                style: TextStyle(color: agreed != null ? C.green : (v == null ? Colors.white60 : Colors.white), fontSize: v == null ? 14 : 30, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 0, 18),
            child: GestureDetector(
              key: const Key('scan-shutter'),
              onTap: c == null || done ? null : () => _take(votes.best, votes.check),
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                padding: const EdgeInsets.all(5),
                child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: agreed != null ? C.green : Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The box: the picture outside it darker, its border green once the reading is agreed. (3.31.3) [turn] = how the phone is held:
/// sideways the box is drawn across the meter as the person sees it (scan_rules.dart guideOnScreen).
class _GuidePainter extends CustomPainter {
  _GuidePainter(this.g, this.turn, this.ok);
  final Guide g;
  final int turn;
  final bool ok;
  @override
  void paint(Canvas canvas, Size size) {
    final b = guideOnScreen(g, size.width, size.height, turn);
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(b.left, b.top, b.width, b.height), const Radius.circular(14));
    final outside = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(r));
    canvas.drawPath(outside, Paint()..color = const Color(0x8C000000));
    canvas.drawRRect(r, Paint()
      ..color = ok ? C.green : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.ok != ok || old.g != g || old.turn != turn;
}

/// (3.31.3, in the background) a JPG turned [m][1] degrees clockwise after its own EXIF turn; null = it could not be opened.
Uint8List? _turnJpg(List<Object> m) {
  final dec = pic.decodeJpg(m[0] as Uint8List);
  if (dec == null) return null;
  final up = pic.copyRotate(pic.bakeOrientation(dec), angle: m[1] as int);
  return pic.encodeJpg(up, quality: 92);
}
