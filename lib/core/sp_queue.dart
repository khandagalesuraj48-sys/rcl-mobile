/* (SP build – local rig) THE FORMATS' OFFLINE QUEUE (D-43): on a weak site network a Save or a Submit of any of the 21 formats made
 * without network waits ON THE PHONE ("Pending") with its own save-once key (rid) and is sent when the network is back → Sent /
 * Failed (why) / Conflict (the document changed on the server meanwhile – the person looks again). The server keeps the first answer
 * of a key, so a send repeated after a lost answer never makes a second document. NEVER QUEUED: a decision (verify / approve / send
 * back / reject) and every action that posts stock (dispatch, receive, reverse …) – those happen only online, on what the server
 * has now. One queue per module, site and person, kept in the phone's own store (Keep). */
import 'dart:convert';

import 'api.dart';

class SpQueue {
  SpQueue(this.keep, String mod, String site, String email) : key = 'spq|$mod|$site|${email.toLowerCase()}';
  final Keep keep;
  final String key;
  static const queued = {'save', 'submit'};

  Future<List<Map<String, dynamic>>> all() async {
    try {
      final v = await keep.read(key);
      if (v == null || v.isEmpty) return [];
      return [for (final x in (jsonDecode(v) as List).whereType<Map>()) x.cast<String, dynamic>()];
    } catch (_) {
      return [];
    }
  }

  Future<void> _put(List<Map<String, dynamic>> l) => keep.write(key, l.isEmpty ? null : jsonEncode(l));

  /// A change made without network: kept with its key; only a Save or a Submit (never a decision or a posting).
  Future<void> add(String action, Map<String, dynamic> body) async {
    if (!queued.contains(action)) throw ApiError('This needs the network – a decision or a stock posting is never kept for later.', code: 'online');
    final l = await all();
    l.removeWhere((x) => x['rid'] == body['rid']);
    l.add({'rid': body['rid'], 'action': action, 'body': body, 'at': DateTime.now().toUtc().toIso8601String(), 'state': 'Pending', 'kind': body['kind'], 'title': body['title'] ?? ''});
    await _put(l);
  }

  Future<void> drop(String rid) async {
    final l = await all();
    l.removeWhere((x) => x['rid'] == rid);
    await _put(l);
  }

  /// Sends what waits, in order. [send] does one (it throws ApiError). Network still down: it stops, the rest waits.
  Future<({int sent, int failed, int conflict, bool offline})> flush(Future<Map<String, dynamic>> Function(Map<String, dynamic> body) send) async {
    final l = await all();
    var sent = 0, failed = 0, conflict = 0;
    var offline = false;
    for (final x in l) {
      if (x['state'] != 'Pending') continue;
      try {
        final r = await send({...(x['body'] as Map).cast<String, dynamic>(), 'action': x['action']});
        x['state'] = 'Sent';
        x['answer'] = {'no': r['no'], 'status': r['status'], 'repeat': r['repeat'] == true};
        sent++;
      } on ApiError catch (e) {
        if (e.code == 'net') {
          offline = true;
          break;
        }
        final stale = e.status == 409 && '${e.data['rule'] ?? ''}' == 'SP_STALE';
        x['state'] = stale ? 'Conflict' : 'Failed';
        x['error'] = e.message;
        if (stale) {
          conflict++;
        } else {
          failed++;
        }
      }
    }
    // what was sent is kept a day (to be seen), then forgotten
    final cut = DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String();
    l.removeWhere((x) => x['state'] == 'Sent' && '${x['at']}'.compareTo(cut) < 0);
    await _put(l);
    return (sent: sent, failed: failed, conflict: conflict, offline: offline);
  }
}
