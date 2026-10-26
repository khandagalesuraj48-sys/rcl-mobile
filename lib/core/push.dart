/* THE APP'S NOTIFICATIONS THROUGH GOOGLE FIREBASE (3.42.0, asked 26-10-2026: "mala app war pratek gostich realtime notification
 * jayla haw app band aso ki chalu app updet pasun te sagle kahi") – at once, whether the app is open or closed (Android).
 *   – Signed in at a site, the phone gives Mechanical its Firebase address (fcmSave – Mechanical update-161 keeps it at the first site,
 *     so EVERY site reaches it); one phone = one person (another person signing in takes it); Sign out takes it off (fcmOff).
 *   – Whatever Mechanical tells the web reaches the phone as a data message (with the site it is from):
 *       ring   a call – its ringtone, "Answer" (the app opens at that site and answers) and "Decline" (said to the caller)
 *       done   answered on another device – the ring stops;  missed – "Missed call from …"
 *       cr     verification and approvals: waiting for you, the next level, approved / rejected, sent back, answered, sent again,
 *              a reminder – pressed: Approvals at that site
 *   – and every phone with the app: "RCL ERP <version> is ready" when a new version is released (the topic rcl-app-update –
 *     release.yml) – pressed: the app opens and offers the update.
 *   – Shown in the app's language (tr). The approvals' notifications use the same numbers as the 15-minute check (alerts.dart), so
 *     one thing is never told twice; that check stays as it was (if Firebase is ever late, nothing is missed).
 *   – While the app is open: a ring of the open site comes on the app's own ring screen (asked now – no notification); another
 *     site's ring, approvals and the rest are shown as notifications; a new version: the app's own "Update".
 * The settings of Firebase (google-services.json) are put in by the build from a GitHub secret – never in this public repository.
 * Without them (the tests, a build without the secret) the app works as before, without these notifications. */
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'lang.dart';

const kPushTopic = 'rcl-app-update';
/// (3.42.0) a new version was told (while the app is open, or its notification pressed): Home asks for the update again
final pushUpdateTick = ValueNotifier<int>(0);
const kPushSent = 'push_sent'; // "<who>|<token>|<day>": this phone was given to Mechanical today (not asked again at every start)

/// One notification to show (or a ring to stop: [cancel]).
class PushNote {
  const PushNote({required this.id, this.title = '', this.body = '', this.channel = 'rcl_approvals', this.payload = '', this.ring = false, this.cancel = -1, this.seen = ''});
  final int id;
  final String title, body, channel, payload;
  /// a call: the ringtone, Answer / Decline
  final bool ring;
  /// the notification to take away first (a ring that has stopped); -1 = none
  final int cancel;
  /// (approvals) the 15-minute check's mark for it: w<id> / r<id> / b<id> – so it is not told again
  final String seen;
}

int _n(String s) => s.hashCode & 0x3fffffff;
/// The number of a call's ring notification (the same for its ring, its stop and its missed).
int pushCallId(String call) => (call.hashCode ^ 0x1b873593) & 0x3fffffff;

String _what(String mode, String page) {
  final w = switch (mode) { 'voice' => 'Voice call', 'video' => 'Video call', 'cam' => 'wants to show you a camera', 'page' => 'wants to show you a page of the app', _ => 'wants to show you a screen' };
  return page.isEmpty ? tr(w) : '${tr(w)} – $page';
}

