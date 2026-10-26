/* NOTIFICATIONS ON THE PHONE (3.1.8, asked 15-10-2026: "jr revert zal tr mahesh la continue hard push notification jatil").
 * From Mechanical's Approvals list (the same one the web shows):
 *   – something new WAITS FOR HIM to approve → one notification for it;
 *   – an entry of his was SENT BACK to him with a question → a notification, and again every 30 minutes until he answers it or
 *     takes it back (Me → Approvals);
 *   – (3.1.11, Mechanical update-118) the sender of an entry that waits for him pressed "Remind" → a notification for each reminder.
 * Asked while the app is open (every live tick that brings "flow") and, with the app closed, by Android every 15 minutes
 * (an Android alarm – Android decides the exact moment; it may wait longer when the phone saves battery). What was told is kept on the
 * phone, so nothing is told twice too soon. */
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';
import 'lang.dart' show tr;
import 'push.dart' show PushNote;

/// What to tell now, from Mechanical's Approvals answer [d]. [seen]: what was told and when (ms) – changed in place.
List<(int, String, String)> alertsFrom(Map d, Map<String, int> seen, int now) {
  final out = <(int, String, String)>[];
  final live = <String>{};
  for (final r in (d['requests'] as List? ?? []).whereType<Map>()) {
    final id = '${r['id'] ?? ''}';
    if (id.isEmpty) continue;
    final what = ((r['summary'] as List?)?.isNotEmpty ?? false) ? '${(r['summary'] as List).first}' : id;
    if (r['canDecide'] == true) {
      live.add('w$id');
      final first = !seen.containsKey('w$id');
      if (first) {
        seen['w$id'] = now;
        out.add((id.hashCode & 0x3fffffff, 'Waiting for your approval – ${r['task'] ?? ''} (${r['by'] ?? ''})', what));
      }
      // (3.1.11) a reminder of its sender: told once for each press (not again for one that came with the first notice)
      final rem = DateTime.tryParse('${r['remindedAt'] ?? ''}')?.millisecondsSinceEpoch;
      if (rem != null) {
        live.add('r$id');
        final last = seen['r$id'];
        if (!first && (last == null ? now - rem < 30 * 60000 : rem > last)) out.add(((id.hashCode ^ 0x2545f491) & 0x3fffffff, 'Reminder from ${r['by'] ?? ''} – ${r['task'] ?? ''} waits for your approval', '$id: $what'));
        seen['r$id'] = rem;
      }
    }
    if (r['canAnswer'] == true) {
      live.add('b$id');
      final last = seen['b$id'];
      if (last == null || now - last >= 30 * 60000) {
        seen['b$id'] = now;
        final rv = (r['reverted'] as Map?) ?? {};
        out.add(((id.hashCode ^ 0x5bd1e995) & 0x3fffffff, 'Sent back to you – answer it: $what', '${rv['by'] ?? ''}: ${rv['note'] ?? ''}'));
      }
    }
  }
  seen.removeWhere((k, _) => !live.contains(k));
  return out;
}

class Alerts {
  static final _n = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  /// (3.42.0) a notification pressed while the app runs (push.dart PushTap); and Decline of a ring with the app closed (main.dart)
  static void Function(NotificationResponse r)? onTap;
  static DidReceiveBackgroundNotificationResponseCallback? onBackgroundTap;

  /// [ask]: ask the person to allow notifications (Android 13 and later), once.
  static Future<void> init({bool ask = false}) async {
    try {
      if (!_ready) {
        await _n.initialize(const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          // (3.19.0) the computer app: Windows' own notifications (while the app is open)
          windows: WindowsInitializationSettings(appName: 'RCL ERP', appUserModelId: 'Rachana.RCLERP', guid: '50cd3324-31ea-41a6-8f01-f79497e4d3f0'),
        ), onDidReceiveNotificationResponse: (r) => onTap?.call(r), onDidReceiveBackgroundNotificationResponse: onBackgroundTap);
        _ready = true;
      }
      if (ask) await _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {/* no notifications on this phone (or in the tests) – the app works without them */}
  }

  static Future<void> show(int id, String title, String body) async {
    try {
      await init();
      await _n.show(id, title, body,
          const NotificationDetails(android: AndroidNotificationDetails('rcl_approvals', 'Approvals', channelDescription: 'Entries waiting for your approval, and entries sent back to you', importance: Importance.high, priority: Priority.high), iOS: DarwinNotificationDetails(), windows: WindowsNotificationDetails()));
    } catch (_) {/* see init */}
  }

