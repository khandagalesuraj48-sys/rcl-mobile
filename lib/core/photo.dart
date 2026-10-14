/* THE 4 PHOTOS OF A DIESEL ISSUE – the same as the web page (update-85): Dashboard (meter) · Vehicle + driver · Dispenser
 * litres · Register. Each is taken with the camera there and then (never from the gallery), made smaller (1600 px, a JPG of a
 * few hundred KB – the digits stay clear), and the date, time, kind, machinery and the place (latitude, longitude) are printed
 * on a band under it, exactly like the web. It is sent at once (dieselPhoto); the server keeps who sent it, when and where, and
 * the entry takes it when it is saved. */
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class PhotoKind {
  const PhotoKind(this.key, this.en, this.mr, this.pic);
  final String key, en, mr, pic;
}

const kPhotoKinds = [
  PhotoKind('dash', 'Dashboard', 'डॅशबोर्ड', 'mobile_phone'),
  PhotoKind('veh', 'Vehicle + driver', 'गाडी + चालक', 'articulated_lorry'),
  PhotoKind('pump', 'Dispenser litres', 'डिस्पेन्सर लिटर', 'fuel_pump'),
  PhotoKind('reg', 'Register', 'रजिस्टर', 'notebook'),
];

/// Why a photo could not be taken – said to the person as it is.
class PhotoProblem implements Exception {
  PhotoProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

class Spot {
  Spot(this.lat, this.lng, this.acc);
  final double lat, lng, acc;
}

/// Where the phone is now (the photo and the entry carry it).
Future<Spot> whereNow() async {
  if (!await Geolocator.isLocationServiceEnabled()) throw PhotoProblem('Turn on the location of the phone (GPS), then take the photo again.');
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    throw PhotoProblem('Allow the location for RCL ERP (Settings → Apps → RCL ERP → Permissions), then take the photo again.');
  }
  try {
    final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
    return Spot(pos.latitude, pos.longitude, pos.accuracy);
  } on TimeoutException {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return Spot(last.latitude, last.longitude, last.accuracy);
    throw PhotoProblem('The location could not be found – go into the open and try again.');
  }
}

class TakenPhoto {
  TakenPhoto(this.jpg, this.at, this.spot);
  final Uint8List jpg;
  final DateTime at;
  final Spot spot;
  String get dataUrl => 'data:image/jpeg;base64,${base64Encode(jpg)}';
}

String two(int n) => n.toString().padLeft(2, '0');
String stampOf(DateTime d) => '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

/// Opens the camera; returns the stamped JPG, or null when the person went back without a photo.
Future<TakenPhoto?> takePhoto(String label, String machineId) async {
  if (Platform.isAndroid) {
    final st = await Permission.camera.request();
    if (!st.isGranted) throw PhotoProblem('Allow the camera for RCL ERP (Settings → Apps → RCL ERP → Permissions), then try again.');
  }
  final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 92, preferredCameraDevice: CameraDevice.rear);
  if (x == null) return null;
  final spot = await whereNow();
  final at = DateTime.now();
  final raw = await x.readAsBytes();
  final lines = ['${stampOf(at)}  ·  $label  ·  $machineId', 'Lat ${spot.lat.toStringAsFixed(6)}, Long ${spot.lng.toStringAsFixed(6)}${spot.acc > 0 ? '  (± ${spot.acc.round()} m)' : ''}'];
  return TakenPhoto(await stamp(raw, lines), at, spot);
}

/// The picture with the band under it (date, time, kind, machinery; latitude, longitude), as a JPG.
Future<Uint8List> stamp(Uint8List raw, List<String> lines) async {
  final codec = await ui.instantiateImageCodec(raw);
  final frame = await codec.getNextFrame();
  final src = frame.image;
  final sc = 1600 / (src.width > src.height ? src.width : src.height);
  final k = sc < 1 ? sc : 1.0;
  final w = (src.width * k).round(), h = (src.height * k).round();
  final band = (w * .075).round() < 56 ? 56 : (w * .075).round();
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawImageRect(src, ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.high);
  c.drawRect(ui.Rect.fromLTWH(0, h.toDouble(), w.toDouble(), band.toDouble()), ui.Paint()..color = const ui.Color(0xFF111827));
  final fs = band * .32, x = fs * .6;
  void line(String t, double y, ui.FontWeight wt, double size) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: const ui.Color(0xFFFFFFFF), fontSize: size, fontWeight: wt, fontFamily: 'Rubik')), maxLines: 1, ellipsis: '…', textDirection: ui.TextDirection.ltr)
      ..layout(maxWidth: w - 2 * x);
    tp.paint(c, ui.Offset(x, y - tp.height / 2));
  }

  line(lines[0], h + band * .3, ui.FontWeight.w700, fs);
  line(lines[1], h + band * .72, ui.FontWeight.w400, fs * .92);
  final out = await rec.endRecording().toImage(w, h + band);
  final rgba = (await out.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  src.dispose();
  out.dispose();
  return compute(_toJpg, _Raw(rgba.buffer.asUint8List(), w, h + band));
}

class _Raw {
  _Raw(this.bytes, this.w, this.h);
  final Uint8List bytes;
  final int w, h;
}

Uint8List _toJpg(_Raw r) {
  final im = img.Image.fromBytes(width: r.w, height: r.h, bytes: r.bytes.buffer, numChannels: 4);
  var jpg = img.encodeJpg(im, quality: 82);
  if (jpg.length > 700 * 1024) jpg = img.encodeJpg(im, quality: 70);
  return jpg;
}
