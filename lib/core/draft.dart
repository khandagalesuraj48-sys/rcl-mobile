/* (3.31.0, asked 20-10-2026: "ISSUE ENTRY KRTANA SAMAJ HALF DATA FEED ZLAY ANI SCREEN CLOSE ZALI NANTR OPEN KEL TR SAGLECH DATA
 * GELEL AST … AS NO HOYLA") A HALF-FILLED ENTRY KEPT ON THE PHONE: what is typed in a new Diesel Issue / Inward / Transfer or a new
 * Log Book entry is kept on this phone a moment after each change; the form opened again brings it back ("Half-filled entry
 * brought back" – "Start new" empties it). Saved, kept for the network, or sent for verification: it is gone. A photo is kept as a
 * file of the phone's own temporary place (it is already on the server – its path is kept). One per site, person and page. */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'api.dart';

class Draft {
  Draft(this.keep, String key) : key = 'draft|$key';
  final Keep keep;
  final String key;
  String _last = '';
  Timer? _t;

  /// The kept entry, or null.
  Future<Map<String, dynamic>?> read() async {
    try {
      final v = await keep.read(key);
      if (v == null || v.isEmpty) return null;
      final m = jsonDecode(v);
      if (m is! Map) return null;
      final d = m.cast<String, dynamic>();
      _last = jsonEncode(Map.of(d)..remove('at'));
      _full = v;
      return d;
    } catch (_) {
      return null;
    }
  }

  String _full = '';

  /// Keeps [m] half a second after the last change (not at every key) with the time it was typed; null = nothing typed – nothing
  /// kept.
  void put(Map<String, dynamic>? m) {
    final j = m == null ? '' : jsonEncode(m);
    if (j == _last) return;
    _last = j;
    _full = m == null ? '' : jsonEncode({...m, 'at': DateTime.now().toUtc().toIso8601String()});
    _t?.cancel();
    final f = _full;
    _t = Timer(const Duration(milliseconds: 500), () => keep.write(key, f.isEmpty ? null : f));
  }

  /// Gone (saved, or "Start new").
  Future<void> clear() async {
    _t?.cancel();
    _last = '';
    _full = '';
    await keep.write(key, null);
  }

  /// The form closes: what waits is written now.
  void close() {
    final t = _t;
    if (t != null && t.isActive) {
      t.cancel();
      keep.write(key, _full.isEmpty ? null : _full);
    }
  }

  String _file(String kind) => '${Directory.systemTemp.path}/rcl_${key.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}_$kind.jpg';

  /// A photo of the entry, kept with it.
  Future<void> putPhoto(String kind, Uint8List jpg) async {
    try {
      await File(_file(kind)).writeAsBytes(jpg, flush: true);
    } catch (_) {/* the photo is taken again */}
  }

  Uint8List? photo(String kind) {
    try {
      final f = File(_file(kind));
      return f.existsSync() ? f.readAsBytesSync() : null;
    } catch (_) {
      return null;
    }
  }
}

/// "6:05 PM" (today) or "19-10 · 6:05 PM" – when the kept entry was typed.
/// (3.62.1, 29-10-2026 – an urgent report: "tyach phone madhun keleli entry disat nahi") the half-filled entry was typed TODAY (the
/// phone's day). Only then its date comes back with it; one kept from an earlier day comes back with TODAY's date – before, its old
/// date came back unseen and every entry of that form was saved on that old day (not in today's list).
bool draftToday(String iso, DateTime now) {
  final t = DateTime.tryParse(iso)?.toLocal();
  return t != null && t.year == now.year && t.month == now.month && t.day == now.day;
}

String draftTime(String iso, DateTime now) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12, mm = t.minute.toString().padLeft(2, '0'), ap = t.hour < 12 ? 'AM' : 'PM';
  final same = t.year == now.year && t.month == now.month && t.day == now.day;
  return '${same ? '' : '${'${t.day}'.padLeft(2, '0')}-${'${t.month}'.padLeft(2, '0')} · '}$h:$mm $ap';
}
