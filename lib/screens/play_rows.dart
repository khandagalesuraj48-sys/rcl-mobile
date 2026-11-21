/* (3.165.0, asked 21-11-2026) THE PLAY STORE'S APP – what Me (the full app and the attendance app) does for its update:
 *  · "Check for update": Google Play is asked; a newer version → Google's own sheet (Update: it downloads while he works on); one
 *    already downloaded → "Install now?" (the app starts again); nothing newer → said so;
 *  · "Auto update": no app can switch the Play Store's auto-update on – the two taps are said and the app's own page in the Play
 *    Store is opened ("app madhe auto updet on kel ki play store war pn on hoyla haway" – this is as near as Android lets an app go).
 * Nothing of it is shown in the app that is given by its file. */
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/lang.dart' show bi;
import '../core/play_update.dart';
import '../ui/widgets.dart';

/// "Check for update" pressed in the Play Store's app.
Future<void> playCheckNow(BuildContext context) async {
  final h = await playLook();
  if (!context.mounted) return;
  switch (h) {
    case PlayHas.none:
      toast(context, bi('You have the newest version.', 'नवीनतम version आहे.'));
    case PlayHas.ready:
      if (await ask(context, bi('Install the update now?', 'Update आत्ता install करायचं?'), bi('The update is downloaded. The app closes and opens again.', 'Update download झालं आहे. App बंद होऊन पुन्हा उघडेल.'), yes: 'Install')) {
        final ok = await playInstall();
        if (!ok && context.mounted) toast(context, bi('The update could not be installed – open the Play Store and update there.', 'Update install झालं नाही – Play Store उघडून तिथे update करा.'), bad: true);
      }
    case PlayHas.there:
      unawaited(playWatch(asked: true));
  }
}

/// "Auto update" pressed: what to tick in the Play Store, then the app's page there.
Future<void> playAutoHelp(BuildContext context) async {
  final go = await ask(
      context,
      'Auto update',
      bi('The Play Store updates the app by itself. Switch it on once:\n\n1. Press "Open Play Store" below.\n2. Press ⋮ at the top right.\n3. Tick "Enable auto update".\n\nAfter that every update comes by itself.',
          'Play Store app स्वतःहून update करतं. एकदाच चालू करा:\n\n1. खाली "Open Play Store" दाबा.\n2. वर उजवीकडे ⋮ दाबा.\n3. "Enable auto update" वर टिक करा.\n\nयानंतर प्रत्येक update आपोआप येईल.'),
      yes: 'Open Play Store',
      no: 'Close');
  if (!go) return;
  final ok = await PlayKit.kit.openStore();
  if (!ok && context.mounted) toast(context, bi('The Play Store could not be opened.', 'Play Store उघडता आलं नाही.'), bad: true);
}
