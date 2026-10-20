/* (3.28.0) THE TEXT OF A PICTURE, READ ON THE PHONE – Google ML Kit text recognition (the same as the number plate, 3.1.8):
 * no internet, nothing paid, no Gemini; a fraction of a second. What the lines mean: ocr_read.dart.
 * A computer (the Windows app) has no such reader: canOcr is false there and the form works as the web does. */
import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'device.dart';
import 'ocr_read.dart';

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
