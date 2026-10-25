/* THE 4 PHOTOS OF A DIESEL ISSUE – the same as the web page (update-85): Dashboard (meter) · Vehicle + driver · Dispenser
 * litres · Register. Each is taken with the camera there and then (never from the gallery), made smaller (1600 px, a JPG of a
 * few hundred KB – the digits stay clear), and the date, time, kind, machinery and the place (latitude, longitude) are printed
 * on a band under it, exactly like the web. It is sent at once (dieselPhoto); the server keeps who sent it, when and where, and
 * the entry takes it when it is saved.
 * (3.19.0) On a computer (Windows): the photo is chosen from a file – as the web does on a computer – and gets the same band;
 * the computer's location (Windows: Settings → Privacy & security → Location) is needed, as for the web. */
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

import 'device.dart';
import 'applock.dart';

class PhotoKind {
  const PhotoKind(this.key, this.en, this.mr, this.pic);
  final String key, en, mr, pic;
}

const kPhotoKinds = [
  PhotoKind('dash', 'Dashboard', 'डॅशबोर्ड', 'mobile_phone'),
  // (3.29.0, Mechanical update-139) only for a machinery measured by KM and Hrs: its hour meter, often not on the dashboard
  PhotoKind('hrs', 'Hour meter', 'तास मीटर', 'gear'),
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
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw PhotoProblem(onComputer ? 'Turn on the location of this computer (Windows Settings › Privacy & security › Location), then choose the photo again.' : 'Turn on the location of the phone (GPS), then take the photo again.');
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
    throw PhotoProblem(onComputer
        ? 'Allow the location for desktop apps (Windows Settings › Privacy & security › Location), then choose the photo again.'
        : 'Allow the location for RCL ERP (Settings › Apps › RCL ERP › Permissions), then take the photo again.');
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
  TakenPhoto(this.jpg, this.at, this.spot, [this.raw = '']);
  final Uint8List jpg;
  final DateTime at;
  final Spot spot;
  /// (3.28.0) the camera's own file, without the band – what the phone reads (ocr.dart); '' = none
  final String raw;
  String get dataUrl => 'data:image/jpeg;base64,${base64Encode(jpg)}';
}

String two(int n) => n.toString().padLeft(2, '0');
String stampOf(DateTime d) => '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

/// Opens the camera (on a computer: the choice of a photo file); returns the stamped JPG, or null when the person went back
/// without a photo.
Future<TakenPhoto?> takePhoto(String label, String machineId) async {
  if (Platform.isAndroid) {
    final st = await Permission.camera.request();
    if (!st.isGranted) throw PhotoProblem('Allow the camera for RCL ERP (Settings › Apps › RCL ERP › Permissions), then try again.');
  }
  final x = await AppLock.whileOutside(() => ImagePicker().pickImage(source: onComputer ? ImageSource.gallery : ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 92, preferredCameraDevice: CameraDevice.rear));
  if (x == null) return null;
  return photoFrom(x, label, machineId);
}