  /* (3.42.0) the notifications that come through Firebase (push.dart): a call rings with the phone's ringtone until it is answered,
   * declined or it stops (60 s) – Answer opens the app, Decline is said to the caller; a missed call; approvals (the channel above –
   * told once: a notification with the same number is replaced, not shown again); a new version of the app. */
  static AndroidNotificationDetails _android(PushNote n) => switch (n.channel) {
        'rcl_calls' => AndroidNotificationDetails('rcl_calls', tr('Calls'), channelDescription: 'A call to you – also when the app is closed',
            importance: Importance.max, priority: Priority.max, category: AndroidNotificationCategory.call, fullScreenIntent: true, ongoing: true, autoCancel: false,
            timeoutAfter: 60000, sound: const UriAndroidNotificationSound('content://settings/system/ringtone'), audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT: the ringtone goes on until it is answered / stops
            actions: <AndroidNotificationAction>[
              AndroidNotificationAction('answer', tr('Answer'), showsUserInterface: true, cancelNotification: true),
              AndroidNotificationAction('decline', tr('Decline'), cancelNotification: true),
            ]),
        'rcl_calls_missed' => AndroidNotificationDetails('rcl_calls_missed', tr('Missed calls'), channelDescription: 'A call you did not answer', importance: Importance.high, priority: Priority.high),
        'rcl_updates' => AndroidNotificationDetails('rcl_updates', tr('App updates'), channelDescription: 'A new version of RCL ERP is ready', importance: Importance.high, priority: Priority.high),
        _ => AndroidNotificationDetails('rcl_approvals', 'Approvals', channelDescription: 'Entries waiting for your approval, and entries sent back to you', importance: Importance.high, priority: Priority.high,
            onlyAlertOnce: true, styleInformation: BigTextStyleInformation(n.body)),
      };

  static Future<void> note(PushNote n) async {
    try {
      await init();
      if (n.cancel >= 0) await _n.cancel(n.cancel);
      if (n.id < 0) return;
      await _n.show(n.id, n.title, n.body, NotificationDetails(android: _android(n), iOS: const DarwinNotificationDetails()), payload: n.payload);
    } catch (_) {/* see init */}
  }

  /// (3.42.0) the notification the app was opened with (pressed while the app was closed)
  static Future<NotificationResponse?> launchedWith() async {
    try {
      await init();
      final d = await _n.getNotificationAppLaunchDetails();
      return d != null && d.didNotificationLaunchApp ? d.notificationResponse : null;
    } catch (_) {
      return null;
    }
  }
}

const kAlertsSeen = 'alerts_seen', kMechUrl = 'mech_url', kLiveAt = 'live_at'; // live_at: (update-155) the app was open and asking

/// Tells what is new from the Approvals answer [d] (kept on the phone in [keep]).
Future<void> tellAlerts(Map d, Keep keep) async {
  Map<String, int> seen = {};
  try {
    final j = jsonDecode(await keep.read(kAlertsSeen) ?? '{}');
    if (j is Map) seen = j.map((k, v) => MapEntry('$k', v is num ? v.toInt() : 0));
  } catch (_) {}
  final list = alertsFrom(d, seen, DateTime.now().millisecondsSinceEpoch);
  await keep.write(kAlertsSeen, jsonEncode(seen));
  for (final a in list.take(5)) {
    await Alerts.show(a.$1, a.$2, a.$3);
  }
}

/// With the app closed (an Android alarm): the sign-in kept on the phone asks Mechanical's Approvals list once.
Future<void> backgroundAlerts(Api api) async {
  await api.load();
  api.mechUrl = await api.keep.read(kMechUrl) ?? '';
  if (api.mechUrl.isEmpty || (api.token ?? '').isEmpty) return;
  // (update-155) the app is open and asking by itself (its live sync – it tells what is new): the alarm does not ask as well
  final at = int.tryParse(await api.keep.read(kLiveAt) ?? '') ?? 0;
  if (DateTime.now().millisecondsSinceEpoch - at < 150000) return;
  final d = await api.call('getChangeRequests', [<String, dynamic>{}]);
  if (d is Map) await tellAlerts(d, api.keep);
}
