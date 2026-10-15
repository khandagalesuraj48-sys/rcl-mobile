/* NOTIFICATIONS ON THE PHONE (3.1.8, asked 15-10-2026: "jr revert zal tr mahesh la continue hard push notification jatil").
 * From Mechanical's Approvals list (the same one the web shows):
 *   – something new WAITS FOR HIM to approve → one notification for it;
 *   – an entry of his was SENT BACK to him with a question → a notification, and again every 30 minutes until he answers it or
 *     takes it back (Me → Approvals).
 * Asked while the app is open (every live tick that brings "flow") and, with the app closed, by Android every 15 minutes
 * (an Android alarm – Android decides the exact moment; it may wait longer when the phone saves battery). What was told is kept on the
 * phone, so nothing is told twice too soon. */
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

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
      if (!seen.containsKey('w$id')) {
        seen['w$id'] = now;
        out.add((id.hashCode & 0x3fffffff, 'Waiting for your approval – ${r['task'] ?? ''} (${r['by'] ?? ''})', what));
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

  /// [ask]: ask the person to allow notifications (Android 13 and later), once.
  static Future<void> init({bool ask = false}) async {
    try {
      if (!_ready) {
        await _n.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()));
        _ready = true;
      }
      if (ask) await _n.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {/* no notifications on this phone (or in the tests) – the app works without them */}
  }

  static Future<void> show(int id, String title, String body) async {
    try {
      await init();
      await _n.show(id, title, body,
          const NotificationDetails(android: AndroidNotificationDetails('rcl_approvals', 'Approvals', channelDescription: 'Entries waiting for your approval, and entries sent back to you', importance: Importance.high, priority: Priority.high), iOS: DarwinNotificationDetails()));
    } catch (_) {/* see init */}
  }
}

const kAlertsSeen = 'alerts_seen', kMechUrl = 'mech_url';

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
  final d = await api.call('getChangeRequests', [<String, dynamic>{}]);
  if (d is Map) await tellAlerts(d, api.keep);
}
