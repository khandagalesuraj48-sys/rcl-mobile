/* (3.84.0, asked 04-11-2026: "app madhech share application asa option de user jewa he dabel to other la whats app aso ki link madhe
 * to share ku shakel dusryala latest version app che … nantr dusra login krel") SHARE APP – Home's ≡ menu: the phone's own share
 * (WhatsApp, a message, e-mail …) with the link of the app's own page – <main address>/app (Mechanical update-210): always the LATEST
 * version to download, the steps to install it, then he signs in with the email and password the Admin gave him. Nothing about the
 * person who shares goes with it. Where the phone / computer cannot share: the link is copied and said so. */
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart' show kMainUrl;

/// The app's own page – the latest version, always.
const kAppPage = '$kMainUrl/app';

/// What is sent – the link and one line in each language.
String appShareText() => 'RCL ERP app – $kAppPage\n\n'
    'नवीन version download करा, install करा आणि Admin ने दिलेला email व password टाकून sign in करा.\n'
    'Download the latest version, install it and sign in with the email and password the Admin gave you.\n'
    'नया version download करें, install करें और Admin का दिया email और password डालकर sign in करें.';

/// The phone's share; false when it cannot share (then the link is copied). Tests put their own here.
Future<bool> Function(String text) appShare = (text) async {
  try {
    final r = await SharePlus.instance.share(ShareParams(text: text, subject: 'RCL ERP app'));
    if (r.status != ShareResultStatus.unavailable) return true;
  } catch (_) {
    // no share here (a computer without it): the link is copied instead
  }
  await Clipboard.setData(ClipboardData(text: text));
  return false;
};
