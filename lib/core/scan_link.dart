/* (3.41.0, asked 25-10-2026: "google scanner mobile scanner madhun jari scan kel adhi app kade jaw app nasel tr browser kade ok ani
 * complete process zal shiway madhech cut hou naye") A "Scan with Mobile" QR code of the web (…/scan?cap=<id>.<token>&site=<site>,
 * Mechanical update-160) opens HERE – whoever read it: the phone's own camera, Google Lens (Android opens the link in this app –
 * AndroidManifest, the web's /.well-known/assetlinks.json) or the app's own Scan (screens/label_scan.dart).
 *   – It is kept until it can be opened: after the sign-in (signed out), after his site is open, after the lock is opened.
 *   – The QR code's site: when the phone is at another of HIS sites, that site is opened first by itself (nothing to choose).
 *   – Then the capture screen (screens/attach_box.dart CaptureScreen) – the server checks the person, the site and the code
 *     (capClaim), as before; the link alone opens nothing.
 * Without the app on the phone the link opens in the browser (the web's own page), as before. */
import 'package:flutter/foundation.dart';

import 'attach.dart' show capCode;

/// The site written in the QR code (…&site=T2) – '' when none (a QR code made before update-160).
String capSite(String text) => RegExp(r'[?&]site=([A-Za-z0-9_-]{1,20})(&|$)').firstMatch(text.trim())?.group(1) ?? '';

/// The QR code waiting to be opened (one at a time – the newest wins).
class ScanLink extends ChangeNotifier {
  ScanLink._();
  static final ScanLink i = ScanLink._();

  /// The code (<id>.<token>) and its site; '' = nothing waiting.
  String code = '', site = '';
  String _last = '';

  /// A link or a scanned text: true when it is a "Scan with Mobile" QR code (it is kept until it can be opened).
  bool take(String text) {
    final c = capCode(text);
    if (c.isEmpty) return false;
    if (c == code || c == _last) return true; // (the same link twice – e.g. the first link of the app and its stream): once
    code = c;
    site = capSite(text);
    notifyListeners();
    return true;
  }

  /// Opened (or given up): nothing waiting any more.
  void done() {
    if (code.isEmpty) return;
    _last = code;
    code = '';
    site = '';
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    code = '';
    site = '';
    _last = '';
  }
}
