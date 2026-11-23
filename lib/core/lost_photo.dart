/* (3.168.0, asked 23-11-2026: "urgent fix kr employee document upload krtana app madhun photo te add krtana app restart hote") A PHOTO
 * TAKEN WHILE THE PHONE CLOSED THE APP. A phone short of memory may close an app that waits in the background while the camera (or
 * the gallery) is open; when the person comes back the app starts again and the photo seemed lost. It is not: the phone keeps it for
 * the app (image_picker's retrieveLostData, Android). Before the camera opens the screen says what the photo is for ([expect]); when
 * the app starts again ([check], main.dart) the photo is kept here, and that screen offers it ("Attach it?") the next time it opens
 * ([take]). Nothing is sent by itself; nothing is kept when the camera came back as usual ([done]). */
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'api.dart' show Keep;

class LostPhoto {
  /// where "what the photo is for" is kept across a restart (the app's own keep – main.dart); null: nothing is kept (tests)
  static Keep? keep;
  static const _k = 'lost.photo.for';
  static ({String what, String name, Uint8List bytes})? _got;
  static Future<void>? _checking;

  /// Before the camera / gallery opens: what the photo is for – e.g. 'hrdoc:<kind>:<replaces>'.
  static Future<void> expect(String what) async {
    try {
      await keep?.write(_k, what);
    } catch (_) {/* nothing kept: only the recovery is lost */}
  }

  /// The camera / gallery came back to the app as usual: nothing to keep.
  static Future<void> done() async {
    try {
      await keep?.write(_k, null);
    } catch (_) {}
  }

  /// At the start of the app (Android): the photo the phone kept for it, if the app said what it was for.
  static Future<void> check() => _checking ??= _check();

  static Future<void> _check() async {
    if (keep == null || !Platform.isAndroid) return;
    try {
      final what = await keep!.read(_k);
      if (what == null || what.isEmpty) return;
      await keep!.write(_k, null);
      final r = await ImagePicker().retrieveLostData();
      final fs = r.files ?? [if (r.file != null) r.file!];
      if (r.isEmpty || fs.isEmpty) return;
      final f = fs.first;
      _got = (what: what, name: f.name, bytes: await f.readAsBytes());
    } catch (_) {/* nothing found: as before */}
  }

  /// (tests) a photo as if the phone had kept it
  static void put(String what, String name, Uint8List bytes) => _got = (what: what, name: name, bytes: bytes);

  /// The photo kept for a screen whose purpose starts with [prefix] – given once; null when there is none.
  static Future<({String what, String name, Uint8List bytes})?> take(String prefix) async {
    await (_checking ?? Future<void>.value());
    final g = _got;
    if (g == null || !g.what.startsWith(prefix)) return null;
    _got = null;
    return g;
  }
}
