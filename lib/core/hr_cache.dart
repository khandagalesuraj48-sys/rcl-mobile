/* WHAT THE HR PAGES READ, KEPT ON THE PHONE (3.154.0, asked 21-11-2026: "hr app madhe pn cache data banwayla hawa – new update ala
 * tr new lagech disel, update nasel tr cache data dakhwel, refresh kel ki new yeil … attendance tab nehmi server kadhun data ghetoy
 * … old data disu deu nko"). A page of "My HR" (Home, Attendance, Leave, My documents) shows AT ONCE what it read the last time –
 * no empty page, no turning ring every time a tab is touched – and asks the server in the same moment; the server's answer takes
 * its place as soon as it is there (always – what is kept never wins over the server), and is kept for the next time.
 *   – kept per person and site (the name of the file carries both): one person never sees another's;
 *   – only READS are kept (a month, the leave page, the papers' list, Home's parts). Nothing is ever SENT from here: a punch, a
 *     request, a paper go to the server as before;
 *   – today's own state (IN / OUT) is shown from what is kept only when it is of TODAY – never yesterday's as today's;
 *   – signed out: what is in memory is forgotten.
 * Files: the app's own private folder (AttendKit – the same place as the kept punches). */
import 'dart:convert';

import 'attend.dart' show AttendKit;

class HrCache {
  HrCache._();
  static final Map<String, Map<String, dynamic>> _mem = {};

  /// (3.171.0 patch 4 – SNI picture 5) when each kept answer came from the server – "Saved 10:12 AM" on the page.
  static final Map<String, DateTime> _at = {};

  /// When what is kept for [key] was read from the server (null: not known – kept by an app of before).
  static DateTime? savedAt(String key) => now(key) == null ? null : _at[key];
  static String _who = '';
  static Object? _kit;

  /// The person and the site whose pages are open ("e-mail|site") – set by the HR pages' shell. Another one: memory is cleared.
  static set who(String v) {
    if (v == _who && identical(_kit, AttendKit.kit)) return;
    _who = v;
    _kit = AttendKit.kit;
    _mem.clear();
    _at.clear();
  }

  static String get who => _who;

  static String _file(String key) => 'hrc_${'$_who|$key'.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}.json';

  /// What is kept in memory for [key] – at once, no waiting (null: nothing).
  static Map<String, dynamic>? now(String key) => _who.isEmpty || !identical(_kit, AttendKit.kit) ? null : _mem[key];

  /// What is kept for [key]: memory, else the phone's file (null: nothing, or not readable).
  static Future<Map<String, dynamic>?> read(String key) async {
    final m = now(key);
    if (m != null || _who.isEmpty) return m;
    final who = _who;
    try {
      final t = await AttendKit.kit.readText(_file(key));
      if (t == null || t.isEmpty || who != _who) return null;
      final j = jsonDecode(t);
      if (j is! Map) return null;
      if (_mem[key] != null) return _mem[key]; // (an answer of the server that came meanwhile stays)
      final m = j.cast<String, dynamic>();
      final at = DateTime.tryParse('${m.remove('_savedAt') ?? ''}');
      if (at != null) _at[key] = at.toLocal();
      return _mem[key] = m;
    } catch (_) {
      return null;
    }
  }

  /// The server's answer for [key]: it is what is shown from now on, and what the next opening starts with.
  static void put(String key, Map<String, dynamic> answer) {
    if (_who.isEmpty) return;
    if (!identical(_kit, AttendKit.kit)) {
      _kit = AttendKit.kit;
      _mem.clear();
    }
    _mem[key] = answer;
    final at = DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now());
    _at[key] = at;
    final f = _file(key);
    () async {
      try {
        await AttendKit.kit.writeText(f, jsonEncode({...answer, '_savedAt': at.toUtc().toIso8601String()}));
      } catch (_) {/* not kept on the phone: memory still has it */}
    }();
  }

  /// Signed out: nothing stays in memory.
  static void clear() {
    _mem.clear();
    _at.clear();
    _who = '';
  }
}
