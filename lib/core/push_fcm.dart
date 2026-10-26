/* (3.42.0) Firebase on the phone – the parts that need its plugins (core/push.dart says what is shown, and is tested without them).
 *   start     the app starts: Firebase with the settings the build put in (none: no notifications of Firebase – the app as before),
 *             every phone listens for a new version (the topic), the address of the phone is read
 *   listen    the app is open: a message is shown (or, for the open site's ring, the app's own ring screen asks now)
 *   tapped    a notification pressed – what it opens waits in ScanLink (the same way as a QR code: sign-in, fingerprint, site)
 *   show      also with the app closed (main.dart pushInBackground): shown in the app's language; approvals marked for the 15-minute
 *             check (alerts.dart) so the same thing is not told again */
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'alerts.dart';
import 'api.dart';
import 'push.dart';
import 'scan_link.dart';
import 'session.dart';
import 'update.dart' show appBuild;

class Fcm {
  static bool on = false;
  static final phone = PushPhone(token);

  static Future<String?> token() async {
    if (!on) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// The app starts (Android): true = Firebase is there. [background]: main.dart's pushInBackground (the app closed).
  static Future<bool> start(Future<void> Function(RemoteMessage m) background) async {
    if (!Platform.isAndroid) return false;
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(background);
      on = true;
    } catch (e) {
      debugPrint('Firebase: $e'); // (a build without its settings: as before)
      return false;
    }
    unawaited(FirebaseMessaging.instance.subscribeToTopic(kPushTopic).catchError((Object _) {}));
    return true;
  }

  /// The session's two moments (session.dart onReady / onSignOut) and the messages while the app is open.
  static void listen(Session s) {
    Session.onReady = (x) => phone.give(x.api, x.email);
    Session.onSignOut = (x) => phone.takeOff(x.api);
    if (s.stage == Stage.ready) unawaited(phone.give(s.api, s.email)); // (the site opened before Firebase was there)
    FirebaseMessaging.onMessage.listen((m) => foreground(s, m.data));
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      if (s.stage == Stage.ready) unawaited(phone.give(s.api, s.email));
    });
  }

  static Future<void> foreground(Session s, Map<String, dynamic> d) async {
    final t = '${d['t'] ?? ''}', site = '${d['site'] ?? ''}';
    final here = s.stage == Stage.ready && (site.isEmpty || s.site?.code == site);
    if ((t == 'ring' || t == 'missed') && here) {
      unawaited(s.liveTick()); // the app's own ring screen / its "missed" – asked now, not at the next beat
      return;
    }
    if (t == 'upd') {
      pushUpdateTick.value++; // Home asks for the update now (its own Update)
      return;
    }
    if (t == 'cr' && here) unawaited(s.liveTick()); // (the lists of Approvals – fresh)
    await show(d, s.api.keep);
  }

  /// Shown – the same with the app closed (main.dart).
  static Future<void> show(Map<String, dynamic> d, Keep keep) async {
    int b = 0;
    try {
      b = await appBuild();
    } catch (_) {}
    final n = pushNoteOf(d, myBuild: b);
    if (n == null) return;
    if (n.seen.isNotEmpty) {
      try {
        final j = jsonDecode(await keep.read(kAlertsSeen) ?? '{}');
        final seen = j is Map ? j.map((k, v) => MapEntry('$k', v)) : <String, dynamic>{};
        seen[n.seen] = DateTime.now().millisecondsSinceEpoch;
        await keep.write(kAlertsSeen, jsonEncode(seen));
      } catch (_) {}
    }
    await Alerts.note(n);
  }

  /// A notification pressed (or its Answer / Decline) while the app runs, or the one it was opened with.
  static void tapped(Session s, PushTap? t) {
    if (t == null) return;
    if (t.t == 'upd') {
      pushUpdateTick.value++;
      return;
    }
    if (t.decline) {
      if (t.call.isNotEmpty && t.from.isNotEmpty) unawaited(decline(s.api, t));
      return;
    }
    ScanLink.i.open(t);
  }

  /// Decline of a ring – said to the one who calls (at the site the phone is signed in at; another site's: the ring only stops).
  static Future<void> decline(Api api, PushTap t) async {
    try {
      if ((t.site.isNotEmpty && (api.site ?? '') != t.site) || (api.token ?? '').isEmpty || api.mechUrl.isEmpty) return;
      await api.call('rtcSend', [
        {'t': 'decline', 'to': [t.from], 'call': t.call, 'd': {'todev': '', 'reply': 0, 'ep': '', 'dev': 'push'}}
      ]);
    } catch (_) {/* the caller sees it as not answered */}
  }
}