/// (3.29.0) A picture just taken (the phone's camera app, or the app's own live reading – scan.dart) → the photo with its band.
Future<TakenPhoto> photoFrom(XFile x, String label, String machineId) async {
  final spot = await whereNow();
  final at = DateTime.now();
  final raw = await x.readAsBytes();
  final lines = ['${stampOf(at)}  ·  $label  ·  $machineId', 'Lat ${spot.lat.toStringAsFixed(6)}, Long ${spot.lng.toStringAsFixed(6)}${spot.acc > 0 ? '  (± ${spot.acc.round()} m)' : ''}'];
  return TakenPhoto(await stamp(raw, lines), at, spot, x.path);
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

/// A smaller copy for the AI (longest side 1280 px) – it is read faster (as the web: update-87).
Future<String> smallCopy(Uint8List jpg) async => 'data:image/jpeg;base64,${base64Encode(await compute(_small, jpg))}';

Uint8List _small(Uint8List jpg) {
  final im = img.decodeJpg(jpg);
  if (im == null) return jpg;
  final k = 1280 / (im.width > im.height ? im.width : im.height);
  final out = k < 1 ? img.copyResize(im, width: (im.width * k).round(), height: (im.height * k).round(), interpolation: img.Interpolation.average) : im;
  return img.encodeJpg(out, quality: 85);
}

/* (3.1.13, Mechanical update-120, asked 16-10-2026: "diesel inward hote tewa inward bill copy pn add krayche aahet … inward copy
 * eka weli multiple click krun save kru shakel user") THE BILL COPIES OF A DIESEL INWARD – as on the web: from the camera (one
 * after another) or from the gallery (several at once); each made a JPG of at most 2000 px (the writing of the bill stays
 * clear), no band on it. Sent at once (inwardPhoto); the inward takes them when it is saved (at most 10). */
const kBillMax = 10;

/// The camera (one photo) or the gallery (up to [room] at once) → the JPGs, ready to send ([] when the person went back).
Future<List<Uint8List>> pickBills({required bool camera, int room = kBillMax}) async {
  if (room < 1) return [];
  if (onComputer) camera = false; // (3.19.0) a computer: the files
  if (camera && Platform.isAndroid) {
    final st = await Permission.camera.request();
    if (!st.isGranted) throw PhotoProblem('Allow the camera for RCL ERP (Settings › Apps › RCL ERP › Permissions), then try again.');
  }
  final picker = ImagePicker();
  final List<XFile> xs;
  if (camera) {
    final x = await AppLock.whileOutside(() => picker.pickImage(source: ImageSource.camera, maxWidth: 2000, maxHeight: 2000, imageQuality: 92, preferredCameraDevice: CameraDevice.rear));
    xs = [if (x != null) x];
  } else if (room == 1) {
    final x = await AppLock.whileOutside(() => picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, maxHeight: 2000, imageQuality: 92));
    xs = [if (x != null) x];
  } else {
    xs = await AppLock.whileOutside(() => picker.pickMultiImage(maxWidth: 2000, maxHeight: 2000, imageQuality: 92, limit: room));
  }
  final out = <Uint8List>[];
  for (final x in xs.take(room)) {
    out.add(await billJpg(await x.readAsBytes()));
  }
  return out;
}

/// A picture of the bill → a JPG, longest side at most 2000 px, at most about 1.3 MB (the server keeps up to 1.5 MB).
Future<Uint8List> billJpg(Uint8List raw) async {
  final codec = await ui.instantiateImageCodec(raw);
  final frame = await codec.getNextFrame();
  final src = frame.image;
  final sc = 2000 / (src.width > src.height ? src.width : src.height);
  final k = sc < 1 ? sc : 1.0;
  final w = (src.width * k).round(), h = (src.height * k).round();
  final rec = ui.PictureRecorder();
  ui.Canvas(rec).drawImageRect(src, ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.high);
  final out = await rec.endRecording().toImage(w, h);
  final rgba = (await out.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  src.dispose();
  out.dispose();
  return compute(_toBillJpg, _Raw(rgba.buffer.asUint8List(), w, h));
}

Uint8List _toBillJpg(_Raw r) {
  final im = img.Image.fromBytes(width: r.w, height: r.h, bytes: r.bytes.buffer, numChannels: 4);
  var jpg = img.encodeJpg(im, quality: 82);
  if (jpg.length > 700 * 1024) jpg = img.encodeJpg(im, quality: 70);
  if (jpg.length > 1300 * 1024) jpg = img.encodeJpg(im, quality: 55);
  return jpg;
}

/// What a save sends for the bill copies (as the web, update-120): a new inward – the copies added (none: nothing, as before);
/// an edit – the whole list only when it was changed (else the inward keeps its own); copies not read / still being read: nothing.
List<Map<String, String>>? billsForSave({required bool isEdit, required String mode, required bool changed, required List<String> paths}) {
  if (!isEdit) return paths.isEmpty ? null : [for (final p in paths) {'p': p}];
  if (mode == 'edit' && changed) return [for (final p in paths) {'p': p}];
  return null;
}
