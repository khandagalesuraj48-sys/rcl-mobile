/* (3.28.0) THE TEXT OF A PICTURE, READ ON THE PHONE – Google ML Kit text recognition (the same as the number plate, 3.1.8):
 * no internet, nothing paid, no Gemini; a fraction of a second. What the lines mean: ocr_read.dart.
 * A computer (the Windows app) has no such reader: canOcr is false there and the form works as the web does. */
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'device.dart';
import 'ocr_read.dart';
import 'scan_rules.dart';
import 'seven.dart';

/// This device reads pictures itself (an Android phone or an iPhone).
bool get canOcr => !onComputer && (Platform.isAndroid || Platform.isIOS);

TextRecognizer? _reader; // made once, kept: the next picture is read at once

/// The lines of text on a picture – from its file ([path]) or its JPG ([jpg], put in a short-lived file for the reader).
Future<List<OcrLine>> ocrLines({String path = '', Uint8List? jpg}) async {
  if (!canOcr) return const [];
  File? tmp;
  var p = path;
  if (p.isEmpty || !File(p).existsSync()) {
    if (jpg == null) return const [];
    tmp = File('${Directory.systemTemp.path}/rcl_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await tmp.writeAsBytes(jpg, flush: true);
    p = tmp.path;
  }
  try {
    final r = await (_reader ??= TextRecognizer(script: TextRecognitionScript.latin)).processImage(InputImage.fromFilePath(p));
    return [
      for (final b in r.blocks)
        for (final l in b.lines) OcrLine(l.text, left: l.boundingBox.left, top: l.boundingBox.top, width: l.boundingBox.width, height: l.boundingBox.height),
    ];
  } finally {
    if (tmp != null) {
      try {
        await tmp.delete();
      } catch (_) {/* the phone clears its temporary files itself */}
    }
  }
}

/// (3.30.0) The lines of a photo with their numbers read again by their segments (seven.dart) – the photo's file ([path]) or its
/// JPG ([jpg]); in the background (the picture is opened there). A line that is not a clear display stays as ML Kit read it.
Future<List<OcrLine>> sevenOnPhoto(List<OcrLine> lines, {String path = '', Uint8List? jpg}) async {
  if (!lines.any((l) => digitsIn(l.text) >= 2 && l.height >= 8)) return lines;
  Uint8List? bytes = jpg;
  if (path.isNotEmpty && File(path).existsSync()) bytes = await File(path).readAsBytes();
  if (bytes == null) return lines;
  final boxes = [for (final l in lines) <Object>[l.text, l.left, l.top, l.width, l.height]];
  try {
    final texts = await compute(_sevenPhoto, <Object>[bytes, boxes]);
    return [for (var i = 0; i < lines.length; i++) withSeven(lines[i], texts[i])];
  } catch (_) {
    return lines;
  }
}

// (in the background) the picture opened and turned upright, each line's part read
List<String?> _sevenPhoto(List<Object> m) {
  final dec = img.decodeImage(m[0] as Uint8List);
  final boxes = (m[1] as List).cast<List<Object>>();
  if (dec == null) return [for (final _ in boxes) null];
  final im = img.bakeOrientation(dec);
  int at(int x, int y) {
    final p = im.getPixel(x, y);
    return (299 * p.r + 587 * p.g + 114 * p.b) ~/ 1000;
  }

  return [
    for (final b in boxes)
      () {
        final l = OcrLine(b[0] as String, left: b[1] as double, top: b[2] as double, width: b[3] as double, height: b[4] as double);
        final want = digitsIn(l.text);
        if (want < 2 || l.height < 8) return null;
        final r = roiOf(l), g = cropOf(im.width, im.height, at, r.left, r.top, r.width, r.height);
        return g == null ? null : readSeven(g.bytes, g.w, g.h, want: want)?.text;
      }(),
  ];
}
