/* (Mechanical update-155, asked 24-10-2026: "Smart Cache … Smart Data Sync … API Calls आणि Egress कमी करणे")
 * "THE SAME AS YOU HAVE" / ONLY WHAT CHANGED – the app's side of the web page's way (Mechanical server/delta.js; the server is not
 * changed for the app). The app keeps the last answer of each question IN MEMORY ONLY (never on the phone's storage), with its
 * fingerprint. Asked again, it says which one it has; the server works the answer out as always – with the person's access – and
 * answers "the same" (a few bytes), only the parts that changed, or the whole answer. What is rebuilt here is checked against the
 * server's fingerprint (SHA-256); anything that does not match asks again for the whole answer. Emptied at sign-out, at another
 * site and at a new sign-in (Api.forget / keepSite / openSite).
 * rclSplit / rclPatch are word for word Mechanical's delta.CLIENT (the same cut marks "}," and "]," – Dart strings count UTF-16
 * code units like JavaScript's). */
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

/// The answer cut into pieces after every "}," and "]," (the end of a row).
List<String> rclSplit(String t) {
  final out = <String>[];
  var st = 0, p = 0;
  final n = t.length;
  for (var j = 0; j < n; j++) {
    final c = t.codeUnitAt(j);
    if (c == 44 && (p == 125 || p == 93)) {
      out.add(t.substring(st, j + 1));
      st = j + 1;
    }
    p = c;
  }
  if (st < n) out.add(t.substring(st));
  return out;
}

/// The new answer from the one kept [base] and the server's changes [ops] (new text, or [first piece, how many] of the base);
/// null = the changes do not fit this base.
String? rclPatch(String base, Object? ops) {
  if (ops is! List) return null;
  final seg = rclSplit(base);
  final b = StringBuffer();
  for (final o in ops) {
    if (o is String) {
      b.write(o);
    } else if (o is List && o.length == 2 && o[0] is int && o[1] is int && (o[0] as int) >= 0 && (o[1] as int) > 0 && (o[0] as int) + (o[1] as int) <= seg.length) {
      for (var i = o[0] as int; i < (o[0] as int) + (o[1] as int); i++) {
        b.write(seg[i]);
      }
    } else {
      return null;
    }
  }
  return b.toString();
}

/// The server's fingerprint of an answer: SHA-256 of its UTF-8 text, the first 32 hex characters.
String fingerprint(String text) => crypto.sha256.convert(utf8.encode(text)).toString().substring(0, 32);

/// The questions whose answers are kept (the web's list: the heartbeat, get… / rpt… and the other questions – never a save, a
/// photo or a file being sent).
bool keptQuestion(String fn) =>
    fn == 'sync' ||
    RegExp(r'^(get|rpt)[A-Z]').hasMatch(fn) ||
    const {'logDashboard', 'pendingLog', 'logPending', 'billInit', 'vendorLedger', 'vendorOutstanding', 'billSummary', 'dieselHistory', 'boqRateCheck', 'boqMissing', 'logPrintExtra'}.contains(fn);

/// The answers kept in memory: per site and whole question (with the sign-in), at most about [maxChars] characters – the oldest
/// go first; one answer above [maxOne] is not kept.
class KeptAnswers {
  static const maxChars = 6000000, maxOne = 3000000;
  final _m = <String, ({String h, String text})>{};
  int _chars = 0;

  /// how many answers were "the same", only the changes, whole, and rebuilt answers that did not match (for the tests)
  int same = 0, delta = 0, full = 0, mismatch = 0;

  int get length => _m.length;
  int get chars => _chars;

  ({String h, String text})? get(String key) => _m[key];

  void keep(String key, String h, String text) {
    drop(key);
    if (text.length > maxOne) return;
    _m[key] = (h: h, text: text);
    _chars += text.length;
    while (_chars > maxChars && _m.length > 1) {
      final k = _m.keys.first;
      _chars -= _m[k]!.text.length;
      _m.remove(k);
    }
  }

  /// used again: it goes to the end (the newest)
  void touch(String key) {
    final v = _m.remove(key);
    if (v != null) _m[key] = v;
  }

  void drop(String key) {
    final v = _m.remove(key);
    if (v != null) _chars -= v.text.length;
  }

  void clear() {
    _m.clear();
    _chars = 0;
  }
}