/// What a Firebase message of Mechanical (or of the release) shows. [myBuild]: this app's build (a release that is not newer: nothing).
/// null = nothing to show.
PushNote? pushNoteOf(Map<String, dynamic> d, {int myBuild = 0}) {
  final t = '${d['t'] ?? ''}', site = '${d['site'] ?? ''}';
  String pay(Map<String, dynamic> m) => jsonEncode({'t': t, 'site': site, ...m});
  switch (t) {
    case 'ring':
      final call = '${d['call'] ?? ''}';
      if (call.isEmpty) return null;
      final name = '${d['name'] ?? ''}';
      return PushNote(id: pushCallId(call), title: tr('$name is calling'), body: _what('${d['mode'] ?? ''}', '${d['page'] ?? ''}'), channel: 'rcl_calls', ring: true,
          payload: pay({'call': call, 'from': '${d['from'] ?? ''}'}));
    case 'done':
      final call = '${d['call'] ?? ''}';
      return call.isEmpty ? null : PushNote(id: -1, cancel: pushCallId(call));
    case 'missed':
      final call = '${d['call'] ?? ''}';
      if (call.isEmpty) return null;
      return PushNote(id: pushCallId(call) ^ 0x5a5a, cancel: pushCallId(call), title: tr('Missed call from ${d['name'] ?? ''}.'), channel: 'rcl_calls_missed', payload: pay({'call': call}));
    case 'cr':
      final id = '${d['id'] ?? ''}', title = '${d['title'] ?? ''}', body = '${d['body'] ?? ''}';
      if (title.isEmpty) return null;
      // the same numbers as the 15-minute check (alerts.dart alertsFrom) for the same thing: told once, never twice
      final (int no, String seen) = id.isEmpty
          ? (_n('cr|$title|$body') ^ 0x77, '')
          : title.startsWith('Reminder from ')
              ? ((id.hashCode ^ 0x2545f491) & 0x3fffffff, 'r$id')
              : title.startsWith('Sent back to you')
                  ? ((id.hashCode ^ 0x5bd1e995) & 0x3fffffff, 'b$id')
                  : RegExp(r'^(Verification – |Sent again for verification|Corrected and sent again|Approval needed)').hasMatch(title)
                      ? (id.hashCode & 0x3fffffff, 'w$id')
                      : (_n('$id|$title') ^ 0x77, '');
      return PushNote(id: no, title: tr(title), body: tr(body), payload: pay({'id': id}), seen: seen);
    case 'upd':
      final b = int.tryParse('${d['build'] ?? ''}') ?? 0, v = '${d['version'] ?? ''}';
      if (v.isEmpty || (myBuild > 0 && b > 0 && b <= myBuild)) return null;
      return PushNote(id: 0x3f0e1, title: tr('RCL ERP $v is ready'), body: tr('Tap to update the app.'), channel: 'rcl_updates', payload: pay({'build': '$b'}));
  }
  return null;
}

/// What a pressed notification asks (its payload, and Answer / Decline of a ring).
class PushTap {
  const PushTap(this.t, this.site, {this.id = '', this.call = '', this.from = '', this.answer = false, this.decline = false});
  final String t, site, id, call, from;
  final bool answer, decline;
  static PushTap? of(String? payload, [String? action]) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final j = jsonDecode(payload);
      if (j is! Map) return null;
      return PushTap('${j['t'] ?? ''}', '${j['site'] ?? ''}', id: '${j['id'] ?? ''}', call: '${j['call'] ?? ''}', from: '${j['from'] ?? ''}', answer: action == 'answer', decline: action == 'decline');
    } catch (_) {
      return null;
    }
  }
}

/// THIS PHONE AT MECHANICAL: given when he is at a site (once a day, or when the address / the person changes); taken off at
/// Sign out. [token]: the phone's Firebase address (null = no Firebase on this phone / in this build).
class PushPhone {
  PushPhone(this.token);
  final Future<String?> Function() token;
  DateTime Function() clock = DateTime.now;

  String _day() => clock().toIso8601String().substring(0, 10);

  Future<void> give(Api api, String who) async {
    try {
      final t = await token();
      if (t == null || t.isEmpty || who.isEmpty) return;
      final mark = '$who|$t|${_day()}';
      if (await api.keep.read(kPushSent) == mark) return;
      final r = await api.call('fcmSave', [{'token': t}]);
      if (r is Map && r['ok'] == true) await api.keep.write(kPushSent, mark);
    } catch (e) {
      debugPrint('notifications: $e'); // (a server before update-161, no network: the next time)
    }
  }

  Future<void> takeOff(Api api) async {
    try {
      final t = await token();
      await api.keep.write(kPushSent, null);
      if (t == null || t.isEmpty) return;
      await api.call('fcmOff', [{'token': t}]).timeout(const Duration(seconds: 3));
    } catch (_) {/* signing out never waits for it */}
  }
}
