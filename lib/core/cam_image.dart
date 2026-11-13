/* A FRAME OF THE CAMERA FOR ML KIT (3.117.0) – what the live reading of a meter does (screens/scan.dart), for the face of
 * attendance: Android – NV21 (made from the three planes when the phone gives those); iPhone – BGRA as it comes. The frames
 * come many times a second, so a blink is seen (a photo taken for every look was too slow for it). */
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// The frame as ML Kit reads it; [turn] – how the camera's picture is turned against the screen (the lens's sensorOrientation).
/// null: a kind of frame this phone gives that is not known here.
InputImage? camInput(CameraImage img, int turn) {
  final rot = InputImageRotationValue.fromRawValue(turn) ?? InputImageRotation.rotation270deg;
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
  return InputImage.fromBytes(bytes: nv21, metadata: InputImageMetadata(size: Size(w.toDouble(), h.toDouble()), rotation: rot, format: InputImageFormat.nv21, bytesPerRow: w));
}

// NV21 with row padding: the rows made w bytes long
Uint8List _rows(Uint8List src, int stride, int w, int h) {
  final rows = h + h ~/ 2, out = Uint8List(w * rows);
  for (var y = 0; y < rows; y++) {
    final s = y * stride;
    if (s + w > src.length) break;
    out.setRange(y * w, y * w + w, src, s);
  }
  return out;
}

// YUV 420 in three planes → NV21 (the example of Google ML Kit)
Uint8List _fromPlanes(CameraImage img) {
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
